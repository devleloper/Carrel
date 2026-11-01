import UIKit

enum BackgroundTask {
    /// Keeps the app running until `work` finishes, so leaving the app right after writing cannot cut a save short.
    static func run(named name: String, _ work: @escaping @MainActor () async -> Void) {
        let identifier = UIApplication.shared.beginBackgroundTask(withName: name, expirationHandler: nil)
        Task {
            await work()
            UIApplication.shared.endBackgroundTask(identifier)
        }
    }
}
