//
//  UserStats.swift
//  Photo Tinder
//

import Foundation
import SwiftData

/// Singleton row holding progress and gamification state.
@Model
final class UserStats {
    var totalSwipes: Int = 0
    var totalDeleted: Int = 0
    var bytesFreed: Int64 = 0
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastActiveDay: Date?
    var yearsVisited: [Int] = []
    var unlockedAchievements: [String] = []
    var libraryCompleted: Bool = false

    init() {}
}
