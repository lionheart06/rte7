//
//  NewsStore.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation

/// One feed's most recent download.
nonisolated struct NewsSection: Codable, Equatable {
    let feedID: String
    /// Feed order, capped at `NewsStore.maxCachedItems`.
    let items: [NewsItem]
    let fetchedAt: Date
}

/// The last download of every selected feed plus which stories recent breaks
/// have shown, so the tile can rotate through each feed instead of repeating
/// its lead story.
nonisolated struct NewsCache: Codable, Equatable {
    var sections: [NewsSection]
    /// Oldest first; bounded by `NewsStore.recentlyShownLimit`.
    var recentlyShownIDs: [String]

    func section(for feedID: String) -> NewsSection? {
        sections.first { $0.feedID == feedID }
    }
}

nonisolated struct NewsStore {
    /// Which catalog feeds to read, in display order. Nothing writes this yet; topic selection will.
    static let feedIDsKey = "NewsFeedIDs"
    static let cacheKey = "NewsCache"
    /// How many downloaded items to keep per feed for rotation between fetches.
    static let maxCachedItems = 20
    /// How many shown ids to remember before the oldest are forgotten: every
    /// feed's whole rotation pool, so a story is not forgotten before the rest
    /// of its feed has had a turn.
    static let recentlyShownLimit = 40

    /// The saved selection in saved order, ignoring unknown and repeated ids.
    /// Falls back to `NewsFeed.defaultSelection` when nothing usable is saved.
    static func loadFeeds(userDefaults: UserDefaults = .standard) -> [NewsFeed] {
        var feeds: [NewsFeed] = []
        for id in userDefaults.stringArray(forKey: feedIDsKey) ?? [] where !feeds.contains(where: { $0.id == id }) {
            if let feed = NewsFeed.catalog.first(where: { $0.id == id }) {
                feeds.append(feed)
            }
        }
        return feeds.isEmpty ? NewsFeed.defaultSelection : feeds
    }

    static func saveFeedIDs(_ ids: [String], userDefaults: UserDefaults = .standard) {
        userDefaults.set(ids, forKey: feedIDsKey)
    }

    /// A cache written by an older layout fails to decode and reads as absent,
    /// so the next refresh simply downloads and overwrites it.
    static func loadCache(userDefaults: UserDefaults = .standard) -> NewsCache? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(NewsCache.self, from: data)
    }

    static func saveCache(_ cache: NewsCache, userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    static func clearCache(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: cacheKey)
    }
}
