import Foundation
import Testing
@testable import TrailDash

struct RideLogTests {
    let fix = Fix(time: Date(timeIntervalSince1970: 1_000), latitude: 44.1, longitude: -115.2,
                  horizontalAccuracy: 5, speed: 4, course: 90, altitude: 1500)

    @Test func eventsRoundTripThroughJSONLines() {
        let events: [LogEvent] = [
            .mark("start", at: Date(timeIntervalSince1970: 999)),
            .fix(fix),
            .heartRate(150, at: Date(timeIntervalSince1970: 1_000.5)),
        ]
        var data = Data()
        for event in events { data.append(encodeLogLine(event)) }
        #expect(decodeLog(data) == events)
        #expect(decodeLog(data)[1].fix?.course == 90)
    }

    @Test func skipsPartialLastLine() {
        var data = encodeLogLine(.fix(fix))
        data.append(Data(#"{"t":1001,"type":"fi"#.utf8))
        #expect(decodeLog(data).count == 1)
    }

    @Test func gpxFiltersBadFixesAndAttachesHeartRate() {
        var bad = fix
        bad.horizontalAccuracy = 50
        let gpx = makeGPX([.fix(fix), .heartRate(142, at: fix.time), .fix(fix), .fix(bad)], name: "test")
        #expect(gpx.components(separatedBy: "<trkpt").count - 1 == 2)
        #expect(gpx.components(separatedBy: "<gpxtpx:hr>142</gpxtpx:hr>").count - 1 == 1)
        #expect(gpx.contains(#"lat="44.1" lon="-115.2""#))
        #expect(gpx.contains("<time>1970-01-01T00:16:40Z</time>"))
    }
}
