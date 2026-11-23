//
//  AppModel.swift
//  Photo Tinder
//

import Foundation
import Photos
import SwiftData

enum AppTab: Hashable {
    case swipe, pile, stats, settings
}

/// Owns the services and the app-wide actions that touch more than one of them.
@Observable
final class AppModel {
    let library: PhotoLibraryService
    let store: DecisionStore
    let game: GamificationEngine
    let deck: DeckViewModel

    var selectedTab: AppTab = .swipe
    var isDeleting = false
    var errorMessage: String?

    init(context: ModelContext) {
        library = PhotoLibraryService()
        store = DecisionStore(context: context)
        game = GamificationEngine(context: context)
        deck = DeckViewModel(library: library, store: store, game: game)
        library.onStructureChange = { [weak self] in self?.deck.reload() }
        deck.reload()
    }

    func requestAccess() async {
        await library.requestAuthorization()
        deck.reload()
    }

    /// Re-runs the fetch after a Settings filter changed.
    func applyFilters() {
        library.refetch()
        deck.reload()
    }

    // MARK: Delete pile

    /// Deletes everything in the pile with one system prompt.
    func confirmDeletion() async {
        let pending = store.records(with: .pendingDelete)
        guard !pending.isEmpty else { return }
        let ids = pending.map(\.assetID)
        let bytes = pending.reduce(Int64(0)) { $0 + $1.byteSize }

        isDeleting = true
        defer { isDeleting = false }
        do {
            try await library.delete(ids: ids)
            store.setDecision(.deleted, for: ids)
            deck.clearUndoHistory()
            game.registerDeletion(count: ids.count, bytes: bytes)
        } catch let error as PHPhotosError where error.code == .userCancelled {
            // User tapped "Don't Allow" – leave the pile as it is.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Moves an item from the pile to "kept".
    func rescue(_ id: String) {
        store.setDecision(.kept, for: [id])
    }

    /// Empties the pile without deleting; those items go back into the deck.
    func clearPile() {
        store.removeAll(with: .pendingDelete)
        deck.reload()
    }

    /// Starts the review over from the oldest photo. Kept items and the delete pile both go back
    /// into the deck; lifetime stats (swipes, space freed, streaks, achievements) are left alone.
    func restartReview() {
        store.removeAll()
        game.stats.libraryCompleted = false
        deck.clearUndoHistory()
        deck.reload()
        selectedTab = .swipe
    }
}
