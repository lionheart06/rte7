//
//  WeatherLocationSettingsModel.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation
import Combine

/// Backs the city field in the main window. Confirms that a typed city resolves
/// and stores its coordinates so the break window can skip geocoding.
final class WeatherLocationSettingsModel: ObservableObject {
    enum Status: Equatable {
        case idle
        case checking
        /// The city resolved; carries the label shown to the user, e.g. "Austin, Texas".
        case found(String)
        case failed(String)
    }

    @Published private(set) var status: Status = .idle

    private let provider: any WeatherProviding
    private let userDefaults: UserDefaults
    private var lastResolvedQuery: String?

    init(provider: any WeatherProviding = OpenMeteoClient(), userDefaults: UserDefaults = .standard) {
        self.provider = provider
        self.userDefaults = userDefaults
    }

    /// Shows the previously resolved place for the saved city without a network call.
    func loadInitialStatus() {
        let query = WeatherCacheStore.loadQuery(userDefaults: userDefaults)
        let cache = WeatherCacheStore.loadCache(userDefaults: userDefaults)
        if let cache, WeatherCacheStore.cache(cache, matches: query) {
            lastResolvedQuery = WeatherCacheStore.normalizedQuery(query)
            status = .found(cache.location.displayName)
        } else {
            lastResolvedQuery = nil
            status = .idle
        }
    }

    /// Resolves the typed city. A blank query resets to idle, and a query that
    /// already resolved is not looked up again.
    func lookUp(_ query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastResolvedQuery = nil
            status = .idle
            return
        }

        let normalized = WeatherCacheStore.normalizedQuery(trimmed)
        if case .found = status, normalized == lastResolvedQuery {
            return
        }

        status = .checking
        do {
            let location = try await provider.geocode(trimmed)

            // Keep an existing reading for the same city; only the coordinates are new.
            let existing = WeatherCacheStore.loadCache(userDefaults: userDefaults)
            let snapshot = WeatherCacheStore.cache(existing, matches: trimmed) ? existing?.snapshot : nil
            WeatherCacheStore.saveCache(
                WeatherCache(query: trimmed, location: location, snapshot: snapshot),
                userDefaults: userDefaults
            )

            lastResolvedQuery = normalized
            status = .found(location.displayName)
        } catch {
            lastResolvedQuery = nil
            status = .failed(error.localizedDescription)
        }
    }
}
