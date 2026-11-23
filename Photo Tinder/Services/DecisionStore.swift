//
//  DecisionStore.swift
//  Photo Tinder
//

import Foundation
import SwiftData

/// Persists swipe decisions and keeps an in-memory set of every decided asset ID for fast deck building.
@Observable
final class DecisionStore {
    @ObservationIgnored private let context: ModelContext
    private(set) var decidedIDs: Set<String> = []

    init(context: ModelContext) {
        self.context = context
        let all = (try? context.fetch(FetchDescriptor<SwipeRecord>())) ?? []
        decidedIDs = Set(all.map(\.assetID))
    }

    func record(_ item: MediaItem, decision: SwipeDecision, byteSize: Int64) {
        if let existing = record(for: item.id) {
            existing.decision = decision
            existing.decidedAt = .now
            existing.byteSize = byteSize
        } else {
            context.insert(SwipeRecord(assetID: item.id, decision: decision, isVideo: item.isVideo,
                                       byteSize: byteSize, assetCreationDate: item.creationDate))
        }
        decidedIDs.insert(item.id)
        save()
    }

    func record(for id: String) -> SwipeRecord? {
        var descriptor = FetchDescriptor<SwipeRecord>(predicate: #Predicate { $0.assetID == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func records(with decision: SwipeDecision) -> [SwipeRecord] {
        let raw = decision.rawValue
        return (try? context.fetch(FetchDescriptor<SwipeRecord>(predicate: #Predicate { $0.decisionRaw == raw }))) ?? []
    }

    func count(of decision: SwipeDecision) -> Int {
        let raw = decision.rawValue
        return (try? context.fetchCount(FetchDescriptor<SwipeRecord>(predicate: #Predicate { $0.decisionRaw == raw }))) ?? 0
    }

    func setDecision(_ decision: SwipeDecision, for ids: [String]) {
        for record in fetch(ids: ids) { record.decision = decision }
        save()
    }

    /// Forgets decisions entirely, so these assets return to the deck as "never swiped".
    func remove(ids: [String]) {
        for record in fetch(ids: ids) { context.delete(record) }
        decidedIDs.subtract(ids)
        save()
    }

    func removeAll(with decision: SwipeDecision) {
        remove(ids: records(with: decision).map(\.assetID))
    }

    /// Forgets every decision, so the whole library counts as "never swiped" again.
    func removeAll() {
        try? context.delete(model: SwipeRecord.self)
        decidedIDs = []
        save()
    }

    private func fetch(ids: [String]) -> [SwipeRecord] {
        (try? context.fetch(FetchDescriptor<SwipeRecord>(predicate: #Predicate { ids.contains($0.assetID) }))) ?? []
    }

    private func save() {
        try? context.save()
    }
}
