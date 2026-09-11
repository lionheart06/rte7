//
//  WeatherCacheStore.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation

/// The city the user typed, the place it resolved to, and the last reading for it.
/// Persisted so the break window can show something instantly and skip
/// re-geocoding until the query changes.
nonisolated struct WeatherCache: Codable, Equatable {
    let query: String
    let location: GeocodedLocation
    let snapshot: WeatherSnapshot?
}

nonisolated struct WeatherCacheStore {
    /// The city typed in the main window. ContentView binds to this key with @AppStorage.
    static let locationQueryKey = "WeatherLocationQuery"
    static let cacheKey = "WeatherCache"

    static func loadQuery(userDefaults: UserDefaults = .standard) -> String {
        userDefaults.string(forKey: locationQueryKey) ?? ""
    }

    static func saveQuery(_ query: String, userDefaults: UserDefaults = .standard) {
        userDefaults.set(query, forKey: locationQueryKey)
    }

    static func loadCache(userDefaults: UserDefaults = .standard) -> WeatherCache? {
        guard let data = userDefaults.data(forKey: cacheKey) else { return nil }
        return try? JSONDecoder().decode(WeatherCache.self, from: data)
    }

    static func saveCache(_ cache: WeatherCache, userDefaults: UserDefaults = .standard) {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        userDefaults.set(data, forKey: cacheKey)
    }

    static func clearCache(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: cacheKey)
    }

    /// Collapses whitespace and case so "Austin " and "austin" hit the same cache entry.
    static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// True when a cache entry was produced for the given query.
    static func cache(_ cache: WeatherCache?, matches query: String) -> Bool {
        guard let cache else { return false }
        return normalizedQuery(cache.query) == normalizedQuery(query)
    }
}
