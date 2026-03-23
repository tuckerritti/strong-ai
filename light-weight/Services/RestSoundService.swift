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

    var url: URL {
        Bundle.main.url(forResource: rawValue, withExtension: "wav")!
    }

    static var selected: RestSound {
        get {
            guard let raw = UserDefaults.standard.string(forKey: "restSound"),
                  let sound = RestSound(rawValue: raw) else { return .yeahBuddy }
            return sound
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "restSound")
        }
    }
}

@MainActor
@Observable
final class RestSoundService {
    private var silencePlayer: AVAudioPlayer?
    private var completionPlayer: AVAudioPlayer?

    func startBackgroundAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
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
        let sound = RestSound.selected
        do {
            completionPlayer = try AVAudioPlayer(contentsOf: sound.url)
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
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            completionPlayer = try AVAudioPlayer(contentsOf: sound.url)
            completionPlayer?.volume = 1.0
            completionPlayer?.play()
        } catch {
            logger.error("Failed to preview \(sound.rawValue): \(error)")
        }
    }
}
