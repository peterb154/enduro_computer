import Foundation

/// A sprint enduro session: many armed/timed runs across a few tests, with one
/// raw log covering the whole day (pit time included). The session opens on the
/// first arm and closes when the rider ends it.
@Observable
final class SprintSession {
    static let tests = [1, 2, 3]

    var selectedTest = 1
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

    func runNumber(for test: Int) -> Int {
        runs.filter { $0.test == test }.count + 1
    }

    private var nextRunLabel: String { "Test \(selectedTest) run \(runNumber(for: selectedTest))" }

    func arm() {
        if log == nil {
            runs = []
            finishedLog = nil
            log = RideLog(startedAt: .now)
            location.setBackgroundUpdates(true)
        }
        timer.arm()
        log?.append(.mark("arm \(nextRunLabel)", at: .now))
    }

    func disarm() {
        timer.disarm()
        log?.append(.mark("disarm", at: .now))
    }

    /// `time` is when the rider started pressing stop, so the hold doesn't add time.
    func stop(at time: Date) {
        guard let result = timer.stop() else { return }
        let run = SprintRun(
            test: selectedTest,
            number: runNumber(for: selectedTest),
            start: result.start,
            end: max(time, result.start),
            distance: result.stats.distance,
            averageHeartRate: result.stats.averageHeartRate,
            maxHeartRate: result.stats.maxHeartRate
        )
        runs.append(run)
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
            log?.append(.mark("start \(nextRunLabel)", at: start))
        }
    }

    func add(heartRate: Int) {
        guard isSessionOpen else { return }
        log?.append(.heartRate(heartRate, at: .now))
        timer.add(heartRate: heartRate)
    }
}
