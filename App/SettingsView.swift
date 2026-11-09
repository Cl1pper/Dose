import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: DoseModel
    @Environment(\.dismiss) private var dismiss

    @State private var draft: [Supplement] = []
    @State private var remindersOn = false
    @State private var lateOn = true
    @State private var lateDelay = 60
    @State private var autoPin = true
    @State private var tick = 0

    private let store = DoseStore.shared

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach($draft) { $s in
                        NavigationLink {
                            SupplementEditor(supplement: $s)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: s.symbol)
                                    .foregroundStyle(Color(hex: s.colorHex))
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(s.name)
                                    Text([s.moment.label, s.doseText].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { draft.remove(atOffsets: $0) }
                    .onMove { draft.move(fromOffsets: $0, toOffset: $1) }

                    Button {
                        draft.append(Supplement(name: "Nouveau", moment: .matin,
                                                colorHex: Theme.palette.randomElement() ?? "#7CF5C4",
                                                symbol: "pills.fill"))
                    } label: {
                        Label("Ajouter un complément", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Ta liste")
                }

                Section {
                    Toggle("Rappel à l'heure", isOn: Binding(get: { remindersOn }, set: { v in
                        remindersOn = v
                        store.remindersOn = v
                        applyNotifications(turningOn: v)
                    }))
                    Toggle("Alerte si oubli", isOn: Binding(get: { lateOn }, set: { v in
                        lateOn = v
                        store.lateAlertOn = v
                        applyNotifications(turningOn: v)
                    }))
                    if lateOn {
                        Picker("Alerte après", selection: Binding(get: { lateDelay }, set: { v in
                            lateDelay = v
                            store.lateAlertDelay = v
                            NotificationManager.reschedule()
                        })) {
                            Text("30 min").tag(30)
                            Text("1 h").tag(60)
                            Text("2 h").tag(120)
                            Text("3 h").tag(180)
                        }
                    }
                    if remindersOn || lateOn {
                        ForEach(usedMoments) { m in
                            DatePicker(selection: timeBinding(m), displayedComponents: .hourAndMinute) {
                                Label(m.label, systemImage: m.symbol)
                            }
                        }
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("« Alerte si oubli » : si un complément n'est toujours pas coché après le délai, tu reçois « Attention, t'as pas pris de Zinc ». Rien n'est envoyé pour ce qui est déjà coché. Dans la notification : « C'est pris ✓ » coche tout le moment, « Dans 30 min » repousse l'alerte.")
                }

                Section {
                    Toggle("Épingler à l'ouverture", isOn: Binding(get: { autoPin }, set: { v in
                        autoPin = v
                        store.autoPin = v
                    }))
                } header: {
                    Text("Écran verrouillé")
                } footer: {
                    Text("À chaque ouverture de l'app, ta checklist s'affiche sur l'écran verrouillé tant qu'il reste quelque chose à prendre.")
                }

                Section("Widgets") {
                    Text("Écran d'accueil : appui long → + → Dose. Écran verrouillé : appui long sur l'écran verrouillé → Personnaliser → widgets.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { EditButton() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") {
                        model.save(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                draft = model.supplements
                remindersOn = store.remindersOn
                lateOn = store.lateAlertOn
                lateDelay = store.lateAlertDelay
                autoPin = store.autoPin
            }
        }
        .preferredColorScheme(.dark)
    }

    private var usedMoments: [Moment] {
        Moment.allCases.filter { m in draft.contains { $0.moment == m } }
    }

    /// Demande l'autorisation la première fois, puis reprogramme tout.
    private func applyNotifications(turningOn: Bool) {
        guard turningOn else {
            NotificationManager.reschedule()
            return
        }
        Task {
            let granted = await NotificationManager.requestAuthorization()
            if !granted {
                remindersOn = false
                lateOn = false
                store.remindersOn = false
                store.lateAlertOn = false
            }
            NotificationManager.reschedule()
        }
    }

    private func timeBinding(_ m: Moment) -> Binding<Date> {
        Binding(
            get: {
                _ = tick
                let mins = store.reminderMinutes(m)
                return Calendar.current.date(bySettingHour: mins / 60, minute: mins % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                store.setReminderMinutes((c.hour ?? 0) * 60 + (c.minute ?? 0), for: m)
                NotificationManager.reschedule()
                tick += 1
            }
        )
    }
}

struct SupplementEditor: View {
    @Binding var supplement: Supplement

    var body: some View {
        Form {
            Section("Nom") {
                TextField("Nom", text: $supplement.name)
                TextField("Note (avec repas, à jeun…)", text: $supplement.detail)
            }
            Section {
                HStack {
                    AmountField(amount: $supplement.amount, placeholder: "Quantité")
                    UnitPicker(unit: $supplement.unit)
                        .labelsHidden()
                }
            } header: {
                Text("Dose habituelle")
            } footer: {
                Text("Enregistrée automatiquement à chaque prise. Tu peux la changer pour un jour précis (appui long sur la carte).")
            }
            Section("Moment") {
                Picker("Moment", selection: $supplement.moment) {
                    ForEach(Moment.allCases) { m in
                        Text(m.label).tag(m)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section("Couleur") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
                    ForEach(Theme.palette, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 30, height: 30)
                            .overlay(Circle().strokeBorder(Color.white, lineWidth: supplement.colorHex == hex ? 3 : 0))
                            .onTapGesture { supplement.colorHex = hex }
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Icône") {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 10) {
                    ForEach(Theme.symbols, id: \.self) { sym in
                        Image(systemName: sym)
                            .font(.title3)
                            .frame(width: 40, height: 40)
                            .foregroundStyle(Color(hex: supplement.colorHex))
                            .background(supplement.symbol == sym ? Color(hex: supplement.colorHex).opacity(0.25) : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture { supplement.symbol = sym }
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(supplement.name.isEmpty ? "Complément" : supplement.name)
    }
}
