//
//  NewsViewModel.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation
import Combine

/// Drives the news tile. Downloads the selected feed at most every 15 minutes
/// (the interval the BBC feed itself advertises) and picks a few headlines each
/// break, preferring ones recent breaks have not shown.
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

    static let headlineCount = 3
    static let defaultMaxAge: TimeInterval = 15 * 60
    /// Headlines are chosen from this many of the feed's leading items.
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

    /// Picks this break's headlines, downloading the feed first if the cache is
    /// stale or belongs to another feed.
    /// - Parameter force: Skip the freshness check and always download.
    func refresh(force: Bool = false) async {
        let feed = NewsStore.loadFeed(userDefaults: userDefaults)
        let cache = NewsStore.loadCache(userDefaults: userDefaults).flatMap { $0.feedID == feed.id ? $0 : nil }
        let previous = cache.map { Self.lastShown(in: $0) } ?? []
        var recentlyShown = cache?.recentlyShownIDs ?? []

        let pool: [NewsItem]
        let fetchedAt: Date
        if !force, let cache, now().timeIntervalSince(cache.fetchedAt) < maxAge {
            pool = cache.items
            fetchedAt = cache.fetchedAt
        } else {
            state = .loading(previous: previous)
            do {
                pool = Array(try await provider.headlines(from: feed).prefix(NewsStore.maxCachedItems))
                fetchedAt = now()
            } catch {
                state = .failed(message: error.localizedDescription, previous: previous)
                return
            }
        }

        let selection = Self.select(from: pool, recentlyShown: recentlyShown)
        recentlyShown.removeAll { id in selection.contains { $0.id == id } }
        recentlyShown.append(contentsOf: selection.map(\.id))
        recentlyShown = Array(recentlyShown.suffix(NewsStore.recentlyShownLimit))

        NewsStore.saveCache(
            NewsCache(feedID: feed.id, items: pool, fetchedAt: fetchedAt, recentlyShownIDs: recentlyShown),
            userDefaults: userDefaults
        )
        state = .loaded(selection)
    }

    /// Chooses `headlineCount` items from the leading `rotationPoolSize` of the
    /// pool: unseen ones first in feed order, then the least recently shown.
    static func select(from pool: [NewsItem],
                       recentlyShown: [String],
                       count: Int = headlineCount,
                       poolSize: Int = rotationPoolSize) -> [NewsItem] {
        let candidates = Array(pool.prefix(poolSize))
        let unseen = candidates.filter { !recentlyShown.contains($0.id) }
        if unseen.count >= count {
            return Array(unseen.prefix(count))
        }

        // Fill the remainder with seen items, oldest showing first.
        let seen = candidates
            .filter { recentlyShown.contains($0.id) }
            .sorted { (recentlyShown.firstIndex(of: $0.id) ?? 0) < (recentlyShown.firstIndex(of: $1.id) ?? 0) }
        return Array((unseen + seen).prefix(count))
    }

    /// The items the previous break showed, in the order it showed them.
    private static func lastShown(in cache: NewsCache) -> [NewsItem] {
        let lastIDs = cache.recentlyShownIDs.suffix(headlineCount)
        return lastIDs.compactMap { id in cache.items.first { $0.id == id } }
    }
}
