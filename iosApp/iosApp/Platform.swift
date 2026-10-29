import CairnApp
import Foundation

extension Data {
    var kotlin: KotlinByteArray {
        let array = KotlinByteArray(size: Int32(count))
        for (index, byte) in enumerated() {
            array.set(index: Int32(index), value: Int8(bitPattern: byte))
        }
        return array
    }
}

extension KotlinByteArray {
    var data: Data {
        Data((0 ..< size).map { UInt8(bitPattern: get(index: $0)) })
    }
}

extension UUID {
    /// The 16 identifier bytes; the radio's address for the core's back-off (ADR 0037 §1).
    var bytes: [UInt8] {
        withUnsafeBytes(of: uuid) { Array($0) }
    }
}

/// Monotonic milliseconds from `CLOCK_MONOTONIC`, which counts sleep on Darwin, and wall-clock
/// seconds (ADR 0022 §2).
final class IosClock: NSObject, ClockSource {
    static func monoMs() -> Int64 {
        Int64(clock_gettime_nsec_np(CLOCK_MONOTONIC) / 1_000_000)
    }

    func now() -> Clock {
        Clock(monoMs: UInt64(Self.monoMs()), unixS: UInt64(Date().timeIntervalSince1970))
    }
}

/// The main queue as the radio's `Scheduler`, against `IosClock`.
final class MainScheduler: Scheduler {
    var nowMs: Int64 { IosClock.monoMs() }

    @discardableResult
    func after(_ ms: Int64, _ block: @escaping () -> Void) -> () -> Void {
        let item = DispatchWorkItem(block: block)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int(max(ms, 0))), execute: item)
        return item.cancel
    }

    func async(_ block: @escaping () -> Void) {
        DispatchQueue.main.async(execute: block)
    }
}

/// The driver's `Timers` on a `Scheduler`; expiry calls [fired].
final class SchedulerTimers: NSObject, Timers {
    private let scheduler: Scheduler
    private let fired: (UInt64) -> Void
    private var pending: [UInt64: () -> Void] = [:]

    init(scheduler: Scheduler, fired: @escaping (UInt64) -> Void) {
        self.scheduler = scheduler
        self.fired = fired
    }

    func schedule(timer: UInt64, atMonoMs: UInt64) {
        cancel(timer: timer)
        pending[timer] = scheduler.after(Int64(atMonoMs) - scheduler.nowMs) { [weak self] in
            guard let self else { return }
            self.pending[timer] = nil
            self.fired(timer)
        }
    }

    func cancel(timer: UInt64) {
        pending.removeValue(forKey: timer)?()
    }
}
