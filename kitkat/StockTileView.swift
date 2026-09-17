//
//  StockTileView.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/16/26.
//

import SwiftUI

/// Owns the view model and refreshes quotes when the break window appears.
struct StockTileView: View {
    @StateObject private var viewModel: StocksViewModel

    init(viewModel: @autoclosure @escaping () -> StocksViewModel = StocksViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        StockTileContent(state: viewModel.state)
            .task {
                await viewModel.refresh()
            }
    }
}

/// Pure rendering of a stocks state, previewable and renderable in tests.
struct StockTileContent: View {
    let state: StocksViewModel.State
    var now: Date = Date()

    /// A last trade older than this means the market is closed, so the tile says when the quotes are from.
    static let closedMarketThreshold: TimeInterval = 20 * 60

    var body: some View {
        InfoTile(title: "Stocks", systemImage: "chart.line.uptrend.xyaxis") {
            switch state {
            case .needsSetup(.missingKey):
                placeholder(systemImage: "key", text: "Add your Finnhub API key in the main window to see stocks here.")

            case .needsSetup(.missingSymbols):
                placeholder(systemImage: "textformat.abc", text: "Add ticker symbols in the main window.")

            case .loading(previous: let quotes) where quotes.isEmpty:
                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Checking the markets…")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 44)

            case .failed(let message, previous: let quotes) where quotes.isEmpty:
                placeholder(systemImage: "exclamationmark.triangle", text: message)

            case .loading(previous: let quotes):
                rows(quotes)
                footnote {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Updating…")
                }

            case .failed(_, previous: let quotes):
                rows(quotes)
                footnote {
                    Image(systemName: "wifi.exclamationmark")
                    Text("Couldn’t refresh. Last quotes \(newestFetch(in: quotes), format: .relative(presentation: .named)).")
                }

            case .loaded(let quotes, let note):
                rows(quotes)
                if let note {
                    footnote {
                        Image(systemName: "exclamationmark.circle")
                        Text(note)
                    }
                }
                if let asOf = closedMarketLabel(for: quotes) {
                    footnote {
                        Image(systemName: "clock")
                        Text("Market closed. As of \(asOf).")
                    }
                }
            }
        }
    }

    // MARK: Rows

    private func rows(_ quotes: [StockQuote]) -> some View {
        VStack(spacing: 10) {
            ForEach(quotes, id: \.symbol) { quote in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(quote.symbol)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)

                        if let name = quote.companyName {
                            Text(name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(quote.formattedPrice())
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(.primary)

                        HStack(spacing: 3) {
                            Image(systemName: arrow(for: quote.direction))
                                .font(.caption2.weight(.bold))
                            Text(quote.formattedChange())
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundStyle(color(for: quote.direction))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(quote.companyName ?? quote.symbol): \(quote.formattedPrice()), \(quote.formattedChange())")
            }
        }
    }

    private func arrow(for direction: StockQuote.Direction) -> String {
        switch direction {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "minus"
        }
    }

    private func color(for direction: StockQuote.Direction) -> Color {
        switch direction {
        case .up: return .green
        case .down: return .red
        case .flat: return .secondary
        }
    }

    // MARK: Footnotes

    private func newestFetch(in quotes: [StockQuote]) -> Date {
        quotes.map(\.fetchedAt).max() ?? now
    }

    /// Time of the last trade when the market looks closed, otherwise nil.
    func closedMarketLabel(for quotes: [StockQuote]) -> String? {
        guard let newest = quotes.map(\.asOf).max(),
              now.timeIntervalSince(newest) > Self.closedMarketThreshold else { return nil }

        if Calendar.current.isDate(newest, inSameDayAs: now) {
            return newest.formatted(date: .omitted, time: .shortened)
        }
        return newest.formatted(date: .abbreviated, time: .shortened)
    }

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

private let previewQuotes = [
    StockQuote(symbol: "ORCL", companyName: "Oracle Corp", price: 152.31, change: 2.38, changePercent: 1.59,
               previousClose: 149.93, asOf: Date().addingTimeInterval(-60), fetchedAt: Date()),
    StockQuote(symbol: "AAPL", companyName: "Apple Inc", price: 231.10, change: -1.42, changePercent: -0.61,
               previousClose: 232.52, asOf: Date().addingTimeInterval(-60), fetchedAt: Date()),
]

#Preview("Stock tile states") {
    VStack(spacing: 12) {
        StockTileContent(state: .loaded(previewQuotes, note: nil))
        StockTileContent(state: .loaded(previewQuotes, note: "Couldn’t find a symbol called “ZZZZ”."))
        StockTileContent(state: .loading(previous: previewQuotes))
        StockTileContent(state: .failed(message: "Network is down", previous: previewQuotes))
        StockTileContent(state: .loading(previous: []))
        StockTileContent(state: .needsSetup(.missingKey))
    }
    .padding()
    .frame(width: 400)
}
