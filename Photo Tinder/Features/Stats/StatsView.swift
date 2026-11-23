//
//  StatsView.swift
//  Photo Tinder
//

import SwiftUI

struct StatsView: View {
    @Environment(AppModel.self) private var app

    private var stats: UserStats { app.game.stats }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    progressCard
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(title: "Kept", value: app.store.count(of: .kept).formatted(), symbol: "heart.fill", color: .green)
                        StatTile(title: "Deleted", value: stats.totalDeleted.formatted(), symbol: "trash.fill", color: .red)
                        StatTile(title: "In pile", value: app.store.count(of: .pendingDelete).formatted(), symbol: "tray.full.fill", color: .orange)
                        StatTile(title: "Space freed", value: Formatters.bytes(stats.bytesFreed), symbol: "internaldrive.fill", color: .blue)
                        StatTile(title: "Streak", value: days(app.game.activeStreak()), symbol: "flame.fill", color: .orange)
                        StatTile(title: "Best streak", value: days(stats.longestStreak), symbol: "trophy.fill", color: .yellow)
                        StatTile(title: "Total swipes", value: stats.totalSwipes.formatted(), symbol: "hand.draw.fill", color: .pink)                    }
                    achievements
                }
                .padding()
            }
            .navigationTitle("Stats")
        }
    }

    private func days(_ count: Int) -> String {
        count == 1 ? "1 day" : "\(count) days"
    }

    private var progressCard: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 12)
                Circle()
                    .trim(from: 0, to: app.deck.progress)
                    .stroke(.pink, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(app.deck.progress * 100))%")
                    .font(.title2.bold())
            }
            .frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 6) {
                Text("Library reviewed").font(.headline)
                Text("\(app.deck.reviewedCount.formatted()) of \(app.deck.totalCount.formatted())")
                    .foregroundStyle(.secondary)
                if let date = app.deck.cards.first?.creationDate {
                    Text("You're in \(Formatters.monthYear(date))")
                        .font(.subheadline.bold())
                        .foregroundStyle(.pink)
                }
            }
            Spacer()
        }
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 20))
    }

    private var achievements: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Achievements").font(.title3.bold())
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                ForEach(Achievement.allCases) { achievement in
                    let unlocked = app.game.isUnlocked(achievement)
                    VStack(spacing: 6) {
                        Image(systemName: achievement.symbol)
                            .font(.title)
                            .foregroundStyle(unlocked ? .pink : .secondary)
                            .frame(height: 36)
                        Text(achievement.title).font(.caption.bold())
                        Text(achievement.detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 110)
                    .padding(8)
                    .background(.background.secondary, in: .rect(cornerRadius: 16))
                    .opacity(unlocked ? 1 : 0.45)
                }
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(value).font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}
