//
//  FinnhubClientTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation
import Testing
@testable import kitkat

// Shapes follow Finnhub's documented /quote and /search responses. The unknown-symbol
// shape is what Finnhub returns instead of an HTTP error for a ticker it doesn't know.
private let quoteFixture = """
{"c":178.72,"d":2.38,"dp":1.35,"h":179.6,"l":175.1,"o":176.15,"pc":176.34,"t":1702569600}
"""

private let unknownSymbolFixture = """
{"c":0,"d":null,"dp":null,"h":0,"l":0,"o":0,"pc":0,"t":0}
"""

private let searchFixture = """
{"count":3,"result":[
 {"description":"ORACLE CORP","displaySymbol":"ORCL.MX","symbol":"ORCL.MX","type":"Common Stock"},
 {"description":"ORACLE CORP","displaySymbol":"ORCL","symbol":"ORCL","type":"Common Stock"},
 {"description":"ORACLE CORP JAPAN","displaySymbol":"4716.T","symbol":"4716.T","type":"Common Stock"}]}
"""

private func queryItems(of url: URL?) -> [String: String] {
    guard let url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return [:] }
    return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
}

private let fetched = Date(timeIntervalSince1970: 1_758_000_000)

struct FinnhubURLTests {
    @Test func quoteURLTargetsQuoteEndpointWithNormalizedSymbol() {
        let url = FinnhubAPI.quoteURL(symbol: " orcl\n")
        #expect(url?.scheme == "https")
        #expect(url?.host() == "finnhub.io")
        #expect(url?.path() == "/api/v1/quote")
        #expect(queryItems(of: url)["symbol"] == "ORCL")
    }

    @Test func searchURLTargetsSearchEndpoint() {
        let url = FinnhubAPI.searchURL(query: "oracle")
        #expect(url?.path() == "/api/v1/search")
        #expect(queryItems(of: url)["q"] == "oracle")
    }

    @Test func keyGoesInHeaderNotURL() {
        let headers = FinnhubAPI.headers(apiKey: "secret")
        #expect(headers == ["X-Finnhub-Token": "secret"])
        #expect(FinnhubAPI.quoteURL(symbol: "ORCL")?.absoluteString.contains("token") == false)
    }
}

struct FinnhubDecodingTests {
    @Test func decodesQuoteAndMapsToStockQuote() throws {
        let response = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: Data(quoteFixture.utf8))
        let quote = try #require(FinnhubAPI.makeQuote(from: response, symbol: "aapl", fetchedAt: fetched))

        #expect(quote.symbol == "AAPL")
        #expect(quote.companyName == nil)
        #expect(quote.price == 178.72)
        #expect(quote.change == 2.38)
        #expect(quote.changePercent == 1.35)
        #expect(quote.previousClose == 176.34)
        #expect(quote.asOf == Date(timeIntervalSince1970: 1_702_569_600))
        #expect(quote.fetchedAt == fetched)
        #expect(quote.direction == .up)
    }

    @Test func unknownSymbolShapeDecodesAndYieldsNoQuote() throws {
        let response = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: Data(unknownSymbolFixture.utf8))
        #expect(response.isEmpty)
        #expect(FinnhubAPI.makeQuote(from: response, symbol: "ZZZZ") == nil)
    }

    @Test func derivesChangeWhenFinnhubOmitsIt() throws {
        let json = """
        {"c":110,"h":0,"l":0,"o":0,"pc":100,"t":1702569600}
        """
        let response = try JSONDecoder().decode(FinnhubQuoteResponse.self, from: Data(json.utf8))
        let quote = try #require(FinnhubAPI.makeQuote(from: response, symbol: "X"))
        #expect(quote.change == 10)
        #expect(quote.changePercent == 10)
    }

    @Test func decodesSearchResultsAndPrefersExactTicker() throws {
        let response = try JSONDecoder().decode(FinnhubSearchResponse.self, from: Data(searchFixture.utf8))
        #expect(response.count == 3)

        let match = try #require(FinnhubAPI.bestMatch(in: response, for: "orcl"))
        #expect(match.symbol == "ORCL")
        #expect(FinnhubAPI.displayName(for: match.description) == "Oracle Corp")
    }

    @Test func fallsBackToDisplaySymbolMatch() throws {
        let json = """
        {"count":1,"result":[{"description":"BERKSHIRE HATHAWAY INC-CL B","displaySymbol":"BRK.B","symbol":"BRK-B","type":"Common Stock"}]}
        """
        let response = try JSONDecoder().decode(FinnhubSearchResponse.self, from: Data(json.utf8))
        #expect(FinnhubAPI.bestMatch(in: response, for: "brk.b")?.symbol == "BRK-B")
        #expect(FinnhubAPI.bestMatch(in: response, for: "NOPE") == nil)
    }
}

struct StockQuoteFormattingTests {
    private func quote(price: Double, change: Double, percent: Double) -> StockQuote {
        StockQuote(symbol: "T", companyName: nil, price: price, change: change, changePercent: percent,
                   previousClose: price - change, asOf: fetched, fetchedAt: fetched)
    }

    @Test func formatsPriceAsUSDollars() {
        #expect(quote(price: 178.72, change: 0, percent: 0).formattedPrice(locale: Locale(identifier: "en_US")) == "$178.72")
        #expect(quote(price: 1234.5, change: 0, percent: 0).formattedPrice(locale: Locale(identifier: "en_US")) == "$1,234.50")
    }

    @Test func gainCarriesPlusSigns() {
        let text = quote(price: 178.72, change: 2.38, percent: 1.35).formattedChange(locale: Locale(identifier: "en_US"))
        #expect(text == "+2.38 (+1.35%)")
    }

    @Test func lossCarriesMinusSigns() {
        let text = quote(price: 173.96, change: -2.38, percent: -1.35).formattedChange(locale: Locale(identifier: "en_US"))
        #expect(text == "-2.38 (-1.35%)")
    }

    @Test func flatQuoteShowsNoSign() {
        let flat = quote(price: 100, change: 0, percent: 0)
        #expect(flat.direction == .flat)
        #expect(flat.formattedChange(locale: Locale(identifier: "en_US")) == "0.00 (0.00%)")
    }

    @Test func directionFollowsSignOfChange() {
        #expect(quote(price: 1, change: 0.01, percent: 1).direction == .up)
        #expect(quote(price: 1, change: -0.01, percent: -1).direction == .down)
    }

    @Test func roundTripsThroughJSON() throws {
        var original = quote(price: 178.72, change: 2.38, percent: 1.35)
        original.companyName = "Apple Inc"
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(StockQuote.self, from: data) == original)
    }
}

@MainActor
struct FinnhubClientTests {
    @Test func missingKeyFailsBeforeAnyNetworkCall() async {
        let client = FinnhubClient(apiKey: { "   " })
        await #expect(throws: FinnhubError.missingAPIKey) {
            _ = try await client.quote(for: "ORCL")
        }
        await #expect(throws: FinnhubError.missingAPIKey) {
            _ = try await client.lookUp(symbol: "ORCL")
        }
    }

    @Test func blankSymbolIsRejected() async {
        let client = FinnhubClient(apiKey: { "key" })
        await #expect(throws: FinnhubError.emptySymbol) {
            _ = try await client.quote(for: " ")
        }
    }

    @Test func mapsAuthAndRateLimitStatusesToFriendlyErrors() {
        #expect(FinnhubClient.mapError(RESTAPIClient.RESTAPIClientError.unexpectedStatusCode(401)) as? FinnhubError == .invalidAPIKey)
        #expect(FinnhubClient.mapError(RESTAPIClient.RESTAPIClientError.unexpectedStatusCode(403)) as? FinnhubError == .invalidAPIKey)
        #expect(FinnhubClient.mapError(RESTAPIClient.RESTAPIClientError.unexpectedStatusCode(429)) as? FinnhubError == .rateLimited)
    }

    @Test func leavesOtherErrorsUntouched() {
        let server = FinnhubClient.mapError(RESTAPIClient.RESTAPIClientError.unexpectedStatusCode(500))
        guard let apiError = server as? RESTAPIClient.RESTAPIClientError, case .unexpectedStatusCode(let code) = apiError else {
            Issue.record("expected the original status error, got \(server)")
            return
        }
        #expect(code == 500)

        let offline = URLError(.notConnectedToInternet)
        #expect((FinnhubClient.mapError(offline) as? URLError)?.code == .notConnectedToInternet)
    }

    @Test func errorsHaveUserFacingText() {
        #expect(FinnhubError.missingAPIKey.errorDescription?.contains("API key") == true)
        #expect(FinnhubError.symbolNotFound("ZZZZ").errorDescription?.contains("ZZZZ") == true)
    }

    @Test func restClientAppliesPerRequestHeaders() throws {
        let client = RESTAPIClient(baseURL: FinnhubAPI.baseURL)
        let request = try client.buildRequest(endpoint: "/quote", method: .get, parameters: nil, headers: ["X-Finnhub-Token": "abc"])
        #expect(request.value(forHTTPHeaderField: "X-Finnhub-Token") == "abc")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.url?.absoluteString.contains("abc") == false)
    }
}
