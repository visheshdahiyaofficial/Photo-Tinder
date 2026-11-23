//
//  AssetSizeEstimator.swift
//  Photo Tinder
//

import Photos

enum AssetSizeEstimator {
    /// On-disk size of all resources for an asset. PhotoKit has no public size API, so this reads
    /// `fileSize` from PHAssetResource and falls back to a rough estimate when it isn't available.
    static func byteSize(of asset: PHAsset) -> Int64 {
        let total = PHAssetResource.assetResources(for: asset).reduce(Int64(0)) { sum, resource in
            sum + ((resource.value(forKey: "fileSize") as? NSNumber)?.int64Value ?? 0)
        }
        if total > 0 { return total }
        if asset.mediaType == .video {
            return Int64(asset.duration * 1_500_000)
        }
        return Int64(asset.pixelWidth * asset.pixelHeight) / 4
    }
}
