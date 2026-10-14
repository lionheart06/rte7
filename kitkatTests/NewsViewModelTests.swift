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
/// World, Business, Technology, Science & Environment.
private let topics = NewsFeed.defaultSelection

/// Story `n` of `feed`, with id "<feedID>-<n>".
private func story(_ feed: NewsFeed, _ n: Int) -> NewsItem {
    NewsItem(id: "\(feed.id)-\(n)", title: "\(feed.name) story \(n)", summary: nil,
             link: URL(string: "https://example.com/\(feed.id)/\(n)"),
             publishedAt: clock.addingTimeInterval(TimeInterval(-60 * n)), source: feed.name)
}

private func stories(_ feed: NewsFeed, _ range: ClosedRange<Int>) -> [NewsItem] {
    range.map { story(feed, $0) }
}

/// Story `n` from each feed in feed order: what one break shows.
private func oneFromEach(_ n: Int, of feeds: [NewsFeed] = topics) -> [NewsItem] {
    feeds.map { story($0, n) }
}

private func section(_ feed: NewsFeed, _ range: ClosedRange<Int>, fetchedAt: Date = clock) -> NewsSection {
    NewsSection(feedID: feed.id, items: stories(feed, range), fetchedAt: fetchedAt)
}

private func sections(_ range: ClosedRange<Int>, fetchedAt: Date = clock, feeds: [NewsFeed] = topics) -> [NewsSection] {
    feeds.map { section($0, range, fetchedAt: fetchedAt) }
}

private func ids(_ items: [NewsItem]) -> [String] {
    items.map(\.id)
}

@MainActor
private final class FakeNewsProvider: NewsProviding {
    /// Per-feed answers; a feed without one gets `fallback`.
    var results: [String: Result<[NewsItem], Error>] = [:]
    var fallback: Result<[NewsItem], Error>
    private(set) var requested: [NewsFeed] = []

    init(fallback: Result<[NewsItem], Error> = .success([])) {
        self.fallback = fallback
    }

    /// Answers every topic feed with its own stories 1...count.
    static func serving(_ count: Int) -> FakeNewsProvider {
        let provider = FakeNewsProvider()
        for feed in topics {
            provider.results[feed.id] = .success(stories(feed, 1...count))
        }
        return provider
    }

    func headlines(from feed: NewsFeed) async throws -> [NewsItem] {
        requested.append(feed)
        return try (results[feed.id] ?? fallback).get()
    }

    /// Feeds download concurrently, so compare as a set.
    var requestedIDs: Set<String> { Set(requested.map(\.id)) }
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
    @Test func feedsDefaultToTheFourTopicsAndHonourKnownIDs() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(NewsStore.loadFeeds(userDefaults: defaults) == [.bbcWorld, .bbcBusiness, .bbcTechnology, .bbcScience])

        NewsStore.saveFeedIDs([NewsFeed.bbcTechnology.id, "not-a-feed", NewsFeed.bbcWorld.id, NewsFeed.bbcTechnology.id], userDefaults: defaults)
        #expect(NewsStore.loadFeeds(userDefaults: defaults) == [.bbcTechnology, .bbcWorld],
                "saved order kept, unknown ids dropped, repeats collapsed")

        NewsStore.saveFeedIDs(["not-a-feed"], userDefaults: defaults)
        #expect(NewsStore.loadFeeds(userDefaults: defaults) == NewsFeed.defaultSelection)
    }

    @Test func cacheRoundTrips() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(NewsStore.loadCache(userDefaults: defaults) == nil)
        let cache = NewsCache(sections: sections(1...3), recentlyShownIDs: ids(oneFromEach(1)))
        NewsStore.saveCache(cache, userDefaults: defaults)
        #expect(NewsStore.loadCache(userDefaults: defaults) == cache)
        #expect(cache.section(for: NewsFeed.bbcBusiness.id) == section(.bbcBusiness, 1...3))
        #expect(cache.section(for: NewsFeed.bbcTopStories.id) == nil)
        NewsStore.clearCache(userDefaults: defaults)
        #expect(NewsStore.loadCache(userDefaults: defaults) == nil)
    }

    @Test func cacheFromTheSingleFeedLayoutReadsAsAbsent() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let old = #"{"feedID":"bbc-top","items":[],"fetchedAt":0,"recentlyShownIDs":["id-1"]}"#
        defaults.set(Data(old.utf8), forKey: NewsStore.cacheKey)
        #expect(NewsStore.loadCache(userDefaults: defaults) == nil, "an undecodable cache is refetched, not a crash")
    }
}

struct NewsSelectionTests {
    private let pools = topics.map { stories($0, 1...12) }

    @Test func nothingSeenTakesEachFeedsLeadStoryInFeedOrder() {
        #expect(NewsViewModel.select(from: pools, recentlyShown: []) == oneFromEach(1))
    }

    @Test func seenStoriesAreSkippedWhileUnseenRemain() {
        let seen = ids(oneFromEach(1)) + ids(oneFromEach(2))
        #expect(NewsViewModel.select(from: pools, recentlyShown: seen) == oneFromEach(3))
    }

    @Test func feedsRotateIndependently() {
        let seen = ids(stories(.bbcWorld, 1...2))
        let picked = NewsViewModel.select(from: pools, recentlyShown: seen)
        #expect(picked == [story(.bbcWorld, 3), story(.bbcBusiness, 1), story(.bbcTechnology, 1), story(.bbcScience, 1)])
    }

    @Test func fullySeenFeedComesBackWithItsLeastRecentlyShownStory() {
        // Shown 2, then 3, then 1 (oldest first), so 2 has waited longest.
        let picked = NewsViewModel.select(from: [stories(.bbcWorld, 1...3)],
                                          recentlyShown: ["bbc-world-2", "bbc-world-3", "bbc-world-1"])
        #expect(picked == [story(.bbcWorld, 2)])
    }

    @Test func selectionNeverReachesBeyondTheRotationPool() {
        let seen = ids(stories(.bbcWorld, 1...10))
        let picked = NewsViewModel.select(from: [stories(.bbcWorld, 1...12)], recentlyShown: seen)
        #expect(picked == [story(.bbcWorld, 1)], "the least recently shown comes back rather than story 11")
    }

    @Test func aStorySyndicatedToTwoFeedsIsShownOnce() {
        let shared = story(.bbcWorld, 1)
        let business = [shared] + stories(.bbcBusiness, 2...5)
        let picked = NewsViewModel.select(from: [stories(.bbcWorld, 1...5), business], recentlyShown: [])
        #expect(picked == [shared, story(.bbcBusiness, 2)])
    }

    @Test func emptyFeedsContributeNothing() {
        #expect(NewsViewModel.select(from: [[], stories(.bbcBusiness, 1...2)], recentlyShown: []) == [story(.bbcBusiness, 1)])
        #expect(NewsViewModel.select(from: [], recentlyShown: []).isEmpty)
    }
}

@MainActor
struct NewsViewModelTests {
    private func makeViewModel(
        cache: NewsCache? = nil,
        feedIDs: [String]? = nil,
        provider: FakeNewsProvider,
        now: Date = clock
    ) throws -> (NewsViewModel, UserDefaults, String) {
        let (defaults, suite) = try makeWeatherTestDefaults()
        if let cache { NewsStore.saveCache(cache, userDefaults: defaults) }
        if let feedIDs { NewsStore.saveFeedIDs(feedIDs, userDefaults: defaults) }
        let viewModel = NewsViewModel(provider: provider, userDefaults: defaults, maxAge: 15 * 60, now: { now })
        return (viewModel, defaults, suite)
    }

    @Test func firstLoadDownloadsEveryFeedPicksOneStoryEachAndCaches() async throws {
        let provider = FakeNewsProvider.serving(25)
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loading(previous: []), .loaded(oneFromEach(1))])
        #expect(provider.requestedIDs == Set(topics.map(\.id)))
        #expect(provider.requested.count == topics.count, "each feed is downloaded exactly once")

        let cache = try #require(NewsStore.loadCache(userDefaults: defaults))
        #expect(cache.sections.map(\.feedID) == topics.map(\.id))
        #expect(cache.sections.allSatisfy { $0.items.count == NewsStore.maxCachedItems }, "only the leading items are kept")
        #expect(cache.sections.allSatisfy { $0.fetchedAt == clock })
        #expect(cache.recentlyShownIDs == ids(oneFromEach(1)))
    }

    @Test func freshCacheRotatesToUnseenStoriesWithoutDownloading() async throws {
        let provider = FakeNewsProvider(fallback: .failure(URLError(.notConnectedToInternet)))
        let cache = NewsCache(sections: sections(1...12, fetchedAt: clock.addingTimeInterval(-5 * 60)), recentlyShownIDs: ids(oneFromEach(1)))
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loaded(oneFromEach(2))], "no loading state when served from cache")
        #expect(provider.requested.isEmpty)
        #expect(NewsStore.loadCache(userDefaults: defaults)?.recentlyShownIDs == ids(oneFromEach(1)) + ids(oneFromEach(2)))
    }

    @Test func staleCacheShowsLastHeadlinesWhileDownloading() async throws {
        let provider = FakeNewsProvider.serving(12)
        let cache = NewsCache(sections: sections(1...12, fetchedAt: clock.addingTimeInterval(-40 * 60)), recentlyShownIDs: ids(oneFromEach(1)))
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loading(previous: oneFromEach(1)), .loaded(oneFromEach(2))])
        #expect(provider.requested.count == topics.count)
        #expect(NewsStore.loadCache(userDefaults: defaults)?.sections.allSatisfy { $0.fetchedAt == clock } == true)
    }

    @Test func everyFeedFailingKeepsLastHeadlinesAndCache() async throws {
        let error = NewsError.unavailable("BBC World", status: 503)
        let provider = FakeNewsProvider(fallback: .failure(error))
        let cache = NewsCache(sections: sections(1...12, fetchedAt: clock.addingTimeInterval(-40 * 60)), recentlyShownIDs: ids(oneFromEach(1)))
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .failed(message: error.localizedDescription, previous: oneFromEach(1)))
        #expect(viewModel.state.items == oneFromEach(1))
        #expect(NewsStore.loadCache(userDefaults: defaults) == cache, "a failed download must not clobber the cache")
    }

    @Test func oneFeedFailingKeepsItsEarlierStoriesAndStillRotates() async throws {
        let provider = FakeNewsProvider.serving(12)
        provider.results[NewsFeed.bbcWorld.id] = .failure(URLError(.timedOut))
        let staleAt = clock.addingTimeInterval(-40 * 60)
        let cache = NewsCache(sections: sections(1...12, fetchedAt: staleAt), recentlyShownIDs: ids(oneFromEach(1)))
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .loaded(oneFromEach(2)), "World's story comes from its earlier download")
        let saved = try #require(NewsStore.loadCache(userDefaults: defaults))
        #expect(saved.section(for: NewsFeed.bbcWorld.id)?.fetchedAt == staleAt, "the failed feed stays stale so the next break retries it")
        #expect(topics.dropFirst().allSatisfy { saved.section(for: $0.id)?.fetchedAt == clock })
    }

    @Test func oneFeedFailingWithNothingCachedShowsTheOthers() async throws {
        let provider = FakeNewsProvider.serving(12)
        provider.results[NewsFeed.bbcScience.id] = .failure(URLError(.timedOut))
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        let others: [NewsFeed] = [.bbcWorld, .bbcBusiness, .bbcTechnology]
        #expect(viewModel.state == .loaded(oneFromEach(1, of: others)))
        #expect(NewsStore.loadCache(userDefaults: defaults)?.sections.map(\.feedID) == others.map(\.id))
    }

    @Test func aFeedFailingAgainWhileOthersAreFreshStillRotates() async throws {
        // World failed last break and is stale; the other three are fresh.
        let provider = FakeNewsProvider(fallback: .failure(URLError(.timedOut)))
        var cached = sections(1...12, fetchedAt: clock.addingTimeInterval(-5 * 60))
        cached[0] = section(.bbcWorld, 1...12, fetchedAt: clock.addingTimeInterval(-40 * 60))
        let cache = NewsCache(sections: cached, recentlyShownIDs: ids(oneFromEach(1)))
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(provider.requestedIDs == [NewsFeed.bbcWorld.id], "only the stale feed is retried")
        #expect(viewModel.state == .loaded(oneFromEach(2)), "three fresh feeds are enough to move on")
    }

    @Test func failureWithNoCacheHasNothingToFallBackOn() async throws {
        let provider = FakeNewsProvider(fallback: .failure(URLError(.timedOut)))
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        guard case .failed(_, let previous) = viewModel.state else {
            Issue.record("expected failed, got \(viewModel.state)")
            return
        }
        #expect(previous.isEmpty)
        #expect(NewsStore.loadCache(userDefaults: defaults) == nil)
    }

    @Test func onlyStaleOrMissingFeedsAreDownloadedAndDroppedFeedsAreForgotten() async throws {
        let provider = FakeNewsProvider.serving(12)
        let chosen: [NewsFeed] = [.bbcWorld, .bbcBusiness, .bbcTechnology]
        // World and Business are fresh, Science is fresh but no longer chosen, Technology has never been fetched.
        let cache = NewsCache(sections: sections(1...12, fetchedAt: clock.addingTimeInterval(-5 * 60), feeds: [.bbcWorld, .bbcBusiness, .bbcScience]),
                              recentlyShownIDs: [])
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, feedIDs: chosen.map(\.id), provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(provider.requestedIDs == [NewsFeed.bbcTechnology.id])
        #expect(viewModel.state == .loaded(oneFromEach(1, of: chosen)))
        #expect(NewsStore.loadCache(userDefaults: defaults)?.sections.map(\.feedID) == chosen.map(\.id), "the dropped feed's section is discarded")
    }

    @Test func forceDownloadsDespiteFreshCache() async throws {
        let provider = FakeNewsProvider.serving(12)
        let cache = NewsCache(sections: sections(1...12, fetchedAt: clock.addingTimeInterval(-60)), recentlyShownIDs: [])
        let (viewModel, defaults, suite) = try makeViewModel(cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh(force: true)

        #expect(provider.requested.count == topics.count)
        #expect(viewModel.state == .loaded(oneFromEach(1)))
    }

    @Test func consecutiveBreaksCycleThroughEachFeedFairly() async throws {
        let provider = FakeNewsProvider.serving(3)
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()
        #expect(viewModel.state.items == oneFromEach(1))
        await viewModel.refresh()
        #expect(viewModel.state.items == oneFromEach(2))
        await viewModel.refresh()
        #expect(viewModel.state.items == oneFromEach(3))
        await viewModel.refresh()
        #expect(viewModel.state.items == oneFromEach(1), "once a feed is exhausted, its oldest showing comes back first")
        #expect(provider.requested.count == topics.count, "all four breaks fell inside the cache window")
    }

    @Test func recentlyShownListStaysBounded() async throws {
        let provider = FakeNewsProvider.serving(20)
        let (viewModel, defaults, suite) = try makeViewModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        for _ in 0..<15 {
            await viewModel.refresh()
        }

        let shown = try #require(NewsStore.loadCache(userDefaults: defaults)?.recentlyShownIDs)
        #expect(shown.count <= NewsStore.recentlyShownLimit)
        #expect(Set(shown).count == shown.count, "ids are moved, not duplicated")
        #expect(viewModel.state.items.count == topics.count)
    }
}
