import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(BackupModel.self) private var backup
    @Environment(\.dismiss) private var dismiss
    @State private var backupFile: SharedFile?
    @State private var isChoosingBackup = false
    @State private var backupToRestore: URL?

    var body: some View {
        @Bindable var backup = backup
        NavigationStack {
            Form {
                dataSection
                writingSection
                aboutSection
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
            .confirmationDialog(
                "Restore from Backup?",
                isPresented: Binding(presenting: $backupToRestore),
                titleVisibility: .visible
            ) {
                Button("Restore", role: .destructive) {
                    if let url = backupToRestore {
                        Task { await backup.restore(from: url) }
                    }
                }
            } message: {
                Text("""
                    Your current library is replaced by the backup. \
                    It is kept in the recovery folder, not deleted.
                    """)
            }
            .alert("Something Went Wrong", isPresented: Binding(presenting: $backup.errorMessage)) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backup.errorMessage ?? "")
            }
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                Task {
                    if let url = await backup.makeBackup() {
                        backupFile = SharedFile(url: url)
                    }
                }
            } label: {
                LabeledContent("Back Up Now") {
                    if backup.isWorking {
                        ProgressView()
                    }
                }
            }
            .disabled(backup.isWorking)
            Button("Restore from Backup…") {
                isChoosingBackup = true
            }
            .disabled(backup.isWorking)
            LabeledContent("Last Backup") {
                if let date = backup.lastBackupDate {
                    Text(date, format: .dateTime.day().month().year().hour().minute())
                } else {
                    Text("Never")
                }
            }
        } header: {
            Text("Data")
        } footer: {
            Text("""
                Notebooks are stored on this iPad and saved as you write. \
                A backup is a single file you can keep in Files or on another device.
                """)
        }
    }

    private var writingSection: some View {
        Section {
            LabeledContent("Drawing with Finger") {
                Text(UIPencilInteraction.prefersPencilOnlyDrawing ? LocalizedStringKey("Off") : "On")
            }
        } header: {
            Text("Writing")
        } footer: {
            Text("""
                Follows Settings › Apple Pencil › Only Draw with Apple Pencil. \
                When fingers can draw, scroll with two fingers.
                """)
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            if let sourceURL = URL(string: "https://github.com/devleloper/notebook") {
                Link("Source Code", destination: sourceURL)
            }
            LabeledContent("Tracking") {
                Text("None")
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
