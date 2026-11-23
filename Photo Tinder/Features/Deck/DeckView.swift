//
//  DeckView.swift
//  Photo Tinder
//

import SwiftData
import SwiftUI

struct DeckView: View {
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<SwipeRecord> { $0.decisionRaw == "pendingDelete" }) private var pending: [SwipeRecord]
    @State private var confirmRestart = false
    @State private var feedback = SwipeFeedback()
    @State private var viewing: MediaItem?

    private var deck: DeckViewModel { app.deck }

    var body: some View {
        VStack(spacing: 16) {
            header
            if app.library.isLimited { limitedBanner }
            cardStack
            if !deck.cards.isEmpty { controls }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .overlay { SwipeFeedbackOverlay(feedback: feedback) }
        .fullScreenCover(item: $viewing) { item in
            FullScreenMediaView(item: item)
                .environment(app)
        }
        .restartReviewConfirmation(isPresented: $confirmRestart)
    }

    // MARK: Header

    private var header: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(deck.cards.first?.creationDate.map { Formatters.monthYear($0) } ?? "Photo Tinder")
                        .font(.title2.bold())
                        .contentTransition(.numericText())
                    Text("\(deck.remainingCount.formatted()) left · \(Int(deck.progress * 100))% reviewed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !pending.isEmpty {
                    Button {
                        app.selectedTab = .pile
                    } label: {
                        Label("\(pending.count)", systemImage: "trash.fill")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.red.opacity(0.15), in: .capsule)
                            .foregroundStyle(.red)
                    }
                }
            }
            ProgressView(value: deck.progress)
                .tint(.pink)
        }
        .padding(.top, 8)
    }

    private var limitedBanner: some View {
        HStack {
            Image(systemName: "photo.badge.exclamationmark")
            Text("You've only shared some photos.")
                .font(.footnote)
            Spacer()
            Button("Add more") { app.library.presentLimitedLibraryPicker() }
                .font(.footnote.bold())
        }
        .padding(12)
        .background(.yellow.opacity(0.15), in: .rect(cornerRadius: 12))
    }

    // MARK: Cards

    @ViewBuilder private var cardStack: some View {
        if deck.cards.isEmpty {
            finishedState
                .frame(maxHeight: .infinity)
        } else {
            ZStack {
                ForEach(Array(deck.cards.prefix(3).enumerated()), id: \.element.id) { index, item in
                    // While the full-screen viewer is open the top card stops playing and ignores touches.
                    SwipeCardView(item: item,
                                  isTop: index == 0 && viewing == nil,
                                  requestedAction: index == 0 ? deck.requestedAction : nil,
                                  onDrag: { feedback.drag($0, progress: $1) },
                                  onFling: { feedback.commit($0) },
                                  onLongPress: { viewing = item }) { action in
                        deck.perform(action, on: item.id)
                    }
                    .scaleEffect(1 - CGFloat(index) * 0.05, anchor: .bottom)
                    .offset(y: CGFloat(index) * 14)
                    .zIndex(Double(-index))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: deck.cards.first?.id)
            .padding(.bottom, 28)
            .frame(maxHeight: .infinity)
        }
    }

    @ViewBuilder private var finishedState: some View {
        if deck.totalCount == 0 {
            ContentUnavailableView("No photos found", systemImage: "photo.on.rectangle.angled",
                                   description: Text("There's nothing in your library to review yet."))
        } else {
            ContentUnavailableView {
                Label("All caught up!", systemImage: "checkmark.seal.fill")
            } description: {
                Text(pending.isEmpty
                     ? "You've reviewed your whole library. New photos will show up here."
                     : "You've reviewed everything. \(pending.count) items are waiting in your delete pile.")
            } actions: {
                if !pending.isEmpty {
                    Button("Review delete pile") { app.selectedTab = .pile }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                }
                Button("Start over from oldest photo", systemImage: "arrow.counterclockwise") {
                    confirmRestart = true
                }
                .buttonStyle(.bordered)
                .tint(.pink)
            }
        }
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 24) {
            CircleButton(symbol: "arrow.uturn.backward", color: .blue) {
                withAnimation(.spring) { deck.undo() }
            }
            .disabled(!deck.canUndo)
            .opacity(deck.canUndo ? 1 : 0.4)
            CircleButton(symbol: "xmark", color: .red) { deck.requestedAction = .delete }
            CircleButton(symbol: "star.fill", color: .yellow) { deck.requestedAction = .favorite }
            CircleButton(symbol: "heart.fill", color: .green) { deck.requestedAction = .keep }
        }
    }
}

/// The four action buttons share one size and style.
private struct CircleButton: View {
    let symbol: String
    let color: Color
    let action: () -> Void

    private let size: CGFloat = 62

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                // White in light mode, raised gray in dark mode, so the circle stays visible against the page.
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: .circle)
                .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
    }
}

