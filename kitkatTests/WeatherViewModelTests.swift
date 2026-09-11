//
//  WeatherViewModelTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation
import Combine
import Testing
@testable import kitkat

// MARK: - Fixtures

private let austin = GeocodedLocation(name: "Austin", latitude: 30.27, longitude: -97.74, region: "Texas", country: "United States")
private let denver = GeocodedLocation(name: "Denver", latitude: 39.74, longitude: -104.99, region: "Colorado", country: "United States")
private let clock = Date(timeIntervalSince1970: 1_757_457_900)

private func snapshot(celsius: Double, fetchedAt: Date, location: GeocodedLocation = austin) -> WeatherSnapshot {
    WeatherSnapshot(temperatureCelsius: celsius, condition: .from(wmoCode: 1), locationName: location.displayName, fetchedAt: fetchedAt)
}

/// Records every state the view model publishes so tests can assert on the loading transition.
@MainActor
private final class StateRecorder {
    private(set) var states: [WeatherViewModel.State] = []
    private var cancellable: AnyCancellable?

    init(_ viewModel: WeatherViewModel) {
        cancellable = viewModel.$state.dropFirst().sink { [weak self] in self?.states.append($0) }
    }
}

// MARK: - Store

struct WeatherCacheStoreTests {
    @Test func cacheRoundTripsThroughUserDefaults() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        let cache = WeatherCache(query: "Austin", location: austin, snapshot: snapshot(celsius: 30, fetchedAt: clock))
        WeatherCacheStore.saveCache(cache, userDefaults: defaults)
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults) == cache)

        WeatherCacheStore.clearCache(userDefaults: defaults)
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults) == nil)
    }

    @Test func queryDefaultsToEmptyString() throws {
        let (defaults, suite) = try makeWeatherTestDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }

        #expect(WeatherCacheStore.loadQuery(userDefaults: defaults) == "")
        WeatherCacheStore.saveQuery("Austin", userDefaults: defaults)
        #expect(WeatherCacheStore.loadQuery(userDefaults: defaults) == "Austin")
    }

    @Test func matchingIgnoresCaseAndSurroundingWhitespace() {
        let cache = WeatherCache(query: "Austin", location: austin, snapshot: nil)
        #expect(WeatherCacheStore.cache(cache, matches: "  austin\n"))
        #expect(!WeatherCacheStore.cache(cache, matches: "Denver"))
        #expect(!WeatherCacheStore.cache(nil, matches: "Austin"))
    }
}

// MARK: - View model

@MainActor
struct WeatherViewModelTests {
    private func makeViewModel(
        query: String?,
        cache: WeatherCache?,
        provider: FakeWeatherProvider,
        now: Date = clock
    ) throws -> (WeatherViewModel, UserDefaults, String) {
        let (defaults, suite) = try makeWeatherTestDefaults()
        if let query { WeatherCacheStore.saveQuery(query, userDefaults: defaults) }
        if let cache { WeatherCacheStore.saveCache(cache, userDefaults: defaults) }
        let viewModel = WeatherViewModel(provider: provider, userDefaults: defaults, maxAge: 15 * 60, now: { now })
        return (viewModel, defaults, suite)
    }

    @Test func blankQueryNeedsLocationAndMakesNoCalls() async throws {
        let provider = FakeWeatherProvider(geocode: .success(austin), weather: .success(snapshot(celsius: 30, fetchedAt: clock)))
        let (viewModel, defaults, suite) = try makeViewModel(query: "   ", cache: nil, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .needsLocation)
        #expect(provider.geocodeQueries.isEmpty)
        #expect(provider.weatherLocations.isEmpty)
    }

    @Test func firstLoadGeocodesFetchesAndCaches() async throws {
        let fresh = snapshot(celsius: 31, fetchedAt: clock)
        let provider = FakeWeatherProvider(geocode: .success(austin), weather: .success(fresh))
        let (viewModel, defaults, suite) = try makeViewModel(query: "Austin", cache: nil, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loading(previous: nil), .loaded(fresh)])
        #expect(provider.geocodeQueries == ["Austin"])
        #expect(provider.weatherLocations == [austin])
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults) == WeatherCache(query: "Austin", location: austin, snapshot: fresh))
    }

    @Test func freshCacheIsServedWithoutNetwork() async throws {
        let cached = snapshot(celsius: 29, fetchedAt: clock.addingTimeInterval(-5 * 60))
        let provider = FakeWeatherProvider(geocode: .failure(FakeError()), weather: .failure(FakeError()))
        let cache = WeatherCache(query: "Austin", location: austin, snapshot: cached)
        let (viewModel, defaults, suite) = try makeViewModel(query: "Austin", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .loaded(cached))
        #expect(provider.geocodeQueries.isEmpty)
        #expect(provider.weatherLocations.isEmpty)
    }

    @Test func staleCacheShowsPreviousWhileRefetchingAndSkipsGeocoding() async throws {
        let stale = snapshot(celsius: 25, fetchedAt: clock.addingTimeInterval(-40 * 60))
        let fresh = snapshot(celsius: 33, fetchedAt: clock)
        let provider = FakeWeatherProvider(geocode: .failure(FakeError()), weather: .success(fresh))
        let cache = WeatherCache(query: "Austin", location: austin, snapshot: stale)
        let (viewModel, defaults, suite) = try makeViewModel(query: "austin ", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loading(previous: stale), .loaded(fresh)])
        #expect(provider.geocodeQueries.isEmpty, "cached coordinates should be reused for the same city")
        #expect(provider.weatherLocations == [austin])
    }

    @Test func changedQueryDiscardsOldCacheAndGeocodesAgain() async throws {
        let old = snapshot(celsius: 25, fetchedAt: clock)
        let fresh = snapshot(celsius: 18, fetchedAt: clock, location: denver)
        let provider = FakeWeatherProvider(geocode: .success(denver), weather: .success(fresh))
        let cache = WeatherCache(query: "Austin", location: austin, snapshot: old)
        let (viewModel, defaults, suite) = try makeViewModel(query: "Denver", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let recorder = StateRecorder(viewModel)

        await viewModel.refresh()

        #expect(recorder.states == [.loading(previous: nil), .loaded(fresh)])
        #expect(provider.geocodeQueries == ["Denver"])
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults)?.location == denver)
    }

    @Test func forceRefreshBypassesFreshCache() async throws {
        let cached = snapshot(celsius: 29, fetchedAt: clock.addingTimeInterval(-60))
        let fresh = snapshot(celsius: 30, fetchedAt: clock)
        let provider = FakeWeatherProvider(geocode: .failure(FakeError()), weather: .success(fresh))
        let cache = WeatherCache(query: "Austin", location: austin, snapshot: cached)
        let (viewModel, defaults, suite) = try makeViewModel(query: "Austin", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh(force: true)

        #expect(viewModel.state == .loaded(fresh))
        #expect(provider.weatherLocations.count == 1)
    }

    @Test func fetchFailureKeepsPreviousReading() async throws {
        let stale = snapshot(celsius: 25, fetchedAt: clock.addingTimeInterval(-40 * 60))
        let provider = FakeWeatherProvider(geocode: .success(austin), weather: .failure(FakeError()))
        let cache = WeatherCache(query: "Austin", location: austin, snapshot: stale)
        let (viewModel, defaults, suite) = try makeViewModel(query: "Austin", cache: cache, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        #expect(viewModel.state == .failed(message: "Network is down", previous: stale))
        #expect(viewModel.state.snapshot == stale)
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults)?.snapshot == stale, "a failed fetch must not clobber the cached reading")
    }

    @Test func unknownPlaceSurfacesNotFoundMessage() async throws {
        let provider = FakeWeatherProvider(geocode: .failure(OpenMeteoError.locationNotFound("Atlantis")), weather: .failure(FakeError()))
        let (viewModel, defaults, suite) = try makeViewModel(query: "Atlantis", cache: nil, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        guard case .failed(let message, let previous) = viewModel.state else {
            Issue.record("expected failed state, got \(viewModel.state)")
            return
        }
        #expect(message.contains("Atlantis"))
        #expect(previous == nil)
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults) == nil)
    }

    @Test func coordinatesAreCachedEvenWhenWeatherCallFails() async throws {
        let provider = FakeWeatherProvider(geocode: .success(austin), weather: .failure(FakeError()))
        let (viewModel, defaults, suite) = try makeViewModel(query: "Austin", cache: nil, provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await viewModel.refresh()

        let cache = WeatherCacheStore.loadCache(userDefaults: defaults)
        #expect(cache?.location == austin)
        #expect(cache?.snapshot == nil)

        // Second attempt reuses the coordinates.
        provider.weatherResult = .success(snapshot(celsius: 31, fetchedAt: clock))
        await viewModel.refresh()
        #expect(provider.geocodeQueries == ["Austin"])
        #expect(provider.weatherLocations.count == 2)
    }

    @Test func stateExposesBestAvailableSnapshot() {
        let reading = snapshot(celsius: 20, fetchedAt: clock)
        #expect(WeatherViewModel.State.needsLocation.snapshot == nil)
        #expect(WeatherViewModel.State.loading(previous: nil).snapshot == nil)
        #expect(WeatherViewModel.State.loading(previous: reading).snapshot == reading)
        #expect(WeatherViewModel.State.loaded(reading).snapshot == reading)
        #expect(WeatherViewModel.State.failed(message: "x", previous: reading).snapshot == reading)
    }
}
