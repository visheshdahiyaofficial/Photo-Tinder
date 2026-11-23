//
//  FullScreenMediaView.swift
//  Photo Tinder
//

import AVKit
import SwiftUI

/// Full-screen look at a photo or video, opened by pressing and holding a card.
/// Photos: pinch or double-tap to zoom, drag to pan, swipe down to close.
struct FullScreenMediaView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale

    let item: MediaItem

    @State private var image: UIImage?
    @State private var player: AVPlayer?
    @State private var byteSize: Int64?
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissOffset: CGFloat = 0

    private let maxScale: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black
                    .opacity(1 - min(abs(dismissOffset) / 500, 0.6))
                    .ignoresSafeArea()
                content(in: geo.size)
                    .offset(y: dismissOffset)
            }
            .overlay(alignment: .top) { topBar.opacity(dismissOffset == 0 ? 1 : 0) }
            .task(id: item.id) { await load(screen: geo.size) }
        }
        .statusBarHidden()
        .onDisappear { player?.pause() }
    }

    @ViewBuilder private func content(in size: CGSize) -> some View {
        if item.isVideo {
            if let player {
                VideoPlayer(player: player)
            } else {
                ProgressView().tint(.white)
            }
        } else if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
                .frame(width: size.width, height: size.height)
                .contentShape(.rect)
                .gesture(zoom.simultaneously(with: pan))
                .onTapGesture(count: 2) { toggleZoom() }
        } else {
            ProgressView().tint(.white)
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                if let date = item.creationDate {
                    Text(Formatters.fullDate(date)).font(.headline)
                }
                if let byteSize {
                    Text(Formatters.bytes(byteSize)).font(.caption).opacity(0.8)
                }
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .frame(width: 40, height: 40)
                    .background(.white.opacity(0.2), in: .circle)
            }
            .accessibilityLabel("Close")
        }
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(LinearGradient(colors: [.black.opacity(0.6), .clear], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea())
    }

    // MARK: Gestures

    private var zoom: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(max(lastScale * value.magnification, 1), maxScale)
            }
            .onEnded { _ in
                if scale <= 1.01 {
                    withAnimation(.spring) { resetZoom() }
                } else {
                    lastScale = scale
                }
            }
    }

    /// Pans when zoomed in; otherwise a vertical drag pulls the photo down to close.
    private var pan: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height)
                } else {
                    dismissOffset = value.translation.height
                }
            }
            .onEnded { value in
                if scale > 1 {
                    lastOffset = offset
                } else if abs(value.translation.height) > 120 || abs(value.predictedEndTranslation.height) > 400 {
                    dismiss()
                } else {
                    withAnimation(.spring) { dismissOffset = 0 }
                }
            }
    }

    private func toggleZoom() {
        withAnimation(.spring) {
            if scale > 1 {
                resetZoom()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }

    // MARK: Loading

    private func load(screen: CGSize) async {
        if let asset = app.library.asset(withID: item.id) {
            byteSize = AssetSizeEstimator.byteSize(of: asset)
        }
        if item.isVideo {
            guard let asset = await app.library.videoAsset(for: item.id) else { return }
            let newPlayer = AVPlayer(playerItem: AVPlayerItem(asset: asset))
            player = newPlayer
            newPlayer.play()
        } else {
            // Loaded well above screen resolution so zooming in stays sharp.
            let target = CGSize(width: screen.width * displayScale * 3, height: screen.height * displayScale * 3)
            for await loaded in app.library.images(for: item.id, targetSize: target) {
                image = loaded
            }
        }
    }
}
