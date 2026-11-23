//
//  MediaItem.swift
//  Photo Tinder
//

import Foundation
import Photos

/// Lightweight snapshot of a PHAsset for the UI.
struct MediaItem: Identifiable, Hashable {
    let id: String
    let creationDate: Date?
    let isVideo: Bool
    let duration: TimeInterval
    let isFavorite: Bool
    let isLivePhoto: Bool
    let isScreenshot: Bool

    init(asset: PHAsset) {
        id = asset.localIdentifier
        creationDate = asset.creationDate
        isVideo = asset.mediaType == .video
        duration = asset.duration
        isFavorite = asset.isFavorite
        isLivePhoto = asset.mediaSubtypes.contains(.photoLive)
        isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
    }

    var year: Int? {
        creationDate.map { Calendar.current.component(.year, from: $0) }
    }
}
