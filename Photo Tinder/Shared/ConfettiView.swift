//
//  ConfettiView.swift
//  Photo Tinder
//

import SwiftUI

/// A short confetti burst whenever `trigger` changes.
struct ConfettiView: View {
    let trigger: Int

    private struct Piece {
        let x: CGFloat
        let vx: CGFloat
        let vy: CGFloat
        let spin: Double
        let size: CGSize
        let color: Color
    }

    private static let duration: TimeInterval = 3
    private static let colors: [Color] = [.pink, .orange, .yellow, .green, .blue, .purple]

    @State private var pieces: [Piece] = []
    @State private var start: Date?

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let t = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let x = piece.x * size.width + piece.vx * t
                    let y = -20 + piece.vy * t + 0.5 * 700 * t * t
                    var layer = context
                    layer.opacity = max(0, 1 - t / Self.duration)
                    layer.translateBy(x: x, y: y)
                    layer.rotate(by: .degrees(piece.spin * t))
                    layer.fill(Path(CGRect(origin: CGPoint(x: -piece.size.width / 2, y: -piece.size.height / 2), size: piece.size)),
                               with: .color(piece.color))
                }
            }
        }
        .onChange(of: trigger) {
            pieces = (0..<90).map { _ in
                Piece(x: .random(in: 0...1), vx: .random(in: -80...80), vy: .random(in: -100...150),
                      spin: .random(in: -360...360), size: CGSize(width: .random(in: 6...10), height: .random(in: 10...16)),
                      color: Self.colors.randomElement()!)
            }
            let burst = Date.now
            start = burst
            Task {
                try? await Task.sleep(for: .seconds(Self.duration))
                if start == burst { start = nil }
            }
        }
    }
}
