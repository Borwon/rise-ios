import AVFoundation
import AudioToolbox
import Foundation
import Observation

/// Plays short previews for the sound library.
@MainActor
@Observable
final class AudioPreviewPlayer {
    private var player: AVAudioPlayer?
    private(set) var playingAssetID: UUID?

    func toggle(asset: SoundAsset, url: URL?) {
        if playingAssetID == asset.id {
            stop()
            return
        }

        stop()

        guard let url else {
            // Built-in sounds ship as product labels; until the licensed audio
            // assets are added, preview a short system tone so the control still
            // gives audible feedback.
            AudioServicesPlaySystemSound(1005)
            playingAssetID = asset.id
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            self.player = player
            playingAssetID = asset.id
        } catch {
            playingAssetID = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingAssetID = nil
    }
}

enum SoundImportError: LocalizedError {
    case unsupportedType
    case tooLong
    case copyFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedType:
            "That file type is not supported. Choose an audio file such as MP3, M4A, WAV or AIFF."
        case .tooLong:
            "That audio file is longer than 5 minutes. Choose a shorter sound."
        case .copyFailed:
            "The file could not be copied into RISE. Try another file."
        }
    }
}

enum SoundImporter {
    static let supportedExtensions = ["mp3", "m4a", "aac", "wav", "aiff", "aif", "caf"]

    /// Copies the picked file into managed storage and returns its metadata.
    static func importFile(at sourceURL: URL) async throws -> (fileName: String, format: String, duration: Double) {
        let extensionName = sourceURL.pathExtension.lowercased()
        guard supportedExtensions.contains(extensionName) else {
            throw SoundImportError.unsupportedType
        }

        let needsSecurityScope = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if needsSecurityScope { sourceURL.stopAccessingSecurityScopedResource() }
        }

        let asset = AVURLAsset(url: sourceURL)
        let duration = (try? await asset.load(.duration))?.seconds ?? 0
        guard duration <= 300 else { throw SoundImportError.tooLong }

        let fileName = "\(UUID().uuidString).\(extensionName)"
        let destination = SoundLibrary.managedSoundsDirectory().appendingPathComponent(fileName)

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: sourceURL, to: destination)
        } catch {
            throw SoundImportError.copyFailed
        }

        return (fileName, extensionName.uppercased(), duration)
    }

    static func deleteFile(for asset: SoundAsset) {
        guard let url = SoundLibrary.fileURL(for: asset) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
