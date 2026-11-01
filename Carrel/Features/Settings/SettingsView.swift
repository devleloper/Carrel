import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    let model: LibraryModel
    @State private var backupFile: SharedFile?
    @State private var isBackingUp = false
    @State private var isChoosingBackup = false
    @State private var backupToRestore: URL?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                dataSection
                Section {
                    LabeledContent("Drawing with Finger", value: UIPencilInteraction.prefersPencilOnlyDrawing ? String(localized: "Off") : String(localized: "On"))
                } header: {
                    Text("Writing")
                } footer: {
                    Text("Follows Settings › Apple Pencil › Only Draw with Apple Pencil. When fingers can draw, scroll with two fingers.")
                }
                Section("About") {
                    LabeledContent("Version", value: appVersion)
                    if let sourceURL = URL(string: "https://github.com/devleloper/notebook") {
                        Link("Source Code", destination: sourceURL)
                    }
                    LabeledContent("Tracking", value: String(localized: "None"))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $backupFile) { file in
                ActivityView(items: [file.url])
            }
            .fileImporter(isPresented: $isChoosingBackup, allowedContentTypes: [.appleArchive]) { result in
                backupToRestore = try? result.get()
            }
            .confirmationDialog("Restore from Backup?", isPresented: restoreBinding, titleVisibility: .visible) {
                Button("Restore", role: .destructive) {
                    if let url = backupToRestore {
                        Task { await model.restoreBackup(from: url) }
                    }
                }
            } message: {
                Text("Your current library is replaced by the backup. It is kept in the recovery folder, not deleted.")
            }
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                Task {
                    isBackingUp = true
                    if let url = await model.makeBackup() {
                        backupFile = SharedFile(url: url)
                    }
                    isBackingUp = false
                }
            } label: {
                LabeledContent("Back Up Now") {
                    if isBackingUp {
                        ProgressView()
                    }
                }
            }
            .disabled(isBackingUp)
            Button("Restore from Backup…") {
                isChoosingBackup = true
            }
            LabeledContent("Last Backup") {
                if let date = model.lastBackupDate {
                    Text(date, format: .dateTime.day().month().year().hour().minute())
                } else {
                    Text("Never")
                }
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Notebooks are stored on this iPad and saved as you write. A backup is a single file you can keep in Files or on another device.")
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var restoreBinding: Binding<Bool> {
        Binding(get: { backupToRestore != nil }, set: { if !$0 { backupToRestore = nil } })
    }
}
