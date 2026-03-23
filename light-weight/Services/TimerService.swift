import AVFoundation
import Foundation
import os
import UserNotifications

private let logger = Logger(subsystem: "com.light-weight", category: "TimerService")

@MainActor
@Observable
final class TimerService {
    var remainingSeconds: Int = 0
    var totalSeconds: Int = 0
    var isRunning: Bool = false

    let soundService = RestSoundService()

    private var timer: Timer?
    private var fireDate: Date?

    func start(seconds: Int) {
        stop()
        guard seconds > 0 else {
            logger.warning("Attempted to start timer with \(seconds) seconds, ignoring")
            return
        }
        remainingSeconds = seconds
        totalSeconds = seconds
        isRunning = true
        fireDate = Date().addingTimeInterval(TimeInterval(seconds))

        scheduleNotification(seconds: seconds)
        soundService.startBackgroundAudio()

        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let left = Int(ceil((self.fireDate ?? .now).timeIntervalSince(.now)))
                if left <= 0 {
                    self.timerExpired()
                } else {
                    self.remainingSeconds = left
                }
            }
        }
    }

    /// User tapped skip — stop everything immediately.
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
        totalSeconds = 0
        fireDate = nil
        soundService.stopBackgroundAudio()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-timer"])
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                logger.error("Notification permission error: \(error)")
            } else if !granted {
                logger.info("Notification permission denied by user")
            }
        }
    }

    var formattedTime: String {
        formatSeconds(remainingSeconds)
    }

    var formattedTotal: String {
        formatSeconds(totalSeconds)
    }

    // MARK: - Private

    /// Timer reached zero — play sound and clean up.
    private func timerExpired() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
        totalSeconds = 0
        fireDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-timer"])

        soundService.playCompletionSound()

        // Delay stopping background audio so the completion sound can finish playing.
        DispatchQueue.main.asyncAfter(deadline: .now() + 12) { [weak self] in
            self?.soundService.stopBackgroundAudio()
        }
    }

    private func scheduleNotification(seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Rest Over"
        content.body = "Time for your next set"
        content.sound = nil

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: "rest-timer", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                logger.error("Failed to schedule notification: \(error)")
            }
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
