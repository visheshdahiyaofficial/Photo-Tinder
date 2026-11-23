//
//  RootView.swift
//  Photo Tinder
//

import SwiftData
import SwiftUI

/// Routes between onboarding, the permission screen and the main tabs.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @State private var app: AppModel?

    var body: some View {
        Group {
            if !hasOnboarded {
                OnboardingView { hasOnboarded = true }
            } else if let app {
                Group {
                    if app.library.isAuthorized {
                        MainTabView()
                    } else {
                        PermissionView()
                    }
                }
                .environment(app)
            } else {
                ProgressView()
            }
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            if app == nil { app = AppModel(context: context) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { app?.library.refreshAuthorization() }
        }
    }
}
