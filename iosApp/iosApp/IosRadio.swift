import CairnApp
import Foundation

/// A manager's power state as the radio needs it; CoreBluetooth's other states map onto these.
enum BleState {
    case unknown, on, off, unauthorized
}

/// What the app shows for the radio (ADR 0037 §5).
enum RadioState {
    case stopped, needsPermission, bluetoothOff, running
}

/// The cairn GATT characteristics (spec §12).
enum GattCharacteristic {
    case beacon, rx, tx, psm
}

/// The answer to a read request from a central.
enum ReadAnswer: Equatable {
    case value(Data)
    case invalidOffset
    case notSupported
}

struct WriteRequest {
    let characteristic: GattCharacteristic
    let offset: Int
    let value: Data
}

/// CoreBluetooth commands, keyed by the peer's identifier (ADR 0037 §1).
protocol BlePort: AnyObject {
    /// Creates the managers; their states arrive through `IosRadio.stateChanged`.
    func start()
    func scan(_ on: Bool)
    /// Publishes the service, if needed, and advertises the service UUID, or stops advertising.
    func advertise(_ on: Bool)
    func connect(_ peer: UUID)
    func cancel(_ peer: UUID)
    /// Discovers the service and its characteristics.
    func discover(_ peer: UUID)
    /// Enables `tx` notifications.
    func subscribe(_ peer: UUID)
    func readBeacon(_ peer: UUID)
    /// Writes to `rx` with response.
    func write(_ peer: UUID, _ value: Data)
    /// The longest value a write without response can carry: the ATT MTU less 3.
    func writeLength(_ peer: UUID) -> Int
    /// Notifies `tx`; false when the transmit queue is full.
    func notify(_ central: UUID, _ value: Data) -> Bool
    /// The longest notification: the ATT MTU less 3.
    func updateLength(_ central: UUID) -> Int
}

/// Monotonic time and deferred work, on the radio's queue.
protocol Scheduler: AnyObject {
    var nowMs: Int64 { get }
    /// Runs [block] after [ms]; the returned closure cancels it.
    @discardableResult
    func after(_ ms: Int64, _ block: @escaping () -> Void) -> () -> Void
    func async(_ block: @escaping () -> Void)
}

/// The iOS [Radio] for slice S3 (ADR 0037). It advertises and scans for the cairn service while
/// started and runs both GATT roles. Every method runs on the scheduler's queue.
final class IosRadio: NSObject, Radio {
    /// Usually the `LinkDriver`; set before `start`.
    var listener: RadioListener!

    var availability: (RadioState) -> Void = { _ in }

    /// The link trace of ADR 0023 §3: link up and down, and each fragment's header byte and size,
    /// logged when it is queued or received; no addresses and no payload.
    var trace: (String) -> Void = { _ in }

    private let port: BlePort
    private let scheduler: Scheduler
    private let random: (ClosedRange<Int64>) -> Int64

    private var started = false
    private var running = false

    private enum Stage { case connecting, discovering, subscribing, up }

    private final class Central {
        var stage = Stage.connecting
        var link: UInt64 = 0
        var mtu = 0
        var reading = false
        var held: Data?
        var cancelTimeout: () -> Void = {}
    }

    private final class Dial {
        var notBefore: Int64
        var failures = 0

        init(notBefore: Int64) {
            self.notBefore = notBefore
        }
    }

    private struct Peripheral {
        let link: UInt64
        var mtu: Int
    }

    private enum Endpoint {
        case central(UUID)
        case peripheral(UUID)
    }

    private var centrals: [UUID: Central] = [:]
    private var dials: [UUID: Dial] = [:]
    private var peripherals: [UUID: Peripheral] = [:]
    private var links: [UInt64: Endpoint] = [:]
    private var notifications: [(central: UUID, link: UInt64, value: Data)] = []

    init(port: BlePort, scheduler: Scheduler, random: @escaping (ClosedRange<Int64>) -> Int64 = { Int64.random(in: $0) }) {
        self.port = port
        self.scheduler = scheduler
        self.random = random
    }

    func start() {
        guard !started else { return }
        started = true
        port.start()
    }

    /// Stops discovery and closes every link, reporting `linkDown` for each.
    func stop() {
        guard started else { return }
        started = false
        if running {
            running = false
            port.scan(false)
            port.advertise(false)
            closeAll()
        }
    }

    func stateChanged(central: BleState, peripheral: BleState) {
        guard started else { return }
        if central == .on && peripheral == .on {
            guard !running else { return }
            running = true
            port.advertise(true)
            port.scan(true)
            availability(.running)
        } else if central == .unknown || peripheral == .unknown, central != .unauthorized, peripheral != .unauthorized {
            return
        } else {
            if running {
                running = false
                closeAll()
            }
            availability(central == .unauthorized || peripheral == .unauthorized ? .needsPermission : .bluetoothOff)
        }
    }

    private func closeAll() {
        Array(centrals.keys).forEach(closeCentral)
        Array(peripherals.keys).forEach(closePeripheral)
    }

    // MARK: Radio

    // Deferred, because the driver calls these while it dispatches, possibly before linkUp returned the id.
    func send(link: UInt64, fragment: KotlinByteArray) {
        let value = fragment.data
        scheduler.async { [self] in
            if links[link] != nil { traceFragment(link, "out", value) }
            switch links[link] {
            case let .central(peer): write(peer, value)
            case let .peripheral(central):
                notifications.append((central, link, value))
                pump()
            case nil: break
            }
        }
    }

    func disconnect(link: UInt64) {
        scheduler.async { [self] in
            switch links[link] {
            case let .central(peer): closeCentral(peer)
            case let .peripheral(central): closePeripheral(central)
            case nil: break
            }
        }
    }

    private func up(_ role: GattRole, _ mtu: Int, _ peer: UUID, _ endpoint: Endpoint) -> UInt64 {
        let link = listener.linkUp(role: role, mtu: UInt16(mtu), address: Data(peer.bytes).kotlin)
        links[link] = endpoint
        trace("link \(link) up \(role.name) mtu \(mtu)")
        return link
    }

    private func received(_ link: UInt64, _ value: Data) {
        traceFragment(link, "in", value)
        listener.received(link: link, fragment: value.kotlin)
    }

    private func traceFragment(_ link: UInt64, _ direction: String, _ value: Data) {
        trace("link \(link) \(direction) 0x\(value.prefix(1).map { String(format: "%02x", $0) }.joined()) \(value.count) B")
    }

    private func down(_ link: UInt64) {
        links[link] = nil
        trace("link \(link) down")
        listener.linkDown(link: link)
    }

    // MARK: Central (spec §10.4, ADR 0037 §3)

    private static let firstDialSpreadMs: Int64 = 3_000
    private static let attemptIntervalMs: Int64 = 120_000
    private static let dialTimeoutMs: Int64 = 10_000
    private static let maxDialsInFlight = 2

    /// A scan result for [peer]; dials it when the policy allows.
    func discovered(_ peer: UUID) {
        guard running, centrals[peer] == nil, peripherals[peer] == nil else { return }
        guard centrals.values.filter({ $0.stage != .up }).count < Self.maxDialsInFlight else { return }
        let now = scheduler.nowMs
        let dial = dials[peer] ?? Dial(notBefore: now + random(0 ... Self.firstDialSpreadMs))
        dials[peer] = dial
        guard now >= dial.notBefore else { return }
        dial.notBefore = now + Self.attemptIntervalMs
        let central = Central()
        centrals[peer] = central
        port.connect(peer)
        central.cancelTimeout = scheduler.after(Self.dialTimeoutMs) { [weak self, weak central] in
            if let self, let central, self.centrals[peer] === central { self.closeCentral(peer) }
        }
    }

    func connected(_ peer: UUID) {
        guard let central = centrals[peer], central.stage == .connecting else { return }
        central.stage = .discovering
        port.discover(peer)
    }

    func servicesDiscovered(_ peer: UUID, ok: Bool) {
        guard let central = centrals[peer], central.stage == .discovering else { return }
        guard ok else { return closeCentral(peer) }
        central.stage = .subscribing
        port.subscribe(peer)
    }

    func subscribed(_ peer: UUID, ok: Bool) {
        guard let central = centrals[peer], central.stage == .subscribing else { return }
        guard ok else { return closeCentral(peer) }
        central.stage = .up
        central.cancelTimeout()
        dials[peer]?.failures = 0
        central.mtu = port.writeLength(peer) + 3
        central.link = up(.central, central.mtu, peer, .central(peer))
        central.reading = true
        port.readBeacon(peer)
    }

    func beaconRead(_ peer: UUID, value: Data?) {
        guard let central = centrals[peer], central.reading else { return }
        central.reading = false
        guard let value else { return closeCentral(peer) }
        listener.beaconRead(link: central.link, beacon: value.kotlin)
        if let held = central.held {
            central.held = nil
            write(peer, held)
        }
    }

    func notified(_ peer: UUID, value: Data) {
        guard let central = centrals[peer], central.stage == .up else { return }
        received(central.link, value)
    }

    func wrote(_ peer: UUID, ok: Bool) {
        guard let central = centrals[peer], central.stage == .up else { return }
        if ok { listener.sent(link: central.link) } else { closeCentral(peer) }
    }

    /// The connection ended or never came up.
    func disconnected(_ peer: UUID) {
        if centrals[peer] != nil { closeCentral(peer) }
    }

    func connectFailed(_ peer: UUID) {
        disconnected(peer)
    }

    private func write(_ peer: UUID, _ value: Data) {
        let central = centrals[peer]!
        if central.reading {
            central.held = value
            return
        }
        let mtu = port.writeLength(peer) + 3
        if mtu != central.mtu {
            central.mtu = mtu
            listener.mtuChanged(link: central.link, mtu: UInt16(mtu))
        }
        port.write(peer, value)
    }

    private func closeCentral(_ peer: UUID) {
        guard let central = centrals.removeValue(forKey: peer) else { return }
        central.cancelTimeout()
        port.cancel(peer)
        if central.stage == .up {
            down(central.link)
        } else if let dial = dials[peer] {
            dial.failures += 1
            let delay: Int64
            switch dial.failures {
            case 1: delay = random(1_000 ... 5_000)
            case 2: delay = random(5_000 ... 15_000)
            default:
                delay = Self.attemptIntervalMs
                dial.failures = 0
            }
            dial.notBefore = scheduler.nowMs + delay
        }
    }

    // MARK: Peripheral (ADR 0037 §4)

    func centralSubscribed(_ central: UUID) {
        guard running, peripherals[central] == nil else { return }
        let mtu = port.updateLength(central) + 3
        let link = up(.peripheral, mtu, central, .peripheral(central))
        peripherals[central] = Peripheral(link: link, mtu: mtu)
    }

    /// iOS also reports this when the central disconnects.
    func centralUnsubscribed(_ central: UUID) {
        closePeripheral(central)
    }

    func readRequest(_ central: UUID, characteristic: GattCharacteristic, offset: Int) -> ReadAnswer {
        guard characteristic == .beacon else { return .notSupported }
        let value = listener.beacon().data
        return offset > value.count ? .invalidOffset : .value(value.subdata(in: offset ..< value.count))
    }

    /// Returns whether the batch is accepted; an accepted batch is received in order.
    func writeRequests(_ central: UUID, _ requests: [WriteRequest]) -> Bool {
        guard let peripheral = peripherals[central],
              requests.allSatisfy({ $0.characteristic == .rx && $0.offset == 0 }) else { return false }
        for request in requests {
            received(peripheral.link, request.value)
        }
        return true
    }

    /// The transmit queue has room again.
    func readyToUpdate() {
        pump()
    }

    private func pump() {
        while let next = notifications.first {
            let mtu = port.updateLength(next.central) + 3
            if mtu != peripherals[next.central]!.mtu {
                peripherals[next.central]!.mtu = mtu
                listener.mtuChanged(link: next.link, mtu: UInt16(mtu))
            }
            guard port.notify(next.central, next.value) else { return }
            notifications.removeFirst()
            listener.sent(link: next.link)
        }
    }

    /// iOS can't disconnect a central; its link ends here and its writes are refused [OI-39].
    private func closePeripheral(_ central: UUID) {
        guard let peripheral = peripherals.removeValue(forKey: central) else { return }
        notifications.removeAll { $0.central == central }
        down(peripheral.link)
    }
}
