import SwiftUI

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            .sRGB,
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}

enum Theme {
    static let bg = Color(hex: "#0B0D12")
    static let card = Color(hex: "#151922")
    static let mint = Color(hex: "#7CF5C4")
    static let cyan = Color(hex: "#5AC8FA")
    static let flame = Color(hex: "#FF8A3D")

    static var accent: LinearGradient {
        LinearGradient(colors: [mint, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static let palette = ["#7CF5C4", "#5AC8FA", "#B18CFF", "#FFB35C", "#7FE07A", "#FF6B8B", "#FFD84D"]

    static let symbols = [
        "bolt.fill", "sun.max.fill", "shield.fill", "moon.fill", "cup.and.saucer.fill", "capsule.fill",
        "pills.fill", "drop.fill", "leaf.fill", "heart.fill", "flame.fill", "brain.head.profile"
    ]
}

/// Anneau de progression dégradé, partagé par l'app, les widgets et la Live Activity.
struct DoseRing: View {
    var fraction: Double
    var lineWidth: CGFloat = 8

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(
                    AngularGradient(colors: [Theme.mint, Theme.cyan, Theme.mint], center: .center),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

struct StreakBadge: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "flame.fill")
            Text("\(streak)")
                .contentTransition(.numericText(value: Double(streak)))
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(streak > 0 ? Theme.flame : Color.white.opacity(0.3))
    }
}
