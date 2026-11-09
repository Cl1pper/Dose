import SwiftUI

/// Champ numérique pour une dose (accepte la virgule).
struct AmountField: View {
    @Binding var amount: Double?
    var placeholder = "Quantité"
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.decimalPad)
            .focused($focused)
            .toolbar {
                // Le clavier numérique n'a pas de touche « OK » : on en ajoute une.
                if focused {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("OK") { focused = false }
                            .fontWeight(.semibold)
                    }
                }
            }
            .onAppear { text = amount.map(DoseFormat.number) ?? "" }
            .onChange(of: text) { _, newValue in
                let parsed = Self.parse(newValue)
                if parsed != amount { amount = parsed }
            }
            .onChange(of: amount) { _, newValue in
                // Mise à jour venue de l'extérieur (ex. « dose habituelle »).
                if Self.parse(text) != newValue { text = newValue.map(DoseFormat.number) ?? "" }
            }
    }

    static func parse(_ text: String) -> Double? {
        let cleaned = text
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "\u{202F}", with: "")
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .replacingOccurrences(of: " ", with: "")
        return cleaned.isEmpty ? nil : Double(cleaned)
    }
}

struct UnitPicker: View {
    @Binding var unit: DoseUnit?

    var body: some View {
        Picker("Unité", selection: $unit) {
            Text("—").tag(DoseUnit?.none)
            ForEach(DoseUnit.allCases) { u in
                Text(u.rawValue).tag(Optional(u))
            }
        }
        .pickerStyle(.menu)
    }
}

/// Feuille d'édition d'une prise : heure, quantité, ou suppression.
struct IntakeEditor: View {
    @EnvironmentObject private var model: DoseModel
    @Environment(\.dismiss) private var dismiss

    let target: IntakeEditTarget

    @State private var time: Date
    @State private var amount: Double?
    @State private var unit: DoseUnit?

    init(target: IntakeEditTarget) {
        self.target = target
        _time = State(initialValue: target.intake.time)
        _amount = State(initialValue: target.intake.amount)
        _unit = State(initialValue: target.intake.unit ?? target.supplement.unit)
    }

    var body: some View {
        let c = Color(hex: target.supplement.colorHex)
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Image(systemName: target.supplement.symbol)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(c)
                            .frame(width: 48, height: 48)
                            .background(c.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.supplement.name).font(.headline)
                            Text(target.day.formatted(.dateTime.weekday(.wide).day().month(.wide)).capitalized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                }

                Section("Heure") {
                    DatePicker("Prise à", selection: $time, displayedComponents: .hourAndMinute)
                }

                Section {
                    HStack {
                        AmountField(amount: $amount)
                        UnitPicker(unit: $unit)
                            .labelsHidden()
                    }
                    if let usual = target.supplement.doseText {
                        Button("Remettre la dose habituelle (\(usual))") {
                            amount = target.supplement.amount
                            unit = target.supplement.unit
                        }
                        .font(.footnote)
                    }
                } header: {
                    Text("Quantité")
                }

                Section {
                    Button(role: .destructive) {
                        model.setTaken(target.supplement.id, false, on: target.day)
                        dismiss()
                    } label: {
                        Label("Retirer cette prise", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Modifier la prise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Enregistrer") {
                        model.updateIntake(target.supplement.id, on: target.day,
                                           time: combined(), amount: amount, unit: unit)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    /// L'heure choisie, ramenée sur le bon jour.
    private func combined() -> Date {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: c.hour ?? 12, minute: c.minute ?? 0, second: 0, of: target.day) ?? time
    }
}
