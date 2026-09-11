//
//  WeatherViewModel.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation
import Combine

/// Drives the weather tile on the break window. Reads the configured city from
/// UserDefaults, serves a recent cached reading without touching the network,
/// and otherwise geocodes (once per city) and fetches current conditions.
final class WeatherViewModel: ObservableObject {
    enum State: Equatable {
        /// No city configured yet.
        case needsLocation
        /// A fetch is in flight. `previous` is the last reading for the same city, if any.
        case loading(previous: WeatherSnapshot?)
        case loaded(WeatherSnapshot)
        /// The fetch failed. `previous` lets the tile keep showing the last good reading.
        case failed(message: String, previous: WeatherSnapshot?)

        /// The best reading available to display, if any.
        var snapshot: WeatherSnapshot? {
            switch self {
            case .needsLocation:
                return nil
            case .loading(let previous), .failed(_, let previous):
                return previous
            case .loaded(let snapshot):
                return snapshot
            }
        }
    }

    /// Readings younger than this are served from cache instead of refetched.
    static let defaultMaxAge: TimeInterval = 15 * 60

    @Published private(set) var state: State = .needsLocation

    private let provider: any WeatherProviding
    private let userDefaults: UserDefaults
    private let maxAge: TimeInterval
    private let now: () -> Date

    init(provider: any WeatherProviding = OpenMeteoClient(),
         userDefaults: UserDefaults = .standard,
         maxAge: TimeInterval = WeatherViewModel.defaultMaxAge,
         now: @escaping () -> Date = Date.init) {
        self.provider = provider
        self.userDefaults = userDefaults
        self.maxAge = maxAge
        self.now = now
    }

    /// Loads the reading for the configured city.
    /// - Parameter force: Skip the freshness check and always hit the network.
    func refresh(force: Bool = false) async {
        let query = WeatherCacheStore.loadQuery(userDefaults: userDefaults)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            state = .needsLocation
            return
        }

        let cache = WeatherCacheStore.loadCache(userDefaults: userDefaults)
        let cacheMatches = WeatherCacheStore.cache(cache, matches: query)
        let previous = cacheMatches ? cache?.snapshot : nil

        if !force, let previous, now().timeIntervalSince(previous.fetchedAt) < maxAge {
            state = .loaded(previous)
            return
        }

        state = .loading(previous: previous)

        do {
            let location: GeocodedLocation
            if cacheMatches, let cachedLocation = cache?.location {
                location = cachedLocation
            } else {
                location = try await provider.geocode(query)
                // Remember the coordinates even if the weather call below fails,
                // so the next attempt skips geocoding.
                WeatherCacheStore.saveCache(
                    WeatherCache(query: query, location: location, snapshot: nil),
                    userDefaults: userDefaults
                )
            }

            let snapshot = try await provider.currentWeather(at: location)
            WeatherCacheStore.saveCache(
                WeatherCache(query: query, location: location, snapshot: snapshot),
                userDefaults: userDefaults
            )
            state = .loaded(snapshot)
        } catch {
            state = .failed(message: error.localizedDescription, previous: previous)
        }
    }
}
