import NotebookDomain
import Testing

struct AutosavePolicyTests {
    let policy = AutosavePolicy()
    let start = ContinuousClock.now

    @Test func savesAfterIdleDelayWhenWritingStops() {
        let deadline = policy.saveDeadline(firstUnsavedChange: start, lastChange: start + .seconds(1))
        #expect(deadline == start + .seconds(3))
    }

    @Test func continuousWritingIsSavedWithinTheMaximumDelay() {
        let deadline = policy.saveDeadline(firstUnsavedChange: start, lastChange: start + .seconds(4.5))
        #expect(deadline == start + .seconds(5))
    }

    @Test func statusReflectsUnsavedChanges() {
        #expect(policy.status(firstUnsavedChange: nil, lastWriteFailed: false, now: start) == .saved)
        #expect(policy.status(firstUnsavedChange: start, lastWriteFailed: false, now: start + .seconds(3)) == .edited)
        #expect(policy.status(firstUnsavedChange: start, lastWriteFailed: false, now: start + .seconds(8)) == .stalled)
        #expect(policy.status(firstUnsavedChange: start, lastWriteFailed: true, now: start) == .notSaved)
    }

    @Test func savedIsNeverReportedWhileChangesArePending() {
        for second in 0...20 {
            let status = policy.status(firstUnsavedChange: start, lastWriteFailed: false, now: start + .seconds(second))
            #expect(status != .saved)
        }
    }
}
