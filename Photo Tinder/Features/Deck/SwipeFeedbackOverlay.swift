//
//  SwipeFeedbackOverlay.swift
//  Photo Tinder
//

import SwiftUI

/// Drives the full-screen swipe celebration: it builds up while the card is dragged,
/// pops when the swipe lands, then fades away. Each swipe gets a freshly randomized layout.
@Observable
final class SwipeFeedback {
    enum Phase { case idle, dragging, burst, fading }

    /// Drag progress reaches 1 at this multiple of the swipe threshold (see `SwipeCardView.dragHint`).
    static let reachPastThreshold = 1.6

    struct Particle: Identifiable {
        let id = UUID()
        /// Offset from the screen center, in units of the screen width.
        let position: CGPoint
        /// Point size as a fraction of the screen width.
        let size: CGFloat
        /// Kept within ±24° so the idle sway (±6°) never tilts past 30°.
        let rotation: Double
        let delay: Double
        /// How far it drifts while fading, in units of the screen width.
        let drift: CGSize
        /// Offsets the idle sway so particles don't move in lockstep.
        let seed: Double = .random(in: 0...(2 * .pi))
    }

    struct Layout {
        let action: SwipeAction
        let main: Particle?
        let particles: [Particle]
    }

    private(set) var layout: Layout?
    private(set) var phase: Phase = .idle
    private(set) var progress: Double = 0
    @ObservationIgnored private var generation = 0

    /// Live preview while the card is being dragged. `action` is nil when it's back near the center.
    func drag(_ action: SwipeAction?, progress: Double) {
        if phase == .burst { return }
        if phase == .fading { generation += 1; layout = nil }
        guard let action, progress > 0 else { self.progress = 0; return }
        if layout?.action != action { layout = Self.makeLayout(for: action) }
        phase = .dragging
        self.progress = progress
    }

    /// The swipe landed: pop, hold briefly, fade out.
    func commit(_ action: SwipeAction) {
        generation += 1
        let current = generation
        let needsEntrance = phase != .dragging || layout?.action != action
        if layout?.action != action { layout = Self.makeLayout(for: action) }
        if needsEntrance {
            // Render the empty starting state once so the pop has something to animate from (button taps).
            phase = .dragging
            progress = 0
        }
        Task {
            if needsEntrance { try? await Task.sleep(for: .milliseconds(20)) }
            guard generation == current else { return }
            phase = .burst
            progress = 1
            try? await Task.sleep(for: .milliseconds(420))
            guard generation == current else { return }
            phase = .fading
            try? await Task.sleep(for: .milliseconds(1000))
            guard generation == current else { return }
            phase = .idle
            layout = nil
            progress = 0
        }
    }

    /// One big icon in the center with a ring of small ones; the same shape for every swipe direction.
    private static func makeLayout(for action: SwipeAction) -> Layout {
        let main = Particle(position: .zero, size: 0.6, rotation: .random(in: -24...24), delay: 0, drift: .zero)
        let count = Int.random(in: 6...8)
        let smalls = (0..<count).map { index in
            let angle = Double(index) / Double(count) * 2 * .pi + .random(in: -0.35...0.35)
            let point = CGPoint(x: cos(angle) * .random(in: 0.33...0.42), y: sin(angle) * .random(in: 0.5...0.66))
            return Particle(position: point,
                            size: .random(in: 0.11...0.2),
                            rotation: .random(in: -24...24),
                            delay: 0.04 + Double(index) * 0.03 + .random(in: 0...0.04),
                            drift: CGSize(width: point.x * 0.35, height: point.y * 0.35))
        }
        return Layout(action: action, main: main, particles: smalls)
    }
}

struct SwipeFeedbackOverlay: View {
    let feedback: SwipeFeedback
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            if let layout = feedback.layout {
                // Keeps everything gently moving, so the overlay never looks frozen while a finger rests on the card.
                TimelineView(.animation(paused: feedback.phase == .idle || reduceMotion)) { timeline in
                    let time = timeline.date.timeIntervalSinceReferenceDate
                    ZStack {
                        edgeGlow(layout.action, in: geo.size)
                        if let main = layout.main {
                            icon(main, action: layout.action, isMain: true, time: time, in: geo.size)
                        }
                        ForEach(layout.particles) { particle in
                            icon(particle, action: layout.action, isMain: false, time: time, in: geo.size)
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func icon(_ particle: SwipeFeedback.Particle, action: SwipeAction, isMain: Bool,
                      time: TimeInterval, in size: CGSize) -> some View {
        let sway = ambient
        let bob: CGFloat = isMain ? 3 : 7
        let pulse = isMain ? 1 + 0.04 * sin(time * 2.6) * sway : 1
        return Image(systemName: symbol(for: action))
            .font(.system(size: particle.size * size.width))
            .foregroundStyle(color(for: action).gradient)
            .shadow(color: color(for: action).opacity(0.5), radius: isMain ? 24 : 8)
            .rotationEffect(.degrees(particle.rotation + sin(time * 1.7 + particle.seed) * 6 * sway))
            .scaleEffect(scale(isMain: isMain) * pulse)
            .opacity(opacity)
            .offset(x: sin(time * 1.3 + particle.seed) * bob * sway,
                    y: cos(time * 1.1 + particle.seed) * bob * 1.4 * sway)
            .position(position(for: particle, in: size))
            .animation(animation(for: particle, isMain: isMain), value: feedback.phase)
    }

    private func edgeGlow(_ action: SwipeAction, in size: CGSize) -> some View {
        let strength: Double = switch feedback.phase {
        case .idle, .fading: 0
        case .dragging: 0.6 * eased
        case .burst: 1
        }
        return RadialGradient(colors: [color(for: action).opacity(0), color(for: action).opacity(0.35)],
                              center: .center, startRadius: size.width * 0.35, endRadius: size.height * 0.75)
            .opacity(strength)
            .animation(feedback.phase == .fading ? .easeOut(duration: 0.5).delay(0.35) : .easeOut(duration: 0.2), value: feedback.phase)
    }

    // MARK: Per-phase values

    /// Drag progress with an ease-out curve, so the overlay shows up early and keeps growing smoothly.
    private var eased: Double {
        let p = feedback.progress
        return 1 - (1 - p) * (1 - p)
    }

    /// How much idle sway/bob to apply.
    private var ambient: Double {
        if reduceMotion { return 0 }
        return switch feedback.phase {
        case .idle: 0
        case .dragging: eased
        case .burst, .fading: 1
        }
    }

    /// Logarithmic: fades in fast at the start of the drag, then levels off at fully opaque
    /// exactly when the card crosses the swipe threshold.
    private var dragOpacity: Double {
        let toThreshold = min(feedback.progress * SwipeFeedback.reachPastThreshold, 1)
        return log10(1 + 9 * toThreshold)
    }

    private var opacity: Double {
        switch feedback.phase {
        case .idle, .fading: 0
        case .burst: 1
        case .dragging: dragOpacity
        }
    }

    private func scale(isMain: Bool) -> CGFloat {
        let p = CGFloat(eased)
        switch feedback.phase {
        case .idle: return 0.5
        case .dragging: return isMain ? 0.55 + 0.3 * p : 0.4 + 0.45 * p
        case .burst: return 1
        case .fading:
            if reduceMotion { return 1 }
            return isMain ? 1.25 : 0.8
        }
    }

    private func position(for particle: SwipeFeedback.Particle, in size: CGSize) -> CGPoint {
        let w = size.width
        let fading = feedback.phase == .fading && !reduceMotion
        // Small icons start tucked in toward the center and spread out as the drag grows.
        let spread: CGFloat = switch feedback.phase {
        case .idle: 0.6
        case .dragging: 0.6 + 0.4 * CGFloat(eased)
        case .burst, .fading: 1
        }
        let drift = fading ? particle.drift : .zero
        return CGPoint(x: size.width / 2 + (particle.position.x * spread + drift.width) * w,
                       y: size.height / 2 + (particle.position.y * spread + drift.height) * w)
    }

    /// On the way out the small icons go first, one after another, and the big one fades last.
    private func animation(for particle: SwipeFeedback.Particle, isMain: Bool) -> Animation? {
        switch feedback.phase {
        case .burst: .spring(response: 0.34, dampingFraction: 0.55).delay(particle.delay)
        case .fading: isMain ? .easeIn(duration: 0.4).delay(0.45) : .easeIn(duration: 0.3).delay(particle.delay * 0.6)
        case .idle, .dragging: nil
        }
    }

    private func symbol(for action: SwipeAction) -> String {
        switch action {
        case .keep: "hand.thumbsup.fill"
        case .delete: "hand.thumbsdown.fill"
        case .favorite: "star.fill"
        }
    }

    private func color(for action: SwipeAction) -> Color {
        switch action {
        case .keep: .green
        case .delete: .red
        case .favorite: .orange
        }
    }
}
