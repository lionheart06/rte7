//
//  WeatherLocationSettingsModelTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation
import Testing
@testable import kitkat

private let austin = GeocodedLocation(name: "Austin", latitude: 30.27, longitude: -97.74, region: "Texas", country: "United States")
private let denver = GeocodedLocation(name: "Denver", latitude: 39.74, longitude: -104.99, region: "Colorado", country: "United States")
private let reading = WeatherSnapshot(temperatureCelsius: 30, condition: .from(wmoCode: 1), locationName: "Austin, Texas", fetchedAt: Date(timeIntervalSince1970: 1_757_457_900))

@MainActor
struct WeatherLocationSettingsModelTests {
    private func makeModel(provider: FakeWeatherProvider) throws -> (WeatherLocationSettingsModel, UserDefaults, String) {
        let (defaults, suite) = try makeWeatherTestDefaults()
        return (WeatherLocationSettingsModel(provider: provider, userDefaults: defaults), defaults, suite)
    }

    @Test func blankQueryIsIdleAndMakesNoCalls() async throws {
        let provider = FakeWeatherProvider(geocode: .success(austin), weather: .failure(FakeError()))
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp("  \n")

        #expect(model.status == .idle)
        #expect(provider.geocodeQueries.isEmpty)
    }

    @Test func resolvedCityIsReportedAndCoordinatesCached() async throws {
        let provider = FakeWeatherProvider(geocode: .success(austin), weather: .failure(FakeError()))
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp(" Austin ")

        #expect(model.status == .found("Austin, Texas"))
        #expect(provider.geocodeQueries == ["Austin"])
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults) == WeatherCache(query: "Austin", location: austin, snapshot: nil))
    }

    @Test func reResolvingTheSameCityKeepsItsCachedReading() async throws {
        let provider = FakeWeatherProvider(geocode: .success(austin), weather: .failure(FakeError()))
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        WeatherCacheStore.saveCache(WeatherCache(query: "austin", location: austin, snapshot: reading), userDefaults: defaults)

        await model.lookUp("Austin")

        #expect(WeatherCacheStore.loadCache(userDefaults: defaults)?.snapshot == reading)
    }

    @Test func changingCityReplacesCacheAndDropsOldReading() async throws {
        let provider = FakeWeatherProvider(geocode: .success(denver), weather: .failure(FakeError()))
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        WeatherCacheStore.saveCache(WeatherCache(query: "Austin", location: austin, snapshot: reading), userDefaults: defaults)

        await model.lookUp("Denver")

        #expect(model.status == .found("Denver, Colorado"))
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults) == WeatherCache(query: "Denver", location: denver, snapshot: nil))
    }

    @Test func unknownCityReportsFailureAndLeavesCacheAlone() async throws {
        let provider = FakeWeatherProvider(geocode: .failure(OpenMeteoError.locationNotFound("Atlantis")), weather: .failure(FakeError()))
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        let existing = WeatherCache(query: "Austin", location: austin, snapshot: reading)
        WeatherCacheStore.saveCache(existing, userDefaults: defaults)

        await model.lookUp("Atlantis")

        guard case .failed(let message) = model.status else {
            Issue.record("expected failed status, got \(model.status)")
            return
        }
        #expect(message.contains("Atlantis"))
        #expect(WeatherCacheStore.loadCache(userDefaults: defaults) == existing)
    }

    @Test func repeatedLookupOfResolvedCityDoesNotHitNetworkAgain() async throws {
        let provider = FakeWeatherProvider(geocode: .success(austin), weather: .failure(FakeError()))
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }

        await model.lookUp("Austin")
        await model.lookUp("austin ")

        #expect(provider.geocodeQueries.count == 1)
        #expect(model.status == .found("Austin, Texas"))
    }

    @Test func initialStatusComesFromMatchingCache() throws {
        let provider = FakeWeatherProvider(geocode: .failure(FakeError()), weather: .failure(FakeError()))
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        WeatherCacheStore.saveQuery("Austin", userDefaults: defaults)
        WeatherCacheStore.saveCache(WeatherCache(query: "austin", location: austin, snapshot: nil), userDefaults: defaults)

        model.loadInitialStatus()

        #expect(model.status == .found("Austin, Texas"))
        #expect(provider.geocodeQueries.isEmpty)
    }

    @Test func initialStatusIsIdleWhenCacheIsForAnotherCity() throws {
        let provider = FakeWeatherProvider(geocode: .failure(FakeError()), weather: .failure(FakeError()))
        let (model, defaults, suite) = try makeModel(provider: provider)
        defer { defaults.removePersistentDomain(forName: suite) }
        WeatherCacheStore.saveQuery("Denver", userDefaults: defaults)
        WeatherCacheStore.saveCache(WeatherCache(query: "Austin", location: austin, snapshot: nil), userDefaults: defaults)

        model.loadInitialStatus()

        #expect(model.status == .idle)
    }
}
