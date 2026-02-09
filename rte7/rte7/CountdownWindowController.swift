import Cocoa
import UserNotifications

class CountdownWindowController: NSWindowController, UNUserNotificationCenterDelegate {

    var timer: Timer?
    var remainingSeconds = 30 * 60  // 30 minutes in seconds

    let timeLabel = NSTextField(labelWithString: "")

    override var window: NSWindow? {
          didSet {
              if window != nil {
                  setupWindow()
              }
          }
      }
    
    
    private func setupWindow() {
        setupUI()
        startTimer()
        requestNotificationPermission()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        window?.level = .floating

        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 48, weight: .medium)
        timeLabel.alignment = .center
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(timeLabel)

        NSLayoutConstraint.activate([
            timeLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])

        updateLabel()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            updateLabel()
        } else {
            timer?.invalidate()
            timer = nil
            sendNotification()
        }
    }

    private func updateLabel() {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        timeLabel.stringValue = String(format: "%02d:%02d", minutes, seconds)
    }

    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    private func sendNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Timer Finished"
        content.body = "Your 30-minute countdown has ended."
        content.sound = UNNotificationSound.default

        let request = UNNotificationRequest(identifier: "CountdownFinished", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // Optional: Show notification even when app is active
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
