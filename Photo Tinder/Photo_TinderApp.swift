//
//  Photo_TinderApp.swift
//  Photo Tinder
//
//  Created by Vishesh on 02/11/26.
//

import SwiftData
import SwiftUI

@main
struct Photo_TinderApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [SwipeRecord.self, UserStats.self])
    }
}
