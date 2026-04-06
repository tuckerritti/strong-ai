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
    var expiredCount: Int = 0

    let soundService = RestSoundService()

    private var timer: Timer?
    private var fireDate: Date?
    private var cleanupWork: DispatchWorkItem?

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
        logger.info("timer start seconds=\(seconds, privacy: .public)")

        cleanupWork?.cancel()
        cleanupWork = nil
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

    func resync(newTotalSeconds: Int) {
        guard isRunning else { return }
        let elapsed = totalSeconds - remainingSeconds
        let newRemaining = max(0, newTotalSeconds - elapsed)

        if newRemaining <= 0 {
            stop()
            return
        }

        totalSeconds = newTotalSeconds
        remainingSeconds = newRemaining
        fireDate = Date().addingTimeInterval(TimeInterval(newRemaining))

        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-timer"])
        scheduleNotification(seconds: newRemaining)

        logger.info("Timer resynced: \(newTotalSeconds)s total, \(newRemaining)s remaining")
    }

    /// User tapped skip — stop everything immediately.
    func stop() {
        let hadActiveTimer = isRunning || timer != nil || totalSeconds > 0
        timer?.invalidate()
        timer = nil
        isRunning = false
        remainingSeconds = 0
        totalSeconds = 0
        fireDate = nil
        cleanupWork?.cancel()
        cleanupWork = nil
        soundService.stopBackgroundAudio()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-timer"])
        logger.info("timer stop hadActive=\(hadActiveTimer, privacy: .public)")
    }

    func requestPermission() {
        logger.info("timer_permission start")
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                logger.error("Notification permission error: \(error)")
            } else if !granted {
                logger.info("timer_permission denied")
            } else {
                logger.info("timer_permission granted")
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
        expiredCount += 1
        remainingSeconds = 0
        totalSeconds = 0
        fireDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["rest-timer"])
        logger.info("timer expire")

        soundService.playCompletionSound()

        // Delay stopping background audio so the completion sound can finish playing.
        let work = DispatchWorkItem { [weak self] in
            self?.soundService.stopBackgroundAudio()
        }
        cleanupWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: work)
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
            } else {
                logger.info("timer_notification schedule_success seconds=\(seconds, privacy: .public)")
            }
        }
    }

    private func formatSeconds(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}
