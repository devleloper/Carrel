import NotebookDomain
import SwiftUI

struct LibrarySidebar: View {
    @Bindable var model: LibraryModel
    @Binding var isShowingSettings: Bool
    @State private var isCreatingFolder = false
    @State private var renamingFolder: Folder?
    @State private var folderName = ""

    var body: some View {
        List(selection: $model.section) {
            Label("Library", systemImage: "books.vertical")
                .tag(LibraryModel.Section.all)
            Label("Favorites", systemImage: "star")
                .tag(LibraryModel.Section.favorites)

            Section("Folders") {
                ForEach(model.folders) { folder in
                    Label(folder.title, systemImage: "folder")
                        .tag(LibraryModel.Section.folder(folder.id))
                        .contextMenu {
                            Button("Rename…", systemImage: "pencil") {
                                folderName = folder.title
                                renamingFolder = folder
                            }
                            Button("Delete Folder", systemImage: "trash", role: .destructive) {
                                Task { await model.deleteFolder(folder) }
                            }
                        }
                }
                Button("New Folder", systemImage: "folder.badge.plus") {
                    folderName = ""
                    isCreatingFolder = true
                }
                .foregroundStyle(Theme.accent)
            }

            Label("Trash", systemImage: "trash")
                .tag(LibraryModel.Section.trash)
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
            TextField("Name", text: $folderName)
            Button("Cancel", role: .cancel) {}
            Button("Create") {
                Task { await model.createFolder(named: folderName) }
            }
        }
        .alert("Rename Folder", isPresented: Binding(presenting: $renamingFolder)) {
            TextField("Name", text: $folderName)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let folder = renamingFolder {
                    Task { await model.renameFolder(folder, to: folderName) }
                }
            }
        }
    }
}
