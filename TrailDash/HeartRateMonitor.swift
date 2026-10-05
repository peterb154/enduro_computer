import CoreBluetooth
import Foundation

/// A BLE heart rate device seen while scanning (chest strap or a watch broadcasting HR).
struct HeartRateDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
}

/// Connects to the rider's primary heart rate device (chest strap) and an optional
/// backup (a watch broadcasting HR), both remembered across launches. Shows the
/// primary while it sends readings and falls back to the backup when it goes quiet.
/// With no primary chosen yet, it takes the first device found.
/// Keeps scanning so every device in range is listed, and keeps pending connects
/// to the chosen devices so they reconnect whenever they come back. A device that
/// stays "connected" but goes silent is disconnected and reconnected by a watchdog.
@Observable
final class HeartRateMonitor: NSObject {
    /// HR to show, from whichever source is live; nil when none is.
    private(set) var bpm: Int?
    private(set) var status = "Starting…"
    /// Every HR device seen, for the picker.
    private(set) var devices: [HeartRateDevice] = []
    private(set) var connectedIDs: Set<UUID> = []
    /// The device the shown HR comes from.
    private(set) var activeID: UUID?
    private var battery: [UUID: Int] = [:]
    /// Called for every sample that's used, including repeats and 0 bpm (no skin
    /// contact) so the raw log keeps them. The role says which device it came from.
    var onSample: ((Int, HeartRateRole) -> Void)?
    /// Connection and source changes ("hr disconnected primary", ...), for the raw log.
    var onEvent: ((String) -> Void)?

    private static let heartRateService = CBUUID(string: "180D")
    private static let measurement = CBUUID(string: "2A37")
    private static let batteryService = CBUUID(string: "180F")
    private static let batteryLevel = CBUUID(string: "2A19")

    private let settings = RideSettings.standard
    private var central: CBCentralManager!
    /// Strong references; CoreBluetooth drops peripherals nobody holds.
    private var peripherals: [UUID: CBPeripheral] = [:]
    private var sources = HeartRateSources()
    /// Last notification of any kind per connected device, for the watchdog.
    private var lastData: [UUID: Date] = [:]
    private var lastActive: HeartRateRole?
    private var watchdog: Timer?

    private(set) var primaryID = HeartRateMonitor.loadID("preferredHeartRateDevice") {
        didSet { UserDefaults.standard.set(primaryID?.uuidString, forKey: "preferredHeartRateDevice") }
    }
    private(set) var backupID = HeartRateMonitor.loadID("backupHeartRateDevice") {
        didSet { UserDefaults.standard.set(backupID?.uuidString, forKey: "backupHeartRateDevice") }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
        watchdog = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.checkSources()
        }
    }

    /// Battery of the device the HR comes from (or the primary), if it reports one.
    var batteryPercent: Int? { (activeID ?? primaryID).flatMap { battery[$0] } }

    func battery(of id: UUID) -> Int? { battery[id] }

    /// Use this device as the primary source. If it was the backup, there's no backup now.
    func selectPrimary(_ id: UUID) {
        guard id != primaryID else { return }
        let old = primaryID
        primaryID = id
        if backupID == id { backupID = nil }
        sources = HeartRateSources()
        release(old)
        connectWanted()
    }

    /// Use this device as the backup source, or none with nil. Can't be the primary.
    func selectBackup(_ id: UUID?) {
        guard id != backupID, id == nil || id != primaryID else { return }
        let old = backupID
        backupID = id
        sources.forget(.backup)
        release(old)
        connectWanted()
    }

    private func role(of id: UUID) -> HeartRateRole? {
        if id == primaryID { return .primary }
        if id == backupID { return .backup }
        return nil
    }

    /// Connects any chosen device that isn't connected or connecting.
    private func connectWanted() {
        for id in [primaryID, backupID].compactMap({ $0 }) {
            guard let peripheral = peripherals[id] ?? central.retrievePeripherals(withIdentifiers: [id]).first else { continue }
            remember(peripheral)
            if peripheral.state == .disconnected {
                peripheral.delegate = self
                central.connect(peripheral)
            }
        }
        updateDisplay()
    }

    /// Drops the connection to a device that's no longer chosen.
    private func release(_ id: UUID?) {
        guard let id, role(of: id) == nil, let peripheral = peripherals[id] else { return }
        central.cancelPeripheralConnection(peripheral)
        connectedIDs.remove(id)
        battery[id] = nil
    }

    /// Watchdog: reconnect devices that are "connected" but silent, and stop showing stale HR.
    private func checkSources() {
        let now = Date.now
        for id in connectedIDs {
            guard let last = lastData[id], now.timeIntervalSince(last) > settings.hrReconnectAfter,
                  let peripheral = peripherals[id], let role = role(of: id) else { continue }
            onEvent?("hr stale \(role.rawValue)")
            lastData[id] = now // one reconnect attempt per interval
            // didDisconnect follows and queues a reconnect.
            central.cancelPeripheralConnection(peripheral)
        }
        updateDisplay()
    }

    private func updateDisplay() {
        let now = Date.now
        let active = sources.active(at: now)
        bpm = sources.bpm(at: now)
        activeID = active.flatMap { $0 == .primary ? primaryID : backupID }
        if active != lastActive, active != nil || lastActive != nil {
            onEvent?("hr source \(active?.rawValue ?? "none")")
            lastActive = active
        }
        status = statusText(active: active)
    }

    private func statusText(active: HeartRateRole?) -> String {
        if let activeID {
            return active == .backup ? "Backup: \(name(of: activeID))" : name(of: activeID)
        }
        guard let primaryID else { return "Scanning for HR…" }
        if connectedIDs.isEmpty { return "Reconnecting to \(name(of: primaryID))…" }
        return "No HR from \(name(of: primaryID))"
    }

    private func remember(_ peripheral: CBPeripheral, advertisedName: String? = nil) {
        peripherals[peripheral.identifier] = peripheral
        guard !devices.contains(where: { $0.id == peripheral.identifier }) else { return }
        devices.append(HeartRateDevice(id: peripheral.identifier, name: advertisedName ?? peripheral.name ?? "HR device"))
    }

    private func name(of id: UUID) -> String {
        devices.first { $0.id == id }?.name ?? peripherals[id]?.name ?? "HR device"
    }

    private static func loadID(_ key: String) -> UUID? {
        UserDefaults.standard.string(forKey: key).flatMap(UUID.init)
    }
}

extension HeartRateMonitor: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            central.scanForPeripherals(withServices: [Self.heartRateService])
            connectWanted()
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
        if primaryID == nil { primaryID = peripheral.identifier }
        connectWanted()
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard let role = role(of: peripheral.identifier) else {
            central.cancelPeripheralConnection(peripheral)
            return
        }
        connectedIDs.insert(peripheral.identifier)
        lastData[peripheral.identifier] = .now // grace period before the watchdog looks
        onEvent?("hr connected \(role.rawValue)")
        peripheral.discoverServices([Self.heartRateService, Self.batteryService])
        updateDisplay()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard role(of: peripheral.identifier) != nil else { return }
        central.connect(peripheral) // keep trying the chosen device
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let id = peripheral.identifier
        connectedIDs.remove(id)
        lastData[id] = nil
        // A device we switched away from: nothing more to do.
        guard let role = role(of: id) else { return }
        sources.forget(role)
        onEvent?("hr disconnected \(role.rawValue)")
        // A pending connect never times out, so this reconnects whenever the device comes back.
        central.connect(peripheral)
        updateDisplay()
    }
}

extension HeartRateMonitor: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        for service in peripheral.services ?? [] {
            switch service.uuid {
            case Self.heartRateService: peripheral.discoverCharacteristics([Self.measurement], for: service)
            case Self.batteryService: peripheral.discoverCharacteristics([Self.batteryLevel], for: service)
            default: break
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == Self.measurement {
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == Self.batteryLevel {
                peripheral.readValue(for: characteristic)
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        let id = peripheral.identifier
        guard let role = role(of: id), let data = characteristic.value else { return }
        if characteristic.uuid == Self.batteryLevel {
            guard let level = data.first.map({ min(100, Int($0)) }), level != battery[id] else { return }
            battery[id] = level
            onEvent?("hr battery \(role.rawValue) \(level)%")
            return
        }
        let now = Date.now
        lastData[id] = now
        guard let sample = parseHeartRate(data) else { return }
        if sources.add(sample, from: role, at: now) {
            onSample?(sample, role)
        }
        updateDisplay()
    }
}
