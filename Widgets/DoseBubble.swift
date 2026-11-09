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
struct DoseBubble: View {
    let item: DoseItem
    var size: CGFloat
    var showName = false

    private var effect: DoseEffect { .of(item.supplement) }
    private var color: Color { Color(hex: item.supplement.colorHex) }

    var body: some View {
        Button(intent: ToggleSupplementIntent(supplementID: item.id)) {
            VStack(spacing: 4) {
                ZStack {
                    halo
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
                        icon
                    }
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    accent
                }
                .frame(width: size, height: size)

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

    // MARK: Autour du rond

    @ViewBuilder private var halo: some View {
        if item.taken {
            switch effect {
            case .sun:
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [color.opacity(0.6), color.opacity(0)],
                                             center: .center, startRadius: size * 0.3, endRadius: size * 0.9))
                        .frame(width: size * 1.8, height: size * 1.8)
                    ForEach(0..<8, id: \.self) { i in
                        Capsule()
                            .fill(color)
                            .frame(width: max(2, size * 0.07), height: size * 0.16)
                            .offset(y: -size * 0.68)
                            .rotationEffect(.degrees(Double(i) * 45))
                    }
                }
                .transition(.scale(scale: 0.4).combined(with: .opacity))
            case .shield:
                Circle()
                    .strokeBorder(color.opacity(0.7), lineWidth: max(1.5, size * 0.04))
                    .frame(width: size * 1.32, height: size * 1.32)
                    .transition(.scale(scale: 0.7).combined(with: .opacity))
            case .flex:
                Circle()
                    .fill(RadialGradient(colors: [color.opacity(0.45), color.opacity(0)],
                                         center: .center, startRadius: size * 0.35, endRadius: size * 0.8))
                    .frame(width: size * 1.6, height: size * 1.6)
                    .transition(.scale(scale: 0.5).combined(with: .opacity))
            default:
                EmptyView()
            }
        }
    }

    @ViewBuilder private var accent: some View {
        if item.taken {
            switch effect {
            case .moon:
                Image(systemName: "zzz")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(color)
                    .offset(x: size * 0.46, y: -size * 0.48)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            case .leaf:
                Image(systemName: "drop.fill")
                    .font(.system(size: size * 0.22, weight: .bold))
                    .foregroundStyle(color)
                    .offset(x: size * 0.42, y: -size * 0.44)
                    .transition(.move(edge: .top).combined(with: .opacity))
            case .bolt:
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.24, weight: .bold))
                    .foregroundStyle(color)
                    .offset(x: size * 0.44, y: -size * 0.46)
                    .transition(.scale(scale: 0.1).combined(with: .opacity))
            default:
                EmptyView()
            }
        }
    }
}
