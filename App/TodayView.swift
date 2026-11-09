import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: DoseModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var editing: IntakeEditTarget?
    @State private var showConfetti = false
    @State private var celebration = 0

    var body: some View {
        let s = model.snapshot
        ZStack {
            AppBackground(glow: s.isComplete)

            ScrollView {
                VStack(spacing: 24) {
                    header
                    HeroRing(snapshot: s)
                    ForEach(s.moments) { m in
                        MomentSection(moment: m, items: s.items(for: m)) { supplement in
                            editing = model.editTarget(for: supplement, on: .now)
                        }
                    }
                    if !s.isComplete { pinButton }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)

            if showConfetti {
                ConfettiView()
                    .allowsHitTesting(false)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(model)
        }
        .sheet(isPresented: $showHistory) {
            HistoryView().environmentObject(model)
        }
        .sheet(item: $editing) { target in
            IntakeEditor(target: target).environmentObject(model)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.appBecameActive() }
        }
        .onChange(of: model.justCompleted) { _, done in
            guard done else { return }
            model.justCompleted = false
            celebrate()
        }
        .onReceive(NotificationCenter.default.publisher(for: .doseChanged)) { _ in
            model.refresh()
        }
        .sensoryFeedback(.success, trigger: celebration)
        .task {
            // L'alerte d'oubli est active par défaut : on demande l'autorisation au premier lancement.
            if DoseStore.shared.lateAlertOn || DoseStore.shared.remindersOn {
                _ = await NotificationManager.requestAuthorization()
                NotificationManager.reschedule()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Ta dose du jour")
                    .font(.largeTitle.bold())
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .padding(11)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Historique")
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.title3)
                        .padding(11)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Réglages")
            }
        }
        .padding(.top, 8)
    }

    private var pinButton: some View {
        Button {
            model.liveActivityOn ? model.unpin() : model.pin()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: model.liveActivityOn ? "pin.slash.fill" : "pin.fill")
                    .contentTransition(.symbolEffect(.replace))
                Text(model.liveActivityOn ? "Retirer de l'écran verrouillé" : "Épingler sur l'écran verrouillé")
                Spacer()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.mint)
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }

    private func celebrate() {
        celebration += 1
        showConfetti = true
        Task {
            try? await Task.sleep(for: .seconds(3.6))
            showConfetti = false
        }
    }
}

// MARK: - Fond animé

struct AppBackground: View {
    var glow: Bool
    @State private var drift = false

    var body: some View {
        ZStack {
            Theme.bg
            Circle()
                .fill(Theme.mint.opacity(glow ? 0.28 : 0.14))
                .frame(width: 340)
                .blur(radius: 90)
                .offset(x: drift ? 120 : 60, y: drift ? -300 : -240)
            Circle()
                .fill(Theme.cyan.opacity(0.10))
                .frame(width: 300)
                .blur(radius: 90)
                .offset(x: drift ? -140 : -90, y: drift ? 320 : 260)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 1.2), value: glow)
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) { drift = true }
        }
    }
}

// MARK: - Anneau principal

struct HeroRing: View {
    let snapshot: DoseSnapshot
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.mint.opacity(snapshot.isComplete ? 0.35 : 0.12), .clear],
                                     center: .center, startRadius: 10, endRadius: 150))
                .scaleEffect(pulse ? 1.08 : 0.94)

            DoseRing(fraction: snapshot.fraction, lineWidth: 18)
                .frame(width: 196, height: 196)

            VStack(spacing: 4) {
                Text("\(snapshot.done)/\(snapshot.total)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .contentTransition(.numericText(value: Double(snapshot.done)))
                Text(snapshot.isComplete ? "Tout est pris 🎉" : "pris aujourd'hui")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                StreakPill(streak: snapshot.streak)
                    .padding(.top, 4)
            }
        }
        .frame(height: 250)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { pulse = true }
        }
    }
}

struct StreakPill: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "flame.fill")
                .symbolEffect(.bounce, value: streak)
            Text(streak > 0 ? "\(streak) jour\(streak > 1 ? "s" : "") de suite" : "Lance ta série")
                .contentTransition(.numericText(value: Double(streak)))
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(streak > 0 ? Theme.flame : Color.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((streak > 0 ? Theme.flame : Color.white).opacity(0.12), in: Capsule())
    }
}

// MARK: - Sections et cartes

struct MomentSection: View {
    @EnvironmentObject private var model: DoseModel
    let moment: Moment
    let items: [DoseItem]
    let onEdit: (Supplement) -> Void

    var body: some View {
        let done = items.filter(\.taken).count
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(moment.label, systemImage: moment.symbol)
                    .font(.headline)
                Text("\(done)/\(items.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText(value: Double(done)))
                Spacer()
                if done < items.count {
                    Button("Tout cocher") { model.markMoment(moment) }
                        .font(.caption.weight(.semibold))
                        .transition(.opacity)
                }
            }
            ForEach(items) { item in
                SupplementCard(item: item) { onEdit(item.supplement) }
            }
        }
    }
}

struct SupplementCard: View {
    @EnvironmentObject private var model: DoseModel
    let item: DoseItem
    let onEdit: () -> Void

    /// Pris : « 8:12 · 5 g ». À prendre : dose habituelle et note.
    private var subtitle: String? {
        let parts: [String?]
        if let r = item.record {
            parts = ["Pris à " + DoseFormat.time(r.time), r.doseText]
        } else {
            parts = [item.supplement.doseText, item.supplement.detail.isEmpty ? nil : item.supplement.detail]
        }
        let text = parts.compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    var body: some View {
        let c = Color(hex: item.supplement.colorHex)
        Button {
            model.toggle(item.id)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(c.opacity(item.taken ? 0.9 : 0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: item.taken ? "checkmark" : item.supplement.symbol)
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(item.taken ? Theme.bg : c)
                        .contentTransition(.symbolEffect(.replace))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.supplement.name)
                        .font(.body.weight(.semibold))
                        .strikethrough(item.taken, color: .white.opacity(0.35))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .contentTransition(.opacity)
                    }
                }
                Spacer()
                Image(systemName: item.taken ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.taken ? c : Color.white.opacity(0.25))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: item.taken)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.card)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(item.taken ? c.opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
                    )
            )
            .opacity(item.taken ? 0.75 : 1)
        }
        .buttonStyle(PressableStyle())
        .contextMenu {
            if item.taken {
                Button { onEdit() } label: { Label("Modifier l'heure ou la dose", systemImage: "pencil") }
                Button(role: .destructive) { model.toggle(item.id) } label: { Label("Retirer la prise", systemImage: "arrow.uturn.backward") }
            } else {
                Button { model.toggle(item.id) } label: { Label("Marquer pris", systemImage: "checkmark") }
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: item.taken)
        .accessibilityLabel("\(item.supplement.name), \(item.taken ? "pris" : "à prendre")")
    }
}

struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

// MARK: - Confettis (quand tout est pris)

struct ConfettiView: View {
    private struct Particle {
        let x: Double, vx: Double, vy: Double, spin: Double, size: Double, delay: Double
        let color: Color
    }

    @State private var start = Date()
    @State private var particles: [Particle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let tt = t - p.delay
                    guard tt > 0, tt < 3.2 else { continue }
                    let x = p.x * size.width + p.vx * tt
                    let y = -20 + p.vy * tt + 130 * tt * tt
                    var ctx = context
                    ctx.opacity = max(0, 1 - tt / 3.2)
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .degrees(p.spin * tt))
                    let rect = CGRect(x: -p.size / 2, y: -p.size / 4, width: p.size, height: p.size / 2)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(p.color))
                }
            }
        }
        .onAppear {
            start = .now
            let colors = [Theme.mint, Theme.cyan, Theme.flame, Color(hex: "#B18CFF"), Color(hex: "#FFD84D")]
            particles = (0..<150).map { _ in
                Particle(x: .random(in: 0...1), vx: .random(in: -60...60), vy: .random(in: 60...240),
                         spin: .random(in: -540...540), size: .random(in: 7...13), delay: .random(in: 0...0.5),
                         color: colors.randomElement() ?? Theme.mint)
            }
        }
    }
}
