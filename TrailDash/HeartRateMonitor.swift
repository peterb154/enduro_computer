import CoreBluetooth
import Foundation

/// A BLE heart rate device seen while scanning (chest strap or a watch broadcasting HR).
struct HeartRateDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
}

/// Connects to the rider's preferred heart rate device, remembered across launches.
/// With no preference yet, it takes the first device found and remembers that one.
/// Keeps scanning so every device in range is listed, and keeps a pending connect
/// to the chosen device so it reconnects whenever it comes back.
@Observable
final class HeartRateMonitor: NSObject {
    private(set) var bpm: Int?
    private(set) var status = "Starting…"
    /// Every HR device seen, for the picker.
    private(set) var devices: [HeartRateDevice] = []
    /// The device currently delivering HR, if any.
    private(set) var connectedID: UUID?
    /// Called for every HR sample, including repeats of the same value.
    var onSample: ((Int) -> Void)?

    private static let heartRateService = CBUUID(string: "180D")
    private static let measurement = CBUUID(string: "2A37")
    private static let preferredKey = "preferredHeartRateDevice"

    private var central: CBCentralManager!
    /// Strong references; CoreBluetooth drops peripherals nobody holds.
    private var peripherals: [UUID: CBPeripheral] = [:]
    /// The chosen device: connected or waiting to reconnect.
    private var current: CBPeripheral?
    private(set) var preferredID = UserDefaults.standard.string(forKey: HeartRateMonitor.preferredKey).flatMap(UUID.init) {
        didSet { UserDefaults.standard.set(preferredID?.uuidString, forKey: Self.preferredKey) }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    /// Switch to another device and remember it.
    func select(_ id: UUID) {
        guard let peripheral = peripherals[id] else { return }
        preferredID = id
        if let current, current.identifier != id {
            central.cancelPeripheralConnection(current)
            bpm = nil
            connectedID = nil
        }
        connect(peripheral)
    }

    private func connect(_ peripheral: CBPeripheral) {
        current = peripheral
        peripheral.delegate = self
        status = "Connecting to \(name(of: peripheral))…"
        central.connect(peripheral)
    }

    private func remember(_ peripheral: CBPeripheral, advertisedName: String? = nil) {
        peripherals[peripheral.identifier] = peripheral
        guard !devices.contains(where: { $0.id == peripheral.identifier }) else { return }
        devices.append(HeartRateDevice(id: peripheral.identifier, name: advertisedName ?? name(of: peripheral)))
    }

    private func name(of peripheral: CBPeripheral) -> String {
        devices.first { $0.id == peripheral.identifier }?.name ?? peripheral.name ?? "HR device"
    }
}

extension HeartRateMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: [Self.heartRateService])
            if let preferredID, let known = central.retrievePeripherals(withIdentifiers: [preferredID]).first {
                remember(known)
                connect(known)
            } else {
                status = "Scanning for HR…"
            }
        case .unauthorized:
            status = "Bluetooth permission denied"
        case .poweredOff:
            status = "Bluetooth is off"
        default:
            status = "Bluetooth unavailable"
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        remember(peripheral, advertisedName: advertisementData[CBAdvertisementDataLocalNameKey] as? String)
        guard current == nil, preferredID == nil || preferredID == peripheral.identifier else { return }
        preferredID = peripheral.identifier
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard peripheral.identifier == current?.identifier else { return }
        connectedID = peripheral.identifier
        status = "Connected: \(name(of: peripheral))"
        peripheral.discoverServices([Self.heartRateService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == current?.identifier else { return }
        central.connect(peripheral) // keep trying the chosen device
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // A device we switched away from: nothing to do.
        guard peripheral.identifier == current?.identifier else { return }
        bpm = nil
        connectedID = nil
        status = "Reconnecting to \(name(of: peripheral))…"
        // A pending connect never times out, so this reconnects whenever the device comes back.
        central.connect(peripheral)
    }
}

extension HeartRateMonitor: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] where service.uuid == Self.heartRateService {
            peripheral.discoverCharacteristics([Self.measurement], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] where characteristic.uuid == Self.measurement {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard peripheral.identifier == current?.identifier,
              let data = characteristic.value, let sample = parseHeartRate(data) else { return }
        bpm = sample
        onSample?(sample)
    }
}
