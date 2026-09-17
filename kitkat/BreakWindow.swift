//
//  BreakWindow.swift
//  kitkat
//
//  Created by Richard El-Kadi on 2/23/26.
//


//
//  BreakWindowSwift.swift
//  rte7
//
//  Created by Richard El Kadi on 8/26/24.
//

import Foundation
import SwiftUI

struct BreakWindow: View {
    var window: NSWindow?
    var breakIndex: Int = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Color.black.opacity(colorScheme == .dark ? 0.28 : 0.12)
                )
                .ignoresSafeArea()

            BreakView(breakIndex: breakIndex) {
                window?.close()
            }
            .padding(32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct BreakView: View {
    @StateObject private var viewModel = QuoteViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var didAppear = false
    var breakIndex: Int = 0
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header

            HStack(alignment: .top, spacing: 12) {
                WeatherTileView()
                StockTileView()
            }

            HStack(alignment: .top, spacing: 12) {
                NewsTileView()
                StretchSuggestionsView(suggestions: suggestions)
            }

            Text(viewModel.message)
                .font(.title3)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)

            HStack(spacing: 12) {
                Button("Close", action: onClose)
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Spacer()

                Button("Get Quote") {
                    viewModel.getQuote()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .padding(28)
        .frame(maxWidth: 720)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.primary.opacity(colorScheme == .dark ? 0.16 : 0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 24, x: 0, y: 10)
        .onAppear {
            if !didAppear {
                didAppear = true
                viewModel.getQuote()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Break time")
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Take a minute away from the keyboard.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var suggestions: [StretchSuggestion] {
        StretchSuggestion.rotation(breakIndex: breakIndex)
    }
}

struct StretchSuggestionsView: View {
    let suggestions: [StretchSuggestion]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("While you are up")
                .font(.headline)
                .foregroundStyle(.secondary)

            ForEach(suggestions) { suggestion in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: suggestion.systemImage)
                        .font(.title3)
                        .foregroundStyle(.tint)
                        .frame(width: 28, alignment: .center)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)

                        Text(suggestion.detail)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(suggestion.title). \(suggestion.detail)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.quaternary.opacity(0.35))
        )
    }
}

#Preview("Break window") {
    BreakWindow(breakIndex: 0)
        .frame(width: 760, height: 640)
}
