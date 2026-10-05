import SwiftUI

/// HR colored by zone, so effort reads at a glance without reading the number:
/// Zone 1 and below white, 2 blue, 3 orange, 4 red, 5 purple.
nonisolated enum HeartRateZones {
    /// Floors of Zones 2-5 (bpm) unless changed in Settings; from the rider's Garmin.
    static let defaultFloors = [113, 132, 151, 170]

    static func floorKey(zone: Int) -> String { "hrZone\(zone)Floor" }

    /// Floors of Zones 2-5 as set in Settings.
    static var floors: [Int] {
        (2...5).enumerated().map { index, zone in
            UserDefaults.standard.object(forKey: floorKey(zone: zone)) as? Int ?? defaultFloors[index]
        }
    }

    /// 1 below the Zone 2 floor, else the highest zone whose floor the bpm reaches.
    static func zone(_ bpm: Int, floors: [Int] = floors) -> Int {
        1 + floors.filter { bpm >= $0 }.count
    }

    static func color(zone: Int) -> Color {
        switch zone {
        case 2: Color(red: 0.3, green: 0.6, blue: 1.0)
        case 3: .orange
        case 4: .red
        case 5: Color(red: 0.75, green: 0.4, blue: 1.0)
        default: .white
        }
    }

    static func color(bpm: Int?) -> Color {
        bpm.map { color(zone: zone($0)) } ?? .white
    }
}
