//
//  PermissionView.swift
//  Photo Tinder
//

import Photos
import SwiftUI

struct PermissionView: View {
    @Environment(AppModel.self) private var app

    private var isDenied: Bool { app.library.authorization == .denied || app.library.authorization == .restricted }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 80))
                .foregroundStyle(.pink.gradient)
            Text(isDenied ? "Photo access is off" : "Let's see your photos")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)
            Text(isDenied
                 ? "Photo Tinder can't show your library without access. Turn it on in Settings › Photo Tinder › Photos."
                 : "Photo Tinder needs access to your library to show your photos. Everything stays on your device.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                if isDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                } else {
                    Task { await app.requestAccess() }
                }
            } label: {
                Text(isDenied ? "Open Settings" : "Allow access")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
        }
        .padding(32)
    }
}
