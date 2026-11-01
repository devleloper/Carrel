import NotebookDomain
import SwiftUI

struct LibrarySidebar: View {
    @Bindable var model: LibraryModel
    @Binding var isShowingSettings: Bool
    @State private var isCreatingFolder = false
    @State private var renamingFolder: Folder?
    @State private var titleDraft = ""

    var body: some View {
        List(selection: $model.section) {
            row(.all)
            row(.favorites)

            Section("Folders") {
                ForEach(model.folders) { folder in
                    row(.folder(folder.id))
                        .contextMenu {
                            Button("Rename…", systemImage: "pencil") {
                                titleDraft = folder.title
                                renamingFolder = folder
                            }
                            Button("Delete Folder", systemImage: "trash", role: .destructive) {
                                Task { await model.deleteFolder(folder) }
                            }
                        }
                }
                Button("New Folder", systemImage: "folder.badge.plus") {
                    titleDraft = ""
                    isCreatingFolder = true
                }
                .foregroundStyle(Theme.accent)
            }

            row(.trash)
        }
        .navigationTitle("Carrel")
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Settings", systemImage: "gearshape") {
                    isShowingSettings = true
                }
            }
        }
        .alert("New Folder", isPresented: $isCreatingFolder) {
            TextField("Name", text: $titleDraft)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                let title = titleDraft
                Task { await model.createFolder(named: title) }
            }
        }
        .alert("Rename Folder", isPresented: Binding(presenting: $renamingFolder)) {
            TextField("Name", text: $titleDraft)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let folder = renamingFolder {
                    let title = titleDraft
                    Task { await model.renameFolder(folder, to: title) }
                }
            }
        }
    }

    private func row(_ section: LibraryModel.Section) -> some View {
        Label(model.title(of: section), systemImage: section.systemImage)
            .tag(section)
    }
}
