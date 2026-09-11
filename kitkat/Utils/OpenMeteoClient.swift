//
//  OpenMeteoClient.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation

// MARK: - Domain types

/// A place resolved from a user-typed query, with the coordinates needed for a
/// forecast request and a short label for display.
nonisolated struct GeocodedLocation: Codable, Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let region: String?
    let country: String?

    /// "Austin, Texas" when a region is known, otherwise "Austin, United States",
    /// falling back to just the name.
    var displayName: String {
        if let region, !region.isEmpty, region != name {
            return "\(name), \(region)"
        }
        if let country, !country.isEmpty, country != name {
            return "\(name), \(country)"
        }
        return name
    }
}

/// Anything that can turn a query into coordinates and coordinates into a
/// current-conditions reading. Lets the view model be tested with a fake.
protocol WeatherProviding {
    func geocode(_ query: String) async throws -> GeocodedLocation
    func currentWeather(at location: GeocodedLocation) async throws -> WeatherSnapshot
}

nonisolated enum OpenMeteoError: LocalizedError, Equatable {
    case emptyQuery
    case invalidURL
    case locationNotFound(String)

    var errorDescription: String? {
        switch self {
        case .emptyQuery:
            return "Enter a city to show the weather."
        case .invalidURL:
            return "Couldn’t build the weather request."
        case .locationNotFound(let query):
            return "Couldn’t find a place called “\(query)”."
        }
    }
}

// MARK: - Wire format

/// Response from https://geocoding-api.open-meteo.com/v1/search.
/// `results` is omitted entirely when nothing matches.
nonisolated struct OpenMeteoGeocodingResponse: Codable {
    struct Result: Codable {
        let name: String
        let latitude: Double
        let longitude: Double
        let admin1: String?
        let country: String?
    }

    let results: [Result]?
}

/// Response from https://api.open-meteo.com/v1/forecast with
/// `current=temperature_2m,weather_code,is_day`.
nonisolated struct OpenMeteoForecastResponse: Codable {
    struct Current: Codable {
        let time: String
        let temperature_2m: Double
        let weather_code: Int
        let is_day: Int
    }

    let current: Current
}

// MARK: - Pure request/response helpers

/// URL construction and response mapping for Open-Meteo. Kept free of any
/// networking so it can be unit tested directly.
nonisolated enum OpenMeteoAPI {
    static let geocodingBaseURL = "https://geocoding-api.open-meteo.com"
    static let forecastBaseURL = "https://api.open-meteo.com"

    /// Fields requested from the forecast endpoint, in the order Open-Meteo echoes them.
    static let currentFields = ["temperature_2m", "weather_code", "is_day"]

    static func geocodingURL(for query: String) -> URL? {
        var components = URLComponents(string: geocodingBaseURL)
        components?.path = "/v1/search"
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components?.url
    }

    static func forecastURL(latitude: Double, longitude: Double) -> URL? {
        var components = URLComponents(string: forecastBaseURL)
        components?.path = "/v1/forecast"
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(format: "%.4f", latitude)),
            URLQueryItem(name: "longitude", value: String(format: "%.4f", longitude)),
            URLQueryItem(name: "current", value: currentFields.joined(separator: ",")),
        ]
        return components?.url
    }

    static func makeLocation(from result: OpenMeteoGeocodingResponse.Result) -> GeocodedLocation {
        GeocodedLocation(
            name: result.name,
            latitude: result.latitude,
            longitude: result.longitude,
            region: result.admin1,
            country: result.country
        )
    }

    static func makeSnapshot(from response: OpenMeteoForecastResponse,
                             location: GeocodedLocation,
                             fetchedAt: Date = Date()) -> WeatherSnapshot {
        WeatherSnapshot(
            temperatureCelsius: response.current.temperature_2m,
            condition: .from(wmoCode: response.current.weather_code, isDay: response.current.is_day == 1),
            locationName: location.displayName,
            fetchedAt: fetchedAt
        )
    }
}

// MARK: - Client

/// Fetches current conditions from Open-Meteo, which is free and needs no API key.
final class OpenMeteoClient: WeatherProviding {
    private let apiClient: RESTAPIClient

    init(apiClient: RESTAPIClient = RESTAPIClient(baseURL: OpenMeteoAPI.forecastBaseURL)) {
        self.apiClient = apiClient
    }

    func geocode(_ query: String) async throws -> GeocodedLocation {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw OpenMeteoError.emptyQuery }
        guard let url = OpenMeteoAPI.geocodingURL(for: trimmed) else { throw OpenMeteoError.invalidURL }

        let response: OpenMeteoGeocodingResponse = try await apiClient.request(url.absoluteString)
        guard let first = response.results?.first else { throw OpenMeteoError.locationNotFound(trimmed) }
        return OpenMeteoAPI.makeLocation(from: first)
    }

    func currentWeather(at location: GeocodedLocation) async throws -> WeatherSnapshot {
        guard let url = OpenMeteoAPI.forecastURL(latitude: location.latitude, longitude: location.longitude) else {
            throw OpenMeteoError.invalidURL
        }

        let response: OpenMeteoForecastResponse = try await apiClient.request(url.absoluteString)
        return OpenMeteoAPI.makeSnapshot(from: response, location: location)
    }
}
