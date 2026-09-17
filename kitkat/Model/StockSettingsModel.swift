//
//  StockSettingsModel.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation
import Combine

/// Backs the symbols field in the main window. Confirms each ticker resolves and
/// caches its company name so the break window can skip the lookup.
final class StockSettingsModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        case found([StockSymbol])
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private let provider: any StockQuoteProviding
    private let userDefaults: UserDefaults
    private var lastResolved: [String]?

    init(provider: (any StockQuoteProviding)? = nil, userDefaults: UserDefaults = .standard) {
        self.provider = provider ?? FinnhubClient(apiKey: { StockSettingsStore.loadAPIKey(userDefaults: userDefaults) })
        self.userDefaults = userDefaults
    }

    /// Shows the previously resolved names for the saved symbols without a network call.
    func loadInitialStatus() {
        let symbols = StockSettingsStore.parseSymbols(StockSettingsStore.loadSymbolsText(userDefaults: userDefaults))
        let names = StockSettingsStore.loadCache(userDefaults: userDefaults).names
        let resolved = symbols.compactMap { symbol in names[symbol].map { StockSymbol(symbol: symbol, companyName: $0) } }

        if !symbols.isEmpty, resolved.count == symbols.count {
            lastResolved = symbols
            status = .found(resolved)
        } else {
            lastResolved = nil
            status = .idle
        }
    }

    /// Resolves the typed tickers. Blank input resets to idle; an unchanged,
    /// already-resolved list is not looked up again.
    func lookUp(_ text: String) async {
        let symbols = StockSettingsStore.parseSymbols(text)
        guard !symbols.isEmpty else {
            lastResolved = nil
            status = .idle
            return
        }

        if case .found = status, symbols == lastResolved {
            return
        }

        guard !StockSettingsStore.loadAPIKey(userDefaults: userDefaults).isEmpty else {
            lastResolved = nil
            status = .failed(FinnhubError.missingAPIKey.localizedDescription)
            return
        }

        status = .checking
        var cache = StockSettingsStore.loadCache(userDefaults: userDefaults)
        var resolved: [StockSymbol] = []
        var unknown: [String] = []

        for symbol in symbols {
            if let name = cache.names[symbol] {
                resolved.append(StockSymbol(symbol: symbol, companyName: name))
                continue
            }
            do {
                let match = try await provider.lookUp(symbol: symbol)
                cache.names[symbol] = match.companyName
                resolved.append(StockSymbol(symbol: symbol, companyName: match.companyName))
            } catch let error as FinnhubError where error.affectsAllRequests {
                lastResolved = nil
                status = .failed(error.localizedDescription)
                return
            } catch {
                unknown.append(symbol)
            }
        }

        StockSettingsStore.saveCache(cache, userDefaults: userDefaults)

        if unknown.isEmpty {
            lastResolved = symbols
            status = .found(resolved)
        } else {
            lastResolved = nil
            status = .failed(
                unknown.count == 1
                    ? FinnhubError.symbolNotFound(unknown[0]).localizedDescription
                    : "Couldn’t find \(unknown.joined(separator: ", "))."
            )
        }
    }
}
