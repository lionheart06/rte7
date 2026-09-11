//
//  OpenMeteoClientTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation
import Testing
@testable import kitkat

// Captured from the live endpoints on 2026-09-09, trimmed to the fields the app reads
// plus a few it ignores, so decoding is proven tolerant of extra keys.
private let geocodingFixture = """
{"results":[{"id":4671654,"name":"Austin","latitude":30.26715,"longitude":-97.74306,"elevation":149.0,\
"feature_code":"PPLA","country_code":"US","timezone":"America/Chicago","population":974447,\
"country":"United States","admin1":"Texas","admin2":"Travis"}],"generationtime_ms":0.469}
"""

private let geocodingNoMatchFixture = """
{"generationtime_ms":0.47135353}
"""

private let forecastFixture = """
{"latitude":30.269146,"longitude":-97.75338,"generationtime_ms":0.187,"utc_offset_seconds":0,\
"timezone":"GMT","timezone_abbreviation":"GMT","elevation":157.0,\
"current_units":{"time":"iso8601","interval":"seconds","temperature_2m":"°C","weather_code":"wmo code","is_day":""},\
"current":{"time":"2026-09-09T22:45","interval":900,"temperature_2m":35.2,"weather_code":3,"is_day":1}}
"""

private func queryItems(of url: URL?) -> [String: String] {
    guard let url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

struct OpenMeteoURLTests {
    @Test func geocodingURLTargetsSearchEndpointWithSingleResult() {
        let url = OpenMeteoAPI.geocodingURL(for: "Austin")
        #expect(url?.scheme == "https")
        #expect(url?.host() == "geocoding-api.open-meteo.com")
        #expect(url?.path() == "/v1/search")

        let items = queryItems(of: url)
        #expect(items["name"] == "Austin")
        #expect(items["count"] == "1")
        #expect(items["format"] == "json")
    }

    @Test func geocodingURLPercentEncodesSpaces() {
        let url = OpenMeteoAPI.geocodingURL(for: "San Francisco")
        #expect(url?.absoluteString.contains("name=San%20Francisco") == true)
        #expect(queryItems(of: url)["name"] == "San Francisco")
    }

    @Test func forecastURLCarriesCoordinatesAndCurrentFields() {
        let url = OpenMeteoAPI.forecastURL(latitude: 30.26715, longitude: -97.74306)
        #expect(url?.host() == "api.open-meteo.com")
        #expect(url?.path() == "/v1/forecast")

        let items = queryItems(of: url)
        #expect(items["latitude"] == "30.2672")
        #expect(items["longitude"] == "-97.7431")
        #expect(items["current"] == "temperature_2m,weather_code,is_day")
    }

    @Test func forecastURLUsesDotDecimalSeparatorRegardlessOfLocale() {
        // String(format:) without a locale is POSIX, so this must hold on a de_DE Mac too.
        let url = OpenMeteoAPI.forecastURL(latitude: 48.1374, longitude: 11.5755)
        #expect(queryItems(of: url)["latitude"] == "48.1374")
        #expect(url?.absoluteString.contains(",") == true, "only the current= list should contain commas")
        #expect(queryItems(of: url)["longitude"]?.contains(",") == false)
    }
}

struct OpenMeteoDecodingTests {
    @Test func decodesGeocodingResultAndMapsToLocation() throws {
        let response = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: Data(geocodingFixture.utf8))
        let first = try #require(response.results?.first)
        let location = OpenMeteoAPI.makeLocation(from: first)

        #expect(location.name == "Austin")
        #expect(location.latitude == 30.26715)
        #expect(location.longitude == -97.74306)
        #expect(location.region == "Texas")
        #expect(location.country == "United States")
        #expect(location.displayName == "Austin, Texas")
    }

    @Test func decodesGeocodingResponseWithNoMatches() throws {
        let response = try JSONDecoder().decode(OpenMeteoGeocodingResponse.self, from: Data(geocodingNoMatchFixture.utf8))
        #expect(response.results == nil)
    }

    @Test func decodesForecastCurrentBlock() throws {
        let response = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: Data(forecastFixture.utf8))
        #expect(response.current.temperature_2m == 35.2)
        #expect(response.current.weather_code == 3)
        #expect(response.current.is_day == 1)
        #expect(response.current.time == "2026-09-09T22:45")
    }

    @Test func mapsForecastToSnapshotUsingLocationLabelAndDaylight() throws {
        let response = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: Data(forecastFixture.utf8))
        let location = GeocodedLocation(name: "Austin", latitude: 30.27, longitude: -97.74, region: "Texas", country: "United States")
        let now = Date(timeIntervalSince1970: 1_757_457_900)

        let snapshot = OpenMeteoAPI.makeSnapshot(from: response, location: location, fetchedAt: now)

        #expect(snapshot.temperatureCelsius == 35.2)
        #expect(snapshot.condition == WeatherCondition.from(wmoCode: 3, isDay: true))
        #expect(snapshot.locationName == "Austin, Texas")
        #expect(snapshot.fetchedAt == now)
    }

    @Test func nightFlagFlowsThroughToCondition() throws {
        let night = forecastFixture.replacingOccurrences(of: "\"weather_code\":3,\"is_day\":1", with: "\"weather_code\":0,\"is_day\":0")
        let response = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: Data(night.utf8))
        let location = GeocodedLocation(name: "Austin", latitude: 0, longitude: 0, region: nil, country: nil)

        let snapshot = OpenMeteoAPI.makeSnapshot(from: response, location: location)
        #expect(snapshot.condition.systemImage == "moon.stars")
    }
}

struct GeocodedLocationDisplayNameTests {
    @Test func prefersRegionOverCountry() {
        let location = GeocodedLocation(name: "Austin", latitude: 0, longitude: 0, region: "Texas", country: "United States")
        #expect(location.displayName == "Austin, Texas")
    }

    @Test func fallsBackToCountryWhenRegionMissing() {
        let location = GeocodedLocation(name: "Singapore", latitude: 0, longitude: 0, region: nil, country: "Singapore")
        #expect(location.displayName == "Singapore")

        let monaco = GeocodedLocation(name: "Monte Carlo", latitude: 0, longitude: 0, region: nil, country: "Monaco")
        #expect(monaco.displayName == "Monte Carlo, Monaco")
    }

    @Test func skipsRegionThatRepeatsTheName() {
        let location = GeocodedLocation(name: "Berlin", latitude: 0, longitude: 0, region: "Berlin", country: "Germany")
        #expect(location.displayName == "Berlin, Germany")
    }
}

struct OpenMeteoClientTests {
    @Test @MainActor func geocodeRejectsBlankQueryBeforeAnyNetworkCall() async {
        let client = OpenMeteoClient()
        await #expect(throws: OpenMeteoError.emptyQuery) {
            _ = try await client.geocode("   \n")
        }
    }

    @Test func emptyQueryErrorHasUserFacingText() {
        #expect(OpenMeteoError.emptyQuery.errorDescription == "Enter a city to show the weather.")
        #expect(OpenMeteoError.locationNotFound("Atlantis").errorDescription?.contains("Atlantis") == true)
    }
}
