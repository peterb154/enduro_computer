import Testing
@testable import TrailDash

struct PaceScheduleTests {
    @Test func defaultAppliesToEveryTest() {
        let paces = PaceSchedule(defaultMph: 24)
        #expect(paces.pace(for: 1) == 24)
        #expect(paces.pace(for: 12) == 24)
        #expect(paces.summary == "T1+ 24")
    }

    @Test func changeCarriesForward() {
        var paces = PaceSchedule(defaultMph: 24)
        paces.setPace(22, from: 5)
        #expect(paces.pace(for: 4) == 24)
        #expect(paces.pace(for: 5) == 22)
        #expect(paces.pace(for: 9) == 22)
        #expect(paces.summary == "T1–4 24 · T5+ 22")
    }

    @Test func laterChangeOverridesOnlyFromThere() {
        var paces = PaceSchedule(defaultMph: 24)
        paces.setPace(22, from: 5)
        paces.setPace(24, from: 7)
        paces.setPace(20, from: 3)
        #expect(paces.summary == "T1–2 24 · T3–4 20 · T5–6 22 · T7+ 24")
    }

    @Test func singleTestSegment() {
        var paces = PaceSchedule(defaultMph: 24)
        paces.setPace(18, from: 4)
        paces.setPace(24, from: 5)
        #expect(paces.summary == "T1–3 24 · T4 18 · T5+ 24")
    }

    @Test func settingFirstTestChangesWholeEvent() {
        var paces = PaceSchedule(defaultMph: 24)
        paces.setPace(30, from: 1)
        #expect(paces.pace(for: 8) == 30)
        #expect(paces.summary == "T1+ 30")
    }

    @Test func steppingBackToInheritedPaceRemovesChange() {
        var paces = PaceSchedule(defaultMph: 24)
        paces.setPace(23, from: 5)
        paces.setPace(24, from: 5)
        #expect(paces.changes.isEmpty)
    }

    @Test func redundantLaterChangeIsDropped() {
        var paces = PaceSchedule(defaultMph: 24)
        paces.setPace(22, from: 5)
        paces.setPace(22, from: 3) // now 5 no longer changes anything
        #expect(paces.changes == [3: 22])
        #expect(paces.summary == "T1–2 24 · T3+ 22")
    }

    @Test func resetAppliesFirstTestPaceEverywhere() {
        var paces = PaceSchedule(defaultMph: 24)
        paces.setPace(26, from: 1)
        paces.setPace(22, from: 5)
        #expect(paces.varies)
        paces.resetToFirstTestPace()
        #expect(!paces.varies)
        #expect(paces.pace(for: 9) == 26)
        #expect(paces.summary == "T1+ 26")
    }
}
