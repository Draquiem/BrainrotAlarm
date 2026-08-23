import SwiftUI

/// One tappable answer.
///
/// Names are hidden during a challenge on purpose. Showing them would turn a
/// listening puzzle into a spelling puzzle — you could sound out the label without
/// ever recognising the voice.
struct CreatureTile: View {
    /// Not called `State` — that would shadow SwiftUI's property wrapper.
    enum Highlight { case idle, correct, wrong }

    let character: BrainrotCharacter
    var state: Highlight = .idle
    var showsName: Bool = false
    var action: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                CreatureView(recipe: character.art, assetID: character.id)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(borderColor, lineWidth: state == .idle ? 1 : 3))
                if showsName {
                    Text(character.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(TileButtonStyle())
        .opacity(isEnabled ? 1 : 0.65)
        .modifier(ShakeEffect(shakes: state == .wrong ? 3 : 0))
        .animation(.default, value: state)
        .accessibilityLabel(showsName ? character.name : "Unnamed creature")
        .accessibilityHint("Tap if this is the one chanting")
    }

    private var borderColor: Color {
        switch state {
        case .idle: return Color.white.opacity(0.12)
        case .correct: return Color(hex: 0x5CE08A)
        case .wrong: return Color(hex: 0xFF6B6B)
        }
    }
}

private struct TileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Horizontal wobble for a wrong answer.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat
    var amplitude: CGFloat = 8

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(
            translationX: sin(shakes * .pi * 2) * amplitude, y: 0))
    }
}

/// Five bars bouncing while the chant plays. Purely decorative, but it tells you
/// at a glance whether sound is actually coming out.
struct EqualizerBars: View {
    var isAnimating: Bool
    var color: Color = Theme.accent

    private let heights: [CGFloat] = [0.45, 0.85, 0.6, 1.0, 0.5]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24, paused: !isAnimating)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 5) {
                ForEach(heights.indices, id: \.self) { index in
                    let wobble = isAnimating
                        ? 0.55 + 0.45 * sin(t * 6.0 + Double(index) * 0.9)
                        : 0.35
                    Capsule()
                        .fill(color)
                        .frame(width: 6, height: max(6, heights[index] * 34 * wobble))
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

/// Section wrapper used across the settings screens.
struct Panel<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.secondaryText)
            }
            content
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surface))
        }
    }
}
