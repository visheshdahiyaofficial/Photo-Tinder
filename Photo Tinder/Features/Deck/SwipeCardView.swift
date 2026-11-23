//
//  SwipeCardView.swift
//  Photo Tinder
//

import SwiftUI

struct SwipeCardView: View {
    let item: MediaItem
    let isTop: Bool
    let requestedAction: SwipeAction?
    /// Which way the card is leaning and how far (0–1), for the full-screen feedback.
    let onDrag: (SwipeAction?, Double) -> Void
    /// Called as the card starts flying off.
    let onFling: (SwipeAction) -> Void
    /// Press and hold without moving the card.
    let onLongPress: () -> Void
    /// Called once the card is off-screen.
    let onDecide: (SwipeAction) -> Void

    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @State private var offset: CGSize = .zero
    @State private var isFlying = false
    @State private var flungAction: SwipeAction?
    @State private var longPressCount = 0
    /// Resets automatically when the drag ends or is cancelled by the system (where `onEnded` isn't called).
    @GestureState private var isDragging = false

    private let threshold: CGFloat = 110

    var body: some View {
        GeometryReader { geo in
            MediaCardContent(item: item, isActive: isTop)
                .clipShape(.rect(cornerRadius: 24))
                .shadow(color: .black.opacity(isTop ? 0.25 : 0.1), radius: 12, y: 6)
                .offset(offset)
                .rotationEffect(.degrees(Double(offset.width / 18)), anchor: .bottom)
                .gesture(drag(in: geo.size))
                .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    // Only a still press opens the viewer; once the card is moving it's a swipe.
                    guard offset == .zero, !isFlying else { return }
                    longPressCount += 1
                    onLongPress()
                })
                .allowsHitTesting(isTop && !isFlying)
                .onChange(of: requestedAction) { _, action in
                    if isTop, let action { fling(action, in: geo.size) }
                }
                .onChange(of: isDragging) { _, dragging in
                    // A cancelled drag never reaches onEnded, so settle the card here.
                    guard !dragging, !isFlying, offset != .zero else { return }
                    onDrag(nil, 0)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
                }
        }
        .sensoryFeedback(trigger: isPastThreshold) { _, past in
            hapticsEnabled && past ? .selection : nil
        }
        .sensoryFeedback(trigger: longPressCount) { _, _ in
            hapticsEnabled ? .impact(weight: .light) : nil
        }
        .sensoryFeedback(trigger: flungAction) { _, action in
            guard hapticsEnabled, let action else { return nil }
            return action == .delete ? .impact(weight: .medium) : .success
        }
    }

    private var keepProgress: Double { Double(min(max(offset.width / threshold, 0), 1)) }
    private var deleteProgress: Double { Double(min(max(-offset.width / threshold, 0), 1)) }
    private var favoriteProgress: Double {
        guard abs(offset.height) > abs(offset.width) else { return 0 }
        return Double(min(max(-offset.height / threshold, 0), 1))
    }
    private var isPastThreshold: Bool { keepProgress >= 1 || deleteProgress >= 1 || favoriteProgress >= 1 }

    /// The overlay keeps building past the swipe threshold, so it doesn't top out while the finger is still moving.
    private var dragHint: (SwipeAction?, Double) {
        let reach = Double(threshold) * SwipeFeedback.reachPastThreshold
        if favoriteProgress > 0 { return (.favorite, min(-offset.height / reach, 1)) }
        if keepProgress > 0 { return (.keep, min(offset.width / reach, 1)) }
        if deleteProgress > 0 { return (.delete, min(-offset.width / reach, 1)) }
        return (nil, 0)
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture()
            .updating($isDragging) { _, state, _ in state = true }
            .onChanged { value in
                offset = value.translation
                let (action, progress) = dragHint
                onDrag(action, progress)
            }
            .onEnded { value in
                let moved = value.translation
                let predicted = value.predictedEndTranslation
                let isVertical = abs(moved.height) > abs(moved.width)
                if isVertical && (moved.height < -threshold * 1.3 || predicted.height < -threshold * 3) {
                    fling(.favorite, in: size)
                } else if moved.width > threshold || predicted.width > threshold * 2.5 {
                    fling(.keep, in: size)
                } else if moved.width < -threshold || predicted.width < -threshold * 2.5 {
                    fling(.delete, in: size)
                } else {
                    onDrag(nil, 0)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { offset = .zero }
                }
            }
    }

    private func fling(_ action: SwipeAction, in size: CGSize) {
        guard !isFlying else { return }
        isFlying = true
        flungAction = action
        onFling(action)
        let target = switch action {
        case .keep: CGSize(width: size.width * 1.6, height: offset.height + 40)
        case .delete: CGSize(width: -size.width * 1.6, height: offset.height + 40)
        case .favorite: CGSize(width: offset.width, height: -size.height * 1.4)
        }
        withAnimation(.easeIn(duration: 0.22)) {
            offset = target
        } completion: {
            onDecide(action)
        }
    }
}
