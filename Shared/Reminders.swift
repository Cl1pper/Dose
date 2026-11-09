import Foundation
import UserNotifications

/// Rappels locaux : programmés jour par jour sur 7 jours, et seulement pour
/// les moments où il reste quelque chose à prendre (pas de rappel inutile).
enum NotificationManager {
    static let category = "DOSE_MOMENT"
    static let takeAllAction = "TAKE_ALL"

    static func registerCategories() {
        let take = UNNotificationAction(identifier: takeAllAction, title: "C'est pris ✓", options: [])
        let cat = UNNotificationCategory(identifier: category, actions: [take], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func reschedule() {
        let center = UNUserNotificationCenter.current()
        let store = DoseStore.shared
        center.removeAllPendingNotificationRequests()
        updateBadge()
        guard store.remindersOn else { return }

        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)

        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let taken = store.taken(on: day)
            let remainingThatDay = store.supplements.filter { !taken.contains($0.id) }.count

            for moment in Moment.allCases {
                let due = store.sortedSupplements.filter { $0.moment == moment && !taken.contains($0.id) }
                guard !due.isEmpty else { continue }
                let mins = store.reminderMinutes(moment)
                guard let fire = cal.date(bySettingHour: mins / 60, minute: mins % 60, second: 0, of: day),
                      fire > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = "\(moment.label) · c'est l'heure 💊"
                content.body = due.map(\.name).joined(separator: " · ")
                content.sound = .default
                content.categoryIdentifier = category
                content.userInfo = ["moment": moment.rawValue]
                content.badge = NSNumber(value: remainingThatDay)

                let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                center.add(UNNotificationRequest(identifier: "dose.\(offset).\(moment.rawValue)",
                                                 content: content, trigger: trigger))
            }
        }
    }

    /// Pastille sur l'icône = nombre de compléments restant aujourd'hui.
    static func updateBadge() {
#if !WIDGET_EXTENSION
        let remaining = DoseStore.shared.snapshot().remaining
        UNUserNotificationCenter.current().setBadgeCount(remaining) { _ in }
#endif
    }
}
