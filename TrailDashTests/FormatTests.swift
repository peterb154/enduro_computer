import Testing
@testable import TrailDash

struct FormatTests {
    @Test func milesOneDecimal() {
        #expect(Format.miles(1609.344) == "1.0")
        #expect(Format.miles(0) == "0.0")
    }

    @Test func durationDropsHoursUnderAnHour() {
        #expect(Format.duration(65) == "1:05")
        #expect(Format.duration(3725) == "1:02:05")
    }
}
