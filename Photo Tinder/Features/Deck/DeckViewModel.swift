//
//  DeckViewModel.swift
//  Photo Tinder
//

import CoreGraphics
import Foundation
import Photos

enum SwipeAction {
    case keep, delete, favorite
}

/// Builds the deck by walking the oldest-first fetch and skipping anything already decided.
@Observable
final class DeckViewModel {
    private struct UndoEntry {
        let item: MediaItem
        let action: SwipeAction
    }

    private static let windowSize = 6
    private static let maxUndo = 50

    @ObservationIgnored private let library: PhotoLibraryService
    @ObservationIgnored private let store: DecisionStore
    @ObservationIgnored private let game: GamificationEngine
    @ObservationIgnored private var cursor = 0

    /// Upcoming cards; `cards[0]` is on top.
    private(set) var cards: [MediaItem] = []
    private(set) var reviewedCount = 0
    private(set) var totalCount = 0
    private(set) var hasLoaded = false
    private var undoStack: [UndoEntry] = []

    /// Set by the buttons; the top card animates off-screen and then calls `perform`.
    var requestedAction: SwipeAction?
    /// Size the card images are rendered at, used for prefetching.
    @ObservationIgnored var cardImageSize: CGSize = .zero

    init(library: PhotoLibraryService, store: DecisionStore, game: GamificationEngine) {
        self.library = library
        self.store = store
        self.game = game
    }

    var canUndo: Bool { !undoStack.isEmpty }
    var isFinished: Bool { hasLoaded && cards.isEmpty }
    var remainingCount: Int { max(0, totalCount - reviewedCount) }
    var progress: Double { totalCount == 0 ? 0 : Double(reviewedCount) / Double(totalCount) }

    func reload() {
        cursor = 0
        cards = []
        totalCount = library.count
        reviewedCount = library.countDecided(in: store.decidedIDs)
        fill()
        hasLoaded = library.isAuthorized
        if isFinished && totalCount > 0 { game.registerLibraryComplete() }
    }

    /// `id` must be the top card's; a stale callback from a card that's no longer on top is ignored.
    func perform(_ action: SwipeAction, on id: String) {
        requestedAction = nil
        guard cards.first?.id == id else { return }
        let item = cards.removeFirst()
        let size = library.asset(withID: item.id).map { AssetSizeEstimator.byteSize(of: $0) } ?? 0

        store.record(item, decision: action == .delete ? .pendingDelete : .kept, byteSize: size)
        if action == .favorite && !item.isFavorite {
            Task { try? await library.setFavorite(true, id: item.id) }
        }

        undoStack.append(UndoEntry(item: item, action: action))
        if undoStack.count > Self.maxUndo { undoStack.removeFirst() }
        reviewedCount += 1
        game.registerSwipe(item: item)

        fill()
        if cards.isEmpty { game.registerLibraryComplete() }
    }

    func undo() {
        guard let entry = undoStack.popLast() else { return }
        store.remove(ids: [entry.item.id])
        if entry.action == .favorite && !entry.item.isFavorite {
            Task { try? await library.setFavorite(false, id: entry.item.id) }
        }
        cards.insert(entry.item, at: 0)
        reviewedCount = max(0, reviewedCount - 1)
        game.undoSwipe()
        library.updateCache(for: cards.map(\.id), targetSize: cardImageSize)
    }

    /// Items that were actually deleted can't come back, so drop their undo history.
    func clearUndoHistory() {
        undoStack.removeAll()
    }

    private func fill() {
        while cards.count < Self.windowSize, let asset = library.asset(at: cursor) {
            cursor += 1
            let id = asset.localIdentifier
            guard !store.decidedIDs.contains(id), !cards.contains(where: { $0.id == id }) else { continue }
            cards.append(MediaItem(asset: asset))
        }
        library.updateCache(for: cards.map(\.id), targetSize: cardImageSize)
    }
}
