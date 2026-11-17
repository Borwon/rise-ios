import Foundation
import SwiftData

enum PersistenceController {
    static let schema = Schema([
        Alarm.self,
        ChallengeConfig.self,
        SoundAsset.self,
        AlarmHistory.self
    ])

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

enum SoundLibrary {
    struct BuiltIn {
        let name: String
        let category: String
    }

    /// Product-defined built-in sounds (section 4 of the design document).
    /// Audio assets still need to be supplied and licensed before shipping.
    static let builtIns: [BuiltIn] = [
        BuiltIn(name: "Morning Breeze", category: "Morning"),
        BuiltIn(name: "Sunrise", category: "Morning"),
        BuiltIn(name: "Digital Pulse", category: "Digital"),
        BuiltIn(name: "Soft Piano", category: "Piano"),
        BuiltIn(name: "Deep Bell", category: "Classic")
    ]

    static let defaultSoundName = builtIns[0].name

    /// Seeds the built-in catalogue once. Safe to call on every launch.
    static func seedBuiltInsIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<SoundAsset>())) ?? []
        let builtInNames = Set(existing.filter(\.isBuiltIn).map(\.name))
        var didInsert = false

        for sound in builtIns where !builtInNames.contains(sound.name) {
            context.insert(
                SoundAsset(
                    name: sound.name,
                    fileName: nil,
                    formatLabel: sound.category,
                    durationSeconds: 0,
                    isBuiltIn: true
                )
            )
            didInsert = true
        }

        if didInsert {
            try? context.save()
        }
    }

    /// Folder that imported audio is copied into.
    static func managedSoundsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("RISE/Sounds", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func fileURL(for asset: SoundAsset) -> URL? {
        guard let fileName = asset.fileName else { return nil }
        let url = managedSoundsDirectory().appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// First available sound used when an imported file is missing.
    static func fallbackAsset(from assets: [SoundAsset]) -> SoundAsset? {
        assets.first { $0.isBuiltIn }
    }
}
