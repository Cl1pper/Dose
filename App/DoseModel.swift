import SwiftUI
import WidgetKit

/// Prise à modifier (ouverte en feuille depuis l'écran du jour ou l'historique).
struct IntakeEditTarget: Identifiable {
    let day: Date
    let supplement: Supplement
    let intake: Intake
    var id: String { DoseStore.dayKey(day) + "/" + supplement.id }
}

@MainActor
final class DoseModel: ObservableObject {
    @Published private(set) var snapshot: DoseSnapshot
    @Published private(set) var supplements: [Supplement]
    @Published private(set) var liveActivityOn: Bool
    /// Incrémenté à chaque changement : l'historique se redessine.
    @Published private(set) var revision = 0
    @Published var justCompleted = false

    private let store = DoseStore.shared

    init() {
        snapshot = DoseStore.shared.snapshot()
        supplements = DoseStore.shared.supplements
        liveActivityOn = LiveActivitySync.isRunning
    }

    func refresh() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            snapshot = store.snapshot()
        }
        supplements = store.supplements
        liveActivityOn = LiveActivitySync.isRunning
        revision += 1
    }

    func toggle(_ id: String) {
        apply { store.toggle(id) }
    }

    func markMoment(_ moment: Moment) {
        apply { store.markMoment(moment) }
    }

    /// Coche / décoche pour n'importe quel jour (rattrapage depuis l'historique).
    func setTaken(_ id: String, _ value: Bool, on day: Date) {
        apply { store.setTaken(id, value, on: day) }
    }

    func updateIntake(_ id: String, on day: Date, time: Date, amount: Double?, unit: DoseUnit?) {
        apply { store.updateIntake(id, on: day, time: time, amount: amount, unit: unit) }
    }

    func editTarget(for supplement: Supplement, on day: Date) -> IntakeEditTarget? {
        guard let intake = store.records(on: day, in: store.loadLog()).first(where: { $0.supplementID == supplement.id })
        else { return nil }
        return IntakeEditTarget(day: day, supplement: supplement, intake: intake)
    }

    func save(_ list: [Supplement]) {
        store.supplements = list
        supplements = list
        apply {}
    }

    func pin() {
        liveActivityOn = LiveActivitySync.start()
    }

    func unpin() {
        Task {
            await LiveActivitySync.stop()
            liveActivityOn = false
        }
    }

    func appBecameActive() {
        refresh()
        if store.autoPin && !snapshot.isComplete { pin() }
        syncOutside()
    }

    // MARK: Interne

    private func apply(_ change: () -> Void) {
        let wasComplete = snapshot.isComplete
        change()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) {
            snapshot = store.snapshot()
        }
        revision += 1
        if snapshot.isComplete && !wasComplete { justCompleted = true }
        syncOutside()
    }

    private func syncOutside() {
        WidgetCenter.shared.reloadAllTimelines()
        NotificationManager.reschedule()
        Task {
            await LiveActivitySync.update()
            liveActivityOn = LiveActivitySync.isRunning
        }
    }
}
