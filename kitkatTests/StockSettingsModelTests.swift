//
//  StockSettingsModelTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation
import Testing
@testable import kitkat

private let oracle = StockSymbol(symbol: "ORCL", companyName: "Oracle Corp")
private let apple = StockSymbol(symbol: "AAPL", companyName: "Apple Inc")

@MainActor
struct StockSettingsModelTests {
    private func makeModel(key: String? = "key", provider: FakeStockProvider) throws -> (StockSettingsModel, UserDefaults, String) {
        let (defaults, suite) = try makeWeatherTestDefaults()
        if let key { StockSettingsStore.saveAPIKey(key, userDefaults: defaults) }
        return (StockSettingsModel(provider: provider, userDefaults: defaults), defaults, suite)
    }

    @Test func blankInputIsIdleAndMakesNoCalls() async throws {
        let provider = FakeStockProvider(lookups: ["ORCL": .success(oracle)])
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp(" , ")

        #expect(model.status == .idle)
        #expect(provider.lookupCalls.isEmpty)
    }

    @Test func missingKeyFailsBeforeAnyCall() async throws {
        let provider = FakeStockProvider(lookups: ["ORCL": .success(oracle)])
        let (model, defaults, suite) = try makeModel(key: nil, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp("ORCL")

        #expect(model.status == .failed(FinnhubError.missingAPIKey.localizedDescription))
        #expect(provider.lookupCalls.isEmpty)
    }

    @Test func resolvesEachSymbolAndCachesNames() async throws {
        let provider = FakeStockProvider(lookups: ["ORCL": .success(oracle), "AAPL": .success(apple)])
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp("orcl, aapl")

        #expect(model.status == .found([oracle, apple]))
        #expect(provider.lookupCalls == ["ORCL", "AAPL"])
        #expect(StockSettingsStore.loadCache(userDefaults: defaults).names == ["ORCL": "Oracle Corp", "AAPL": "Apple Inc"])
    }

    @Test func cachedNamesSkipTheNetwork() async throws {
        let provider = FakeStockProvider(lookups: ["AAPL": .success(apple)])
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        StockSettingsStore.saveCache(StockCache(names: ["ORCL": "Oracle Corp"], quotes: []), userDefaults: defaults)

        await model.lookUp("ORCL, AAPL")

        #expect(model.status == .found([oracle, apple]))
        #expect(provider.lookupCalls == ["AAPL"])
    }

    @Test func unknownSymbolFailsButOthersAreStillCached() async throws {
        let provider = FakeStockProvider(lookups: ["ORCL": .success(oracle)])
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp("ORCL, ZZZZ")

        guard case .failed(let message) = model.status else {
            Issue.record("expected failed, got \(model.status)")
            return
        }
        #expect(message.contains("ZZZZ"))
        #expect(StockSettingsStore.loadCache(userDefaults: defaults).names == ["ORCL": "Oracle Corp"])
    }

    @Test func severalUnknownSymbolsAreListedTogether() async throws {
        let provider = FakeStockProvider()
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp("AAA, BBB")

        #expect(model.status == .failed("Couldn’t find AAA, BBB."))
    }

    @Test func invalidKeyStopsAtFirstSymbol() async throws {
        let provider = FakeStockProvider(lookups: ["ORCL": .failure(FinnhubError.invalidAPIKey), "AAPL": .success(apple)])
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp("ORCL, AAPL")

        #expect(model.status == .failed(FinnhubError.invalidAPIKey.localizedDescription))
        #expect(provider.lookupCalls == ["ORCL"])
    }

    @Test func unchangedResolvedListIsNotLookedUpAgain() async throws {
        let provider = FakeStockProvider(lookups: ["ORCL": .success(oracle)])
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp("ORCL")
        StockSettingsStore.clearCache(userDefaults: defaults) // prove the short-circuit, not the cache, prevents the call
        await model.lookUp(" orcl ")

        #expect(provider.lookupCalls.count == 1)
        #expect(model.status == .found([oracle]))
    }

    @Test func initialStatusIsFoundOnlyWhenEverySymbolHasACachedName() throws {
        let provider = FakeStockProvider()
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        StockSettingsStore.saveSymbolsText("ORCL, AAPL", userDefaults: defaults)
        StockSettingsStore.saveCache(StockCache(names: ["ORCL": "Oracle Corp"], quotes: []), userDefaults: defaults)

        model.loadInitialStatus()
        #expect(model.status == .idle)

        StockSettingsStore.saveCache(StockCache(names: ["ORCL": "Oracle Corp", "AAPL": "Apple Inc"], quotes: []), userDefaults: defaults)
        model.loadInitialStatus()
        #expect(model.status == .found([oracle, apple]))
        #expect(provider.lookupCalls.isEmpty)
    }
}
