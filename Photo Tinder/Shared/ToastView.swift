//
//  ToastView.swift
//  Photo Tinder
//

import SwiftUI

struct ToastView: View {
    let event: GameEvent

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: event.symbol)
                .font(.title2)
                .foregroundStyle(.pink)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title).font(.subheadline.bold())
                Text(event.subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(.regularMaterial, in: .rect(cornerRadius: 18))
        .shadow(color: .black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
