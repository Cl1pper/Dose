import SwiftUI
import WidgetKit

// MARK: - Timeline (une entrée maintenant, une à minuit pour remettre à zéro)

struct DoseEntry: TimelineEntry {
    let date: Date
    let snapshot: DoseSnapshot
}

struct DoseProvider: TimelineProvider {
    func placeholder(in context: Context) -> DoseEntry {
        DoseEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context)
                                      : DoseEntry(date: .now, snapshot: DoseStore.shared.snapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
        let cal = Calendar.current
        let now = Date()
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now)) ?? now.addingTimeInterval(86_400)
        // Profite du réveil quotidien du widget pour garder les rappels à jour.
        NotificationManager.reschedule()
        let entries = [
            DoseEntry(date: now, snapshot: DoseStore.shared.snapshot(for: now)),
            DoseEntry(date: tomorrow, snapshot: DoseStore.shared.snapshot(for: tomorrow))
        ]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - Éléments communs

struct WidgetBackground: View {
    var body: some View {
        ZStack {
            Theme.bg
            RadialGradient(colors: [Theme.mint.opacity(0.18), .clear], center: .topTrailing, startRadius: 0, endRadius: 200)
            RadialGradient(colors: [Theme.cyan.opacity(0.10), .clear], center: .bottomLeading, startRadius: 0, endRadius: 180)
        }
    }
}

struct ItemRow: View {
    let item: DoseItem
    var compact = false

    var body: some View {
        let c = Color(hex: item.supplement.colorHex)
        Button(intent: ToggleSupplementIntent(supplementID: item.id)) {
            HStack(spacing: 8) {
                Image(systemName: item.taken ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: compact ? 15 : 17, weight: .semibold))
                    .foregroundStyle(item.taken ? c : Color.white.opacity(0.35))
                    .contentTransition(.symbolEffect(.replace))
                Text(item.supplement.name)
                    .font(.system(size: compact ? 13 : 14, weight: .semibold))
                    .strikethrough(item.taken, color: .white.opacity(0.4))
                    .foregroundStyle(item.taken ? Color.secondary : Color.primary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: item.supplement.symbol)
                    .font(.system(size: 11))
                    .foregroundStyle(c.opacity(item.taken ? 0.4 : 0.9))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Écran d'accueil (un rond par complément)

private struct WidgetHeader: View {
    let s: DoseSnapshot
    var compact = false

    var body: some View {
        HStack(spacing: 6) {
            Text("DOSE")
                .font(.system(size: compact ? 11 : 12, weight: .heavy))
                .tracking(1.5)
                .foregroundStyle(Theme.accent)
            Text(s.isComplete ? "tout pris" : "\(s.done)/\(s.total)")
                .font(.system(size: compact ? 12 : 14, weight: .bold, design: .rounded))
                .contentTransition(.numericText(value: Double(s.done)))
            Spacer(minLength: 0)
            StreakBadge(streak: s.streak)
        }
    }
}

struct SmallView: View {
    let s: DoseSnapshot

    var body: some View {
        let items = Array(s.items.prefix(6))
        VStack(spacing: 10) {
            WidgetHeader(s: s, compact: true)
            Spacer(minLength: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 12) {
                ForEach(items) { DoseBubble(item: $0, size: 40) }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
    }
}

struct MediumView: View {
    let s: DoseSnapshot

    var body: some View {
        let items = Array(s.items.prefix(6))
        VStack(spacing: 10) {
            WidgetHeader(s: s)
            Spacer(minLength: 0)
            HStack(spacing: 0) {
                ForEach(items) { item in
                    DoseBubble(item: item, size: 46, showName: true)
                        .frame(maxWidth: .infinity)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
    }
}

struct LargeView: View {
    let s: DoseSnapshot

    var body: some View {
        VStack(spacing: 14) {
            WidgetHeader(s: s)
            Spacer(minLength: 0)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 22) {
                ForEach(s.items) { DoseBubble(item: $0, size: 74, showName: true) }
            }
            Spacer(minLength: 0)
            Text(s.isComplete ? "Tout est pris 🎉" : "Touche un rond quand c'est pris")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
    }
}

struct DoseWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DoseEntry

    var body: some View {
        content
            .environment(\.colorScheme, .dark)
            .containerBackground(for: .widget) { WidgetBackground() }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .systemSmall: SmallView(s: entry.snapshot)
        case .systemMedium: MediumView(s: entry.snapshot)
        default: LargeView(s: entry.snapshot)
        }
    }
}

struct DoseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DoseWidget", provider: DoseProvider()) { entry in
            DoseWidgetView(entry: entry)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Dose du jour")
        .description("Coche tes compléments sans ouvrir l'app.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

// MARK: - Écran verrouillé

struct LockView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DoseEntry

    var body: some View {
        content
            .containerBackground(for: .widget) { Color.clear }
    }

    @ViewBuilder private var content: some View {
        let s = entry.snapshot
        switch family {
        case .accessoryCircular:
            Button(intent: TakeNextIntent()) {
                Gauge(value: s.fraction, in: 0...1) {
                    Image(systemName: "pills.fill")
                } currentValueLabel: {
                    Text("\(s.done)/\(s.total)")
                        .contentTransition(.numericText(value: Double(s.done)))
                }
                .gaugeStyle(.accessoryCircularCapacity)
            }
            .buttonStyle(.plain)

        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("Dose").font(.headline)
                    Spacer()
                    Text(s.isComplete ? "tout pris" : "\(s.done)/\(s.total)")
                        .font(.headline)
                        .contentTransition(.numericText(value: Double(s.done)))
                }
                if s.isComplete {
                    Label("Série \(s.streak) j", systemImage: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                } else {
                    // Les 3 prochains à prendre, en gros ronds faciles à toucher.
                    HStack(spacing: 8) {
                        ForEach(Array(s.items.filter { !$0.taken }.prefix(3))) { item in
                            Button(intent: ToggleSupplementIntent(supplementID: item.id)) {
                                ZStack {
                                    Circle().strokeBorder(lineWidth: 2)
                                    Image(systemName: DoseEffect.of(item.supplement).pendingSymbol(item.supplement))
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .frame(width: 36, height: 36)
                                .contentShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Prendre \(item.supplement.name)")
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .widgetAccentable()

        default:
            Label("\(s.done)/\(s.total) · série \(s.streak) j", systemImage: "pills.fill")
        }
    }
}

struct DoseLockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DoseLockWidget", provider: DoseProvider()) { entry in
            LockView(entry: entry)
        }
        .configurationDisplayName("Dose · écran verrouillé")
        .description("Coche le complément suivant depuis l'écran verrouillé.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Live Activity

struct ChipsRow: View {
    let state: DoseActivityAttributes.ContentState
    var size: CGFloat = 50

    var body: some View {
        HStack(spacing: 0) {
            ForEach(state.items) { chip in
                DoseBubble(item: chip.asItem, size: size, showName: true,
                           action: ActivityToggleIntent(supplementID: chip.id))
                    .frame(maxWidth: .infinity)
            }
        }
    }
}

struct LockActivityView: View {
    let state: DoseActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Label("Dose du jour", systemImage: "pills.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.mint)
                Spacer()
                if state.streak > 0 {
                    Label("\(state.streak)", systemImage: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.flame)
                }
                Text("\(state.done)/\(state.total)")
                    .font(.subheadline.weight(.heavy))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(state.done)))
            }
            ChipsRow(state: state, size: 50)
                .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .environment(\.colorScheme, .dark)
    }
}

struct DoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { context in
            LockActivityView(state: context.state)
                .activityBackgroundTint(Theme.bg.opacity(0.88))
                .activitySystemActionForegroundColor(Theme.mint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Dose", systemImage: "pills.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.mint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.done)/\(context.state.total)")
                        .font(.caption.weight(.bold))
                        .contentTransition(.numericText(value: Double(context.state.done)))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ChipsRow(state: context.state, size: 40)
                }
            } compactLeading: {
                Image(systemName: "pills.fill")
                    .foregroundStyle(Theme.mint)
            } compactTrailing: {
                Text("\(context.state.done)/\(context.state.total)")
                    .font(.caption2.weight(.bold))
            } minimal: {
                DoseRing(fraction: context.state.fraction, lineWidth: 3)
            }
        }
    }
}

// MARK: - Point d'entrée

@main
struct DoseWidgetBundle: WidgetBundle {
    var body: some Widget {
        DoseWidget()
        DoseLockWidget()
        DoseLiveActivity()
    }
}
