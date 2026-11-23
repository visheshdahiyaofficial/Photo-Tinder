//
//  Achievement.swift
//  Photo Tinder
//

import Foundation

enum Achievement: String, CaseIterable, Identifiable {
    case firstSwipe, swipes100, swipes1000, swipes10000
    case streak7, streak30
    case freed1GB, freed10GB
    case timeTraveler, libraryComplete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstSwipe: "First Swipe"
        case .swipes100: "Warming Up"
        case .swipes1000: "Swipe Machine"
        case .swipes10000: "Legend"
        case .streak7: "On Fire"
        case .streak30: "Unstoppable"
        case .freed1GB: "Breathing Room"
        case .freed10GB: "Storage Hero"
        case .timeTraveler: "Time Traveler"
        case .libraryComplete: "Clean Slate"
        }
    }

    var detail: String {
        switch self {
        case .firstSwipe: "Make your first swipe"
        case .swipes100: "Swipe 100 items"
        case .swipes1000: "Swipe 1,000 items"
        case .swipes10000: "Swipe 10,000 items"
        case .streak7: "7-day streak"
        case .streak30: "30-day streak"
        case .freed1GB: "Free 1 GB"
        case .freed10GB: "Free 10 GB"
        case .timeTraveler: "Swipe through 5 different years"
        case .libraryComplete: "Review your whole library"
        }
    }

    var symbol: String {
        switch self {
        case .firstSwipe: "hand.draw.fill"
        case .swipes100: "flame"
        case .swipes1000: "bolt.fill"
        case .swipes10000: "crown.fill"
        case .streak7: "flame.fill"
        case .streak30: "sparkles"
        case .freed1GB: "externaldrive.fill"
        case .freed10GB: "externaldrive.fill.badge.checkmark"
        case .timeTraveler: "clock.arrow.circlepath"
        case .libraryComplete: "checkmark.seal.fill"
        }
    }

    func isEarned(by stats: UserStats) -> Bool {
        switch self {
        case .firstSwipe: stats.totalSwipes >= 1
        case .swipes100: stats.totalSwipes >= 100
        case .swipes1000: stats.totalSwipes >= 1_000
        case .swipes10000: stats.totalSwipes >= 10_000
        case .streak7: stats.longestStreak >= 7
        case .streak30: stats.longestStreak >= 30
        case .freed1GB: stats.bytesFreed >= 1_000_000_000
        case .freed10GB: stats.bytesFreed >= 10_000_000_000
        case .timeTraveler: stats.yearsVisited.count >= 5
        case .libraryComplete: stats.libraryCompleted
        }
    }
}
