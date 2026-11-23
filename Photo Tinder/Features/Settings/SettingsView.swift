//
//  SettingsView.swift
//  Photo Tinder
//

import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(PhotoLibraryService.includeVideosKey) private var includeVideos = true
    @AppStorage(PhotoLibraryService.includeScreenshotsKey) private var includeScreenshots = true
    @AppStorage("hapticsEnabled") private var hapticsEnabled = true
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @AppStorage("hasOnboarded") private var hasOnboarded = true
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(Appearance.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("System matches your iPhone's light or dark setting.")
                }

                Section {
                    Toggle("Include videos", isOn: $includeVideos)
                    Toggle("Include screenshots", isOn: $includeScreenshots)
                    Toggle("Haptics", isOn: $hapticsEnabled)
                } header: {
                    Text("Deck")
                } footer: {
                    Text("The deck always starts from your oldest photo you haven't swiped yet.")
                }
                .onChange(of: includeVideos) { app.applyFilters() }
                .onChange(of: includeScreenshots) { app.applyFilters() }

                if app.library.isLimited {
                    Section("Library access") {
                        Button("Choose more photos") { app.library.presentLimitedLibraryPicker() }
                        Button("Allow full access in Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                        }
                    }
                }

                Section {
                    Button("Start over from oldest photo", systemImage: "arrow.counterclockwise", role: .destructive) {
                        confirmReset = true
                    }
                    Button("Show intro again") { hasOnboarded = false }
                } header: {
                    Text("Progress")
                } footer: {
                    Text("Starting over lets you review your whole library again from the oldest photo. Deleted items stay in Photos › Recently Deleted for 30 days.")
                }
            }
            .navigationTitle("Settings")
            .restartReviewConfirmation(isPresented: $confirmReset)
        }
    }
}
