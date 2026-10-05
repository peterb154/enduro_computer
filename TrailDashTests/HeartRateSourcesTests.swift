import Foundation
import Testing
@testable import TrailDash

struct HeartRateSourcesTests {
    let t0 = Date(timeIntervalSince1970: 0)

    func at(_ seconds: Double) -> Date { t0.addingTimeInterval(seconds) }

    @Test func primaryWinsWhileFresh() {
        var sources = HeartRateSources()
        let primaryUsed = sources.add(150, from: .primary, at: at(0))
        let backupUsed = sources.add(140, from: .backup, at: at(1))
        #expect(primaryUsed)
        #expect(!backupUsed)
        #expect(sources.active(at: at(1)) == .primary)
        #expect(sources.bpm(at: at(1)) == 150)
    }

    @Test func backupTakesOverWhenPrimaryGoesQuiet() {
        var sources = HeartRateSources()
        _ = sources.add(150, from: .primary, at: at(0))
        let stillFresh = sources.add(140, from: .backup, at: at(5))
        let stale = sources.add(141, from: .backup, at: at(6))
        #expect(!stillFresh)
        #expect(stale)
        #expect(sources.active(at: at(6)) == .backup)
        #expect(sources.bpm(at: at(6)) == 141)
    }

    @Test func primaryTakesBackOverWhenItReturns() {
        var sources = HeartRateSources()
        _ = sources.add(140, from: .backup, at: at(0))
        #expect(sources.active(at: at(0)) == .backup)
        let primaryUsed = sources.add(160, from: .primary, at: at(1))
        let backupUsed = sources.add(141, from: .backup, at: at(2))
        #expect(primaryUsed)
        #expect(!backupUsed)
        #expect(sources.active(at: at(2)) == .primary)
    }

    @Test func zeroIsNotAReading() {
        // Strap lost skin contact: it keeps sending 0, so the backup takes over.
        var sources = HeartRateSources()
        _ = sources.add(150, from: .primary, at: at(0))
        _ = sources.add(140, from: .backup, at: at(3))
        for second in 1...6 { _ = sources.add(0, from: .primary, at: at(Double(second))) }
        #expect(sources.active(at: at(6)) == .backup)
    }

    @Test func primaryZerosAreLoggedWhenNothingIsLive() {
        var sources = HeartRateSources()
        let primaryUsed = sources.add(0, from: .primary, at: at(0))
        let backupUsed = sources.add(0, from: .backup, at: at(0))
        #expect(primaryUsed)
        #expect(!backupUsed)
        #expect(sources.bpm(at: at(0)) == nil)
    }

    @Test func everythingStaleShowsNothing() {
        var sources = HeartRateSources()
        _ = sources.add(150, from: .primary, at: at(0))
        #expect(sources.bpm(at: at(5)) == 150)
        #expect(sources.bpm(at: at(5.1)) == nil)
    }

    @Test func forgetDropsASource() {
        var sources = HeartRateSources()
        _ = sources.add(150, from: .primary, at: at(0))
        _ = sources.add(140, from: .backup, at: at(0))
        sources.forget(.primary)
        #expect(sources.active(at: at(0)) == .backup)
    }
}
