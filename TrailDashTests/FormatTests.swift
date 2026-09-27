import Foundation
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

    @Test func clockIs24Hour() {
        #expect(Format.clock(seconds: 10 * 3600 + 54 * 60) == "10:54:00")
        #expect(Format.clock(seconds: 13 * 3600 + 4 * 60) == "13:04:00")
        #expect(Format.clock(seconds: 9 * 3600) == "9:00:00")
        #expect(Format.clock(seconds: 0) == "0:00:00")
    }

    @Test func clockFromDate() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 4, hour: 14, minute: 51, second: 7))!
        #expect(Format.clock(date, calendar: calendar) == "14:51:07")
    }
}
