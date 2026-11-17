import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SoundLibraryView: View {
    var selectedSoundName: Binding<String>? = nil
    var selectedSoundID: Binding<UUID?>? = nil

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SoundAsset.createdAt) private var sounds: [SoundAsset]

    @State private var player = AudioPreviewPlayer()
    @State private var isImporting = false
    @State private var importError: String?
    @State private var renamingAsset: SoundAsset?
    @State private var renameText = ""
    @State private var assetPendingDeletion: SoundAsset?

    private var builtInSounds: [SoundAsset] { sounds.filter(\.isBuiltIn) }
    private var importedSounds: [SoundAsset] { sounds.filter { !$0.isBuiltIn } }

    var body: some View {
        List {
            if let importError {
                Section {
                    RISEInlineMessage(text: importError, kind: .error)
                }
            }

            Section("Built-in Sounds") {
                ForEach(builtInSounds) { sound in
                    SoundPickerRow(
                        name: sound.name,
                        metadata: sound.metadataLabel,
                        isSelected: isSelected(sound),
                        isPlaying: player.playingAssetID == sound.id,
                        onPreview: { player.toggle(asset: sound, url: nil) },
                        onSelect: { select(sound) }
                    )
                }
            }

            Section {
                if importedSounds.isEmpty {
                    Text("No imported sounds yet. Audio you add from Files appears here.")
                        .font(RISETheme.Typography.caption)
                        .foregroundStyle(RISETheme.Colors.muted)
                } else {
                    ForEach(importedSounds) { sound in
                        SoundPickerRow(
                            name: sound.name,
                            metadata: sound.metadataLabel,
                            isSelected: isSelected(sound),
                            isPlaying: player.playingAssetID == sound.id,
                            onPreview: {
                                player.toggle(asset: sound, url: SoundLibrary.fileURL(for: sound))
                            },
                            onSelect: { select(sound) }
                        )
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                assetPendingDeletion = sound
                            }
                            Button("Rename") {
                                renamingAsset = sound
                                renameText = sound.name
                            }
                            .tint(RISETheme.Colors.secondary)
                        }
                    }
                }

                Button {
                    isImporting = true
                } label: {
                    Label("Import Audio from Files", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("My Sounds")
            } footer: {
                Text("Custom audio is previewed in the app. Whether it can play as the actual system alarm sound depends on iOS, so a built-in fallback is always kept.")
                    .font(RISETheme.Typography.caption)
            }
        }
        .scrollContentBackground(.hidden)
        .background(RISETheme.Colors.background)
        .listRowBackground(RISETheme.Colors.surface)
        .navigationTitle("Alarm Sound")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { player.stop() }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await importSound(from: url) }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
        .alert("Rename sound", isPresented: Binding(
            get: { renamingAsset != nil },
            set: { if !$0 { renamingAsset = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) { renamingAsset = nil }
            Button("Save") {
                if let asset = renamingAsset {
                    let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        asset.name = trimmed
                        try? modelContext.save()
                    }
                }
                renamingAsset = nil
            }
        }
        .confirmationDialog(
            "Delete this sound?",
            isPresented: Binding(
                get: { assetPendingDeletion != nil },
                set: { if !$0 { assetPendingDeletion = nil } }
            ),
            presenting: assetPendingDeletion
        ) { asset in
            Button("Delete \(asset.name)", role: .destructive) {
                delete(asset)
                assetPendingDeletion = nil
            }
            Button("Keep", role: .cancel) { assetPendingDeletion = nil }
        } message: { asset in
            Text("The file is removed from RISE. Alarms using it switch to \(SoundLibrary.defaultSoundName).")
        }
    }

    // MARK: - Actions

    private func isSelected(_ sound: SoundAsset) -> Bool {
        selectedSoundID?.wrappedValue == sound.id
    }

    private func select(_ sound: SoundAsset) {
        selectedSoundName?.wrappedValue = sound.name
        selectedSoundID?.wrappedValue = sound.id
        RiseHaptics.tap(enabled: true)
    }

    private func importSound(from url: URL) async {
        importError = nil
        do {
            let imported = try await SoundImporter.importFile(at: url)
            let displayName = url.deletingPathExtension().lastPathComponent
            let asset = SoundAsset(
                name: displayName.isEmpty ? "Imported Sound" : displayName,
                fileName: imported.fileName,
                formatLabel: imported.format,
                durationSeconds: imported.duration,
                isBuiltIn: false
            )
            modelContext.insert(asset)
            try modelContext.save()
            select(asset)
        } catch {
            importError = error.localizedDescription
        }
    }

    private func delete(_ asset: SoundAsset) {
        SoundImporter.deleteFile(for: asset)
        modelContext.delete(asset)
        try? modelContext.save()

        if isSelected(asset) {
            if let fallback = SoundLibrary.fallbackAsset(from: sounds.filter { $0.id != asset.id }) {
                select(fallback)
            } else {
                selectedSoundName?.wrappedValue = SoundLibrary.defaultSoundName
                selectedSoundID?.wrappedValue = nil
            }
        }
    }
}
