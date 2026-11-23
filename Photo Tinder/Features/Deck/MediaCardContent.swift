//
//  MediaCardContent.swift
//  Photo Tinder
//

import AVFoundation
import SwiftUI

/// The picture (or muted looping video) on a card, with a date/size info bar.
struct MediaCardContent: View {
    @Environment(AppModel.self) private var app
    @Environment(\.displayScale) private var displayScale

    let item: MediaItem
    /// Only the top card plays video.
    let isActive: Bool

    @State private var image: UIImage?
    @State private var player: AVQueuePlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isMuted = true
    @State private var byteSize: Int64?

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .blur(radius: 30)
                        .opacity(0.5)
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView().tint(.white)
                }
                if let player, isActive {
                    PlayerLayerView(player: player)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .bottom) { infoBar }
            .overlay(alignment: .topTrailing) { muteButton }
            .task(id: item.id) {
                let size = CGSize(width: geo.size.width * displayScale, height: geo.size.height * displayScale)
                app.deck.cardImageSize = size
                if let asset = app.library.asset(withID: item.id) {
                    byteSize = AssetSizeEstimator.byteSize(of: asset)
                }
                for await loaded in app.library.images(for: item.id, targetSize: size) {
                    image = loaded
                }
            }
            .task(id: isActive) { await updatePlayback() }
            .onChange(of: isMuted) { _, muted in player?.isMuted = muted }
            .onDisappear { player?.pause() }
        }
    }

    private func updatePlayback() async {
        guard item.isVideo else { return }
        guard isActive else { player?.pause(); return }
        if player == nil, let asset = await app.library.videoAsset(for: item.id) {
            let queue = AVQueuePlayer()
            queue.isMuted = isMuted
            looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(asset: asset))
            player = queue
        }
        player?.play()
    }

    @ViewBuilder private var muteButton: some View {
        if item.isVideo && isActive {
            Button {
                isMuted.toggle()
            } label: {
                Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.45), in: .circle)
            }
            .padding(14)
        }
    }

    private var infoBar: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                if let date = item.creationDate {
                    Text(Formatters.fullDate(date)).font(.title3.bold())
                }
                HStack(spacing: 8) {
                    if item.isVideo { Badge(symbol: "video.fill", text: Formatters.duration(item.duration)) }
                    if item.isLivePhoto { Badge(symbol: "livephoto", text: "Live") }
                    if item.isScreenshot { Badge(symbol: "camera.viewfinder", text: "Screenshot") }
                    if let byteSize { Badge(symbol: "internaldrive", text: Formatters.bytes(byteSize)) }
                }
            }
            Spacer()
            if item.isFavorite {
                Image(systemName: "heart.fill").foregroundStyle(.pink).font(.title2)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }
}

private struct Badge: View {
    let symbol: String
    let text: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2), in: .capsule)
    }
}

/// AVPlayerLayer host, so the video has no playback controls (it's a card, not a player).
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        view.playerLayer.player = player
    }

    final class PlayerUIView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
