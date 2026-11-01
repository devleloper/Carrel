import UIKit

enum BackgroundTask {
    /// Keeps the app running until `work` finishes, so leaving the app right after writing cannot cut a save short.
    static func run(named name: String, _ work: @escaping @MainActor () async -> Void) {
        let handle = Handle()
        // The system terminates an app that still holds a background task when its time runs out. Ending the task
        // then only suspends the work; an interrupted write leaves the previous generation of the file intact.
        handle.identifier = UIApplication.shared.beginBackgroundTask(withName: name) {
            handle.end()
        }
        Task {
            await work()
            handle.end()
        }
    }

    /// Ends the background task exactly once, whichever comes first: the work finishing or the time running out.
    private final class Handle {
        var identifier = UIBackgroundTaskIdentifier.invalid

        func end() {
            guard identifier != .invalid else {
                return
            }
            UIApplication.shared.endBackgroundTask(identifier)
            identifier = .invalid
        }
    }
}
