import CoreBluetooth
import Foundation

/// Connects to the first BLE heart rate device it finds (chest strap or a
/// watch broadcasting HR) and keeps reconnecting to it if the link drops.
@Observable
final class HeartRateMonitor: NSObject {
    private(set) var bpm: Int?
    private(set) var status = "Starting…"
    /// Called for every HR sample, including repeats of the same value.
    var onSample: ((Int) -> Void)?

    private static let heartRateService = CBUUID(string: "180D")
    private static let measurement = CBUUID(string: "2A37")

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    private func scan() {
        status = "Scanning for HR…"
        central.scanForPeripherals(withServices: [Self.heartRateService])
    }
}

extension HeartRateMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            scan()
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
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        status = "Connecting to \(peripheral.name ?? "HR device")…"
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        status = "Connected: \(peripheral.name ?? "HR device")"
        peripheral.discoverServices([Self.heartRateService])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        self.peripheral = nil
        scan()
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        bpm = nil
        status = "Reconnecting to \(peripheral.name ?? "HR device")…"
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
        guard let data = characteristic.value, let sample = parseHeartRate(data) else { return }
        bpm = sample
        onSample?(sample)
    }
}
