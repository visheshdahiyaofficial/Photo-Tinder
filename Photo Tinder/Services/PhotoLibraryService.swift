//
//  PhotoLibraryService.swift
//  Photo Tinder
//

import AVFoundation
import Photos
import PhotosUI
import UIKit

/// Wraps PhotoKit: authorization, the oldest-first fetch, image/video loading,
/// deletion and favoriting, plus library change notifications.
@Observable
final class PhotoLibraryService: NSObject, PHPhotoLibraryChangeObserver {
    static let includeVideosKey = "includeVideos"
    static let includeScreenshotsKey = "includeScreenshots"

    private(set) var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    private var fetchResult: PHFetchResult<PHAsset>?
    private var isObserving = false
    @ObservationIgnored private let imageManager = PHCachingImageManager()
    @ObservationIgnored private var cachedIDs: [String] = []
    @ObservationIgnored private var cacheTargetSize: CGSize = .zero

    /// Called when assets are inserted or removed (not for metadata-only changes such as favoriting).
    @ObservationIgnored var onStructureChange: (() -> Void)?

    var isAuthorized: Bool { authorization == .authorized || authorization == .limited }
    var isLimited: Bool { authorization == .limited }
    var count: Int { fetchResult?.count ?? 0 }

    override init() {
        super.init()
        UserDefaults.standard.register(defaults: [Self.includeVideosKey: true, Self.includeScreenshotsKey: true])
        if isAuthorized { startObserving(); refetch() }
    }

    // MARK: Authorization

    func requestAuthorization() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if isAuthorized { startObserving(); refetch() }
    }

    /// Re-reads the status, e.g. after returning from the Settings app.
    func refreshAuthorization() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status != authorization else { return }
        authorization = status
        if isAuthorized { startObserving(); refetch() }
        onStructureChange?()
    }

    func presentLimitedLibraryPicker() {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }
            .first
        guard var top = root else { return }
        while let presented = top.presentedViewController { top = presented }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }

    private func startObserving() {
        guard !isObserving else { return }
        PHPhotoLibrary.shared().register(self)
        isObserving = true
    }

    // MARK: Fetching

    /// All photos (and optionally videos), oldest first. PHFetchResult is lazy, so this is cheap even for huge libraries.
    func refetch() {
        guard isAuthorized else { fetchResult = nil; return }
        let defaults = UserDefaults.standard
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        var predicates: [NSPredicate] = []
        let images = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        if defaults.bool(forKey: Self.includeVideosKey) {
            let videos = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [images, videos]))
        } else {
            predicates.append(images)
        }
        if !defaults.bool(forKey: Self.includeScreenshotsKey) {
            predicates.append(NSPredicate(format: "(mediaSubtypes & %d) == 0", PHAssetMediaSubtype.photoScreenshot.rawValue))
        }
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        fetchResult = PHAsset.fetchAssets(with: options)
    }

    func asset(at index: Int) -> PHAsset? {
        guard let fetchResult, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index)
    }

    func asset(withID id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    /// How many assets in the current fetch already have a decision.
    func countDecided(in decided: Set<String>) -> Int {
        guard let fetchResult, !decided.isEmpty else { return 0 }
        var total = 0
        fetchResult.enumerateObjects { asset, _, _ in
            if decided.contains(asset.localIdentifier) { total += 1 }
        }
        return total
    }

    // MARK: Loading media

    /// Yields a fast degraded image first, then the full-quality one (downloading from iCloud if needed).
    func images(for id: String, targetSize: CGSize, contentMode: PHImageContentMode = .aspectFit) -> AsyncStream<UIImage> {
        AsyncStream { continuation in
            guard let asset = asset(withID: id) else { continuation.finish(); return }
            let options = PHImageRequestOptions()
            options.deliveryMode = .opportunistic
            options.isNetworkAccessAllowed = true
            options.resizeMode = .fast
            let requestID = imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, options: options) { @Sendable image, info in
                if let image { continuation.yield(image) }
                let degraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let cancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                if !degraded || cancelled || info?[PHImageErrorKey] != nil { continuation.finish() }
            }
            let manager = imageManager
            continuation.onTermination = { @Sendable _ in manager.cancelImageRequest(requestID) }
        }
    }

    func videoAsset(for id: String) async -> AVAsset? {
        guard let asset = asset(withID: id) else { return nil }
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        return await withCheckedContinuation { continuation in
            imageManager.requestAVAsset(forVideo: asset, options: options) { @Sendable avAsset, _, _ in
                continuation.resume(returning: avAsset)
            }
        }
    }

    /// Keeps the next few cards warm in PhotoKit's cache so swipes feel instant.
    func updateCache(for ids: [String], targetSize: CGSize) {
        guard targetSize != .zero else { return }
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        if targetSize != cacheTargetSize {
            imageManager.stopCachingImagesForAllAssets()
            cachedIDs = []
            cacheTargetSize = targetSize
        }
        let removed = cachedIDs.filter { !ids.contains($0) }
        let added = ids.filter { !cachedIDs.contains($0) }
        if !removed.isEmpty {
            imageManager.stopCachingImages(for: assets(for: removed), targetSize: targetSize, contentMode: .aspectFit, options: options)
        }
        if !added.isEmpty {
            imageManager.startCachingImages(for: assets(for: added), targetSize: targetSize, contentMode: .aspectFit, options: options)
        }
        cachedIDs = ids
    }

    private func assets(for ids: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        return result.objects(at: IndexSet(integersIn: 0..<result.count))
    }

    // MARK: Changes

    /// Deletes in a single change request, so iOS shows one confirmation for the whole batch.
    /// Throws `PHPhotosError.userCancelled` if the user taps "Don't Allow".
    func delete(ids: [String]) async throws {
        guard !ids.isEmpty, PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil).count > 0 else { return }
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    func setFavorite(_ isFavorite: Bool, id: String) async throws {
        try await PHPhotoLibrary.shared().performChanges { @Sendable in
            guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else { return }
            PHAssetChangeRequest(for: asset).isFavorite = isFavorite
        }
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        Task { @MainActor in
            guard let current = self.fetchResult, let details = changeInstance.changeDetails(for: current) else { return }
            self.fetchResult = details.fetchResultAfterChanges
            let structural = !details.hasIncrementalChanges
                || !(details.insertedIndexes?.isEmpty ?? true)
                || !(details.removedIndexes?.isEmpty ?? true)
            if structural { self.onStructureChange?() }
        }
    }
}
