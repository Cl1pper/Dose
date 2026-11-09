import Foundation

// MARK: - Moments de prise

enum Moment: String, Codable, CaseIterable, Identifiable {
    case matin, midi, soir, coucher

    var id: String { rawValue }

    var label: String {
        switch self {
        case .matin: return "Matin"
        case .midi: return "Midi"
        case .soir: return "Soir"
        case .coucher: return "Coucher"
        }
    }

    var symbol: String {
        switch self {
        case .matin: return "sunrise.fill"
        case .midi: return "sun.max.fill"
        case .soir: return "sunset.fill"
        case .coucher: return "moon.stars.fill"
        }
    }

    /// Heure de rappel par défaut, en minutes depuis minuit.
    var defaultMinutes: Int {
        switch self {
        case .matin: return 8 * 60
        case .midi: return 12 * 60 + 15
        case .soir: return 19 * 60
        case .coucher: return 22 * 60 + 30
        }
    }

    var order: Int { Moment.allCases.firstIndex(of: self) ?? 0 }
}

// MARK: - Unités et formatage des doses

enum DoseUnit: String, Codable, CaseIterable, Identifiable {
    case g = "g"
    case mg = "mg"
    case mcg = "µg"
    case ui = "UI"
    case gelule = "gélule"
    case goutte = "goutte"
    case ml = "ml"

    var id: String { rawValue }

    func label(for amount: Double?) -> String {
        switch self {
        case .gelule, .goutte:
            return (amount ?? 1) > 1 ? rawValue + "s" : rawValue
        default:
            return rawValue
        }
    }
}

enum DoseFormat {
    static func number(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)))
    }

    static func text(_ amount: Double?, _ unit: DoseUnit?) -> String? {
        guard let amount else { return nil }
        guard let unit else { return number(amount) }
        return "\(number(amount)) \(unit.label(for: amount))"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func time(minutes: Int) -> String {
        String(format: "%d h %02d", minutes / 60, minutes % 60)
    }
}

// MARK: - Complément

struct Supplement: Codable, Identifiable, Hashable {
    var id: String = UUID().uuidString
    var name: String
    var detail: String = ""
    var moment: Moment
    var colorHex: String
    var symbol: String
    /// Dose habituelle (optionnelle), enregistrée à chaque prise.
    var amount: Double? = nil
    var unit: DoseUnit? = nil

    var doseText: String? { DoseFormat.text(amount, unit) }

    /// Liste de départ — modifiable dans l'app (Réglages).
    static let defaults: [Supplement] = [
        Supplement(id: "creatine", name: "Créatine", moment: .matin, colorHex: "#7CF5C4", symbol: "bolt.fill", unit: .g),
        Supplement(id: "vitamine-d", name: "Vitamine D", moment: .matin, colorHex: "#FFD84D", symbol: "sun.max.fill", unit: .ui),
        Supplement(id: "zinc", name: "Zinc", moment: .midi, colorHex: "#5AC8FA", symbol: "shield.fill", unit: .mg),
        Supplement(id: "magnesium", name: "Magnésium", moment: .coucher, colorHex: "#B18CFF", symbol: "moon.fill", unit: .mg),
        Supplement(id: "l-theanine", name: "L-théanine", moment: .coucher, colorHex: "#7FE07A", symbol: "cup.and.saucer.fill", unit: .mg),
        Supplement(id: "mk-677", name: "MK-677", moment: .coucher, colorHex: "#FF6B8B", symbol: "capsule.fill", unit: .mg)
    ]
}

// MARK: - Une prise enregistrée

struct Intake: Codable, Hashable, Identifiable {
    var supplementID: String
    /// Nom au moment de la prise : l'historique reste lisible même si le complément est supprimé.
    var name: String
    var time: Date
    var amount: Double?
    var unit: DoseUnit?

    var id: String { supplementID }
    var doseText: String? { DoseFormat.text(amount, unit) }
}

// MARK: - Instantané d'une journée (lu par l'app et les widgets)

struct DoseItem: Identifiable, Hashable {
    let supplement: Supplement
    let record: Intake?

    var taken: Bool { record != nil }
    var id: String { supplement.id }
}

struct DoseSnapshot {
    let date: Date
    let items: [DoseItem]
    let streak: Int

    var done: Int { items.filter(\.taken).count }
    var total: Int { items.count }
    var remaining: Int { total - done }
    var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }
    var isComplete: Bool { total > 0 && done == total }
    var next: DoseItem? { items.first { !$0.taken } }

    var moments: [Moment] {
        Moment.allCases.filter { m in items.contains { $0.supplement.moment == m } }
    }

    func items(for moment: Moment) -> [DoseItem] {
        items.filter { $0.supplement.moment == moment }
    }

    static let placeholder = DoseSnapshot(
        date: .now,
        items: Supplement.defaults.enumerated().map { pair in
            let s = pair.element
            let record = pair.offset < 2 ? Intake(supplementID: s.id, name: s.name, time: .now, amount: s.amount, unit: s.unit) : nil
            return DoseItem(supplement: s, record: record)
        },
        streak: 4
    )
}

// MARK: - Statistiques

struct SupplementStats: Identifiable {
    let supplement: Supplement
    let takenDays: Int
    let days: Int
    let averageMinutes: Int?
    let totalAmount: Double?

    var id: String { supplement.id }
    var rate: Double { days == 0 ? 0 : Double(takenDays) / Double(days) }
}
