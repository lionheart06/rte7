//
//  StocksViewModelTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation
import Combine
import Testing
@testable import kitkat

private let clock = Date(timeIntervalSince1970: 1_758_000_000)
private let oracle = StockSymbol(symbol: "ORCL", companyName: "Oracle Corp")
private let apple = StockSymbol(symbol: "AAPL", companyName: "Apple Inc")

@MainActor
private final class StateRecorder {
    private(set) var states: [StocksViewModel.State] = []
    private var cancellable: AnyCancellable?

    init(_ viewModel: StocksViewModel) {
        cancellable = viewModel.$state.dropFirst().sink { [weak self] in self?.states.append($0) }
    }
}

struct StockSettingsStoreTests {
    @Test func parsesCommaAndSpaceSeparatedSymbols() {
        #expect(StockSettingsStore.parseSymbols("orcl, aapl msft\nGOOG") == ["ORCL", "AAPL", "MSFT", "GOOG"])
    }

    @Test func parseDropsDuplicatesBlanksAndCapsAtFour() {
        #expect(StockSettingsStore.parseSymbols(" , ORCL,,orcl ,AAPL, MSFT, GOOG, AMZN") == ["ORCL", "AAPL", "MSFT", "GOOG"])
        #expect(StockSettingsStore.parseSymbols("   ").isEmpty)
    }

    @Test func cacheRoundTripsAndDefaultsToEmpty() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(StockSettingsStore.loadCache(userDefaults: defaults) == .empty)
        let cache = StockCache(names: ["ORCL": "Oracle Corp"], quotes: [makeQuote("ORCL", price: 150, fetchedAt: clock)])
        StockSettingsStore.saveCache(cache, userDefaults: defaults)
        #expect(StockSettingsStore.loadCache(userDefaults: defaults) == cache)

        StockSettingsStore.clearCache(userDefaults: defaults)
        #expect(StockSettingsStore.loadCache(userDefaults: defaults) == .empty)
    }

    @Test func apiKeyIsTrimmedOnLoad() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(StockSettingsStore.loadAPIKey(userDefaults: defaults) == "")
        StockSettingsStore.saveAPIKey("  abc \n", userDefaults: defaults)
        #expect(StockSettingsStore.loadAPIKey(userDefaults: defaults) == "abc")
    }
}

@MainActor
struct StocksViewModelTests {
    private func makeViewModel(
        key: String? = "key",
        symbols: String?,
        cache: StockCache? = nil,
        provider: FakeStockProvider,
        now: Date = clock
    ) throws -> (StocksViewModel, UserDefaults, String) {
        let (defaults, suite) = try makeWeatherTestDefaults()
        if let key { StockSettingsStore.saveAPIKey(key, userDefaults: defaults) }
        if let symbols { StockSettingsStore.saveSymbolsText(symbols, userDefaults: defaults) }
        if let cache { StockSettingsStore.saveCache(cache, userDefaults: defaults) }
        let viewModel = StocksViewModel(provider: provider, userDefaults: defaults, maxAge: 5 * 60, now: { now })
        return (viewModel, defaults, suite)
    }

    @Test func missingKeyNeedsSetupAndMakesNoCalls() async throws {
        let provider = FakeStockProvider()
        let (viewModel, defaults, suite) = try makeViewModel(key: nil, symbols: "ORCL", provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .needsSetup(.missingKey))
        #expect(provider.quoteCalls.isEmpty)
    }

    @Test func missingSymbolsNeedsSetup() async throws {
        let provider = FakeStockProvider()
        let (viewModel, defaults, suite) = try makeViewModel(symbols: " , ", provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .needsSetup(.missingSymbols))
        #expect(provider.quoteCalls.isEmpty)
    }

    @Test func firstLoadFetchesInOrderResolvesNamesAndCaches() async throws {
        let orcl = makeQuote("ORCL", price: 150, fetchedAt: clock)
        let aapl = makeQuote("AAPL", price: 180, fetchedAt: clock)
        let provider = FakeStockProvider(
            quotes: ["ORCL": .success(orcl), "AAPL": .success(aapl)],
            lookups: ["ORCL": .success(oracle), "AAPL": .success(apple)]
        )
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "orcl, aapl", provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        var namedOrcl = orcl; namedOrcl.companyName = "Oracle Corp"
        var namedAapl = aapl; namedAapl.companyName = "Apple Inc"
        #expect(recorder.states == [.loading(previous: []), .loaded([namedOrcl, namedAapl], note: nil)])
        #expect(provider.quoteCalls == ["ORCL", "AAPL"])
        #expect(provider.lookupCalls == ["ORCL", "AAPL"])

        let cache = StockSettingsStore.loadCache(userDefaults: defaults)
        #expect(cache.names == ["ORCL": "Oracle Corp", "AAPL": "Apple Inc"])
        #expect(cache.quotes == [namedOrcl, namedAapl])
    }

    @Test func freshCacheCoveringAllSymbolsIsServedWithoutNetwork() async throws {
        let cached = [makeQuote("ORCL", price: 150, fetchedAt: clock.addingTimeInterval(-60), name: "Oracle Corp")]
        let provider = FakeStockProvider()
        let cache = StockCache(names: ["ORCL": "Oracle Corp"], quotes: cached)
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .loaded(cached, note: nil))
        #expect(provider.quoteCalls.isEmpty)
    }

    @Test func staleCacheShowsPreviousWhileRefetchingAndSkipsLookups() async throws {
        let stale = makeQuote("ORCL", price: 140, fetchedAt: clock.addingTimeInterval(-30 * 60), name: "Oracle Corp")
        let fresh = makeQuote("ORCL", price: 150, fetchedAt: clock)
        let provider = FakeStockProvider(quotes: ["ORCL": .success(fresh)])
        let cache = StockCache(names: ["ORCL": "Oracle Corp"], quotes: [stale])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        var named = fresh; named.companyName = "Oracle Corp"
        #expect(recorder.states == [.loading(previous: [stale]), .loaded([named], note: nil)])
        #expect(provider.lookupCalls.isEmpty, "cached names should be reused")
    }

    @Test func newSymbolForcesFetchEvenWhenOthersAreFresh() async throws {
        let cachedOrcl = makeQuote("ORCL", price: 150, fetchedAt: clock.addingTimeInterval(-60), name: "Oracle Corp")
        let aapl = makeQuote("AAPL", price: 180, fetchedAt: clock)
        let provider = FakeStockProvider(
            quotes: ["ORCL": .success(cachedOrcl), "AAPL": .success(aapl)],
            lookups: ["AAPL": .success(apple)]
        )
        let cache = StockCache(names: ["ORCL": "Oracle Corp"], quotes: [cachedOrcl])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL, AAPL", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(provider.quoteCalls == ["ORCL", "AAPL"])
        #expect(provider.lookupCalls == ["AAPL"])
        #expect(viewModel.state.quotes.map(\.symbol) == ["ORCL", "AAPL"])
        #expect(viewModel.state.quotes.last?.companyName == "Apple Inc")
    }

    @Test func removedSymbolIsDroppedFromDisplayAndCache() async throws {
        let orcl = makeQuote("ORCL", price: 150, fetchedAt: clock.addingTimeInterval(-60), name: "Oracle Corp")
        let aapl = makeQuote("AAPL", price: 180, fetchedAt: clock.addingTimeInterval(-60), name: "Apple Inc")
        let provider = FakeStockProvider()
        let cache = StockCache(names: ["ORCL": "Oracle Corp", "AAPL": "Apple Inc"], quotes: [orcl, aapl])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "AAPL", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .loaded([aapl], note: nil))
        #expect(provider.quoteCalls.isEmpty)
    }

    @Test func unknownSymbolIsReportedInNoteWhileOthersLoad() async throws {
        let orcl = makeQuote("ORCL", price: 150, fetchedAt: clock)
        let provider = FakeStockProvider(quotes: ["ORCL": .success(orcl)], lookups: ["ORCL": .success(oracle)])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL, ZZZZ", provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        guard case .loaded(let quotes, let note) = viewModel.state else {
            Issue.record("expected loaded, got \(viewModel.state)")
            return
        }
        #expect(quotes.map(\.symbol) == ["ORCL"])
        #expect(note?.contains("ZZZZ") == true)
        #expect(StockSettingsStore.loadCache(userDefaults: defaults).quotes.map(\.symbol) == ["ORCL"])
    }

    @Test func transientFailureKeepsPreviousQuoteForThatSymbol() async throws {
        let staleAapl = makeQuote("AAPL", price: 170, fetchedAt: clock.addingTimeInterval(-30 * 60), name: "Apple Inc")
        let orcl = makeQuote("ORCL", price: 150, fetchedAt: clock)
        let provider = FakeStockProvider(
            quotes: ["ORCL": .success(orcl), "AAPL": .failure(URLError(.timedOut))],
            lookups: ["ORCL": .success(oracle)]
        )
        let cache = StockCache(names: ["AAPL": "Apple Inc"], quotes: [staleAapl])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL, AAPL", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        guard case .loaded(let quotes, let note) = viewModel.state else {
            Issue.record("expected loaded, got \(viewModel.state)")
            return
        }
        #expect(quotes.map(\.symbol) == ["ORCL", "AAPL"])
        #expect(quotes.last == staleAapl)
        #expect(note != nil)
    }

    @Test func multipleFailuresAreSummarisedInOneNote() async throws {
        let orcl = makeQuote("ORCL", price: 150, fetchedAt: clock)
        let provider = FakeStockProvider(quotes: ["ORCL": .success(orcl)], lookups: ["ORCL": .success(oracle)])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL, AAA, BBB", provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        guard case .loaded(_, let note) = viewModel.state else {
            Issue.record("expected loaded, got \(viewModel.state)")
            return
        }
        #expect(note == "Couldn’t load AAA, BBB.")
    }

    @Test func invalidKeyStopsAfterFirstCallAndKeepsPrevious() async throws {
        let stale = makeQuote("ORCL", price: 140, fetchedAt: clock.addingTimeInterval(-30 * 60), name: "Oracle Corp")
        let provider = FakeStockProvider(quotes: ["ORCL": .failure(FinnhubError.invalidAPIKey), "AAPL": .failure(FinnhubError.invalidAPIKey)])
        let cache = StockCache(names: ["ORCL": "Oracle Corp"], quotes: [stale])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL, AAPL", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .failed(message: FinnhubError.invalidAPIKey.localizedDescription, previous: [stale]))
        #expect(provider.quoteCalls == ["ORCL"], "a bad key should not be retried for every symbol")
        #expect(StockSettingsStore.loadCache(userDefaults: defaults).quotes == [stale], "cache must survive a failed run")
    }

    @Test func rateLimitIsFatalToo() async throws {
        let provider = FakeStockProvider(quotes: ["ORCL": .failure(FinnhubError.rateLimited)])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL, AAPL", provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .failed(message: FinnhubError.rateLimited.localizedDescription, previous: []))
        #expect(provider.quoteCalls.count == 1)
    }

    @Test func allSymbolsFailingWithoutPreviousIsFailed() async throws {
        let provider = FakeStockProvider()
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "AAA, BBB", provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        guard case .failed(let message, let previous) = viewModel.state else {
            Issue.record("expected failed, got \(viewModel.state)")
            return
        }
        #expect(message.contains("AAA"))
        #expect(previous.isEmpty)
    }

    @Test func lookupFailureStillShowsTheQuoteWithoutAName() async throws {
        let orcl = makeQuote("ORCL", price: 150, fetchedAt: clock)
        let provider = FakeStockProvider(quotes: ["ORCL": .success(orcl)], lookups: ["ORCL": .failure(URLError(.timedOut))])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL", provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .loaded([orcl], note: nil))
        #expect(viewModel.state.quotes.first?.companyName == nil)
    }

    @Test func forceRefreshBypassesFreshCache() async throws {
        let cached = makeQuote("ORCL", price: 150, fetchedAt: clock.addingTimeInterval(-60), name: "Oracle Corp")
        let fresh = makeQuote("ORCL", price: 151, fetchedAt: clock)
        let provider = FakeStockProvider(quotes: ["ORCL": .success(fresh)])
        let cache = StockCache(names: ["ORCL": "Oracle Corp"], quotes: [cached])
        let (viewModel, defaults, suite) = try makeViewModel(symbols: "ORCL", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh(force: true)

        #expect(provider.quoteCalls == ["ORCL"])
        #expect(viewModel.state.quotes.first?.price == 151)
    }
}
