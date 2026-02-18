import AppKit
import UserNotifications

/// NSApplicationDelegate that bootstraps the notification center and starts the main flow.
/// Conforms to UNUserNotificationCenterDelegate directly — no separate delegate object needed.
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from Dock — this is a headless CLI tool
        NSApp.setActivationPolicy(.accessory)

        // Register self as delegate before any callbacks fire
        UNUserNotificationCenter.current().delegate = self

        // Start the main async flow
        Task { await MainFlow.run() }
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Called when the app is in the foreground and a notification arrives.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping @Sendable (UNNotificationPresentationOptions) -> Void
    ) {
        if #available(macOS 11.0, *) {
            completionHandler([.banner, .sound, .badge])
        } else {
            completionHandler([.alert, .sound, .badge])
        }
    }

    /// Called when the user interacts with a notification.
    /// We do not handle click actions — just complete and exit.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping @Sendable () -> Void
    ) {
        completionHandler()
        exit(0)
    }
}
