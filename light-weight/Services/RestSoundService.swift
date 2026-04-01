import AVFoundation
import os

private let logger = Logger(subsystem: "com.strong-ai", category: "RestSoundService")

enum RestSound: String, CaseIterable, Identifiable {
    case boxingBell = "boxing-bell"
    case yeahBuddy = "yeah-buddy"
    case dontKnowMe = "dont-know-me"
    case carryTheBoats = "carry-the-boats"
    case bodybuilder = "bodybuilder"
    case weight = "weight"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .boxingBell: "Boxing Bell"
        case .yeahBuddy: "Light Weight Baby"
        case .dontKnowMe: "They Don't Know Me Son"
        case .carryTheBoats: "Who's Gonna Carry the Boats"
        case .bodybuilder: "Everybody Wants to Be a Bodybuilder"
        case .weight: "Metal Plates"
        }
    }

    var url: URL? {
        Bundle.main.url(forResource: rawValue, withExtension: "wav")
    }

    static var selected: Set<RestSound> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "restSounds"),
                  let rawValues = try? JSONDecoder().decode([String].self, from: data) else {
                return [.yeahBuddy]
            }
            let sounds = Set(rawValues.compactMap { RestSound(rawValue: $0) })
            return sounds.isEmpty ? [.yeahBuddy] : sounds
        }
        set {
            let rawValues = newValue.map(\.rawValue)
            if let data = try? JSONEncoder().encode(rawValues) {
                UserDefaults.standard.set(data, forKey: "restSounds")
            }
        }
    }

    static func resetSelection() {
        UserDefaults.standard.removeObject(forKey: "restSounds")
    }
}

@MainActor
@Observable
final class RestSoundService: NSObject, AVAudioPlayerDelegate {
    private var silencePlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?

    func startBackgroundAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("Failed to configure audio session: \(error)")
            return
        }

        guard let url = Bundle.main.url(forResource: "silence", withExtension: "wav") else {
            logger.error("Missing silence.wav")
            return
        }
        do {
            silencePlayer = try AVAudioPlayer(contentsOf: url)
            silencePlayer?.numberOfLoops = -1
            silencePlayer?.volume = 0
            silencePlayer?.play()
        } catch {
            logger.error("Failed to start silence loop: \(error)")
        }
    }

    func playCompletionSound() {
        let sound = RestSound.selected.randomElement() ?? .yeahBuddy
        guard let url = sound.url else {
            logger.error("Missing audio file: \(sound.rawValue).wav")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
            completionPlayer = try AVAudioPlayer(contentsOf: url)
            completionPlayer?.delegate = self
            completionPlayer?.volume = 1.0
            completionPlayer?.play()
        } catch {
            logger.error("Failed to play \(sound.rawValue): \(error)")
        }
    }

    func stopBackgroundAudio() {
        silencePlayer?.stop()
        silencePlayer = nil
        completionPlayer?.stop()
        completionPlayer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func previewSound(_ sound: RestSound) {
        guard let url = sound.url else {
            logger.error("Missing audio file: \(sound.rawValue).wav")
            return
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true)
            completionPlayer = try AVAudioPlayer(contentsOf: url)
            completionPlayer?.delegate = self
            completionPlayer?.volume = 1.0
            completionPlayer?.play()
        } catch {
            logger.error("Failed to preview \(sound.rawValue): \(error)")
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        MainActor.assumeIsolated {
            // Switch back to mixWithOthers so music volume restores immediately
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: .mixWithOthers)
        }
    }
}
