import CairnApp
import Foundation

/// Opens the core's sealed SQLDelight rows (ADR 0006, ADR 0035).
enum RowStorage {
    static let name = "cairn.db"

    /// SQLiter's default iOS database directory.
    static func appDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("databases")
    }

    /// Without a database this is a fresh install, so Keychain items that survived an uninstall are deleted first.
    static func open(directory: URL, service: String) throws -> SealedRows {
        if !FileManager.default.fileExists(atPath: directory.appendingPathComponent(name).path) {
            KeychainRowSealer.deleteKeys(service: service)
        }
        try prepare(directory: directory)
        let sealer = try KeychainRowSealer(service: service)
        let driver = NativeSqliteDriver(
            schema: RowDatabaseCompanion.shared.Schema,
            name: name,
            maxReaderConnections: 1,
            onConfiguration: { configuration in
                configuration.doCopy(
                    name: configuration.name,
                    version: configuration.version,
                    create: configuration.create,
                    upgrade: configuration.upgrade,
                    inMemory: configuration.inMemory,
                    journalMode: configuration.journalMode,
                    extendedConfig: configuration.extendedConfig.doCopy(
                        foreignKeyConstraints: configuration.extendedConfig.foreignKeyConstraints,
                        busyTimeout: configuration.extendedConfig.busyTimeout,
                        pageSize: configuration.extendedConfig.pageSize,
                        basePath: directory.path,
                        synchronousFlag: configuration.extendedConfig.synchronousFlag,
                        recursiveTriggers: configuration.extendedConfig.recursiveTriggers,
                        lookasideSlotSize: configuration.extendedConfig.lookasideSlotSize,
                        lookasideSlotCount: configuration.extendedConfig.lookasideSlotCount
                    ),
                    loggingConfig: configuration.loggingConfig,
                    lifecycleConfig: configuration.lifecycleConfig,
                    encryptionConfig: configuration.encryptionConfig
                )
            },
            callbacks: KotlinArray(size: 0) { _ in nil }
        )
        return SealedRows(store: SealedRowStore(driver: driver, sealer: sealer), driver: driver)
    }

    private static func prepare(directory: URL) throws {
        let protection = [FileAttributeKey.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: protection)
        try FileManager.default.setAttributes(protection, ofItemAtPath: directory.path)
        var directory = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try directory.setResourceValues(values)
    }
}

/// The sealed rows of one open database.
final class SealedRows: NSObject, Rows {
    private let store: SealedRowStore
    private let driver: NativeSqliteDriver

    fileprivate init(store: SealedRowStore, driver: NativeSqliteDriver) {
        self.store = store
        self.driver = driver
    }

    func commit(actions: [Action]) {
        store.commit(actions: actions)
    }

    func restore() -> Restored {
        store.restore()
    }

    func wipe() {
        store.wipe()
    }

    func close() {
        driver.close()
    }
}
