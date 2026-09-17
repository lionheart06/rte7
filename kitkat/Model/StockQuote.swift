//
//  StockQuote.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation

/// A single price reading for one ticker, shown on the break window.
nonisolated struct StockQuote: Codable, Equatable {
    let symbol: String
    /// Filled in from the resolved symbol lookup; the quote endpoint itself carries no name.
    var companyName: String?
    let price: Double
    let change: Double
    /// Percent change from the previous close, in percent units (1.35 means +1.35%).
    let changePercent: Double
    let previousClose: Double
    /// Time of the last trade reported by the data source.
    let asOf: Date
    let fetchedAt: Date

    enum Direction: Equatable {
        case up, down, flat
    }

    var direction: Direction {
        if change > 0 { return .up }
        if change < 0 { return .down }
        return .flat
    }

    /// Free-tier Finnhub covers US listings, so prices are always US dollars.
    /// The locale only affects separators and symbol placement.
    func formattedPrice(locale: Locale = .current) -> String {
        price.formatted(.currency(code: "USD").precision(.fractionLength(2)).locale(locale))
    }

    /// "+2.38 (+1.35%)". Gains carry a plus sign, losses a minus, and a flat quote shows no sign.
    func formattedChange(locale: Locale = .current) -> String {
        let amount = change.formatted(
            .number.precision(.fractionLength(2)).sign(strategy: .always(includingZero: false)).locale(locale)
        )
        let percent = (changePercent / 100).formatted(
            .percent.precision(.fractionLength(2)).sign(strategy: .always(includingZero: false)).locale(locale)
        )
        return "\(amount) (\(percent))"
    }
}
