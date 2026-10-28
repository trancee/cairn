import CairnApp
import CryptoKit
import Foundation
import Security

/// Seals rows with AES-256-GCM under a random key kept in a device-only Keychain item (ADR 0006, ADR 0035).
final class KeychainRowSealer: NSObject, RowSealer {
    static let account = "row-master-key"

    private static let overhead = 12 + 16

    private let key: SymmetricKey

    init(service: String) throws {
        key = SymmetricKey(data: try Self.loadKey(service: service) ?? Self.createKey(service: service))
    }

    func seal(aad: KotlinByteArray, plaintext: KotlinByteArray) -> KotlinByteArray {
        // A random 96-bit nonce and a valid key cannot fail to seal.
        // swiftlint:disable:next force_try
        try! AES.GCM.seal(plaintext.data, using: key, authenticating: aad.data).combined!.kotlin
    }

    func open(aad: KotlinByteArray, sealed: KotlinByteArray) -> KotlinByteArray? {
        let bytes = sealed.data
        guard bytes.count >= Self.overhead,
              let box = try? AES.GCM.SealedBox(combined: bytes),
              let plaintext = try? AES.GCM.open(box, using: key, authenticating: aad.data)
        else { return nil }
        return plaintext.kotlin
    }

    /// Deletes every row key under [service]; rows sealed with them can no longer open.
    static func deleteKeys(service: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ] as CFDictionary)
    }

    private static func loadKey(service: String) throws -> Data? {
        var item: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
        ] as CFDictionary, &item)
        switch status {
        case errSecSuccess: return item as? Data
        case errSecItemNotFound: return nil
        default: throw KeychainError(status: status)
        }
    }

    private static func createKey(service: String) throws -> Data {
        let key = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let status = SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: key,
        ] as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        return key
    }
}

struct KeychainError: Error, Equatable {
    let status: OSStatus
}
