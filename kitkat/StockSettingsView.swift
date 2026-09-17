//
//  StockSettingsView.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/16/26.
//

import SwiftUI

/// The Finnhub key and ticker list for the break window's stock tile. Values are
/// saved as typed; pressing Return or leaving the symbols field confirms they resolve.
struct StockSettingsView: View {
    private enum Field: Hashable {
        case key, symbols
    }

    @AppStorage(StockSettingsStore.apiKeyKey) private var apiKey = ""
    @AppStorage(StockSettingsStore.symbolsKey) private var symbolsText = ""
    @StateObject private var model = StockSettingsModel()
    @FocusState private var focusedField: Field?

    var body: some View {
        GroupBox("Break Window Stocks") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Label("API key", systemImage: "key")
                        .foregroundStyle(.secondary)
                        .frame(width: 96, alignment: .leading)

                    SecureField("Finnhub API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                        .focused($focusedField, equals: .key)
                        .accessibilityLabel("Finnhub API key")

                    Spacer()
                }

                HStack(spacing: 12) {
                    Label("Symbols", systemImage: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.secondary)
                        .frame(width: 96, alignment: .leading)

                    TextField("e.g. ORCL, AAPL", text: $symbolsText)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320)
                        .focused($focusedField, equals: .symbols)
                        .onSubmit(lookUp)
                        .accessibilityLabel("Stock symbols")

                    statusView

                    Spacer()
                }

                Text("Up to \(StockSettingsStore.maxSymbols) US tickers. Quotes come from Finnhub and appear on the break window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(.automatic)
        .onAppear(perform: model.loadInitialStatus)
        .onChange(of: focusedField) { previous, current in
            if previous == .symbols, current != .symbols { lookUp() }
        }
    }

    @ViewBuilder
    private var statusView: some View {
        switch model.status {
        case .idle:
            EmptyView()

        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Looking up…")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

        case .found(let symbols):
            Label(symbols.map(\.companyName).joined(separator: ", "), systemImage: "checkmark.circle.fill")
                .font(.callout)
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.multicolor)
                .lineLimit(1)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.callout)
                .foregroundStyle(.orange)
                .lineLimit(1)
        }
    }

    private func lookUp() {
        Task { await model.lookUp(symbolsText) }
    }
}

#Preview("Stock settings") {
    StockSettingsView()
        .padding()
        .frame(width: 700)
}
