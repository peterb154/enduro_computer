import Foundation

/// Builds a GPX track from a raw log. Uses the same accuracy filter as ride
/// stats, and attaches the most recent HR sample to each point using Garmin's
/// TrackPointExtension (read by Strava, Garmin Connect, etc). Points get no HR
/// when the last real reading is old (strap died) or was 0 (no skin contact).
nonisolated func makeGPX(_ events: [LogEvent], name: String, settings: RideSettings = .standard) -> String {
    let timeFormat = ISO8601DateFormatter()
    var lines = [
        #"<?xml version="1.0" encoding="UTF-8"?>"#,
        #"<gpx version="1.1" creator="TrailDash" xmlns="http://www.topografix.com/GPX/1/1" xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">"#,
        "<trk><name>\(name)</name><trkseg>",
    ]
    var heartRate: (bpm: Int, time: Date)?
    for event in events {
        if event.type == "hr" {
            if let bpm = event.bpm, bpm > 0 { heartRate = (bpm, event.time) }
            continue
        }
        guard let fix = event.fix,
              fix.horizontalAccuracy >= 0,
              fix.horizontalAccuracy <= settings.maxHorizontalAccuracy else { continue }

        var point = #"<trkpt lat="\#(fix.latitude)" lon="\#(fix.longitude)">"#
        point += "<ele>\(String(format: "%.1f", fix.altitude))</ele>"
        point += "<time>\(timeFormat.string(from: fix.time))</time>"
        if let heartRate, fix.time.timeIntervalSince(heartRate.time) <= settings.gpxMaxHeartRateAge {
            point += "<extensions><gpxtpx:TrackPointExtension><gpxtpx:hr>\(heartRate.bpm)</gpxtpx:hr></gpxtpx:TrackPointExtension></extensions>"
        }
        point += "</trkpt>"
        lines.append(point)
    }
    lines.append("</trkseg></trk></gpx>")
    return lines.joined(separator: "\n") + "\n"
}
