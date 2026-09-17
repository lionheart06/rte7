//
//  NewsTileView.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/17/26.
//

import SwiftUI

/// Owns the view model and picks this break's headlines when the window appears.
struct NewsTileView: View {
    @StateObject private var viewModel: NewsViewModel

    init(viewModel: @autoclosure @escaping () -> NewsViewModel = NewsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        NewsTileContent(state: viewModel.state)
            .task {
                await viewModel.refresh()
            }
    }
}

/// Pure rendering of a news state, previewable and renderable in tests.
struct NewsTileContent: View {
    let state: NewsViewModel.State

    var body: some View {
        InfoTile(title: "News", systemImage: "newspaper") {
            switch state {
            case .loading(previous: let items) where items.isEmpty:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Fetching the headlines…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)

            case .failed(let message, previous: let items) where items.isEmpty:
                placeholder(systemImage: "exclamationmark.triangle", text: message)

            case .loading(previous: let items):
                headlines(items)
                footnote {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Updating…")
                }

            case .failed(_, previous: let items):
                headlines(items)
                footnote {
                    Image(systemName: "wifi.exclamationmark")
                    Text("Couldn’t refresh. Showing earlier headlines.")
                }

            case .loaded(let items) where items.isEmpty:
                placeholder(systemImage: "newspaper", text: "No stories right now.")

            case .loaded(let items):
                headlines(items)
            }
        }
    }

    // MARK: Headlines

    private func headlines(_ items: [NewsItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    headline(item)

                    if let summary = item.summary {
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 4) {
                        Text(item.source)
                        if let publishedAt = item.publishedAt {
                            Text("·")
                            Text(publishedAt, format: .relative(presentation: .named))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The headline opens in the default browser; the break window stays open.
    @ViewBuilder
    private func headline(_ item: NewsItem) -> some View {
        if let link = item.link {
            Link(destination: link) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    headlineText(item.title)
                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .help("Open in your browser")
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        } else {
            headlineText(item.title)
        }
    }

    private func headlineText(_ title: String) -> some View {
        Text(title)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Shared bits

    private func placeholder(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .center)

            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(minHeight: 44, alignment: .top)
    }

    private func footnote<Note: View>(@ViewBuilder _ note: () -> Note) -> some View {
        HStack(spacing: 6) {
            note()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

// MARK: - Previews

private let previewItems: [NewsItem] = [
    NewsItem(id: "1", title: "Interest rates held but Bank signals rise if energy prices stay high",
             summary: "Rates are held for the sixth time in a row but the Bank says high energy prices make a rise more likely.",
             link: URL(string: "https://www.bbc.co.uk/news"), publishedAt: Date().addingTimeInterval(-2 * 3600), source: "BBC News"),
    NewsItem(id: "2", title: "New telescope captures first images of distant galaxy cluster",
             summary: nil, link: URL(string: "https://www.bbc.co.uk/news"), publishedAt: Date().addingTimeInterval(-45 * 60), source: "BBC News"),
    NewsItem(id: "3", title: "Chip maker and rival agree to share factories",
             summary: "The deal covers plants in Arizona and Dresden.", link: nil, publishedAt: nil, source: "BBC News"),
]

#Preview("News tile states") {
    VStack(spacing: 12) {
        NewsTileContent(state: .loaded(previewItems))
        NewsTileContent(state: .loading(previous: previewItems))
        NewsTileContent(state: .failed(message: "Network is down", previous: previewItems))
        NewsTileContent(state: .loading(previous: []))
        NewsTileContent(state: .failed(message: NewsError.unavailable("BBC News", status: 503).localizedDescription, previous: []))
    }
    .padding()
    .frame(width: 360)
}
