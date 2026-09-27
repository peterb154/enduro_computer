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

    @Test func mphFromMetersPerSecond() {
        #expect(Format.mph(2.2352) == "5.0")
    }

    @Test func runTimeInTenths() {
        #expect(Format.runTime(201.47) == "3:21.4")
        #expect(Format.runTime(9.05) == "0:09.0")
    }

    @Test func signedMinutesForPace() {
        #expect(Format.signedMinutes(65.9) == "+1:05")
        #expect(Format.signedMinutes(-12.4) == "-0:12")
        #expect(Format.signedMinutes(0) == "+0:00")
    }

    @Test func clockFromSeconds() {
        #expect(Format.clock(seconds: 10 * 3600 + 54 * 60) == "10:54:00")
        #expect(Format.clock(seconds: 13 * 3600 + 7 * 60 + 15) == "1:07:15")
        #expect(Format.clock(seconds: 12 * 3600) == "12:00:00")
        #expect(Format.clock(seconds: 0) == "12:00:00")
    }
}
