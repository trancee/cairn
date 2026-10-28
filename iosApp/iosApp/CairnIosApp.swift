import CairnApp
import Foundation
import SwiftUI

/// Runs the shared core and sealed-storage self-test at launch, like Android's `CoreStatusInstrumentation`.
/// With the `-selfTest` launch argument it prints the verdict and exits 0 on PASS, 1 on FAIL.
/// Storage reports `new` on the first launch and `restored` after; `reset` or a missing device row fails.
@main
struct CairnIosApp: App {
    private let verdict: String

    init() {
        let status = CoreStatusKt.coreStatus()
        let storage = Self.storageStatus()
        let passed = status == CoreStatusKt.EXPECTED_CORE_STATUS
            && (storage == "storage=new device=stored" || storage == "storage=restored device=stored")
        verdict = passed
            ? "PASS: \(status) \(storage)"
            : "FAIL: expected '\(CoreStatusKt.EXPECTED_CORE_STATUS)' and stored rows, got '\(status)' '\(storage)'"
        NSLog("%@", verdict)
        if ProcessInfo.processInfo.arguments.contains("-selfTest") {
            exit(passed ? 0 : 1)
        }
    }

    private static func storageStatus() -> String {
        do {
            let rows = try RowStorage.open(directory: try RowStorage.appDirectory(), service: "ch.trancee.cairn")
            defer { rows.close() }
            let now = Date().timeIntervalSince1970
            return StorageCheckKt.checkStorage(
                rows: rows,
                clock: Clock(monoMs: UInt64(ProcessInfo.processInfo.systemUptime * 1000), unixS: UInt64(now))
            )
        } catch {
            return "storage=error \(error)"
        }
    }

    var body: some Scene {
        WindowGroup {
            Text(verdict).padding()
        }
    }
}
