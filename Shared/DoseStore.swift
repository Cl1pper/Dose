import Foundation

/// Identifiant de l'App Group partagé entre l'app et les widgets.
/// SideStore / AltStore renomment les App Groups à la signature et écrivent
/// le nouveau nom dans la clé `ALTAppGroups` de l'Info.plist : on la lit en priorité.
enum AppGroup {
    static let fallback = "group.com.luka.dose"

    static var identifier: String {
        if let groups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String],
           let first = groups.first {
            return first
        }
        return fallback
    }
}

/// Journal : jour ("yyyy-MM-dd") -> prises de ce jour.
typealias IntakeLog = [String: [Intake]]

/// Stockage unique (UserDefaults de l'App Group), utilisé par l'app, les widgets et les intents.
final class DoseStore {
    static let shared = DoseStore()

    let defaults: UserDefaults

    private init() {
        defaults = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }

    private enum Key {
        static let supplements = "dose.supplements"
        static let log = "dose.log.v2"
        static let legacyHistory = "dose.history"
        static let reminders = "dose.reminders"
        static let remindersOn = "dose.remindersOn"
        static let autoPin = "dose.autoPin"
        static let lateAlertOn = "dose.lateAlertOn"
        static let lateAlertDelay = "dose.lateAlertDelay"
    }

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func date(fromKey key: String) -> Date? { dayFormatter.date(from: key) }

    private var cal: Calendar { Calendar.current }

    // MARK: Liste

    var supplements: [Supplement] {
        get {
            guard let data = defaults.data(forKey: Key.supplements),
                  let list = try? JSONDecoder().decode([Supplement].self, from: data) else {
                return Supplement.defaults
            }
            return list
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.supplements)
            }
        }
    }

    /// Triés par moment de la journée, puis dans l'ordre de la liste.
    var sortedSupplements: [Supplement] {
        supplements.enumerated()
            .sorted { ($0.element.moment.order, $0.offset) < ($1.element.moment.order, $1.offset) }
            .map(\.element)
    }

    // MARK: Journal des prises

    func loadLog() -> IntakeLog {
        if let data = defaults.data(forKey: Key.log),
           let log = try? JSONDecoder().decode(IntakeLog.self, from: data) {
            return log
        }
        return migrateLegacyHistory()
    }

    private func saveLog(_ log: IntakeLog) {
        var log = log
        // On garde un peu plus d'un an d'historique.
        if log.count > 400 {
            for old in log.keys.sorted().prefix(log.count - 400) { log.removeValue(forKey: old) }
        }
        if let data = try? JSONEncoder().encode(log) {
            defaults.set(data, forKey: Key.log)
        }
    }

    /// Ancien format (jour -> identifiants) : converti une fois, heure fixée à midi.
    private func migrateLegacyHistory() -> IntakeLog {
        guard let old = defaults.dictionary(forKey: Key.legacyHistory) as? [String: [String]] else { return [:] }
        let byID = Dictionary(supplements.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var log: IntakeLog = [:]
        for (key, ids) in old {
            guard let day = Self.date(fromKey: key) else { continue }
            let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
            log[key] = ids.map { id in
                Intake(supplementID: id, name: byID[id]?.name ?? id, time: noon, amount: nil, unit: nil)
            }
        }
        saveLog(log)
        defaults.removeObject(forKey: Key.legacyHistory)
        return log
    }

    func records(on date: Date, in log: IntakeLog) -> [Intake] {
        log[Self.dayKey(date)] ?? []
    }

    func taken(on date: Date = .now, in log: IntakeLog? = nil) -> Set<String> {
        Set(records(on: date, in: log ?? loadLog()).map(\.supplementID))
    }

    /// Heure enregistrée : maintenant si c'est aujourd'hui, sinon l'heure de rappel du moment ce jour-là.
    private func defaultTime(for supplement: Supplement?, on date: Date) -> Date {
        if cal.isDateInToday(date) { return .now }
        let mins = supplement.map { reminderMinutes($0.moment) } ?? 12 * 60
        return cal.date(bySettingHour: mins / 60, minute: mins % 60, second: 0, of: date) ?? date
    }

    private func add(_ id: String, on date: Date, to log: inout IntakeLog) {
        let key = Self.dayKey(date)
        var list = log[key] ?? []
        guard !list.contains(where: { $0.supplementID == id }) else { return }
        let s = supplements.first { $0.id == id }
        list.append(Intake(supplementID: id, name: s?.name ?? id, time: defaultTime(for: s, on: date),
                           amount: s?.amount, unit: s?.unit))
        log[key] = list
    }

    func setTaken(_ id: String, _ value: Bool, on date: Date = .now) {
        var log = loadLog()
        let key = Self.dayKey(date)
        if value {
            add(id, on: date, to: &log)
        } else {
            log[key]?.removeAll { $0.supplementID == id }
            if log[key]?.isEmpty == true { log.removeValue(forKey: key) }
        }
        saveLog(log)
    }

    @discardableResult
    func toggle(_ id: String) -> Bool {
        let newValue = !taken().contains(id)
        setTaken(id, newValue)
        return newValue
    }

    func markMoment(_ moment: Moment, on date: Date = .now) {
        var log = loadLog()
        for s in supplements where s.moment == moment { add(s.id, on: date, to: &log) }
        saveLog(log)
    }

    func takeNext() {
        if let next = snapshot().next { setTaken(next.id, true) }
    }

    /// Modifie l'heure et la dose d'une prise déjà enregistrée.
    func updateIntake(_ id: String, on date: Date, time: Date, amount: Double?, unit: DoseUnit?) {
        var log = loadLog()
        let key = Self.dayKey(date)
        guard var list = log[key], let index = list.firstIndex(where: { $0.supplementID == id }) else { return }
        list[index].time = time
        list[index].amount = amount
        list[index].unit = unit
        log[key] = list
        saveLog(log)
    }

    /// Complète les prises du jour enregistrées sans quantité avec la dose habituelle actuelle
    /// (ex. : complément coché avant d'avoir renseigné sa dose).
    func fillMissingDoses(on date: Date = .now) {
        var log = loadLog()
        let key = Self.dayKey(date)
        guard var list = log[key] else { return }
        var changed = false
        for i in list.indices where list[i].amount == nil {
            if let s = supplements.first(where: { $0.id == list[i].supplementID }), let amount = s.amount {
                list[i].amount = amount
                list[i].unit = s.unit
                changed = true
            }
        }
        guard changed else { return }
        log[key] = list
        saveLog(log)
    }

    // MARK: Séries et progression

    private func isComplete(_ day: Date, ids: Set<String>, log: IntakeLog) -> Bool {
        !ids.isEmpty && ids.isSubset(of: Set(records(on: day, in: log).map(\.supplementID)))
    }

    /// Part des compléments actuels pris ce jour-là (0…1).
    func dayFraction(_ day: Date, in log: IntakeLog) -> Double {
        let ids = Set(supplements.map(\.id))
        guard !ids.isEmpty else { return 0 }
        let t = Set(records(on: day, in: log).map(\.supplementID))
        return Double(ids.intersection(t).count) / Double(ids.count)
    }

    /// Nombre de jours de suite où tout a été pris (aujourd'hui compte s'il est complet).
    func streak(asOf date: Date = .now, in log: IntakeLog? = nil) -> Int {
        let log = log ?? loadLog()
        let ids = Set(supplements.map(\.id))
        guard !ids.isEmpty else { return 0 }
        var day = cal.startOfDay(for: date)
        if !isComplete(day, ids: ids, log: log) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while isComplete(day, ids: ids, log: log), count < 3650 {
            count += 1
            guard let previous = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    func bestStreak(in log: IntakeLog) -> Int {
        let ids = Set(supplements.map(\.id))
        guard let firstKey = log.keys.min(), let first = Self.date(fromKey: firstKey) else { return 0 }
        var best = 0, current = 0
        var day = cal.startOfDay(for: first)
        let end = cal.startOfDay(for: .now)
        while day <= end {
            if isComplete(day, ids: ids, log: log) {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    func snapshot(for date: Date = .now) -> DoseSnapshot {
        let log = loadLog()
        let byID = Dictionary(records(on: date, in: log).map { ($0.supplementID, $0) }, uniquingKeysWith: { a, _ in a })
        let items = sortedSupplements.map { DoseItem(supplement: $0, record: byID[$0.id]) }
        return DoseSnapshot(date: date, items: items, streak: streak(asOf: date, in: log))
    }

    // MARK: Statistiques

    /// Nombre de jours suivis sur la période (sans compter avant la toute première prise).
    func trackedDays(window: Int, in log: IntakeLog) -> Int {
        guard let firstKey = log.keys.min(), let first = Self.date(fromKey: firstKey) else { return 0 }
        let since = (cal.dateComponents([.day], from: cal.startOfDay(for: first), to: cal.startOfDay(for: .now)).day ?? 0) + 1
        return max(1, min(window, since))
    }

    /// Régularité globale sur la période, pour les compléments actuels.
    func adherence(window: Int = 30, in log: IntakeLog) -> Double {
        let days = trackedDays(window: window, in: log)
        guard days > 0 else { return 0 }
        let today = cal.startOfDay(for: .now)
        var sum = 0.0
        for offset in 0..<days {
            if let day = cal.date(byAdding: .day, value: -offset, to: today) { sum += dayFraction(day, in: log) }
        }
        return sum / Double(days)
    }

    func stats(window: Int = 30, in log: IntakeLog) -> [SupplementStats] {
        let days = trackedDays(window: window, in: log)
        let today = cal.startOfDay(for: .now)
        let recent: [Intake] = (0..<days).flatMap { offset -> [Intake] in
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { return [] }
            return records(on: day, in: log)
        }
        return sortedSupplements.map { s in
            let mine = recent.filter { $0.supplementID == s.id }
            let minutes = mine.map { r -> Int in
                let c = cal.dateComponents([.hour, .minute], from: r.time)
                return (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
            let average = minutes.isEmpty ? nil : minutes.reduce(0, +) / minutes.count
            // Total seulement si la dose est enregistrée dans l'unité actuelle.
            let amounts = mine.compactMap { r -> Double? in
                guard let a = r.amount, r.unit == s.unit else { return nil }
                return a
            }
            return SupplementStats(supplement: s, takenDays: mine.count, days: days,
                                   averageMinutes: average,
                                   totalAmount: amounts.isEmpty ? nil : amounts.reduce(0, +))
        }
    }

    /// Export pour tableur (séparateur « ; », compatible Excel en français).
    func csv() -> String {
        let log = loadLog()
        var lines = ["date;heure;complement;quantite;unite"]
        for key in log.keys.sorted() {
            for r in (log[key] ?? []).sorted(by: { $0.time < $1.time }) {
                let amount = r.amount.map { String($0).replacingOccurrences(of: ".", with: ",") } ?? ""
                let name = r.name.replacingOccurrences(of: ";", with: ",")
                lines.append("\(key);\(DoseFormat.time(r.time));\(name);\(amount);\(r.unit?.rawValue ?? "")")
            }
        }
        return lines.joined(separator: "\n")
    }

    // MARK: Réglages

    func reminderMinutes(_ moment: Moment) -> Int {
        (defaults.dictionary(forKey: Key.reminders) as? [String: Int])?[moment.rawValue] ?? moment.defaultMinutes
    }

    func setReminderMinutes(_ minutes: Int, for moment: Moment) {
        var d = defaults.dictionary(forKey: Key.reminders) as? [String: Int] ?? [:]
        d[moment.rawValue] = minutes
        defaults.set(d, forKey: Key.reminders)
    }

    var remindersOn: Bool {
        get { defaults.bool(forKey: Key.remindersOn) }
        set { defaults.set(newValue, forKey: Key.remindersOn) }
    }

    /// Alerte « Attention, t'as pas pris de… » si rien n'est coché après le délai.
    var lateAlertOn: Bool {
        get { defaults.object(forKey: Key.lateAlertOn) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.lateAlertOn) }
    }

    /// Délai après l'heure du moment, en minutes.
    var lateAlertDelay: Int {
        get { defaults.object(forKey: Key.lateAlertDelay) as? Int ?? 60 }
        set { defaults.set(newValue, forKey: Key.lateAlertDelay) }
    }

    /// Épingle la checklist sur l'écran verrouillé à chaque ouverture de l'app.
    var autoPin: Bool {
        get { defaults.object(forKey: Key.autoPin) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoPin) }
    }
}
