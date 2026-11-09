import ActivityKit
import Foundation

// MARK: - Données de la Live Activity (écran verrouillé + Dynamic Island)

struct DoseChip: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    var symbol: String
    var colorHex: String
    var taken: Bool
}

struct DoseActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var items: [DoseChip]
        var streak: Int

        var done: Int { items.filter(\.taken).count }
        var total: Int { items.count }
        var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
    }

    var title: String
}

// MARK: - Synchronisation

enum LiveActivitySync {
    static func state() -> DoseActivityAttributes.ContentState {
        let snap = DoseStore.shared.snapshot()
        return DoseActivityAttributes.ContentState(
            items: snap.items.map {
                DoseChip(id: $0.supplement.id, name: $0.supplement.name, symbol: $0.supplement.symbol,
                         colorHex: $0.supplement.colorHex, taken: $0.taken)
            },
            streak: snap.streak
        )
    }

    static var endOfDay: Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: .now)) ?? .now.addingTimeInterval(86_400)
    }

#if WIDGET_EXTENSION
    // Dans l'extension widget, ActivityKit ne peut pas démarrer d'activité :
    // la mise à jour est faite par l'app (les boutons de la Live Activity s'exécutent dans l'app).
    static var isRunning: Bool { false }
    @discardableResult static func start() -> Bool { false }
    static func update() async {}
    static func stop() async {}
#else
    static var isRunning: Bool { !Activity<DoseActivityAttributes>.activities.isEmpty }

    /// Épingle la checklist sur l'écran verrouillé (l'app doit être au premier plan).
    @discardableResult
    static func start() -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }
        let st = state()
        guard st.total > 0, st.done < st.total else { return false }
        if isRunning {
            Task { await update() }
            return true
        }
        do {
            _ = try Activity<DoseActivityAttributes>.request(
                attributes: DoseActivityAttributes(title: "Dose"),
                content: ActivityContent(state: st, staleDate: endOfDay),
                pushType: nil
            )
            return true
        } catch {
            return false
        }
    }

    /// Met à jour l'activité, et la retire quelques secondes après que tout est pris.
    static func update() async {
        let st = state()
        for activity in Activity<DoseActivityAttributes>.activities {
            if st.total > 0 && st.done == st.total {
                await activity.end(ActivityContent(state: st, staleDate: nil),
                                   dismissalPolicy: .after(.now.addingTimeInterval(5)))
            } else {
                await activity.update(ActivityContent(state: st, staleDate: endOfDay))
            }
        }
    }

    static func stop() async {
        for activity in Activity<DoseActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
#endif
}
