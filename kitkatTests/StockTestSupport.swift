//
//  StockTestSupport.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation
@testable import kitkat

@MainActor
final class FakeStockProvider: StockQuoteProviding {
    var quotes: [String: Result<StockQuote, Error>]
    var lookups: [String: Result<StockSymbol, Error>]
    private(set) var quoteCalls: [String] = []
    private(set) var lookupCalls: [String] = []

    init(quotes: [String: Result<StockQuote, Error>] = [:], lookups: [String: Result<StockSymbol, Error>] = [:]) {
        self.quotes = quotes
        self.lookups = lookups
    }

    func quote(for symbol: String) async throws -> StockQuote {
        quoteCalls.append(symbol)
        guard let result = quotes[symbol] else { throw FinnhubError.symbolNotFound(symbol) }
        return try result.get()
    }

    func lookUp(symbol: String) async throws -> StockSymbol {
        lookupCalls.append(symbol)
        guard let result = lookups[symbol] else { throw FinnhubError.symbolNotFound(symbol) }
        return try result.get()
    }
}

func makeQuote(_ symbol: String, price: Double, change: Double = 1, fetchedAt: Date, name: String? = nil) -> StockQuote {
    StockQuote(symbol: symbol, companyName: name, price: price, change: change, changePercent: change,
               previousClose: price - change, asOf: fetchedAt, fetchedAt: fetchedAt)
}
