//
//  GamificationEngine.swift
//  Photo Tinder
//

import Foundation
import SwiftData

struct GameEvent: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let symbol: String
    var celebrate = false
}

/// Streaks, achievements and milestone toasts.
@Observable
final class GamificationEngine {
    @ObservationIgnored private let context: ModelContext
    @ObservationIgnored private var calendar = Calendar.current
    @ObservationIgnored private var queue: [GameEvent] = []
    let stats: UserStats

    private(set) var toast: GameEvent?
    private(set) var confettiTrigger = 0

    init(context: ModelContext) {
        self.context = context
        if let existing = try? context.fetch(FetchDescriptor<UserStats>()).first {
            stats = existing
        } else {
            stats = UserStats()
            context.insert(stats)
            try? context.save()
        }
    }

    // MARK: Read

    /// The streak is only alive if the user swiped today or yesterday.
    func activeStreak(now: Date = .now) -> Int {
        guard let last = stats.lastActiveDay else { return 0 }
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
        return last == today || last == yesterday ? stats.currentStreak : 0
    }

    func isUnlocked(_ achievement: Achievement) -> Bool {
        stats.unlockedAchievements.contains(achievement.rawValue)
    }

    // MARK: Write

    func registerSwipe(item: MediaItem, now: Date = .now) {
        let today = calendar.startOfDay(for: now)
        if stats.lastActiveDay != today {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: today)
            stats.currentStreak = stats.lastActiveDay == yesterday ? stats.currentStreak + 1 : 1
            stats.longestStreak = max(stats.longestStreak, stats.currentStreak)
            stats.lastActiveDay = today
            if stats.currentStreak > 1 {
                announce(GameEvent(title: "\(stats.currentStreak)-day streak!", subtitle: "Keep it going", symbol: "flame.fill"))
            }
        }

        stats.totalSwipes += 1

        if let year = item.year, !stats.yearsVisited.contains(year) {
            if !stats.yearsVisited.isEmpty {
                announce(GameEvent(title: "Welcome to \(String(year))", subtitle: "You've reached a new year", symbol: "calendar"))
            }
            stats.yearsVisited.append(year)
        }

        evaluateAchievements()
        save()
    }

    func undoSwipe() {
        stats.totalSwipes = max(0, stats.totalSwipes - 1)
        save()
    }

    func registerDeletion(count: Int, bytes: Int64) {
        stats.totalDeleted += count
        stats.bytesFreed += bytes
        announce(GameEvent(title: "\(Formatters.bytes(bytes)) freed", subtitle: "\(count) items moved to Recently Deleted",
                           symbol: "sparkles", celebrate: true))
        evaluateAchievements()
        save()
    }

    func registerLibraryComplete() {
        guard !stats.libraryCompleted else { return }
        stats.libraryCompleted = true
        evaluateAchievements()
        save()
    }

    func dismissToast() {
        toast = queue.isEmpty ? nil : queue.removeFirst()
        if toast?.celebrate == true { confettiTrigger += 1 }
    }

    // MARK: Private

    private func evaluateAchievements() {
        for achievement in Achievement.allCases where !isUnlocked(achievement) && achievement.isEarned(by: stats) {
            stats.unlockedAchievements.append(achievement.rawValue)
            announce(GameEvent(title: "Achievement: \(achievement.title)", subtitle: achievement.detail,
                               symbol: achievement.symbol, celebrate: true))
        }
    }

    private func announce(_ event: GameEvent) {
        if toast == nil {
            toast = event
            if event.celebrate { confettiTrigger += 1 }
        } else {
            queue.append(event)
        }
    }

    private func save() {
        try? context.save()
    }
}
