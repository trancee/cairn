import CairnApp
import CoreBluetooth
import XCTest
@testable import CairnIos

final class IosRadioTests: XCTestCase {
    private let a = UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!
    private let b = UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!
    private let c = UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!

    private var port: FakePort!
    private var scheduler: FakeScheduler!
    private var listener: FakeListener!
    private var states: [RadioState]!
    private var randomPick: (ClosedRange<Int64>) -> Int64 = { $0.lowerBound }
    private var radio: IosRadio!

    override func setUp() {
        port = FakePort()
        scheduler = FakeScheduler()
        listener = FakeListener()
        states = []
        radio = IosRadio(port: port, scheduler: scheduler) { [unowned self] in randomPick($0) }
        radio.listener = listener
        radio.availability = { [unowned self] in states.append($0) }
    }

    private func running() {
        radio.start()
        radio.stateChanged(central: .on, peripheral: .on)
        port.calls.removeAll()
    }

    /// Brings up a central link to [peer] and returns its id.
    @discardableResult
    private func centralLink(_ peer: UUID) -> UInt64 {
        radio.discovered(peer)
        radio.connected(peer)
        radio.servicesDiscovered(peer, ok: true)
        radio.subscribed(peer, ok: true)
        return listener.lastLink
    }

    // MARK: Adapter state

    func testStartsBothManagersAndRunsOnceBothArePoweredOn() {
        radio.start()
        radio.stateChanged(central: .on, peripheral: .unknown)
        XCTAssertEqual(port.calls, ["start"])

        radio.stateChanged(central: .on, peripheral: .on)

        XCTAssertEqual(port.calls, ["start", "advertise true", "scan true"])
        XCTAssertEqual(states, [.running])
    }

    func testStateBeforeStartIsIgnored() {
        radio.stateChanged(central: .on, peripheral: .on)

        XCTAssertEqual(port.calls, [])
        XCTAssertEqual(states, [])
    }

    func testUnauthorizedNeedsPermission() {
        radio.start()

        radio.stateChanged(central: .unauthorized, peripheral: .unknown)

        XCTAssertEqual(states, [.needsPermission])
    }

    func testPowerOffClosesEveryLinkAndPowerOnResumes() {
        running()
        let up = centralLink(a)
        radio.centralSubscribed(b)

        radio.stateChanged(central: .off, peripheral: .off)

        XCTAssertEqual(listener.downs, [up, listener.lastLink])
        XCTAssertEqual(states, [.running, .bluetoothOff])
        radio.stateChanged(central: .on, peripheral: .on)
        XCTAssertEqual(states, [.running, .bluetoothOff, .running])
        XCTAssertEqual(port.calls.suffix(2), ["advertise true", "scan true"])
    }

    func testStopEndsDiscoveryAndClosesLinks() {
        running()
        let up = centralLink(a)

        radio.stop()

        XCTAssertEqual(port.calls.suffix(3), ["scan false", "advertise false", "cancel A"])
        XCTAssertEqual(listener.downs, [up])
        radio.discovered(b)
        XCTAssertFalse(port.calls.contains("connect B"))
    }

    // MARK: Central

    func testCentralLinksUpAfterSubscribingThenReadsBeacon() {
        running()

        radio.discovered(a)
        radio.connected(a)
        radio.servicesDiscovered(a, ok: true)
        XCTAssertEqual(listener.events, [])
        radio.subscribed(a, ok: true)

        XCTAssertEqual(port.calls, ["connect A", "discover A", "subscribe A", "readBeacon A"])
        XCTAssertEqual(listener.events, ["up 1 central 185 \(a.bytesHex)"])
        radio.beaconRead(a, value: Data([9, 8]))
        XCTAssertEqual(listener.events.last, "beacon 1 0908")
    }

    func testWriteWaitsForTheBeaconRead() {
        running()
        let link = centralLink(a)

        radio.send(link: link, fragment: Data([1]).kotlin)
        scheduler.drain()
        XCTAssertFalse(port.calls.contains("write A 01"))
        radio.beaconRead(a, value: Data([9]))

        XCTAssertEqual(port.calls.last, "write A 01")
    }

    func testWriteAckReportsSentAndWriteErrorCloses() {
        running()
        let link = centralLink(a)
        radio.beaconRead(a, value: Data([9]))

        radio.send(link: link, fragment: Data([1]).kotlin)
        scheduler.drain()
        radio.wrote(a, .ok)
        XCTAssertEqual(listener.events.last, "sent \(link)")
        radio.wrote(a, .failed)

        XCTAssertEqual(port.calls.last, "cancel A")
        XCTAssertEqual(listener.downs, [link])
    }

    func testFailedBeaconReadCloses() {
        running()
        let link = centralLink(a)

        radio.beaconRead(a, value: nil)

        XCTAssertEqual(listener.downs, [link])
    }

    func testFailedDiscoveryOrSubscriptionCloses() {
        running()
        radio.discovered(a)
        radio.connected(a)
        radio.servicesDiscovered(a, ok: false)
        radio.discovered(b)
        radio.connected(b)
        radio.servicesDiscovered(b, ok: true)

        radio.subscribed(b, ok: false)

        XCTAssertEqual(port.calls.filter { $0.hasPrefix("cancel") }, ["cancel A", "cancel B"])
        XCTAssertEqual(listener.events, [])
    }

    func testNotificationsAreReceivedOnlyOnceUp() {
        running()
        radio.discovered(a)
        radio.connected(a)
        radio.notified(a, value: Data([5]))
        XCTAssertEqual(listener.events, [])
        radio.servicesDiscovered(a, ok: true)
        radio.subscribed(a, ok: true)

        radio.notified(a, value: Data([5]))

        XCTAssertEqual(listener.events.last, "in 1 05")
    }

    func testWriteLengthChangeReportsMtuBeforeWriting() {
        running()
        let link = centralLink(a)
        radio.beaconRead(a, value: Data([9]))
        port.writeLength = 244

        radio.send(link: link, fragment: Data([1]).kotlin)
        scheduler.drain()

        XCTAssertEqual(listener.events.last, "mtu \(link) 247")
        XCTAssertEqual(port.calls.last, "write A 01")
    }

    func testDisconnectFromPeerReportsLinkDown() {
        running()
        let link = centralLink(a)

        radio.disconnected(a)

        XCTAssertEqual(listener.downs, [link])
        radio.notified(a, value: Data([5]))
        XCTAssertEqual(listener.events.last, "down \(link)")
    }

    func testDisconnectClosesTheCentralLinkLater() {
        running()
        let link = centralLink(a)

        radio.disconnect(link: link, reason: .busy)
        XCTAssertEqual(listener.downs, [])
        scheduler.drain()

        XCTAssertEqual(port.calls.last, "cancel A")
        XCTAssertEqual(listener.downs, [link])
    }

    func testSendAndDisconnectForUnknownLinksAreIgnored() {
        running()

        radio.send(link: 7, fragment: Data([1]).kotlin)
        radio.disconnect(link: 7, reason: .busy)
        scheduler.drain()

        XCTAssertEqual(port.calls, [])
    }

    func testCallbacksForUnknownPeersAreIgnored() {
        running()

        radio.connected(a)
        radio.servicesDiscovered(a, ok: true)
        radio.subscribed(a, ok: true)
        radio.beaconRead(a, value: Data([1]))
        radio.wrote(a, .ok)
        radio.disconnected(a)
        radio.centralUnsubscribed(a)

        XCTAssertEqual(port.calls, [])
        XCTAssertEqual(listener.events, [])
    }

    // MARK: Dial policy (spec §10.4)

    func testFirstDialWaitsTheRandomSpread() {
        randomPick = { $0.upperBound }
        running()

        radio.discovered(a)
        scheduler.advance(by: 2_999)
        radio.discovered(a)
        XCTAssertEqual(port.calls, [])
        scheduler.advance(by: 1)
        radio.discovered(a)

        XCTAssertEqual(port.calls, ["connect A"])
    }

    func testDefaultSpreadIsAtMostThreeSeconds() {
        radio = IosRadio(port: port, scheduler: scheduler)
        running()

        radio.discovered(a)
        scheduler.advance(by: 3_000)
        radio.discovered(a)

        XCTAssertEqual(port.calls, ["connect A"])
    }

    func testDialTimesOutAfterTenSecondsThenRetriesAfterOneToFiveSeconds() {
        running()
        radio.discovered(a)

        scheduler.advance(by: 10_000)
        XCTAssertEqual(port.calls, ["connect A", "cancel A"])
        scheduler.advance(by: 999)
        radio.discovered(a)
        XCTAssertEqual(port.calls.count, 2)
        scheduler.advance(by: 1)
        radio.discovered(a)

        XCTAssertEqual(port.calls.last, "connect A")
    }

    func testThirdFailureWaitsTheAttemptInterval() {
        running()
        for wait: Int64 in [1_000, 5_000] {
            radio.discovered(a)
            radio.connectFailed(a)
            scheduler.advance(by: wait)
        }
        radio.discovered(a)
        radio.connectFailed(a)

        scheduler.advance(by: 119_999)
        radio.discovered(a)
        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 3)
        scheduler.advance(by: 1)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 4)
    }

    func testLinkedPeerIsDialledAgainOnlyAfterTheAttemptInterval() {
        running()
        centralLink(a)
        radio.disconnected(a)

        scheduler.advance(by: 119_999)
        radio.discovered(a)
        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 1)
        scheduler.advance(by: 1)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 2)
    }

    /// Dials [a] once allowed, keeps the link up for [upMs], then loses it to a supervision timeout.
    private func linkThenTimeOut(upMs: Int64) {
        centralLink(a)
        scheduler.advance(by: upMs)
        radio.disconnected(a, error: CBError.connectionTimeout.rawValue)
    }

    func testLinkLostToASupervisionTimeoutLeavesThePeerFortyFiveSecondsPlusTheSpreadToDial() {
        randomPick = { $0.upperBound }
        running()
        radio.discovered(a)
        scheduler.advance(by: 3_000)
        linkThenTimeOut(upMs: 0)

        scheduler.advance(by: 47_999)
        radio.discovered(a)
        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 1)
        scheduler.advance(by: 1)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 2)
    }

    func testSupervisionTimeoutBeforeTheLinkIsUpAlsoLeavesThePeerToDial() {
        running()
        radio.discovered(a)
        radio.connected(a)
        radio.disconnected(a, error: CBError.connectionTimeout.rawValue)

        scheduler.advance(by: 44_999)
        radio.discovered(a)
        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 1)
        scheduler.advance(by: 1)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 2)
    }

    func testEveryTimeoutLeavesThePeerToDial() {
        running()
        linkThenTimeOut(upMs: 0)
        scheduler.advance(by: 45_000)
        linkThenTimeOut(upMs: 0)

        scheduler.advance(by: 44_999)
        radio.discovered(a)
        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 2)
        scheduler.advance(by: 1)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 3)
    }

    func testAPeerThatDialsUsAfterAHandOverIsNotDialledWhileThatLinkIsUp() {
        running()
        linkThenTimeOut(upMs: 0)
        scheduler.advance(by: 20_000)
        radio.centralSubscribed(c)

        scheduler.advance(by: 100_000)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 1)
    }

    func testHandOverStartsAgainWhenTheLinkThePeerDialledGoesDown() {
        running()
        linkThenTimeOut(upMs: 0)
        radio.centralSubscribed(c)
        scheduler.advance(by: 60_000)
        radio.centralUnsubscribed(c)

        scheduler.advance(by: 44_999)
        radio.discovered(a)
        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 1)
        scheduler.advance(by: 1)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 2)
    }

    func testALinkUpBeforeTheTimeoutDoesNotHoldTheDialBack() {
        running()
        radio.centralSubscribed(c)
        scheduler.advance(by: 1)
        linkThenTimeOut(upMs: 0)

        scheduler.advance(by: 45_000)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 2)
    }

    func testOurOwnLinkEndsTheHandOver() {
        running()
        linkThenTimeOut(upMs: 0)
        scheduler.advance(by: 45_000)
        centralLink(a)
        radio.centralSubscribed(c)
        radio.disconnected(a)

        scheduler.advance(by: 120_000)
        radio.discovered(a)

        XCTAssertEqual(port.calls.filter { $0 == "connect A" }.count, 3)
    }

    func testTimeoutOfALinkedDialDoesNothing() {
        running()
        centralLink(a)

        scheduler.advance(by: 10_000)

        XCTAssertFalse(port.calls.contains("cancel A"))
    }

    func testAtMostTwoDialsInFlightAndNoneToAPeerLinkedToTheServer() {
        running()
        radio.centralSubscribed(c)
        radio.discovered(c)
        radio.discovered(a)
        radio.discovered(b)
        radio.discovered(UUID())

        XCTAssertEqual(port.calls, ["connect A", "connect B"])
        radio.discovered(a)
        XCTAssertEqual(port.calls.count, 2)
    }

    func testTraceLogsLinksAndFragmentHeadersWithoutPayload() {
        var lines: [String] = []
        radio.trace = { lines.append($0) }
        running()
        let link = centralLink(a)
        radio.beaconRead(a, value: Data([9]))

        radio.send(link: link, fragment: Data([0x21, 0xAA]).kotlin)
        scheduler.drain()
        radio.notified(a, value: Data([]))
        radio.disconnected(a, error: 6)

        XCTAssertEqual(lines, [
            "link 1 up CENTRAL mtu 185",
            "link 1 out 0x21 2 B",
            "link 1 in 0x 0 B",
            "link 1 lost error 6",
            "link 1 down",
        ])
    }

    func testTraceNamesALinkTheCoreClosesAndOneThePeerEndsCleanly() {
        var lines: [String] = []
        radio.trace = { lines.append($0) }
        running()
        let first = centralLink(a)
        let second = centralLink(b)

        radio.disconnect(link: first, reason: .busy)
        scheduler.drain()
        radio.disconnected(b)

        XCTAssertEqual(lines.filter { !$0.contains(" up ") }, [
            "link \(first) close requested (busy)",
            "link \(first) down",
            "link \(second) lost",
            "link \(second) down",
        ])
    }

    // MARK: Peripheral

    func testSubscriptionLinksUpAndUnsubscriptionLinksDown() {
        running()

        radio.centralSubscribed(a)
        radio.centralSubscribed(a)
        XCTAssertEqual(listener.events, ["up 1 peripheral 185 \(a.bytesHex)"])
        radio.centralUnsubscribed(a)

        XCTAssertEqual(listener.downs, [1])
    }

    func testSubscriptionWhileStoppedIsIgnored() {
        radio.centralSubscribed(a)

        XCTAssertEqual(listener.events, [])
    }

    func testBeaconReadsHonourTheOffset() {
        listener.beaconValue = Data([1, 2, 3])

        XCTAssertEqual(radio.readRequest(a, characteristic: .beacon, offset: 1), .value(Data([2, 3])))
        XCTAssertEqual(radio.readRequest(a, characteristic: .beacon, offset: 3), .value(Data()))
        XCTAssertEqual(radio.readRequest(a, characteristic: .beacon, offset: 4), .invalidOffset)
        XCTAssertEqual(radio.readRequest(a, characteristic: .psm, offset: 0), .notSupported)
    }

    func testWritesAreAcceptedOnlyFromALinkedCentralToRxAtOffsetZero() {
        running()
        let rx = WriteRequest(characteristic: .rx, offset: 0, value: checked(1))
        XCTAssertEqual(radio.writeRequests(a, [rx]), .refused)
        radio.centralSubscribed(a)
        let link = listener.lastLink

        XCTAssertEqual(radio.writeRequests(a, [rx, WriteRequest(characteristic: .rx, offset: 1, value: checked(2))]), .refused)
        XCTAssertEqual(radio.writeRequests(a, [WriteRequest(characteristic: .beacon, offset: 0, value: checked(2))]), .refused)
        XCTAssertEqual(radio.writeRequests(a, [rx, WriteRequest(characteristic: .rx, offset: 0, value: checked(2))]), .accepted)

        XCTAssertEqual(listener.events.suffix(2), ["in \(link) \(checked(1).hex)", "in \(link) \(checked(2).hex)"])
    }

    func testABatchWithAWriteFailingItsCheckIsRefusedForAResend() {
        running()
        var traces: [String] = []
        radio.trace = { traces.append($0) }
        radio.centralSubscribed(a)
        let link = listener.lastLink
        var corrupted = checked(1, 2)
        corrupted[1] = 3

        let answer = radio.writeRequests(a, [
            WriteRequest(characteristic: .rx, offset: 0, value: checked(1)),
            WriteRequest(characteristic: .rx, offset: 0, value: corrupted),
        ])

        XCTAssertEqual(answer, .checkFailed)
        XCTAssertFalse(listener.events.contains { $0.hasPrefix("in") })
        XCTAssertEqual(traces.last, "link \(link) write rejected (check)")
    }

    func testACentralResendsAWriteRejectedForItsCheckThreeTimesThenCloses() {
        running()
        var traces: [String] = []
        radio.trace = { traces.append($0) }
        let link = centralLink(a)
        radio.beaconRead(a, value: Data([9]))
        radio.send(link: link, fragment: checked(1).kotlin)
        scheduler.drain()

        for _ in 0 ..< 4 {
            radio.wrote(a, .checkFailed)
        }

        let writes = port.calls.filter { $0.hasPrefix("write A") }
        XCTAssertEqual(writes, Array(repeating: "write A \(checked(1).hex)", count: 4))
        XCTAssertEqual(traces.filter { $0.contains("resend") }, (1 ... 3).map { "link \(link) resend \($0) (check)" })
        XCTAssertEqual(listener.downs, [link])
    }

    func testACentralCountsResendsAfreshForEachAcceptedWrite() {
        running()
        let link = centralLink(a)
        radio.beaconRead(a, value: Data([9]))
        radio.send(link: link, fragment: checked(1).kotlin)
        scheduler.drain()
        for _ in 0 ..< 3 {
            radio.wrote(a, .checkFailed)
        }
        radio.wrote(a, .ok)

        radio.wrote(a, .checkFailed)

        XCTAssertEqual(listener.downs, [])
        XCTAssertEqual(port.calls.filter { $0.hasPrefix("write A") }.count, 5)
    }

    func testNotificationsWaitForTheQueueToDrain() {
        running()
        radio.centralSubscribed(a)
        let link = listener.lastLink
        port.notifyAccepts = false

        radio.send(link: link, fragment: Data([1]).kotlin)
        scheduler.drain()
        XCTAssertEqual(listener.events.last, "up \(link) peripheral 185 \(a.bytesHex)")
        port.notifyAccepts = true
        radio.readyToUpdate()

        XCTAssertEqual(port.calls.suffix(2), ["notify A 01", "notify A 01"])
        XCTAssertEqual(listener.events.last, "sent \(link)")
    }

    func testUpdateLengthChangeReportsMtuBeforeNotifying() {
        running()
        radio.centralSubscribed(a)
        let link = listener.lastLink
        port.updateLength = 509

        radio.send(link: link, fragment: Data([1]).kotlin)
        scheduler.drain()

        XCTAssertEqual(listener.events.suffix(2), ["mtu \(link) 512", "sent \(link)"])
    }

    func testDisconnectEndsThePeripheralLinkAndDropsHeldNotifications() {
        running()
        radio.centralSubscribed(a)
        let link = listener.lastLink
        port.notifyAccepts = false
        radio.send(link: link, fragment: Data([1]).kotlin)
        scheduler.drain()

        radio.disconnect(link: link, reason: .busy)
        scheduler.drain()
        port.notifyAccepts = true
        radio.readyToUpdate()

        XCTAssertEqual(listener.downs, [link])
        XCTAssertEqual(port.calls.filter { $0.hasPrefix("notify") }.count, 1)
        XCTAssertEqual(radio.writeRequests(a, [WriteRequest(characteristic: .rx, offset: 0, value: checked(1))]), .refused)
        radio.centralUnsubscribed(a)
        XCTAssertEqual(listener.downs, [link])
    }
}

// MARK: Fakes

final class FakePort: BlePort {
    var calls: [String] = []
    var writeLength = 182
    var updateLength = 182
    var notifyAccepts = true

    private func name(_ peer: UUID) -> String {
        String(peer.uuidString.last!)
    }

    func start() { calls.append("start") }
    func scan(_ on: Bool) { calls.append("scan \(on)") }
    func advertise(_ on: Bool) { calls.append("advertise \(on)") }
    func connect(_ peer: UUID) { calls.append("connect \(name(peer))") }
    func cancel(_ peer: UUID) { calls.append("cancel \(name(peer))") }
    func discover(_ peer: UUID) { calls.append("discover \(name(peer))") }
    func subscribe(_ peer: UUID) { calls.append("subscribe \(name(peer))") }
    func readBeacon(_ peer: UUID) { calls.append("readBeacon \(name(peer))") }
    func write(_ peer: UUID, _ value: Data) { calls.append("write \(name(peer)) \(value.hex)") }
    func writeLength(_ peer: UUID) -> Int { writeLength }

    func notify(_ central: UUID, _ value: Data) -> Bool {
        calls.append("notify \(name(central)) \(value.hex)")
        return notifyAccepts
    }

    func updateLength(_ central: UUID) -> Int { updateLength }
}

final class FakeScheduler: Scheduler {
    private(set) var nowMs: Int64 = 1_000
    private var tasks: [(at: Int64, id: Int, block: () -> Void)] = []
    private var deferred: [() -> Void] = []
    private var nextId = 0

    @discardableResult
    func after(_ ms: Int64, _ block: @escaping () -> Void) -> () -> Void {
        nextId += 1
        let id = nextId
        tasks.append((nowMs + ms, id, block))
        return { [weak self] in self?.tasks.removeAll { $0.id == id } }
    }

    func async(_ block: @escaping () -> Void) {
        deferred.append(block)
    }

    func drain() {
        while !deferred.isEmpty {
            deferred.removeFirst()()
        }
    }

    func advance(by ms: Int64) {
        let end = nowMs + ms
        while let next = tasks.filter({ $0.at <= end }).min(by: { ($0.at, $0.id) < ($1.at, $1.id) }) {
            tasks.removeAll { $0.id == next.id }
            nowMs = next.at
            next.block()
        }
        nowMs = end
    }
}

final class FakeListener: NSObject, RadioListener {
    var events: [String] = []
    var downs: [UInt64] = []
    var beaconValue = Data([7])
    private(set) var lastLink: UInt64 = 0

    func linkUp(role: GattRole, mtu: UInt16, address: KotlinByteArray) -> UInt64 {
        lastLink += 1
        events.append("up \(lastLink) \(role.name.lowercased()) \(mtu) \(address.data.hex)")
        return lastLink
    }

    func mtuChanged(link: UInt64, mtu: UInt16) { events.append("mtu \(link) \(mtu)") }
    func beaconRead(link: UInt64, beacon: KotlinByteArray) { events.append("beacon \(link) \(beacon.data.hex)") }
    func received(link: UInt64, fragment: KotlinByteArray) { events.append("in \(link) \(fragment.data.hex)") }
    func sent(link: UInt64) { events.append("sent \(link)") }

    func linkDown(link: UInt64) {
        events.append("down \(link)")
        downs.append(link)
    }

    func beacon() -> KotlinByteArray { beaconValue.kotlin }
}

extension Data {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}

extension UUID {
    var bytesHex: String { Data(bytes).hex }
}

/// [bytes] as a GATT fragment: header and body, then their CRC-16/CCITT-FALSE check (ADR 0042).
private func checked(_ bytes: UInt8...) -> Data {
    var crc: UInt16 = 0xFFFF
    for byte in bytes {
        crc ^= UInt16(byte) << 8
        for _ in 0 ..< 8 {
            crc = crc & 0x8000 != 0 ? crc << 1 ^ 0x1021 : crc << 1
        }
    }
    return Data(bytes + [UInt8(crc >> 8), UInt8(crc & 0xFF)])
}
