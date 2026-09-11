//
//  InfoTile.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/9/26.
//

import SwiftUI

/// A titled card used for the glanceable widgets (weather, stocks) on the
/// break window. Styled to match the stretch-suggestions panel.
struct InfoTile<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .foregroundStyle(.secondary)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        )
    }
}

#Preview("Info tile") {
    InfoTile(title: "Example", systemImage: "star") {
        Text("Tile content goes here.")
    }
    .padding()
    .frame(width: 360)
}
