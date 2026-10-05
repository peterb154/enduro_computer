import Foundation

/// A sprint enduro race: tests ridden once each, in order (Test 1, 2, 3, ...),
/// with one raw log covering the whole day, transfer and pit time included.
/// The race (session) opens when the rider starts it and only closes when they
/// explicitly end it in Settings, so the day's track is always recorded.
@Observable
final class SprintSession {
    /// The test that the next arm will time. Advances after each run.
    private(set) var nextTest = 1
    /// Saved races (key time + roll chart), kept across app restarts and sessions.
    var races: [RaceSchedule] = SprintSession.loadRaces() {
        didSet { Self.save(races, key: "races") }
    }
    /// The race used for countdowns and scoring; nil means plain timing, no chart.
    var selectedRaceID: UUID? = UserDefaults.standard.string(forKey: "selectedRaceID").flatMap(UUID.init) {
        didSet { UserDefaults.standard.set(selectedRaceID?.uuidString, forKey: "selectedRaceID") }
    }

    /// The selected race, or an empty one (no tests) when none is selected.
    var race: RaceSchedule {
        races.first { $0.id == selectedRaceID } ?? RaceSchedule(name: "No race")
    }
    var hasSelectedRace: Bool { races.contains { $0.id == selectedRaceID } }

    /// Adds a race, selects it, and returns its id for editing.
    @discardableResult
    func newRace() -> UUID {
        let race = RaceSchedule(name: "Race \(races.count + 1)")
        races.append(race)
        selectedRaceID = race.id
        return race.id
    }

    func deleteRaces(at offsets: IndexSet) {
        races.remove(atOffsets: offsets)
        if !hasSelectedRace { selectedRaceID = nil }
    }
    private(set) var timer = SprintTimer()
    /// Distance ridden since the last test ended (the out-check), for the transfer.
    private(set) var transferStats = TripStats()
    private(set) var runs: [SprintRun] = []
    private(set) var log: RideLog?
    private let location: LocationTracker

    init(location: LocationTracker) {
        self.location = location
    }

    var isSessionOpen: Bool { log != nil }

    /// Chart pace for the next test, if its times and miles are entered.
    var chartPaceMph: Double? { race.paceMph(for: nextTest) }

    /// Miles left to the next test's start, counted from the last test's end mile.
    var transferMilesToGo: Double? {
        guard let last = runs.last, let total = race.transferMiles(afterTest: last.test, to: nextTest) else { return nil }
        return max(0, total - transferStats.distance / 1609.344)
    }

    /// Chart length of the next (or running) test, if its miles are entered.
    var chartLengthMiles: Double? { race.test(nextTest)?.lengthMiles }

    /// Pace for live time-dropped while running: the chart's, else the fallback.
    var livePaceMph: Double { chartPaceMph ?? RideSettings.standard.sprintFallbackPaceMph }

    /// When this rider is due at the next test's start, if it's on the roll chart.
    func nextTestDue(today: Date = .now) -> Date? {
        race.dueDate(for: nextTest, on: today)
    }

    /// Sum of all test times: what the event is scored on.
    var totalTime: TimeInterval { runs.map(\.duration).reduce(0, +) }
    var totalDropped: TimeInterval { runs.map(\.timeDropped).reduce(0, +) }

    /// Fix the count if a test was skipped or cancelled.
    func changeNextTest(by delta: Int) {
        nextTest = max(1, nextTest + delta)
    }

    /// Opens the race: starts the raw log and background GPS.
    func startSession() {
        guard log == nil else { return }
        // Test number and race selection are the rider's pre-race setup; keep them.
        runs = []
        transferStats = TripStats()
        log = RideLog(startedAt: .now)
        log?.append(.mark("start race \(race.name)", at: .now))
        location.setBackgroundUpdates(true)
    }

    func arm() {
        guard isSessionOpen else { return }
        timer.arm()
        log?.append(.mark("arm Test \(nextTest)", at: .now))
    }

    func disarm() {
        timer.disarm()
        log?.append(.mark("disarm", at: .now))
    }

    /// `time` is when the rider started pressing stop, so the hold doesn't add time.
    /// If the bike had already stopped, the run ends when it stopped moving instead.
    func stop(at pressed: Date) {
        let time = officialStop(pressed: pressed, lastMoving: timer.lastMoving)
        guard let result = timer.stop() else { return }
        if time != pressed { log?.append(.mark("pressed stop", at: pressed)) }
        let run = SprintRun(
            test: nextTest,
            start: result.start,
            end: max(time, result.start),
            distance: result.stats.distance,
            averageHeartRate: result.stats.averageHeartRate,
            maxHeartRate: result.stats.maxHeartRate,
            idealTime: race.idealTime(for: nextTest),
            rolled: timer.rolledAt
        )
        runs.append(run)
        nextTest += 1
        transferStats = TripStats() // at the out-check: odometer = this test's end mile
        log?.append(.mark("stop \(run.label)", at: run.end))
    }

    func endSession() {
        timer.disarm()
        log?.append(.mark("end race", at: .now))
        log?.finish()
        log = nil
        location.setBackgroundUpdates(false)
        // Results stay on screen until the next arm; saved races are kept.
        nextTest = 1
    }

    /// Clear results and go back to Test 1. An open race keeps recording.
    func reset() {
        timer.disarm()
        log?.append(.mark("reset results", at: .now))
        runs = []
        nextTest = 1
        transferStats = TripStats()
    }

    func add(_ fix: Fix) {
        guard isSessionOpen else { return }
        log?.append(.fix(fix))
        if !timer.isRunning { transferStats.add(fix) }
        let wasRunning = timer.isRunning
        timer.add(fix)
        if !wasRunning, case .running(let rolling) = timer.state {
            // Late riders are timed from their due minute, like the official clock.
            let start = officialStart(rolling: rolling, due: nextTestDue(today: rolling))
            timer.setStart(start)
            // Logged after the fact with the backdated start times.
            log?.append(.mark("rolled Test \(nextTest)", at: rolling))
            log?.append(.mark("start Test \(nextTest)", at: start))
        }
    }

    func mark(_ name: String) {
        guard isSessionOpen else { return }
        log?.append(.mark(name, at: .now))
    }

    func add(heartRate: Int, source: HeartRateRole = .primary) {
        guard isSessionOpen else { return }
        log?.append(.heartRate(heartRate, at: .now, source: source))
        timer.add(heartRate: heartRate)
    }

    /// Loads saved races, migrating the single race saved by earlier versions.
    private static func loadRaces() -> [RaceSchedule] {
        if let races = load([RaceSchedule].self, key: "races") { return races }
        guard let old = load(RaceSchedule.self, key: "race") else { return [] }
        UserDefaults.standard.set(old.id.uuidString, forKey: "selectedRaceID")
        return [old]
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }
}
