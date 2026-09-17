//
//  NewsStore.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation

/// The last downloaded headlines plus which ones recent breaks have shown, so
/// the tile can rotate through a feed instead of repeating its lead stories.
nonisolated struct NewsCache: Codable, Equatable {
    let feedID: String
    let items: [NewsItem]
    let fetchedAt: Date
    /// Oldest first; bounded by `NewsStore.recentlyShownLimit`.
    var recentlyShownIDs: [String]
}

nonisolated struct NewsStore {
    /// Which catalog feed to read. Nothing writes this yet; topic selection will.
    static let feedIDKey = "NewsFeedID"
    static let cacheKey = "NewsCache"
    /// How many downloaded items to keep for rotation between fetches.
    static let maxCachedItems = 20
    /// How many shown ids to remember before the oldest are forgotten.
    static let recentlyShownLimit = 30

    static func loadFeed(userDefaults: UserDefaults = .standard) -> NewsFeed {
        guard let id = userDefaults.string(forKey: feedIDKey),
              let feed = NewsFeed.catalog.first(where: { $0.id == id }) else { return .default }
        return feed
    }

    static func saveFeedID(_ id: String, userDefaults: UserDefaults = .standard) {
        userDefaults.set(id, forKey: feedIDKey)
    }

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
