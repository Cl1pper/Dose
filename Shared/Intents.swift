import AppIntents
import WidgetKit

/// Après chaque changement : widgets, rappels, pastille et Live Activity.
private func syncEverywhere() async {
    WidgetCenter.shared.reloadAllTimelines()
    NotificationManager.reschedule()
    await LiveActivitySync.update()
}

/// Bouton des widgets : coche / décoche un complément.
struct ToggleSupplementIntent: AppIntent {
    static let title: LocalizedStringResource = "Cocher un complément"
    static let isDiscoverable = false

    @Parameter(title: "Identifiant")
    var supplementID: String

    init() {}
    init(supplementID: String) { self.supplementID = supplementID }

    func perform() async throws -> some IntentResult {
        DoseStore.shared.toggle(supplementID)
        await syncEverywhere()
        return .result()
    }
}

/// Bouton de l'écran verrouillé : coche le prochain complément à prendre.
struct TakeNextIntent: AppIntent {
    static let title: LocalizedStringResource = "Prendre le suivant"
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        DoseStore.shared.takeNext()
        await syncEverywhere()
        return .result()
    }
}

/// Bouton de la Live Activity : s'exécute dans l'app, qui peut mettre l'activité à jour.
struct ActivityToggleIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Cocher depuis l'écran verrouillé"
    static let isDiscoverable = false

    @Parameter(title: "Identifiant")
    var supplementID: String

    init() {}
    init(supplementID: String) { self.supplementID = supplementID }

    func perform() async throws -> some IntentResult {
        DoseStore.shared.toggle(supplementID)
        await syncEverywhere()
        return .result()
    }
}
