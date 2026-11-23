//
//  RestartReviewDialog.swift
//  Photo Tinder
//

import SwiftUI

extension View {
    /// Confirmation for `AppModel.restartReview()`, shared by Settings and the "All caught up" screen.
    func restartReviewConfirmation(isPresented: Binding<Bool>) -> some View {
        modifier(RestartReviewDialog(isPresented: isPresented))
    }
}

private struct RestartReviewDialog: ViewModifier {
    @Environment(AppModel.self) private var app
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.confirmationDialog("Start over from your oldest photo?", isPresented: $isPresented, titleVisibility: .visible) {
            Button("Start over", role: .destructive) { app.restartReview() }
        } message: {
            Text(message)
        }
    }

    private var message: String {
        let pending = app.store.count(of: .pendingDelete)
        let pile = pending == 0 ? "" : " The \(pending) items in your delete pile will go back into the deck too."
        return "Every photo you've kept will show up again so you can review your whole library.\(pile) Your stats and achievements are kept."
    }
}
