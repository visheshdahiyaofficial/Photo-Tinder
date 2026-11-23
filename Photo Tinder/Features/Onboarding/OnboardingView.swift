//
//  OnboardingView.swift
//  Photo Tinder
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private let pages: [(symbol: String, color: Color, title: String, text: String)] = [
        ("clock.arrow.circlepath", .pink, "Start from the beginning",
         "Photo Tinder shows your library one photo at a time, starting with the oldest."),
        ("hand.draw.fill", .green, "Swipe to decide",
         "Swipe right to keep, left to delete, up to keep and favorite. Made a mistake? Tap undo."),
        ("trash.fill", .red, "Nothing is lost by accident",
         "Left swipes go to a delete pile. You review it and confirm once — and iOS keeps deleted items for 30 days."),
    ]

    var body: some View {
        VStack {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    let item = pages[index]
                    VStack(spacing: 24) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 90))
                            .foregroundStyle(item.color.gradient)
                        Text(item.title)
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text(item.text)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .tag(index)
                }
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? "Next" : "Get started")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding()
        }
    }
}
