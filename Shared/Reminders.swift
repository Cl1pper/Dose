import Foundation
import UserNotifications

/// Notifications locales, programmées jour par jour sur 7 jours :
/// - le rappel à l'heure du moment (« Matin · c'est l'heure ») ;
/// - l'alerte d'oubli, un peu plus tard, si quelque chose n'est toujours pas coché
///   (« Attention, t'as pas pris de Zinc »).
/// Tout est reprogrammé à chaque coche : ce qui est pris ne déclenche plus rien.
enum NotificationManager {
    static let category = "DOSE_MOMENT"
    static let takeAllAction = "TAKE_ALL"
    static let snoozeAction = "SNOOZE"
    static let snoozeMinutes = 30

    private static let prefix = "dose."
    private static let snoozePrefix = "dose.snooze."

    static func registerCategories() {
        let take = UNNotificationAction(identifier: takeAllAction, title: "C'est pris ✓", options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Dans \(snoozeMinutes) min", options: [])
        let cat = UNNotificationCategory(identifier: category, actions: [take, snooze], intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([cat])
    }

    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    // MARK: Textes

    /// « Zinc », « Zinc et Magnésium », « Zinc, Magnésium et MK-677 ».
    static func frenchList(_ names: [String]) -> String {
        guard names.count > 1, let last = names.last else { return names.first ?? "" }
        return names.dropLast().joined(separator: ", ") + " et " + last
    }

    static func lateBody(_ names: [String]) -> String {
        "T'as pas pris de " + frenchList(names)
    }

    private static func lateContent(moment: Moment, names: [String], badge: Int) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = "Attention ⚠️"
        content.body = lateBody(names)
        content.sound = .default
        content.categoryIdentifier = category
        content.userInfo = ["moment": moment.rawValue]
        content.badge = NSNumber(value: badge)
        return content
    }

    // MARK: Programmation

    static func reschedule() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { pending in
            let store = DoseStore.shared
            let log = store.loadLog()
            let takenToday = store.taken(on: .now, in: log)

            // On efface tout ce qui vient de Dose, sauf les « Dans 30 min » encore utiles.
            var toRemove: [String] = []
            for request in pending where request.identifier.hasPrefix(prefix) {
                if request.identifier.hasPrefix(snoozePrefix),
                   let raw = request.content.userInfo["moment"] as? String,
                   let moment = Moment(rawValue: raw),
                   store.supplements.contains(where: { $0.moment == moment && !takenToday.contains($0.id) }) {
                    continue
                }
                toRemove.append(request.identifier)
            }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
            schedule(center: center, store: store, log: log)
        }
        updateBadge()
    }

    private static func schedule(center: UNUserNotificationCenter, store: DoseStore, log: IntakeLog) {
        let remindersOn = store.remindersOn
        let lateOn = store.lateAlertOn
        guard remindersOn || lateOn else { return }

        let cal = Calendar.current
        let now = Date()
        let today = cal.startOfDay(for: now)

        for offset in 0..<7 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today) else { continue }
            let taken = store.taken(on: day, in: log)
            let remainingThatDay = store.supplements.filter { !taken.contains($0.id) }.count

            for moment in Moment.allCases {
                let due = store.sortedSupplements.filter { $0.moment == moment && !taken.contains($0.id) }
                guard !due.isEmpty else { continue }
                let mins = store.reminderMinutes(moment)
                guard let fire = cal.date(bySettingHour: mins / 60, minute: mins % 60, second: 0, of: day) else { continue }

                if remindersOn, fire > now {
                    let content = UNMutableNotificationContent()
                    content.title = "\(moment.label) · c'est l'heure 💊"
                    content.body = due.map(\.name).joined(separator: " · ")
                    content.sound = .default
                    content.categoryIdentifier = category
                    content.userInfo = ["moment": moment.rawValue]
                    content.badge = NSNumber(value: remainingThatDay)
                    add(center, id: "\(prefix)\(offset).\(moment.rawValue)", content: content, at: fire, cal: cal)
                }

                if lateOn {
                    let late = fire.addingTimeInterval(TimeInterval(store.lateAlertDelay * 60))
                    if late > now {
                        let content = lateContent(moment: moment, names: due.map(\.name), badge: remainingThatDay)
                        add(center, id: "\(prefix)late.\(offset).\(moment.rawValue)", content: content, at: late, cal: cal)
                    }
                }
            }
        }
    }

    private static func add(_ center: UNUserNotificationCenter, id: String, content: UNNotificationContent, at date: Date, cal: Calendar) {
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Bouton « Dans 30 min » : renvoie l'alerte avec ce qui reste à prendre à ce moment-là.
    static func snooze(_ moment: Moment) {
        let store = DoseStore.shared
        let taken = store.taken()
        let due = store.sortedSupplements.filter { $0.moment == moment && !taken.contains($0.id) }
        guard !due.isEmpty else { return }
        let content = lateContent(moment: moment, names: due.map(\.name), badge: store.snapshot().remaining)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(snoozeMinutes * 60), repeats: false)
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: "\(snoozePrefix)\(moment.rawValue)", content: content, trigger: trigger)
        )
    }

    /// Pastille sur l'icône = nombre de compléments restants aujourd'hui.
    static func updateBadge() {
#if !WIDGET_EXTENSION
        let remaining = DoseStore.shared.snapshot().remaining
        UNUserNotificationCenter.current().setBadgeCount(remaining) { _ in }
#endif
    }
}
