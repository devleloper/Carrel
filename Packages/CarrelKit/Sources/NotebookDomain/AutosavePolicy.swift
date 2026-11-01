/// When unsaved ink is written, and what the save indicator says about it.
///
/// A save runs after `idleDelay` without changes, but never later than `maximumDelay` after the first unsaved
/// change, so continuous writing loses at most `maximumDelay` of strokes if the app crashes.
public struct AutosavePolicy: Sendable {
    public var idleDelay: Duration
    public var maximumDelay: Duration
    /// Extra time before a pending save is reported as stalled rather than routine.
    public var stallMargin: Duration
    /// Wait before writing again after a failed write, for example while the disk is full.
    public var retryDelay: Duration

    public init(
        idleDelay: Duration = .seconds(2),
        maximumDelay: Duration = .seconds(5),
        stallMargin: Duration = .seconds(2),
        retryDelay: Duration = .seconds(5)
    ) {
        self.idleDelay = idleDelay
        self.maximumDelay = maximumDelay
        self.stallMargin = stallMargin
        self.retryDelay = retryDelay
    }

    public func saveDeadline(
        firstUnsavedChange: ContinuousClock.Instant,
        lastChange: ContinuousClock.Instant
    ) -> ContinuousClock.Instant {
        min(lastChange + idleDelay, firstUnsavedChange + maximumDelay)
    }

    public func stallDeadline(firstUnsavedChange: ContinuousClock.Instant) -> ContinuousClock.Instant {
        firstUnsavedChange + maximumDelay + stallMargin
    }

    public func status(
        firstUnsavedChange: ContinuousClock.Instant?,
        lastWriteFailed: Bool,
        now: ContinuousClock.Instant
    ) -> SaveStatus {
        if lastWriteFailed {
            return .notSaved
        }
        guard let firstUnsavedChange else {
            return .saved
        }
        return now >= stallDeadline(firstUnsavedChange: firstUnsavedChange) ? .saving : .edited
    }
}

public enum SaveStatus: Hashable, Sendable {
    /// Everything is on disk.
    case saved
    /// Unsaved changes are younger than the save deadline; this is the normal state while writing.
    case edited
    /// A save is overdue, which only happens when the disk is slow or busy.
    case saving
    /// The last write failed; changes stay in memory and are retried.
    case notSaved
}
