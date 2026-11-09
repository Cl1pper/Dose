import AppIntents
import SwiftUI
import WidgetKit

/// Effet propre à chaque complément quand on le coche dans le widget.
/// (iOS joue l'animation une fois, au moment du changement.)
enum DoseEffect: Equatable {
    case sun      // Vitamine D : le soleil s'allume et ses rayons jaillissent
    case flex     // MK-677 : un bras qui gonfle
    case shield   // Zinc : un bouclier s'active avec une onde protectrice
    case moon     // Magnésium : la lune s'endort, des « zzz » s'envolent
    case leaf     // L-théanine : une feuille de thé, une goutte qui tombe
    case bolt     // Créatine : la jauge se charge de bas en haut, éclair
    case generic  // Complément ajouté plus tard : simple coche

    static func of(_ s: Supplement) -> DoseEffect {
        switch s.id {
        case "vitamine-d": return .sun
        case "mk-677": return .flex
        case "zinc": return .shield
        case "magnesium": return .moon
        case "l-theanine": return .leaf
        case "creatine": return .bolt
        default: return .generic
        }
    }

    func pendingSymbol(_ s: Supplement) -> String {
        switch self {
        case .sun: return "sun.min"
        case .flex: return "dumbbell.fill"
        case .shield: return "shield"
        case .moon: return "moon"
        case .leaf: return "leaf"
        case .bolt: return "bolt"
        case .generic: return s.symbol
        }
    }

    func takenSymbol(_ s: Supplement) -> String {
        switch self {
        case .sun: return "sun.max.fill"
        case .flex: return "dumbbell.fill"
        case .shield: return "checkmark.shield.fill"
        case .moon: return "moon.zzz.fill"
        case .leaf: return "leaf.fill"
        case .bolt: return "bolt.fill"
        case .generic: return "checkmark"
        }
    }

    /// Façon dont l'icône se transforme.
    var replace: ReplaceSymbolEffect {
        switch self {
        case .sun, .bolt: return .replace.upUp
        case .shield, .leaf: return .replace.downUp
        case .moon: return .replace.offUp
        default: return .replace
        }
    }

    /// Façon dont la couleur remplit le rond.
    var fillTransition: AnyTransition {
        switch self {
        case .bolt: return .push(from: .bottom)                 // ça se charge
        case .leaf: return .push(from: .top)                    // le thé se verse
        case .flex: return .scale(scale: 0.4).combined(with: .opacity)
        case .moon, .shield: return .opacity                    // doux
        default: return .scale.combined(with: .opacity)
        }
    }
}

/// Un rond par complément : contour quand c'est à prendre, rempli et animé quand c'est pris.
struct DoseBubble<Action: AppIntent>: View {
    let item: DoseItem
    var size: CGFloat
    var showName = false
    let action: Action

    private var effect: DoseEffect { .of(item.supplement) }
    private var color: Color { Color(hex: item.supplement.colorHex) }

    var body: some View {
        Button(intent: action) {
            VStack(spacing: 4) {
                // Tout reste DANS le rond : rien ne déborde sur les voisins ni sur les noms.
                ZStack {
                    Circle()
                        .fill(color.opacity(0.10))
                    Circle()
                        .strokeBorder(color.opacity(item.taken ? 0 : 0.55), lineWidth: max(2, size * 0.055))
                    if item.taken {
                        Circle()
                            .fill(color)
                            .transition(effect.fillTransition)
                    }
                    inner
                    icon
                    accent
                }
                .frame(width: size, height: size)
                .clipShape(Circle())

                if showName {
                    Text(item.supplement.name)
                        .font(.system(size: max(9, size * 0.17), weight: .semibold))
                        .foregroundStyle(item.taken ? Color.secondary : Color.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.5, dampingFraction: 0.62), value: item.taken)
        .accessibilityLabel("\(item.supplement.name), \(item.taken ? "pris" : "à prendre")")
    }

    // MARK: Icône

    @ViewBuilder private var icon: some View {
        if effect == .flex {
            if item.taken {
                Text("💪")
                    .font(.system(size: size * 0.5))
                    .transition(.scale(scale: 0.15, anchor: .bottomLeading).combined(with: .opacity))
            } else {
                Image(systemName: effect.pendingSymbol(item.supplement))
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(color)
                    .transition(.opacity)
            }
        } else {
            Image(systemName: item.taken ? effect.takenSymbol(item.supplement) : effect.pendingSymbol(item.supplement))
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(item.taken ? Theme.bg : color)
                .contentTransition(.symbolEffect(effect.replace))
        }
    }

    // MARK: Effets intérieurs (dans le rond)

    @ViewBuilder private var inner: some View {
        if item.taken {
            switch effect {
            case .sun:
                // Le soleil « brille » : un cœur lumineux qui s'allume au centre.
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.75), Color.white.opacity(0)],
                                         center: .center, startRadius: 0, endRadius: size * 0.42))
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
            case .shield:
                // Le bouclier s'active : un anneau protecteur à l'intérieur du bord.
                Circle()
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: max(1.5, size * 0.045))
                    .padding(size * 0.08)
                    .transition(.scale(scale: 1.3).combined(with: .opacity))
            case .flex:
                // Le bras gonfle : une onde qui part du bas.
                Circle()
                    .fill(RadialGradient(colors: [Color.white.opacity(0.4), Color.white.opacity(0)],
                                         center: .bottom, startRadius: 0, endRadius: size * 0.7))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder private var accent: some View {
        if item.taken {
            switch effect {
            case .moon:
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.16, weight: .bold))
                    .foregroundStyle(Theme.bg.opacity(0.7))
                    .offset(x: size * 0.2, y: -size * 0.22)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .leaf:
                Image(systemName: "drop.fill")
                    .font(.system(size: size * 0.15, weight: .bold))
                    .foregroundStyle(Theme.bg.opacity(0.7))
                    .offset(x: size * 0.22, y: -size * 0.2)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .bolt:
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.15, weight: .bold))
                    .foregroundStyle(Theme.bg.opacity(0.7))
                    .offset(x: size * 0.22, y: -size * 0.22)
                    .transition(.scale(scale: 0.1).combined(with: .opacity))
            default:
                EmptyView()
            }
        }
    }
}

extension DoseBubble where Action == ToggleSupplementIntent {
    /// Rond de widget : coche / décoche le complément.
    init(item: DoseItem, size: CGFloat, showName: Bool = false) {
        self.init(item: item, size: size, showName: showName, action: ToggleSupplementIntent(supplementID: item.id))
    }
}

extension DoseChip {
    /// Convertit une puce de Live Activity en élément affichable par DoseBubble.
    var asItem: DoseItem {
        let s = Supplement(id: id, name: name, moment: .matin, colorHex: colorHex, symbol: symbol)
        let record = taken ? Intake(supplementID: id, name: name, time: .now, amount: nil, unit: nil) : nil
        return DoseItem(supplement: s, record: record)
    }
}
