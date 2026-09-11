//
//  WeatherTestSupport.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation
@testable import kitkat

func makeWeatherTestDefaults() throws -> (defaults: UserDefaults, suiteName: String) {
    let suiteName = "kitkat.tests.weather.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        throw NSError(domain: "kitkatTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create suite"])
    }
    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
}

struct FakeError: LocalizedError {
    var errorDescription: String? { "Network is down" }
}

@MainActor
final class FakeWeatherProvider: WeatherProviding {
    var geocodeResult: Result<GeocodedLocation, Error>
    var weatherResult: Result<WeatherSnapshot, Error>
    private(set) var geocodeQueries: [String] = []
    private(set) var weatherLocations: [GeocodedLocation] = []

    init(geocode: Result<GeocodedLocation, Error>, weather: Result<WeatherSnapshot, Error>) {
        geocodeResult = geocode
        weatherResult = weather
    }

    func geocode(_ query: String) async throws -> GeocodedLocation {
        geocodeQueries.append(query)
        return try geocodeResult.get()
    }

    func currentWeather(at location: GeocodedLocation) async throws -> WeatherSnapshot {
        weatherLocations.append(location)
        return try weatherResult.get()
    }
}
