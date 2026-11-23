//
//  DeletePileView.swift
//  Photo Tinder
//

import Photos
import SwiftData
import SwiftUI

/// Everything swiped left, waiting for one confirmed batch delete.
struct DeletePileView: View {
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<SwipeRecord> { $0.decisionRaw == "pendingDelete" },
           sort: \SwipeRecord.decidedAt, order: .reverse)
    private var pending: [SwipeRecord]
    @State private var confirmClear = false

    private var totalBytes: Int64 { pending.reduce(0) { $0 + $1.byteSize } }

    var body: some View {
        NavigationStack {
            Group {
                if pending.isEmpty {
                    ContentUnavailableView("Your pile is empty", systemImage: "trash.slash",
                                           description: Text("Photos you swipe left land here. Nothing is deleted until you confirm."))
                } else {
                    grid
                }
            }
            .navigationTitle("To Delete")
            .toolbar {
                if !pending.isEmpty {
                    Menu {
                        Button("Keep all and return to deck", systemImage: "arrow.uturn.backward") { confirmClear = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .confirmationDialog("Put all \(pending.count) items back in the deck?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Return to deck") { app.clearPile() }
            }
            .alert("Couldn't delete", isPresented: Binding(get: { app.errorMessage != nil }, set: { if !$0 { app.errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(app.errorMessage ?? "")
            }
        }
    }

    private var grid: some View {
        ScrollView {
            Text("Tap \(Image(systemName: "arrow.uturn.backward.circle.fill")) to keep a photo instead. Deleted items stay in Recently Deleted for 30 days.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 105), spacing: 4)], spacing: 4) {
                ForEach(pending) { record in
                    AssetThumbnail(id: record.assetID)
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(alignment: .bottomLeading) {
                            if record.isVideo {
                                Image(systemName: "video.fill")
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .padding(6)
                                    .shadow(radius: 2)
                            }
                        }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                withAnimation { app.rescue(record.assetID) }
                            } label: {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                    .font(.title2)
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, .green)
                                    .shadow(radius: 2)
                            }
                            .padding(4)
                        }
                        .contextMenu {
                            Button("Keep instead", systemImage: "heart") { app.rescue(record.assetID) }
                        }
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 90)
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                Task { await app.confirmDeletion() }
            } label: {
                HStack {
                    if app.isDeleting { ProgressView().tint(.white) }
                    Text("Delete \(pending.count) items · \(Formatters.bytes(totalBytes))")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(app.isDeleting)
            .padding()
            .background(.bar)
        }
    }
}

struct AssetThumbnail: View {
    @Environment(AppModel.self) private var app
    @Environment(\.displayScale) private var displayScale
    let id: String
    @State private var image: UIImage?

    var body: some View {
        Color.secondary.opacity(0.15)
            .overlay {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .task(id: id) {
                let side = 120 * displayScale
                for await loaded in app.library.images(for: id, targetSize: CGSize(width: side, height: side), contentMode: .aspectFill) {
                    image = loaded
                }
            }
    }
}
