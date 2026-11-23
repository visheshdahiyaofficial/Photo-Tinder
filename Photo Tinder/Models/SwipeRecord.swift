//
//  SwipeRecord.swift
//  Photo Tinder
//

import Foundation
import SwiftData

enum SwipeDecision: String, Codable {
    /// Swiped right (or up). Never shown again unless the user resets.
    case kept
    /// Swiped left. Sitting in the delete pile until the user confirms.
    case pendingDelete
    /// Confirmed and removed from the photo library.
    case deleted
}

/// One user decision about one asset. Assets with no record are "never swiped".
@Model
final class SwipeRecord {
    @Attribute(.unique) var assetID: String
    var decisionRaw: String
    var decidedAt: Date
    var isVideo: Bool
    var byteSize: Int64
    var assetCreationDate: Date?

    var decision: SwipeDecision {
        get { SwipeDecision(rawValue: decisionRaw) ?? .kept }
        set { decisionRaw = newValue.rawValue }
    }

    init(assetID: String, decision: SwipeDecision, isVideo: Bool, byteSize: Int64, assetCreationDate: Date?) {
        self.assetID = assetID
        self.decisionRaw = decision.rawValue
        self.decidedAt = .now
        self.isVideo = isVideo
        self.byteSize = byteSize
        self.assetCreationDate = assetCreationDate
    }
}
