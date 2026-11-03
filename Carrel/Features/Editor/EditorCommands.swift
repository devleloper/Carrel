import SwiftUI

/// The editor's items in the View menu. They act on the notebook open in the focused window and are disabled
/// elsewhere; with fingers drawing they are the only way back to fitting the width after a pinch.
struct EditorCommands: Commands {
    @FocusedValue(EditorSession.self) private var session

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Section {
                button("Zoom In", command: .zoomIn, shortcut: "+")
                button("Zoom Out", command: .zoomOut, shortcut: "-")
                button("Fit Width", command: .fitWidth, shortcut: "0")
            }
        }
    }

    private func button(
        _ title: LocalizedStringKey,
        command: PageStackLayout.ZoomCommand,
        shortcut: KeyEquivalent
    ) -> some View {
        Button(title) { session?.zoomCommand = command }
            .keyboardShortcut(shortcut)
            .disabled(session == nil)
    }
}
