//
//  WeatherTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/9/26.
//

import Foundation
import Testing
@testable import kitkat

struct WeatherConditionTests {
    @Test func clearSkyUsesSunDuringTheDay() {
        let condition = WeatherCondition.from(wmoCode: 0, isDay: true)
        #expect(condition.code == 0)
        #expect(condition.description == "Clear sky")
        #expect(condition.systemImage == "sun.max")
    }

    @Test func clearSkyUsesMoonAtNight() {
        let condition = WeatherCondition.from(wmoCode: 0, isDay: false)
        #expect(condition.description == "Clear sky")
        #expect(condition.systemImage == "moon.stars")
    }

    @Test func partlyCloudySwitchesSymbolWithDaylight() {
        #expect(WeatherCondition.from(wmoCode: 2, isDay: true).systemImage == "cloud.sun")
        #expect(WeatherCondition.from(wmoCode: 2, isDay: false).systemImage == "cloud.moon")
    }

    @Test func overcastIgnoresDaylight() {
        let day = WeatherCondition.from(wmoCode: 3, isDay: true)
        let night = WeatherCondition.from(wmoCode: 3, isDay: false)
        #expect(day == night)
        #expect(day.description == "Overcast")
        #expect(day.systemImage == "cloud")
    }

    @Test(arguments: [
        (45, "Fog", "cloud.fog"),
        (51, "Light drizzle", "cloud.drizzle"),
        (56, "Light freezing drizzle", "cloud.sleet"),
        (61, "Light rain", "cloud.rain"),
        (65, "Heavy rain", "cloud.heavyrain"),
        (71, "Light snow", "cloud.snow"),
        (77, "Snow grains", "snowflake"),
        (82, "Heavy showers", "cloud.heavyrain"),
        (95, "Thunderstorm", "cloud.bolt"),
        (99, "Thunderstorm with heavy hail", "cloud.bolt.rain"),
    ])
    func knownCodesMapToDescriptionAndSymbol(code: Int, description: String, systemImage: String) {
        let condition = WeatherCondition.from(wmoCode: code)
        #expect(condition.code == code)
        #expect(condition.description == description)
        #expect(condition.systemImage == systemImage)
    }

    @Test func everyDocumentedCodeHasASpecificMapping() {
        let documentedCodes = [0, 1, 2, 3, 45, 48, 51, 53, 55, 56, 57, 61, 63, 65, 66, 67,
                               71, 73, 75, 77, 80, 81, 82, 85, 86, 95, 96, 99]
        for code in documentedCodes {
            let condition = WeatherCondition.from(wmoCode: code)
            #expect(condition.description != WeatherCondition.unknown.description, "code \(code) fell through to the fallback")
        }
    }

    @Test func unknownCodeFallsBackButKeepsTheCode() {
        let condition = WeatherCondition.from(wmoCode: 42)
        #expect(condition.code == 42)
        #expect(condition.description == WeatherCondition.unknown.description)
        #expect(condition.systemImage == WeatherCondition.unknown.systemImage)
    }
}

struct WeatherSnapshotTests {
    private let sample = WeatherSnapshot(
        temperatureCelsius: 22.4,
        condition: .from(wmoCode: 2),
        locationName: "Austin",
        fetchedAt: Date(timeIntervalSince1970: 1_757_400_000)
    )

    @Test func temperatureIsExposedAsACelsiusMeasurement() {
        #expect(sample.temperature.unit == .celsius)
        #expect(sample.temperature.value == 22.4)
    }

    @Test func formatsInFahrenheitForUSLocale() {
        let text = sample.formattedTemperature(locale: Locale(identifier: "en_US"))
        #expect(text == "72°F")
    }

    @Test func formatsInCelsiusForUKLocale() {
        let text = sample.formattedTemperature(locale: Locale(identifier: "en_GB"))
        #expect(text == "22°C")
    }

    @Test func roundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(sample)
        let decoded = try JSONDecoder().decode(WeatherSnapshot.self, from: data)
        #expect(decoded == sample)
    }
}
