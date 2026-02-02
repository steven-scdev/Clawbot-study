import SwiftUI

struct FoldersSettingsView: View {
    @AppStorage("workforceSharedFolders") private var foldersData = Data()
    @State private var folders: [String] = []

    var body: some View {
        Form {
            Section("Shared Folders") {
                if self.folders.isEmpty {
                    Text("No shared folders configured.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else {
                    ForEach(self.folders, id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder")
                                .foregroundStyle(.secondary)
                            Text(folder)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button {
                                self.removeFolder(folder)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Section {
                Button("Add Folder...") {
                    self.pickFolder()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            self.loadFolders()
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path(percentEncoded: false)
            if !self.folders.contains(path) {
                self.folders.append(path)
                self.saveFolders()
            }
        }
    }

    private func removeFolder(_ folder: String) {
        self.folders.removeAll { $0 == folder }
        self.saveFolders()
    }

    private func loadFolders() {
        guard !self.foldersData.isEmpty,
              let decoded = try? JSONDecoder().decode([String].self, from: self.foldersData)
        else { return }
        self.folders = decoded
    }

    private func saveFolders() {
        self.foldersData = (try? JSONEncoder().encode(self.folders)) ?? Data()
    }
}
