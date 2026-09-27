import Foundation
import Testing
@testable import TrailDash

struct SprintTimerTests {
    let t0 = Date(timeIntervalSince1970: 0)

    /// Fix `meters` north of a fixed origin, `seconds` after t0.
    func fix(_ seconds: Double, speed: Double, meters: Double = 0, accuracy: Double = 5) -> Fix {
        Fix(time: t0.addingTimeInterval(seconds),
            latitude: 44.0 + meters / 111_195,
            longitude: -115.0,
            horizontalAccuracy: accuracy,
            speed: speed)
    }

    func armed() -> SprintTimer {
        var timer = SprintTimer()
        timer.arm()
        return timer
    }

    @Test func idleIgnoresMovement() {
        var timer = SprintTimer()
        timer.add(fix(0, speed: 10))
        timer.add(fix(2, speed: 10))
        #expect(timer.state == .idle)
    }

    @Test func stoppedJitterDoesNotStart() {
        var timer = armed()
        for second in 0..<10 {
            timer.add(fix(Double(second), speed: 0.4))
        }
        #expect(timer.state == .armed)
    }

    @Test func singleFastFixDoesNotStart() {
        var timer = armed()
        timer.add(fix(0, speed: 3))
        timer.add(fix(1, speed: 0))
        #expect(timer.state == .armed)
    }

    @Test func launchStartsBackdatedToFirstRollingFix() {
        var timer = armed()
        timer.add(fix(0, speed: 0))
        timer.add(fix(1, speed: 1.5, meters: 1)) // rolling, under 5 mph
        timer.add(fix(2, speed: 4, meters: 4)) // fast
        #expect(timer.state == .armed)
        timer.add(fix(3, speed: 7, meters: 10)) // fast, sustained 1 s
        #expect(timer.state == .running(start: t0.addingTimeInterval(1)))
        #expect(abs(timer.stats.distance - 9) < 0.1)
    }

    @Test func slowCreepBackdateIsCapped() {
        var timer = armed()
        for second in 0..<10 {
            timer.add(fix(Double(second), speed: 1.2, meters: Double(second)))
        }
        timer.add(fix(10, speed: 4, meters: 12))
        timer.add(fix(11, speed: 6, meters: 18))
        // Fast streak began at 10 s; capped at 3 s before that.
        #expect(timer.state == .running(start: t0.addingTimeInterval(7)))
    }

    @Test func droppingBelowMovingSpeedResetsLaunch() {
        var timer = armed()
        timer.add(fix(0, speed: 3))
        timer.add(fix(1, speed: 0.2)) // stalled
        timer.add(fix(2, speed: 3))
        timer.add(fix(3, speed: 3))
        #expect(timer.state == .running(start: t0.addingTimeInterval(2)))
    }

    @Test func inaccurateFixesAreIgnoredWhileArmed() {
        var timer = armed()
        timer.add(fix(0, speed: 10, accuracy: 60))
        timer.add(fix(1, speed: 10, accuracy: 60))
        #expect(timer.state == .armed)
    }

    @Test func stopReturnsRunStatsAndGoesIdle() {
        var timer = armed()
        timer.add(fix(0, speed: 3, meters: 0))
        timer.add(fix(1, speed: 3, meters: 3))
        timer.add(fix(2, speed: 3, meters: 6))
        timer.add(heartRate: 170)
        let result = timer.stop()
        #expect(result?.start == t0)
        #expect(abs((result?.stats.distance ?? 0) - 6) < 0.1)
        #expect(result?.stats.maxHeartRate == 170)
        #expect(timer.state == .idle)
        let second = timer.stop()
        #expect(second == nil)
    }

    @Test func disarmReturnsToIdle() {
        var timer = armed()
        timer.disarm()
        timer.add(fix(0, speed: 5))
        timer.add(fix(1, speed: 5))
        #expect(timer.state == .idle)
    }

    @Test func runAverageSpeedIncludesStops() {
        let run = SprintRun(test: 2, start: t0, end: t0.addingTimeInterval(100),
                            distance: 1000, averageHeartRate: nil, maxHeartRate: nil, idealTime: nil)
        #expect(run.averageSpeed == 10)
        #expect(run.label == "Test 2")
    }

    @Test func timeDroppedAgainstPace() {
        // One mile at 24 mph takes 150 s.
        #expect(abs(timeDropped(elapsed: 190, distance: 1609.344, paceMph: 24) - 40) < 0.01)
        #expect(abs(timeDropped(elapsed: 140, distance: 1609.344, paceMph: 24) + 10) < 0.01)
        #expect(timeDropped(elapsed: 100, distance: 1000, paceMph: 0) == 0)
    }

    @Test func runDroppedUsesChartIdealTimeWhenKnown() {
        let run = SprintRun(test: 2, start: t0, end: t0.addingTimeInterval(1750),
                            distance: 15_000, averageHeartRate: nil, maxHeartRate: nil, idealTime: 1710)
        #expect(run.timeDropped == 40)
    }

    @Test func runDroppedFallsBackToGPSDistanceAtDefaultPace() {
        // One mile at the 24 mph fallback takes 150 s.
        let run = SprintRun(test: 2, start: t0, end: t0.addingTimeInterval(190),
                            distance: 1609.344, averageHeartRate: nil, maxHeartRate: nil, idealTime: nil)
        #expect(abs(run.timeDropped - 40) < 0.01)
    }

    @Test func lateRiderIsTimedFromDueMinute() {
        let due = t0
        #expect(officialStart(rolling: t0.addingTimeInterval(95), due: due) == due)
    }

    @Test func earlyOrOnTimeRiderIsTimedFromRolling() {
        let rolling = t0.addingTimeInterval(-4)
        #expect(officialStart(rolling: rolling, due: t0) == rolling)
        #expect(officialStart(rolling: t0, due: t0) == t0)
    }

    @Test func noDueTimeUsesRolling() {
        let rolling = t0.addingTimeInterval(30)
        #expect(officialStart(rolling: rolling, due: nil) == rolling)
    }

    @Test func implausiblyLateUsesRolling() {
        // Over an hour late: probably the wrong test number or race selected.
        let rolling = t0.addingTimeInterval(3 * 3600)
        #expect(officialStart(rolling: rolling, due: t0) == rolling)
    }

    @Test func setStartMovesRunningStartOnly() {
        var timer = armed()
        timer.setStart(t0) // not running yet: ignored
        #expect(timer.state == .armed)
        timer.add(fix(10, speed: 3))
        timer.add(fix(11, speed: 3))
        timer.setStart(t0)
        #expect(timer.state == .running(start: t0))
    }
}
