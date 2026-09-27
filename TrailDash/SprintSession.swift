import Foundation

/// A sprint enduro session: tests ridden once each, in order (Test 1, 2, 3, ...),
/// with one raw log covering the whole day, transfer and pit time included.
/// The session opens on the first arm and closes when the rider ends it.
@Observable
final class SprintSession {
    /// The test that the next arm will time. Advances after each run.
    private(set) var nextTest = 1
    private(set) var timer = SprintTimer()
    private(set) var runs: [SprintRun] = []
    private(set) var log: RideLog?
    /// The last closed session's log, for sharing.
    private(set) var finishedLog: RideLog?
    private let location: LocationTracker

    init(location: LocationTracker) {
        self.location = location
    }

    var isSessionOpen: Bool { log != nil }

    /// Sum of all test times: what the event is scored on.
    var totalTime: TimeInterval { runs.map(\.duration).reduce(0, +) }

    /// Fix the count if a test was skipped or cancelled.
    func changeNextTest(by delta: Int) {
        nextTest = max(1, nextTest + delta)
    }

    func arm() {
        if log == nil {
            runs = []
            nextTest = 1
            finishedLog = nil
            log = RideLog(startedAt: .now)
            location.setBackgroundUpdates(true)
        }
        timer.arm()
        log?.append(.mark("arm Test \(nextTest)", at: .now))
    }

    func disarm() {
        timer.disarm()
        log?.append(.mark("disarm", at: .now))
    }

    /// `time` is when the rider started pressing stop, so the hold doesn't add time.
    func stop(at time: Date) {
        guard let result = timer.stop() else { return }
        let run = SprintRun(
            test: nextTest,
            start: result.start,
            end: max(time, result.start),
            distance: result.stats.distance,
            averageHeartRate: result.stats.averageHeartRate,
            maxHeartRate: result.stats.maxHeartRate
        )
        runs.append(run)
        nextTest += 1
        log?.append(.mark("stop \(run.label)", at: run.end))
    }

    func endSession() {
        log?.append(.mark("end session", at: .now))
        log?.finish()
        finishedLog = log
        log = nil
        location.setBackgroundUpdates(false)
    }

    func add(_ fix: Fix) {
        guard isSessionOpen else { return }
        log?.append(.fix(fix))
        let wasRunning = timer.isRunning
        timer.add(fix)
        if !wasRunning, case .running(let start) = timer.state {
            // Logged after the fact with the backdated start time.
            log?.append(.mark("start Test \(nextTest)", at: start))
        }
    }

    func add(heartRate: Int) {
        guard isSessionOpen else { return }
        log?.append(.heartRate(heartRate, at: .now))
        timer.add(heartRate: heartRate)
    }
}
