import CoreBluetooth
import Foundation

/// The cairn GATT service (spec §12, ADR 0003); the same UUIDs as Android's `GattProfile`.
enum GattProfile {
    static let service = CBUUID(string: "d8177748-2cfa-4aa1-b3d0-c46de25a0e45")
    static let beacon = CBUUID(string: "725e4d3d-d899-4e4e-990a-af2bac20deb4")
    static let rx = CBUUID(string: "eabb6cc0-aa49-4dd4-ae89-af2383e291dd")
    static let tx = CBUUID(string: "d91c38e6-5dbc-4eee-828b-707e41d63451")
    static let psm = CBUUID(string: "1446537a-3d32-4b5c-89d9-8c05f045487a")

    static func characteristic(_ uuid: CBUUID) -> GattCharacteristic? {
        switch uuid {
        case beacon: return .beacon
        case rx: return .rx
        case tx: return .tx
        case psm: return .psm
        default: return nil
        }
    }
}

/// The CoreBluetooth side of [IosRadio] (ADR 0037 §1): both managers on the main queue, each
/// delegate callback forwarded as a radio event. Covered by the device demo, not XCTest (§7).
final class CoreBluetoothPort: NSObject, BlePort {
    weak var radio: IosRadio?

    private var central: CBCentralManager?
    private var peripheralManager: CBPeripheralManager?
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var subscribers: [UUID: CBCentral] = [:]
    private var tx: CBMutableCharacteristic?
    private var published = false
    private var advertising = false

    func start() {
        if central == nil {
            central = CBCentralManager(delegate: self, queue: .main)
            peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
        } else {
            report()
        }
    }

    func scan(_ on: Bool) {
        guard let central, central.state == .poweredOn else { return }
        if on {
            central.scanForPeripherals(
                withServices: [GattProfile.service],
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
            )
        } else {
            central.stopScan()
        }
    }

    func advertise(_ on: Bool) {
        advertising = on
        guard let manager = peripheralManager, manager.state == .poweredOn else { return }
        if !on {
            manager.stopAdvertising()
        } else if published {
            manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [GattProfile.service]])
        } else {
            publish(manager)
        }
    }

    func connect(_ peer: UUID) {
        guard let peripheral = peripherals[peer] else { return }
        peripheral.delegate = self
        central?.connect(peripheral)
    }

    func cancel(_ peer: UUID) {
        guard let peripheral = peripherals[peer] else { return }
        central?.cancelPeripheralConnection(peripheral)
    }

    func discover(_ peer: UUID) {
        peripherals[peer]?.discoverServices([GattProfile.service])
    }

    func subscribe(_ peer: UUID) {
        guard let peripheral = peripherals[peer], let tx = characteristic(peripheral, GattProfile.tx) else {
            return radio?.subscribed(peer, ok: false) ?? ()
        }
        peripheral.setNotifyValue(true, for: tx)
    }

    func readBeacon(_ peer: UUID) {
        guard let peripheral = peripherals[peer], let beacon = characteristic(peripheral, GattProfile.beacon) else {
            return radio?.beaconRead(peer, value: nil) ?? ()
        }
        peripheral.readValue(for: beacon)
    }

    func write(_ peer: UUID, _ value: Data) {
        guard let peripheral = peripherals[peer], let rx = characteristic(peripheral, GattProfile.rx) else {
            return radio?.wrote(peer, ok: false) ?? ()
        }
        peripheral.writeValue(value, for: rx, type: .withResponse)
    }

    // The with-response limit is always 512 and would make CoreBluetooth use prepared writes,
    // which the cairn server refuses; the without-response limit is the ATT MTU less 3 (§3).
    func writeLength(_ peer: UUID) -> Int {
        peripherals[peer]?.maximumWriteValueLength(for: .withoutResponse) ?? 20
    }

    func notify(_ central: UUID, _ value: Data) -> Bool {
        guard let manager = peripheralManager, let tx, let subscriber = subscribers[central] else { return true }
        return manager.updateValue(value, for: tx, onSubscribedCentrals: [subscriber])
    }

    func updateLength(_ central: UUID) -> Int {
        subscribers[central]?.maximumUpdateValueLength ?? 20
    }

    private func characteristic(_ peripheral: CBPeripheral, _ uuid: CBUUID) -> CBCharacteristic? {
        peripheral.services?.first { $0.uuid == GattProfile.service }?.characteristics?.first { $0.uuid == uuid }
    }

    private func publish(_ manager: CBPeripheralManager) {
        let tx = CBMutableCharacteristic(type: GattProfile.tx, properties: [.notify], value: nil, permissions: [])
        let service = CBMutableService(type: GattProfile.service, primary: true)
        service.characteristics = [
            CBMutableCharacteristic(type: GattProfile.beacon, properties: [.read], value: nil, permissions: [.readable]),
            CBMutableCharacteristic(type: GattProfile.rx, properties: [.write], value: nil, permissions: [.writeable]),
            tx,
            CBMutableCharacteristic(type: GattProfile.psm, properties: [.read], value: nil, permissions: [.readable]),
        ]
        self.tx = tx
        manager.removeAllServices()
        manager.add(service)
    }

    private func report() {
        radio?.stateChanged(central: Self.state(central?.state), peripheral: Self.state(peripheralManager?.state))
    }

    private static func state(_ state: CBManagerState?) -> BleState {
        switch state {
        case .poweredOn: return .on
        case .unauthorized: return .unauthorized
        case .unknown, nil: return .unknown
        default: return .off
        }
    }
}

extension CoreBluetoothPort: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state != .poweredOn {
            peripherals.removeAll()
        }
        report()
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let peer = peripheral.identifier
        if peripherals[peer] == nil {
            peripherals[peer] = peripheral
        }
        radio?.discovered(peer)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        radio?.connected(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        radio?.connectFailed(peripheral.identifier)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        radio?.disconnected(peripheral.identifier)
    }
}

extension CoreBluetoothPort: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let service = peripheral.services?.first(where: { $0.uuid == GattProfile.service }) else {
            return radio?.servicesDiscovered(peripheral.identifier, ok: false) ?? ()
        }
        peripheral.discoverCharacteristics([GattProfile.beacon, GattProfile.rx, GattProfile.tx], for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        let found = Set(service.characteristics?.map(\.uuid) ?? [])
        let ok = error == nil && found.isSuperset(of: [GattProfile.beacon, GattProfile.rx, GattProfile.tx])
        radio?.servicesDiscovered(peripheral.identifier, ok: ok)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == GattProfile.tx else { return }
        radio?.subscribed(peripheral.identifier, ok: error == nil && characteristic.isNotifying)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        switch characteristic.uuid {
        case GattProfile.beacon:
            radio?.beaconRead(peripheral.identifier, value: error == nil ? characteristic.value ?? Data() : nil)
        case GattProfile.tx:
            if error == nil, let value = characteristic.value {
                radio?.notified(peripheral.identifier, value: value)
            }
        default:
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard characteristic.uuid == GattProfile.rx else { return }
        radio?.wrote(peripheral.identifier, ok: error == nil)
    }
}

extension CoreBluetoothPort: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state != .poweredOn {
            // CoreBluetooth drops the local database when the power goes; publish again later.
            published = false
            subscribers.removeAll()
        }
        report()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            NSLog("CairnRadio add service failed: %@", String(describing: error))
            return
        }
        published = true
        if advertising {
            peripheral.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [GattProfile.service]])
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard characteristic.uuid == GattProfile.tx else { return }
        subscribers[central.identifier] = central
        radio?.centralSubscribed(central.identifier)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard characteristic.uuid == GattProfile.tx else { return }
        subscribers[central.identifier] = nil
        radio?.centralUnsubscribed(central.identifier)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard let radio, let characteristic = GattProfile.characteristic(request.characteristic.uuid) else {
            return peripheral.respond(to: request, withResult: .requestNotSupported)
        }
        switch radio.readRequest(request.central.identifier, characteristic: characteristic, offset: request.offset) {
        case let .value(value):
            request.value = value
            peripheral.respond(to: request, withResult: .success)
        case .invalidOffset:
            peripheral.respond(to: request, withResult: .invalidOffset)
        case .notSupported:
            peripheral.respond(to: request, withResult: .requestNotSupported)
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let first = requests.first else { return }
        let writes = requests.compactMap { request in
            GattProfile.characteristic(request.characteristic.uuid).map {
                WriteRequest(characteristic: $0, offset: request.offset, value: request.value ?? Data())
            }
        }
        let accepted = writes.count == requests.count
            && radio?.writeRequests(first.central.identifier, writes) == true
        peripheral.respond(to: first, withResult: accepted ? .success : .writeNotPermitted)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        radio?.readyToUpdate()
    }
}
