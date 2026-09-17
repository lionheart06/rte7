//
//  StocksViewModel.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation
import Combine

/// Drives the stock tile on the break window. Reads the key and symbol list from
/// UserDefaults, serves recent cached quotes without touching the network, and
/// otherwise fetches each symbol, resolving company names once per ticker.
final class StocksViewModel: ObservableObject {
    enum Setup: Equatable {
        case missingKey
        case missingSymbols
    }

    enum State: Equatable {
        case needsSetup(Setup)
        /// A fetch is in flight. `previous` holds the last quotes for the current symbols.
        case loading(previous: [StockQuote])
        /// `note` describes any symbols that could not be refreshed this time.
        case loaded([StockQuote], note: String?)
        /// Nothing could be fetched. `previous` lets the tile keep showing the last quotes.
        case failed(message: String, previous: [StockQuote])

        /// The best quotes available to display.
        var quotes: [StockQuote] {
            switch self {
            case .needsSetup:
                return []
            case .loading(let previous), .failed(_, let previous):
                return previous
            case .loaded(let quotes, _):
                return quotes
            }
        }
    }

    /// Quotes younger than this are served from cache instead of refetched.
    static let defaultMaxAge: TimeInterval = 5 * 60

    @Published private(set) var state: State = .needsSetup(.missingKey)

    private let provider: any StockQuoteProviding
    private let userDefaults: UserDefaults
    private let maxAge: TimeInterval
    private let now: () -> Date

    init(provider: (any StockQuoteProviding)? = nil,
         userDefaults: UserDefaults = .standard,
         maxAge: TimeInterval = StocksViewModel.defaultMaxAge,
         now: @escaping () -> Date = Date.init) {
        self.provider = provider ?? FinnhubClient(apiKey: { StockSettingsStore.loadAPIKey(userDefaults: userDefaults) })
        self.userDefaults = userDefaults
        self.maxAge = maxAge
        self.now = now
    }

    /// Loads quotes for the configured symbols.
    /// - Parameter force: Skip the freshness check and always hit the network.
    func refresh(force: Bool = false) async {
        guard !StockSettingsStore.loadAPIKey(userDefaults: userDefaults).isEmpty else {
            state = .needsSetup(.missingKey)
            return
        }

        let symbols = StockSettingsStore.parseSymbols(StockSettingsStore.loadSymbolsText(userDefaults: userDefaults))
        guard !symbols.isEmpty else {
            state = .needsSetup(.missingSymbols)
            return
        }

        var cache = StockSettingsStore.loadCache(userDefaults: userDefaults)
        let previousBySymbol = Dictionary(cache.quotes.map { ($0.symbol, $0) }, uniquingKeysWith: { _, last in last })
        let previous = symbols.compactMap { previousBySymbol[$0] }

        let cacheCoversAllSymbols = previous.count == symbols.count
        let cacheIsFresh = previous.allSatisfy { now().timeIntervalSince($0.fetchedAt) < maxAge }
        if !force, cacheCoversAllSymbols, cacheIsFresh {
            state = .loaded(previous, note: nil)
            return
        }

        state = .loading(previous: previous)

        var displayed: [StockQuote] = []
        var failures: [(symbol: String, error: Error)] = []

        for symbol in symbols {
            do {
                var quote = try await provider.quote(for: symbol)
                if cache.names[symbol] == nil, let resolved = try? await provider.lookUp(symbol: symbol) {
                    cache.names[symbol] = resolved.companyName
                }
                quote.companyName = cache.names[symbol]
                displayed.append(quote)
            } catch let error as FinnhubError where error.affectsAllRequests {
                // A bad key or a rate limit will fail every symbol; stop here.
                state = .failed(message: error.localizedDescription, previous: previous)
                return
            } catch {
                failures.append((symbol, error))
                if let stale = previousBySymbol[symbol] {
                    displayed.append(stale)
                }
            }
        }

        cache.quotes = displayed
        StockSettingsStore.saveCache(cache, userDefaults: userDefaults)

        if displayed.isEmpty, let first = failures.first {
            state = .failed(message: first.error.localizedDescription, previous: previous)
        } else {
            state = .loaded(displayed, note: Self.note(for: failures))
        }
    }

    private static func note(for failures: [(symbol: String, error: Error)]) -> String? {
        switch failures.count {
        case 0:
            return nil
        case 1:
            return failures[0].error.localizedDescription
        default:
            return "Couldn’t load \(failures.map(\.symbol).joined(separator: ", "))."
        }
    }
}
