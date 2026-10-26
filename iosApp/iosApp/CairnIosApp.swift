import CairnApp
import Foundation
import SwiftUI

/// Runs the shared core self-test at launch, like Android's `CoreStatusInstrumentation`.
/// With the `-selfTest` launch argument it prints the verdict and exits 0 on PASS, 1 on FAIL.
@main
struct CairnIosApp: App {
    private let verdict: String

    init() {
        let status = CoreStatusKt.coreStatus()
        let passed = status == CoreStatusKt.EXPECTED_CORE_STATUS
        verdict = passed ? "PASS: \(status)" : "FAIL: expected '\(CoreStatusKt.EXPECTED_CORE_STATUS)', got '\(status)'"
        NSLog("%@", verdict)
        if ProcessInfo.processInfo.arguments.contains("-selfTest") {
            exit(passed ? 0 : 1)
        }
    }

    var body: some Scene {
        WindowGroup {
            Text(verdict).padding()
        }
    }
}
