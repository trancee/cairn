import CairnApp
import Foundation

/// One core, its `LinkDriver` and the `IosRadio`, all on the main queue (ADR 0023 §2, ADR 0037 §6).
/// It outlives scenes; the radio runs only while the app is in the foreground. Covered by the
/// device demo, not XCTest (ADR 0037 §7).
final class Session {
    let model = ChatModel()

    private let port = CoreBluetoothPort()
    private let radio: IosRadio
    private var driver: LinkDriver!

    init(rows: Rows) {
        let scheduler = MainScheduler()
        radio = IosRadio(port: port, scheduler: scheduler)
        port.radio = radio
        let model = self.model
        let timers = SchedulerTimers(scheduler: scheduler) { [weak self] in self?.driver.timerFired(timer: $0) }
        driver = LinkDriver(
            rows: rows,
            newEngine: { CoreEngine() },
            radio: radio,
            timers: timers,
            clock: IosClock(),
            listener: { model.onNotice($0) }
        )
        radio.listener = RefreshingListener(driver: driver) { [weak self] in self?.refresh() }
        radio.availability = { model.radio = $0 }
        radio.trace = { NSLog("CairnRadio %@", $0) }
        driver.start()
    }

    /// Starts the radio; its state follows Bluetooth power and permission until `pause`.
    func resume() {
        radio.start()
    }

    /// Stops the radio, which closes every link.
    func pause() {
        radio.stop()
        model.radio = .stopped
    }

    func send(contact: UInt64, text: String) {
        model.send(contact: contact, text: text) { driver.sendChat(contact: contact, text: text) }
        refresh()
    }

    /// Marks `contact`'s conversation read up to its last received message, if any.
    func read(contact: UInt64) {
        if let msgno = model.lastReceived(contact) {
            driver.markRead(contact: contact, msgno: msgno)
        }
    }

    private func refresh() {
        model.links = driver.links()
    }
}

/// The driver, refreshing the links panel after each event that changes its stats.
private final class RefreshingListener: NSObject, RadioListener {
    private let driver: LinkDriver
    private let refresh: () -> Void

    init(driver: LinkDriver, refresh: @escaping () -> Void) {
        self.driver = driver
        self.refresh = refresh
    }

    func beacon() -> KotlinByteArray {
        driver.beacon()
    }

    func beaconRead(link: UInt64, beacon: KotlinByteArray) {
        driver.beaconRead(link: link, beacon: beacon)
    }

    func linkUp(role: GattRole, mtu: UInt16, address: KotlinByteArray) -> UInt64 {
        defer { refresh() }
        return driver.linkUp(role: role, mtu: mtu, address: address)
    }

    func mtuChanged(link: UInt64, mtu: UInt16) {
        driver.mtuChanged(link: link, mtu: mtu)
        refresh()
    }

    func received(link: UInt64, fragment: KotlinByteArray) {
        driver.received(link: link, fragment: fragment)
        refresh()
    }

    func sent(link: UInt64) {
        driver.sent(link: link)
        refresh()
    }

    func linkDown(link: UInt64) {
        driver.linkDown(link: link)
        refresh()
    }
}
