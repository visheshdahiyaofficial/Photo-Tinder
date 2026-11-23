//
//  MainTabView.swift
//  Photo Tinder
//

import SwiftData
import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @Query(filter: #Predicate<SwipeRecord> { $0.decisionRaw == "pendingDelete" }) private var pending: [SwipeRecord]

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedTab) {
            Tab("Swipe", systemImage: "rectangle.stack.fill", value: AppTab.swipe) {
                DeckView()
            }
            Tab("Pile", systemImage: "trash", value: AppTab.pile) {
                DeletePileView()
            }
            .badge(pending.count)
            Tab("Stats", systemImage: "chart.bar.fill", value: AppTab.stats) {
                StatsView()
            }
            Tab("Settings", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tint(.pink)
        .overlay(alignment: .top) {
            if let toast = app.game.toast {
                ToastView(event: toast)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { app.game.dismissToast() }
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(2.5))
                        app.game.dismissToast()
                    }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: app.game.toast?.id)
        .overlay {
            ConfettiView(trigger: app.game.confettiTrigger)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}
