import Testing
@testable import TrailDash

struct HeartRateZonesTests {
    let floors = [113, 132, 151, 170]

    @Test func zoneBoundaries() {
        #expect(HeartRateZones.zone(90, floors: floors) == 1)
        #expect(HeartRateZones.zone(112, floors: floors) == 1)
        #expect(HeartRateZones.zone(113, floors: floors) == 2)
        #expect(HeartRateZones.zone(131, floors: floors) == 2)
        #expect(HeartRateZones.zone(132, floors: floors) == 3)
        #expect(HeartRateZones.zone(151, floors: floors) == 4)
        #expect(HeartRateZones.zone(169, floors: floors) == 4)
        #expect(HeartRateZones.zone(170, floors: floors) == 5)
        #expect(HeartRateZones.zone(210, floors: floors) == 5)
    }
}
