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

    @Test func earlyRiderIsStillTimedFromDueMinute() {
        // Leaving early doesn't help: you're counted from your minute.
        #expect(officialStart(rolling: t0.addingTimeInterval(-14), due: t0) == t0)
        #expect(officialStart(rolling: t0, due: t0) == t0)
    }

    @Test func practiceRollLongBeforeDueUsesRolling() {
        let rolling = t0.addingTimeInterval(-20 * 60)
        #expect(officialStart(rolling: rolling, due: t0) == rolling)
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

    @Test func speedTrendAgainstTestAverage() {
        #expect(speedTrend(recent: 9, average: 8) == .up)
        #expect(speedTrend(recent: 7, average: 8) == .down)
        #expect(speedTrend(recent: 8.1, average: 8) == .flat)
        #expect(speedTrend(recent: nil, average: 8) == .flat)
    }

    @Test func recentSpeedUsesLastMinuteOnly() {
        var timer = armed()
        timer.add(fix(0, speed: 3, meters: 0))
        timer.add(fix(1, speed: 3, meters: 3)) // starts
        #expect(timer.recentSpeed() == nil) // not enough history yet
        // 60 s slow (3 m/s), then 60 s fast (8 m/s).
        var meters = 3.0
        for second in 2...61 { meters += 3; timer.add(fix(Double(second), speed: 3, meters: meters)) }
        for second in 62...121 { meters += 8; timer.add(fix(Double(second), speed: 8, meters: meters)) }
        #expect(abs((timer.recentSpeed() ?? 0) - 8) < 0.1)
    }

    @Test func stopWhileMovingEndsAtPress() {
        let pressed = t0.addingTimeInterval(100)
        #expect(officialStop(pressed: pressed, lastMoving: t0.addingTimeInterval(99.5)) == pressed)
    }

    @Test func stopAfterStandingStillEndsWhenBikeStopped() {
        // Stopped at the check, 30 s to get a glove off, then pressed.
        let stopped = t0.addingTimeInterval(100)
        #expect(officialStop(pressed: stopped.addingTimeInterval(30), lastMoving: stopped) == stopped)
        #expect(officialStop(pressed: t0, lastMoving: nil) == t0)
    }

    @Test func timerTracksLastMovingFix() {
        var timer = armed()
        timer.add(fix(0, speed: 3, meters: 0))
        timer.add(fix(1, speed: 3, meters: 3)) // starts
        timer.add(fix(2, speed: 5, meters: 8))
        timer.add(fix(3, speed: 0.2, meters: 8)) // stopped
        timer.add(fix(40, speed: 0.1, meters: 8))
        #expect(timer.lastMoving == t0.addingTimeInterval(2))
    }

    @Test func ridingAverageIgnoresDueMinuteShift() {
        var timer = armed()
        timer.add(fix(100, speed: 5, meters: 0))
        timer.add(fix(101, speed: 5, meters: 5)) // rolls at 100
        timer.setStart(t0.addingTimeInterval(110)) // official start: due minute 10 s later
        timer.add(fix(102, speed: 5, meters: 10))
        // 10 m in 2 s of riding, not 10 m in "negative" official time.
        #expect(abs(timer.ridingAverageSpeed(at: t0.addingTimeInterval(102)) - 5) < 0.01)
    }

    @Test func runAverageSpeedUsesRidingTime() {
        // Timed from due (t0) but rolled 20 s late: 1000 m over 100 s of riding.
        let run = SprintRun(test: 1, start: t0, end: t0.addingTimeInterval(120), distance: 1000,
                            averageHeartRate: nil, maxHeartRate: nil, idealTime: nil,
                            rolled: t0.addingTimeInterval(20))
        #expect(run.averageSpeed == 10)
    }
}
