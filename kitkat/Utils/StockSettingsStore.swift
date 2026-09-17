//
//  StockSettingsStore.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation

/// Resolved company names and the last quotes, keyed per ticker so editing the
/// symbol list keeps what is still relevant.
nonisolated struct StockCache: Codable, Equatable {
    var names: [String: String]
    var quotes: [StockQuote]

    static let empty = StockCache(names: [:], quotes: [])
}

nonisolated struct StockSettingsStore {
    /// Finnhub key, entered in the main window. Lives in the app's sandboxed defaults;
    /// see TODO.md for the Keychain follow-up once the app is signed with a team.
    static let apiKeyKey = "FinnhubAPIKey"
    /// Comma-separated tickers as typed. ContentView binds to this with @AppStorage.
    static let symbolsKey = "StockSymbols"
    static let cacheKey = "StockCache"
    /// Keeps the tile glanceable and the call budget trivial.
    static let maxSymbols = 4

    static func loadAPIKey(userDefaults: UserDefaults = .standard) -> String {
        userDefaults.string(forKey: apiKeyKey)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    static func saveAPIKey(_ key: String, userDefaults: UserDefaults = .standard) {
        userDefaults.set(key, forKey: apiKeyKey)
    }

    static func loadSymbolsText(userDefaults: UserDefaults = .standard) -> String {
        userDefaults.string(forKey: symbolsKey) ?? ""
    }

    static func saveSymbolsText(_ text: String, userDefaults: UserDefaults = .standard) {
        userDefaults.set(text, forKey: symbolsKey)
    }

    static func loadCache(userDefaults: UserDefaults = .standard) -> StockCache {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(StockCache.self, from: data) else { return .empty }
        return cache
    }

    static func saveCache(_ cache: StockCache, userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    static func clearCache(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: cacheKey)
    }

    /// "orcl, aapl msft" -> ["ORCL", "AAPL", "MSFT"]. Splits on commas and
    /// whitespace, uppercases, drops duplicates, and keeps the first `maxSymbols`.
    static func parseSymbols(_ text: String) -> [String] {
        var seen = Set<String>()
        var symbols: [String] = []
        for piece in text.split(whereSeparator: { $0 == "," || $0.isWhitespace || $0.isNewline }) {
            let symbol = FinnhubAPI.normalizedSymbol(String(piece))
            guard !symbol.isEmpty, !seen.contains(symbol) else { continue }
            seen.insert(symbol)
            symbols.append(symbol)
            if symbols.count == maxSymbols { break }
        }
        return symbols
    }
}
