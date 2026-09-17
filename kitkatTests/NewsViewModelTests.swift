//
//  NewsViewModelTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation
import Combine
import Testing
@testable import kitkat

private let clock = Date(timeIntervalSince1970: 1_758_100_000)

private func item(_ n: Int, source: String = "BBC News") -> NewsItem {
    NewsItem(id: "id-\(n)", title: "Story \(n)", summary: nil, link: URL(string: "https://example.com/\(n)"),
             publishedAt: clock.addingTimeInterval(TimeInterval(-60 * n)), source: source)
}

private func items(_ range: ClosedRange<Int>) -> [NewsItem] {
    range.map { item($0) }
}

@MainActor
private final class FakeNewsProvider: NewsProviding {
    var result: Result<[NewsItem], Error>
    private(set) var feeds: [NewsFeed] = []

    init(_ result: Result<[NewsItem], Error>) {
        self.result = result
    }

    func headlines(from feed: NewsFeed) async throws -> [NewsItem] {
        feeds.append(feed)
        return try result.get()
    }
}

@MainActor
private final class StateRecorder {
    private(set) var states: [NewsViewModel.State] = []
    private var cancellable: AnyCancellable?

    init(_ viewModel: NewsViewModel) {
        cancellable = viewModel.$state.dropFirst().sink { [weak self] in self?.states.append($0) }
    }
}

struct NewsStoreTests {
    @Test func feedDefaultsToTopStoriesAndHonoursAKnownID() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(NewsStore.loadFeed(userDefaults: defaults) == .default)
        NewsStore.saveFeedID(NewsFeed.bbcTechnology.id, userDefaults: defaults)
        #expect(NewsStore.loadFeed(userDefaults: defaults) == .bbcTechnology)
        NewsStore.saveFeedID("not-a-feed", userDefaults: defaults)
        #expect(NewsStore.loadFeed(userDefaults: defaults) == .default)
    }

    @Test func cacheRoundTrips() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(NewsStore.loadCache(userDefaults: defaults) == nil)
        let cache = NewsCache(feedID: "bbc-top", items: items(1...3), fetchedAt: clock, recentlyShownIDs: ["id-1"])
        NewsStore.saveCache(cache, userDefaults: defaults)
        #expect(NewsStore.loadCache(userDefaults: defaults) == cache)
        NewsStore.clearCache(userDefaults: defaults)
        #expect(NewsStore.loadCache(userDefaults: defaults) == nil)
    }
}

struct NewsSelectionTests {
    @Test func nothingSeenTakesTheLeadStoriesInFeedOrder() {
        #expect(NewsViewModel.select(from: items(1...12), recentlyShown: []) == items(1...3))
    }

    @Test func seenStoriesAreSkippedWhileUnseenRemain() {
        let picked = NewsViewModel.select(from: items(1...12), recentlyShown: ["id-1", "id-2", "id-3"])
        #expect(picked == items(4...6))
    }

    @Test func partiallySeenPoolFillsWithLeastRecentlyShown() {
        // Pool of 5, seen 1,2 then 3,4 (oldest first). Unseen: 5. Fill with 1 and 2.
        let picked = NewsViewModel.select(from: items(1...5), recentlyShown: ["id-1", "id-2", "id-3", "id-4"])
        #expect(picked.map(\.id) == ["id-5", "id-1", "id-2"])
    }

    @Test func selectionNeverReachesBeyondTheRotationPool() {
        let seen = (1...10).map { "id-\($0)" }
        let picked = NewsViewModel.select(from: items(1...12), recentlyShown: seen)
        #expect(!picked.contains { $0.id == "id-11" || $0.id == "id-12" })
        #expect(picked.map(\.id) == ["id-1", "id-2", "id-3"], "least recently shown come back first")
    }

    @Test func smallPoolReturnsEverything() {
        #expect(NewsViewModel.select(from: items(1...2), recentlyShown: []) == items(1...2))
        #expect(NewsViewModel.select(from: [], recentlyShown: []).isEmpty)
    }
}

@MainActor
struct NewsViewModelTests {
    private func makeViewModel(
        cache: NewsCache? = nil,
        feedID: String? = nil,
        provider: FakeNewsProvider,
        now: Date = clock
    ) throws -> (NewsViewModel, UserDefaults, String) {
        let (defaults, suite) = try makeWeatherTestDefaults()
        if let cache { NewsStore.saveCache(cache, userDefaults: defaults) }
        if let feedID { NewsStore.saveFeedID(feedID, userDefaults: defaults) }
        let viewModel = NewsViewModel(provider: provider, userDefaults: defaults, maxAge: 15 * 60, now: { now })
        return (viewModel, defaults, suite)
    }

    @Test func firstLoadDownloadsPicksLeadStoriesAndCaches() async throws {
        let provider = FakeNewsProvider(.success(items(1...25)))
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loading(previous: []), .loaded(items(1...3))])
        #expect(provider.feeds == [.bbcTopStories])

        let cache = try #require(NewsStore.loadCache(userDefaults: defaults))
        #expect(cache.feedID == NewsFeed.bbcTopStories.id)
        #expect(cache.items.count == NewsStore.maxCachedItems, "only the leading items are kept")
        #expect(cache.fetchedAt == clock)
        #expect(cache.recentlyShownIDs == ["id-1", "id-2", "id-3"])
    }

    @Test func freshCacheRotatesToUnseenStoriesWithoutDownloading() async throws {
        let provider = FakeNewsProvider(.failure(URLError(.notConnectedToInternet)))
        let cache = NewsCache(feedID: "bbc-top", items: items(1...12), fetchedAt: clock.addingTimeInterval(-5 * 60), recentlyShownIDs: ["id-1", "id-2", "id-3"])
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loaded(items(4...6))], "no loading state when served from cache")
        #expect(provider.feeds.isEmpty)
        #expect(NewsStore.loadCache(userDefaults: defaults)?.recentlyShownIDs == ["id-1", "id-2", "id-3", "id-4", "id-5", "id-6"])
    }

    @Test func staleCacheShowsLastHeadlinesWhileDownloading() async throws {
        let provider = FakeNewsProvider(.success(items(1...12)))
        let cache = NewsCache(feedID: "bbc-top", items: items(1...12), fetchedAt: clock.addingTimeInterval(-40 * 60), recentlyShownIDs: ["id-1", "id-2", "id-3"])
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loading(previous: items(1...3)), .loaded(items(4...6))])
        #expect(provider.feeds.count == 1)
        #expect(NewsStore.loadCache(userDefaults: defaults)?.fetchedAt == clock)
    }

    @Test func failureKeepsLastHeadlinesAndCache() async throws {
        let provider = FakeNewsProvider(.failure(NewsError.unavailable("BBC News", status: 503)))
        let cache = NewsCache(feedID: "bbc-top", items: items(1...12), fetchedAt: clock.addingTimeInterval(-40 * 60), recentlyShownIDs: ["id-1", "id-2", "id-3"])
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .failed(message: NewsError.unavailable("BBC News", status: 503).localizedDescription, previous: items(1...3)))
        #expect(viewModel.state.items == items(1...3))
        #expect(NewsStore.loadCache(userDefaults: defaults) == cache, "a failed download must not clobber the cache")
    }

    @Test func failureWithNoCacheHasNothingToFallBackOn() async throws {
        let provider = FakeNewsProvider(.failure(URLError(.timedOut)))
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        guard case .failed(_, let previous) = viewModel.state else {
            Issue.record("expected failed, got \(viewModel.state)")
            return
        }
        #expect(previous.isEmpty)
    }

    @Test func differentFeedIgnoresTheOldCacheEntirely() async throws {
        let provider = FakeNewsProvider(.success(items(1...5).map { NewsItem(id: "tech-\($0.id)", title: $0.title, summary: nil, link: nil, publishedAt: nil, source: "BBC Technology") }))
        let cache = NewsCache(feedID: "bbc-top", items: items(1...12), fetchedAt: clock, recentlyShownIDs: ["id-1", "id-2", "id-3"])
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, feedID: NewsFeed.bbcTechnology.id, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states.first == .loading(previous: []), "another feed's headlines are not shown as previous")
        #expect(provider.feeds == [.bbcTechnology], "a fresh cache for another feed must not suppress the download")
        #expect(viewModel.state.items.map(\.source) == Array(repeating: "BBC Technology", count: 3))
        #expect(NewsStore.loadCache(userDefaults: defaults)?.feedID == NewsFeed.bbcTechnology.id)
    }

    @Test func forceDownloadsDespiteFreshCache() async throws {
        let provider = FakeNewsProvider(.success(items(1...12)))
        let cache = NewsCache(feedID: "bbc-top", items: items(1...12), fetchedAt: clock.addingTimeInterval(-60), recentlyShownIDs: [])
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh(force: true)

        #expect(provider.feeds.count == 1)
        #expect(viewModel.state == .loaded(items(1...3)))
    }

    @Test func consecutiveBreaksCycleThroughTheFeedFairly() async throws {
        let provider = FakeNewsProvider(.success(items(1...6)))
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()
        #expect(viewModel.state.items == items(1...3))
        await viewModel.refresh()
        #expect(viewModel.state.items == items(4...6))
        await viewModel.refresh()
        #expect(viewModel.state.items == items(1...3), "once everything has been seen, the oldest showing comes back first")
        #expect(provider.feeds.count == 1, "all three breaks fell inside the cache window")
    }

    @Test func recentlyShownListStaysBounded() async throws {
        let provider = FakeNewsProvider(.success(items(1...20)))
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        for _ in 0..<15 {
            await viewModel.refresh()
        }

        let shown = try #require(NewsStore.loadCache(userDefaults: defaults)?.recentlyShownIDs)
        #expect(shown.count <= NewsStore.recentlyShownLimit)
        #expect(Set(shown).count == shown.count, "ids are moved, not duplicated")
        #expect(viewModel.state.items.count == 3)
    }
}
