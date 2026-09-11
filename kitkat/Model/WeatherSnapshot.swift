//
//  WeatherSnapshot.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation

/// A single current-conditions reading shown on the break window.
/// Marked `nonisolated` so it can be decoded on the network client's background
/// queue under the project's main-actor default isolation.
nonisolated struct WeatherSnapshot: Codable, Equatable {
    let temperatureCelsius: Double
    let condition: WeatherCondition
    let locationName: String
    let fetchedAt: Date

    var temperature: Measurement<UnitTemperature> {
        Measurement(value: temperatureCelsius, unit: .celsius)
    }

    /// Formats the temperature in the unit the given locale expects for weather,
    /// e.g. "72°F" for en_US and "22°C" for en_GB.
    func formattedTemperature(locale: Locale = .current) -> String {
        temperature.formatted(
            .measurement(width: .abbreviated, usage: .weather, numberFormatStyle: .number.precision(.fractionLength(0)))
            .locale(locale)
        )
    }
}

/// A human-readable weather condition paired with the SF Symbol used to draw it.
nonisolated struct WeatherCondition: Codable, Equatable {
    /// The WMO weather interpretation code reported by the data source.
    let code: Int
    let description: String
    let systemImage: String
}

extension WeatherCondition {
    static let unknown = WeatherCondition(code: -1, description: "Conditions unavailable", systemImage: "cloud")

    /// Maps a WMO weather interpretation code (as used by Open-Meteo) to a
    /// description and SF Symbol. Clear and partly cloudy codes switch to moon
    /// symbols at night.
    static func from(wmoCode code: Int, isDay: Bool = true) -> WeatherCondition {
        let description: String
        let systemImage: String

        switch code {
        case 0:
            description = "Clear sky"
            systemImage = isDay ? "sun.max" : "moon.stars"
        case 1:
            description = "Mainly clear"
            systemImage = isDay ? "sun.max" : "moon.stars"
        case 2:
            description = "Partly cloudy"
            systemImage = isDay ? "cloud.sun" : "cloud.moon"
        case 3:
            description = "Overcast"
            systemImage = "cloud"
        case 45:
            description = "Fog"
            systemImage = "cloud.fog"
        case 48:
            description = "Icy fog"
            systemImage = "cloud.fog"
        case 51:
            description = "Light drizzle"
            systemImage = "cloud.drizzle"
        case 53:
            description = "Drizzle"
            systemImage = "cloud.drizzle"
        case 55:
            description = "Heavy drizzle"
            systemImage = "cloud.drizzle"
        case 56:
            description = "Light freezing drizzle"
            systemImage = "cloud.sleet"
        case 57:
            description = "Freezing drizzle"
            systemImage = "cloud.sleet"
        case 61:
            description = "Light rain"
            systemImage = "cloud.rain"
        case 63:
            description = "Rain"
            systemImage = "cloud.rain"
        case 65:
            description = "Heavy rain"
            systemImage = "cloud.heavyrain"
        case 66:
            description = "Light freezing rain"
            systemImage = "cloud.sleet"
        case 67:
            description = "Freezing rain"
            systemImage = "cloud.sleet"
        case 71:
            description = "Light snow"
            systemImage = "cloud.snow"
        case 73:
            description = "Snow"
            systemImage = "cloud.snow"
        case 75:
            description = "Heavy snow"
            systemImage = "cloud.snow"
        case 77:
            description = "Snow grains"
            systemImage = "snowflake"
        case 80:
            description = "Light showers"
            systemImage = isDay ? "cloud.sun.rain" : "cloud.moon.rain"
        case 81:
            description = "Showers"
            systemImage = "cloud.rain"
        case 82:
            description = "Heavy showers"
            systemImage = "cloud.heavyrain"
        case 85:
            description = "Light snow showers"
            systemImage = "cloud.snow"
        case 86:
            description = "Heavy snow showers"
            systemImage = "cloud.snow"
        case 95:
            description = "Thunderstorm"
            systemImage = "cloud.bolt"
        case 96:
            description = "Thunderstorm with hail"
            systemImage = "cloud.bolt.rain"
        case 99:
            description = "Thunderstorm with heavy hail"
            systemImage = "cloud.bolt.rain"
        default:
            return WeatherCondition(code: code, description: unknown.description, systemImage: unknown.systemImage)
        }

        return WeatherCondition(code: code, description: description, systemImage: systemImage)
    }
}
