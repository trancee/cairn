import CairnApp
@testable import CairnIos
import Foundation
import Security
import XCTest

private let clock = Clock(monoMs: 1_000, unixS: 1_761_177_600)

final class KeychainRowSealerTests: XCTestCase {
    private var service = ""

    override func setUp() {
        service = "ch.trancee.cairn.test.\(UUID().uuidString)"
    }

    override func tearDown() {
        KeychainRowSealer.deleteKeys(service: service)
    }

    func testASealedRowOpensUnderItsAad() throws {
        let sealer = try KeychainRowSealer(service: service)
        let plaintext = Data("row".utf8).kotlin

        let sealed = sealer.seal(aad: Data("slot".utf8).kotlin, plaintext: plaintext)

        XCTAssertEqual(Int(sealed.size), 12 + 3 + 16)
        XCTAssertEqual(sealer.open(aad: Data("slot".utf8).kotlin, sealed: sealed)?.data, Data("row".utf8))
    }

    func testEverySealDrawsAFreshNonce() throws {
        let sealer = try KeychainRowSealer(service: service)

        let first = sealer.seal(aad: Data().kotlin, plaintext: Data("row".utf8).kotlin).data
        let second = sealer.seal(aad: Data().kotlin, plaintext: Data("row".utf8).kotlin).data

        XCTAssertNotEqual(first.prefix(12), second.prefix(12))
    }

    func testAnotherAadATamperedOrAShortRowDoesNotOpen() throws {
        let sealer = try KeychainRowSealer(service: service)
        let sealed = sealer.seal(aad: Data("slot".utf8).kotlin, plaintext: Data("row".utf8).kotlin).data
        var tampered = sealed
        tampered[tampered.count - 1] ^= 1

        XCTAssertNil(sealer.open(aad: Data("other".utf8).kotlin, sealed: sealed.kotlin))
        XCTAssertNil(sealer.open(aad: Data("slot".utf8).kotlin, sealed: tampered.kotlin))
        XCTAssertNil(sealer.open(aad: Data("slot".utf8).kotlin, sealed: sealed.prefix(27).kotlin))
    }

    func testTheKeyLivesInADeviceOnlyKeychainItemUntilDeleted() throws {
        let sealed = try KeychainRowSealer(service: service)
            .seal(aad: Data().kotlin, plaintext: Data("row".utf8).kotlin)

        let reopened = try KeychainRowSealer(service: service).open(aad: Data().kotlin, sealed: sealed)
        KeychainRowSealer.deleteKeys(service: service)
        let replaced = try KeychainRowSealer(service: service).open(aad: Data().kotlin, sealed: sealed)

        XCTAssertEqual(reopened?.data, Data("row".utf8))
        XCTAssertNil(replaced)
        XCTAssertEqual(accessibility(service: service), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }
}

final class RowStorageTests: XCTestCase {
    private var service = ""
    private var directory = URL(fileURLWithPath: "/")
    private var opened: [SealedRows] = []

    override func setUpWithError() throws {
        service = "ch.trancee.cairn.test.\(UUID().uuidString)"
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        opened.forEach { $0.close() }
        KeychainRowSealer.deleteKeys(service: service)
        try? FileManager.default.removeItem(at: directory)
    }

    func testRowsSurviveReopeningTheDatabase() throws {
        let first = StorageCheckKt.checkStorage(rows: try open(), clock: clock)

        let second = StorageCheckKt.checkStorage(rows: try open(), clock: clock)

        XCTAssertEqual(first, "storage=new device=stored")
        XCTAssertEqual(second, "storage=restored device=stored")
    }

    func testAFreshInstallDeletesKeysThatSurvivedAnUninstall() throws {
        let stale = try KeychainRowSealer(service: service)
            .seal(aad: Data().kotlin, plaintext: Data("row".utf8).kotlin)

        _ = try open()

        XCTAssertNil(try KeychainRowSealer(service: service).open(aad: Data().kotlin, sealed: stale))
    }

    func testALostKeyResetsTheStoredRows() throws {
        _ = StorageCheckKt.checkStorage(rows: try open(), clock: clock)
        KeychainRowSealer.deleteKeys(service: service)

        let status = StorageCheckKt.checkStorage(rows: try open(), clock: clock)

        XCTAssertEqual(status, "storage=reset device=stored")
    }

    func testWipeDeletesTheStoredRows() throws {
        _ = StorageCheckKt.checkStorage(rows: try open(), clock: clock)
        let rows = try open()

        rows.wipe()

        XCTAssertNil(rows.restore().event.device)
    }

    func testTheDatabaseDirectoryIsExcludedFromBackup() throws {
        _ = StorageCheckKt.checkStorage(rows: try open(), clock: clock)

        let values = try directory.resourceValues(forKeys: [.isExcludedFromBackupKey])

        XCTAssertEqual(values.isExcludedFromBackup, true)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appendingPathComponent(RowStorage.name).path))
    }

    private func open() throws -> SealedRows {
        let rows = try RowStorage.open(directory: directory, service: service)
        opened.append(rows)
        return rows
    }

    func testTheAppDatabaseLivesInApplicationSupport() throws {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)

        XCTAssertEqual(try RowStorage.appDirectory(), support.appendingPathComponent("databases"))
    }
}

private func accessibility(service: String) -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecReturnAttributes as String: true,
    ]
    var item: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
    return (item as? [String: Any])?[kSecAttrAccessible as String] as? String
}
