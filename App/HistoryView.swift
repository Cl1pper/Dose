import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: DoseModel
    @Environment(\.dismiss) private var dismiss

    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now
    @State private var selected = Calendar.current.startOfDay(for: .now)
    @State private var editing: IntakeEditTarget?
    @State private var csvURL: URL?

    private let store = DoseStore.shared

    var body: some View {
        let _ = model.revision
        let log = store.loadLog()
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    SummaryCards(current: store.streak(in: log),
                                 best: store.bestStreak(in: log),
                                 adherence: store.adherence(window: 30, in: log))
                    MonthCalendar(month: $month, selected: $selected, log: log)
                    DayDetail(day: selected, log: log, supplements: model.supplements) { supplement in
                        editing = model.editTarget(for: supplement, on: selected)
                    }
                    StatsSection(stats: store.stats(window: 30, in: log))
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground(glow: false))
            .navigationTitle("Historique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if let csvURL {
                        ShareLink(item: csvURL) {
                            Label("Exporter", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(item: $editing) { target in
            IntakeEditor(target: target).environmentObject(model)
        }
        .task(id: model.revision) { csvURL = writeCSV() }
    }

    private func writeCSV() -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("dose-historique.csv")
        // BOM UTF-8 pour qu'Excel lise bien les accents.
        let content = "\u{FEFF}" + store.csv()
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}

// MARK: - Résumé

private struct SummaryCards: View {
    let current: Int
    let best: Int
    let adherence: Double

    var body: some View {
        HStack(spacing: 10) {
            card(value: "\(current)", label: "Série actuelle", symbol: "flame.fill", color: Theme.flame)
            card(value: "\(best)", label: "Meilleure série", symbol: "trophy.fill", color: Color(hex: "#FFD84D"))
            card(value: "\(Int((adherence * 100).rounded())) %", label: "Régularité 30 j", symbol: "chart.bar.fill", color: Theme.mint)
        }
    }

    private func card(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - Calendrier (heatmap)

private struct MonthCalendar: View {
    @Binding var month: Date
    @Binding var selected: Date
    let log: IntakeLog

    private let cal = Calendar.current
    private let store = DoseStore.shared
    @State private var forward = true

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Mois précédent")
                Spacer()
                Text(month.formatted(.dateTime.month(.wide).year()).capitalized)
                    .font(.headline)
                    .contentTransition(.numericText())
                Spacer()
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(isCurrentMonth)
                    .accessibilityLabel("Mois suivant")
            }
            .font(.headline)
            .padding(.horizontal, 4)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { pair in
                    Text(pair.element)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { pair in
                    if let day = pair.element {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
            .id(month)
            .transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                                    removal: .opacity))

            HStack(spacing: 6) {
                Text("Moins").font(.caption2).foregroundStyle(.secondary)
                ForEach([0.0, 0.34, 0.67, 1.0], id: \.self) { f in
                    RoundedRectangle(cornerRadius: 3).fill(fill(for: f)).frame(width: 12, height: 12)
                }
                Text("Tout pris").font(.caption2).foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipped()
    }

    private func dayCell(_ day: Date) -> some View {
        let isFuture = day > cal.startOfDay(for: .now)
        let isSelected = cal.isDate(day, inSameDayAs: selected)
        let fraction = isFuture ? 0 : store.dayFraction(day, in: log)
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selected = day }
        } label: {
            Text("\(cal.component(.day, from: day))")
                .font(.system(size: 14, weight: fraction >= 1 ? .heavy : .semibold, design: .rounded))
                .foregroundStyle(fraction >= 0.67 ? Theme.bg : Color.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .background(fill(for: fraction), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: isSelected ? 2 : 0)
                )
                .overlay(alignment: .bottom) {
                    if cal.isDateInToday(day) {
                        Circle().fill(fraction >= 0.67 ? Theme.bg : Theme.mint).frame(width: 4, height: 4).padding(.bottom, 4)
                    }
                }
                .opacity(isFuture ? 0.3 : 1)
                .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func fill(for fraction: Double) -> Color {
        fraction <= 0 ? Color.white.opacity(0.05) : Theme.mint.opacity(0.25 + 0.75 * fraction)
    }

    private var isCurrentMonth: Bool { cal.isDate(month, equalTo: .now, toGranularity: .month) }

    private func shift(_ value: Int) {
        guard let m = cal.date(byAdding: .month, value: value, to: month) else { return }
        forward = value > 0
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { month = m }
    }

    /// Initiales des jours, en commençant par le premier jour de la semaine local (lundi en France).
    private var weekdaySymbols: [String] {
        let symbols = cal.veryShortStandaloneWeekdaySymbols
        let first = cal.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// Cases du mois, avec des cases vides avant le 1er pour aligner sur le bon jour.
    private var cells: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = cal.component(.weekday, from: month)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        let days: [Date?] = range.compactMap { d in cal.date(byAdding: .day, value: d - 1, to: month) }
        return Array(repeating: nil, count: leading) + days
    }
}

// MARK: - Détail d'un jour

private struct DayDetail: View {
    @EnvironmentObject private var model: DoseModel
    let day: Date
    let log: IntakeLog
    let supplements: [Supplement]
    let onEdit: (Supplement) -> Void

    private let store = DoseStore.shared

    var body: some View {
        let records = store.records(on: day, in: log)
        let byID = Dictionary(records.map { ($0.supplementID, $0) }, uniquingKeysWith: { a, _ in a })
        let current = Set(supplements.map(\.id))
        let removed = records.filter { !current.contains($0.supplementID) }
        let ordered = store.sortedSupplements

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(ordered.filter { byID[$0.id] != nil }.count)/\(ordered.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            ForEach(ordered) { s in
                row(for: s, record: byID[s.id])
            }

            ForEach(removed) { r in
                HStack(spacing: 12) {
                    Image(systemName: "archivebox")
                        .frame(width: 34, height: 34)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(r.name).font(.subheadline.weight(.semibold))
                        Text(subtitle(for: r)).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: day)
    }

    private var title: String {
        if Calendar.current.isDateInToday(day) { return "Aujourd'hui" }
        if Calendar.current.isDateInYesterday(day) { return "Hier" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized
    }

    private func subtitle(for r: Intake) -> String {
        [DoseFormat.time(r.time), r.doseText].compactMap { $0 }.joined(separator: " · ")
    }

    @ViewBuilder
    private func row(for s: Supplement, record: Intake?) -> some View {
        let c = Color(hex: s.colorHex)
        HStack(spacing: 12) {
            Image(systemName: record != nil ? "checkmark" : s.symbol)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(record != nil ? Theme.bg : c)
                .frame(width: 34, height: 34)
                .background(record != nil ? c : c.opacity(0.14), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .contentTransition(.symbolEffect(.replace))
            VStack(alignment: .leading, spacing: 2) {
                Text(s.name).font(.subheadline.weight(.semibold))
                if let record {
                    Text(subtitle(for: record)).font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Pas pris").font(.caption).foregroundStyle(Color(hex: "#FF6B8B").opacity(0.9))
                }
            }
            Spacer()
            if record != nil {
                Button { onEdit(s) } label: {
                    Image(systemName: "pencil")
                        .font(.footnote.weight(.semibold))
                        .padding(8)
                        .background(Color.white.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Modifier la prise de \(s.name)")
            } else {
                Button("Marquer pris") { model.setTaken(s.id, true, on: day) }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(c)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Statistiques par complément

private struct StatsSection: View {
    let stats: [SupplementStats]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("30 derniers jours")
                .font(.headline)
            ForEach(stats) { st in
                let c = Color(hex: st.supplement.colorHex)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label(st.supplement.name, systemImage: st.supplement.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(c)
                        Spacer()
                        Text("\(st.takenDays)/\(st.days) j")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.07))
                            Capsule().fill(c).frame(width: max(6, geo.size.width * st.rate))
                        }
                    }
                    .frame(height: 8)
                    HStack(spacing: 12) {
                        if let m = st.averageMinutes {
                            Label("vers \(DoseFormat.time(minutes: m))", systemImage: "clock")
                        }
                        if let total = st.totalAmount, let text = DoseFormat.text(total, st.supplement.unit) {
                            Label("total \(text)", systemImage: "sum")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
