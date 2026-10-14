//
//  NewsViewModel.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation
import Combine

/// Drives the news tile. Reads one feed per topic, downloading each at most
/// every 15 minutes (the interval the BBC feeds advertise), and shows one
/// headline from each feed per break, preferring ones recent breaks have not shown.
final class NewsViewModel: ObservableObject {
    enum State: Equatable {
        /// A fetch is in flight. `previous` holds what the last break showed.
        case loading(previous: [NewsItem])
        case loaded([NewsItem])
        /// The fetch failed. `previous` lets the tile keep showing the last headlines.
        case failed(message: String, previous: [NewsItem])

        var items: [NewsItem] {
            switch self {
            case .loading(let previous), .failed(_, let previous):
                return previous
            case .loaded(let items):
                return items
            }
        }
    }

    static let defaultMaxAge: TimeInterval = 15 * 60
    /// Each feed's headline is chosen from this many of its leading items.
    static let rotationPoolSize = 10

    @Published private(set) var state: State = .loading(previous: [])

    private let provider: any NewsProviding
    private let userDefaults: UserDefaults
    private let maxAge: TimeInterval
    private let now: () -> Date

    init(provider: any NewsProviding = RSSFeedClient(),
         userDefaults: UserDefaults = .standard,
         maxAge: TimeInterval = NewsViewModel.defaultMaxAge,
         now: @escaping () -> Date = Date.init) {
        self.provider = provider
        self.userDefaults = userDefaults
        self.maxAge = maxAge
        self.now = now
    }

    /// Picks this break's headlines, one per feed, downloading any feed whose
    /// cached copy is stale or missing. A feed that fails to download keeps
    /// contributing from its earlier copy; only when nothing at all is fresh
    /// does the tile fall back to the last break's headlines.
    /// - Parameter force: Skip the freshness check and download every feed.
    func refresh(force: Bool = false) async {
        let feeds = NewsStore.loadFeeds(userDefaults: userDefaults)
        let cache = NewsStore.loadCache(userDefaults: userDefaults)
        var recentlyShown = cache?.recentlyShownIDs ?? []
        let previous = Self.lastShown(in: cache, feeds: feeds)

        // Serve each feed from the cache while its copy is fresh.
        var sections: [NewsSection?] = feeds.map { feed in
            guard !force, let section = cache?.section(for: feed.id),
                  now().timeIntervalSince(section.fetchedAt) < maxAge else { return nil }
            return section
        }

        let stale = feeds.indices.filter { sections[$0] == nil }
        if !stale.isEmpty {
            state = .loading(previous: previous)
            let fetchedAt = now()
            let results = await fetchHeadlines(from: stale.map { feeds[$0] })

            var downloaded = 0
            var firstError: Error?
            for (offset, index) in stale.enumerated() {
                switch results[offset] {
                case .success(let items):
                    downloaded += 1
                    sections[index] = NewsSection(feedID: feeds[index].id,
                                                  items: Array(items.prefix(NewsStore.maxCachedItems)),
                                                  fetchedAt: fetchedAt)
                case .failure(let error):
                    // Keep the stale copy so the feed still contributes; it is retried next break.
                    firstError = firstError ?? error
                    sections[index] = cache?.section(for: feeds[index].id)
                }
            }

            if downloaded == 0, stale.count == feeds.count, let firstError {
                state = .failed(message: firstError.localizedDescription, previous: previous)
                return
            }
        }

        let live = sections.compactMap { $0 }
        let selection = Self.select(from: live.map(\.items), recentlyShown: recentlyShown)
        recentlyShown.removeAll { id in selection.contains { $0.id == id } }
        recentlyShown.append(contentsOf: selection.map(\.id))
        recentlyShown = Array(recentlyShown.suffix(NewsStore.recentlyShownLimit))

        NewsStore.saveCache(NewsCache(sections: live, recentlyShownIDs: recentlyShown), userDefaults: userDefaults)
        state = .loaded(selection)
    }

    /// One story per feed: the first unseen item among the feed's leading
    /// `poolSize`, else the one shown longest ago. A story syndicated to more
    /// than one feed is shown once.
    static func select(from feeds: [[NewsItem]],
                       recentlyShown: [String],
                       poolSize: Int = rotationPoolSize) -> [NewsItem] {
        var picked: [NewsItem] = []
        for items in feeds {
            let candidates = items.prefix(poolSize).filter { candidate in !picked.contains { $0.id == candidate.id } }
            let choice = candidates.first { !recentlyShown.contains($0.id) }
                ?? candidates.min { (recentlyShown.firstIndex(of: $0.id) ?? 0) < (recentlyShown.firstIndex(of: $1.id) ?? 0) }
            if let choice {
                picked.append(choice)
            }
        }
        return picked
    }

    /// Downloads the feeds concurrently; results line up with `feeds`.
    private func fetchHeadlines(from feeds: [NewsFeed]) async -> [Result<[NewsItem], Error>] {
        await withTaskGroup(of: (Int, Result<[NewsItem], Error>).self) { group in
            for (index, feed) in feeds.enumerated() {
                group.addTask { [provider] in
                    do {
                        return (index, .success(try await provider.headlines(from: feed)))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            var results = [Result<[NewsItem], Error>](repeating: .success([]), count: feeds.count)
            for await (index, result) in group {
                results[index] = result
            }
            return results
        }
    }

    /// The items the previous break showed, in the order it showed them.
    private static func lastShown(in cache: NewsCache?, feeds: [NewsFeed]) -> [NewsItem] {
        guard let cache else { return [] }
        let items = feeds.flatMap { cache.section(for: $0.id)?.items ?? [] }
        return cache.recentlyShownIDs.suffix(feeds.count).compactMap { id in items.first { $0.id == id } }
    }
}
