import SwiftUI
import UserNotifications
import WidgetKit

extension Notification.Name {
    static let doseChanged = Notification.Name("dose.changed")
}

/// Gère le bouton « C'est pris ✓ » des notifications.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationManager.registerCategories()
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard response.actionIdentifier == NotificationManager.takeAllAction,
              let raw = response.notification.request.content.userInfo["moment"] as? String,
              let moment = Moment(rawValue: raw) else { return }
        DoseStore.shared.markMoment(moment)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationManager.reschedule()
        await LiveActivitySync.update()
        await MainActor.run {
            NotificationCenter.default.post(name: .doseChanged, object: nil)
        }
    }
}

@main
struct DoseApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = DoseModel()

    var body: some Scene {
        WindowGroup {
            TodayView()
                .environmentObject(model)
                .preferredColorScheme(.dark)
                .tint(Theme.mint)
        }
    }
}
