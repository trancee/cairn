import CairnApp
import XCTest
@testable import CairnIos

final class PlatformTests: XCTestCase {
    func testBytesRoundTripThroughKotlin() {
        let bytes = Data([0, 1, 0x7F, 0x80, 0xFF])

        XCTAssertEqual(bytes.kotlin.data, bytes)
    }

    func testUuidBytesAreItsSixteenBytesInOrder() {
        let id = UUID(uuidString: "00010203-0405-0607-0809-0A0B0C0D0E0F")!

        XCTAssertEqual(id.bytes, Array(0 ... 15))
    }

    func testClockIsMonotonicAndTracksWallTime() {
        let first = IosClock().now()
        let second = IosClock().now()

        XCTAssertGreaterThanOrEqual(second.monoMs, first.monoMs)
        XCTAssertEqual(Double(first.unixS), Date().timeIntervalSince1970, accuracy: 2)
    }

    func testTimersFireAtTheirDeadlineAndCancelledOnesDont() {
        let scheduler = FakeScheduler()
        var fired: [UInt64] = []
        let timers = SchedulerTimers(scheduler: scheduler) { fired.append($0) }

        timers.schedule(timer: 1, atMonoMs: UInt64(scheduler.nowMs + 50))
        timers.schedule(timer: 2, atMonoMs: UInt64(scheduler.nowMs + 20))
        timers.schedule(timer: 3, atMonoMs: UInt64(scheduler.nowMs + 10))
        timers.schedule(timer: 2, atMonoMs: UInt64(scheduler.nowMs + 30))
        timers.cancel(timer: 3)
        scheduler.advance(by: 100)

        XCTAssertEqual(fired, [2, 1])
        timers.cancel(timer: 1)
    }

    func testMainSchedulerRunsDeferredAndDelayedWork() {
        let scheduler = MainScheduler()
        let deferred = expectation(description: "async")
        let delayed = expectation(description: "after")
        let start = scheduler.nowMs

        scheduler.async { deferred.fulfill() }
        scheduler.after(20) { delayed.fulfill() }
        let cancel = scheduler.after(10) { XCTFail("cancelled work ran") }
        cancel()

        wait(for: [deferred, delayed], timeout: 2)
        XCTAssertGreaterThanOrEqual(scheduler.nowMs - start, 20)
    }
}
