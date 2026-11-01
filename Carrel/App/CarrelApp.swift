import SwiftUI

@main
struct CarrelApp: App {
    @State private var dependencies = Result { try AppDependencies() }

    var body: some Scene {
        WindowGroup {
            switch dependencies {
            case .success(let dependencies):
                LibraryView(model: dependencies.libraryModel)
                    .environment(dependencies.backupModel)
                    .environment(dependencies.toolPalette)
            case .failure(let error):
                ContentUnavailableView {
                    Label("Carrel Can't Open Your Library", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(UserFacingError.message(for: error))
                }
            }
        }
    }
}
