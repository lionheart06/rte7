//
//  FinnhubClient.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/16/26.
//

import Foundation

// MARK: - Domain types

/// A ticker resolved through symbol lookup, with the company name used for display.
nonisolated struct StockSymbol: Codable, Equatable {
    let symbol: String
    let companyName: String
}

/// Anything that can resolve a ticker and fetch its latest quote.
/// Lets the view model be tested with a fake instead of the network.
protocol StockQuoteProviding {
    func lookUp(symbol: String) async throws -> StockSymbol
    func quote(for symbol: String) async throws -> StockQuote
}

nonisolated enum FinnhubError: LocalizedError, Equatable {
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case emptySymbol
    case invalidURL
    case symbolNotFound(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Add your Finnhub API key in the main window."
        case .invalidAPIKey:
            return "Finnhub rejected the API key. Check it in the main window."
        case .rateLimited:
            return "Finnhub rate limit reached. Try again in a minute."
        case .emptySymbol:
            return "Enter a ticker symbol."
        case .invalidURL:
            return "Couldn’t build the stock request."
        case .symbolNotFound(let symbol):
            return "Couldn’t find a symbol called “\(symbol)”."
        }
    }
}

// MARK: - Wire format

/// Response from https://finnhub.io/api/v1/quote. Unknown symbols come back as
/// zeros with `d` and `dp` null rather than as an HTTP error.
nonisolated struct FinnhubQuoteResponse: Codable {
    /// Current price.
    let c: Double
    /// Change since previous close.
    let d: Double?
    /// Percent change since previous close.
    let dp: Double?
    let h: Double?
    let l: Double?
    let o: Double?
    /// Previous close.
    let pc: Double
    /// Unix timestamp of the last trade.
    let t: Int

    var isEmpty: Bool {
        c == 0 && pc == 0 && t == 0
    }
}

/// Response from https://finnhub.io/api/v1/search.
nonisolated struct FinnhubSearchResponse: Codable {
    struct Result: Codable, Equatable {
        let description: String
        let displaySymbol: String
        let symbol: String
        let type: String?
    }

    let count: Int
    let result: [Result]
}

// MARK: - Pure request/response helpers

/// URL construction and response mapping for Finnhub, free of networking so it
/// can be unit tested directly.
nonisolated enum FinnhubAPI {
    static let baseURL = "https://finnhub.io/api/v1"
    /// The key travels in a header so it never appears in URLs, logs, or error text.
    static let tokenHeader = "X-Finnhub-Token"

    static func normalizedSymbol(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func headers(apiKey: String) -> [String: String] {
        [tokenHeader: apiKey]
    }

    static func quoteURL(symbol: String) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.path = "/api/v1/quote"
        components?.queryItems = [URLQueryItem(name: "symbol", value: normalizedSymbol(symbol))]
        return components?.url
    }

    static func searchURL(query: String) -> URL? {
        var components = URLComponents(string: baseURL)
        components?.path = "/api/v1/search"
        components?.queryItems = [URLQueryItem(name: "q", value: query.trimmingCharacters(in: .whitespacesAndNewlines))]
        return components?.url
    }

    /// Returns nil when the response is Finnhub's all-zero "unknown symbol" shape.
    static func makeQuote(from response: FinnhubQuoteResponse,
                          symbol: String,
                          fetchedAt: Date = Date()) -> StockQuote? {
        guard !response.isEmpty else { return nil }

        let change = response.d ?? (response.c - response.pc)
        let percent = response.dp ?? (response.pc == 0 ? 0 : change / response.pc * 100)

        return StockQuote(
            symbol: normalizedSymbol(symbol),
            companyName: nil,
            price: response.c,
            change: change,
            changePercent: percent,
            previousClose: response.pc,
            asOf: Date(timeIntervalSince1970: TimeInterval(response.t)),
            fetchedAt: fetchedAt
        )
    }

    /// Prefers an exact ticker match, then a display-symbol match, so "ORCL"
    /// picks the US listing over ORCL.MX and friends.
    static func bestMatch(in response: FinnhubSearchResponse, for symbol: String) -> FinnhubSearchResponse.Result? {
        let wanted = normalizedSymbol(symbol)
        return response.result.first { $0.symbol.uppercased() == wanted }
            ?? response.result.first { $0.displaySymbol.uppercased() == wanted }
    }

    /// Finnhub returns names in capitals ("ORACLE CORP"); this makes them readable.
    static func displayName(for description: String) -> String {
        description.localizedCapitalized
    }
}

// MARK: - Client

/// Fetches quotes from Finnhub. The API key is read on every call so a key
/// entered in the main window takes effect without restarting.
final class FinnhubClient: StockQuoteProviding {
    private let apiClient: RESTAPIClient
    private let apiKey: () -> String?

    init(apiClient: RESTAPIClient = RESTAPIClient(baseURL: FinnhubAPI.baseURL),
         apiKey: @escaping () -> String?) {
        self.apiClient = apiClient
        self.apiKey = apiKey
    }

    func lookUp(symbol: String) async throws -> StockSymbol {
        let wanted = FinnhubAPI.normalizedSymbol(symbol)
        guard !wanted.isEmpty else { throw FinnhubError.emptySymbol }
        let headers = try authHeaders()
        guard let url = FinnhubAPI.searchURL(query: wanted) else { throw FinnhubError.invalidURL }

        let response: FinnhubSearchResponse
        do {
            response = try await apiClient.request(url.absoluteString, headers: headers)
        } catch {
            throw Self.mapError(error)
        }

        guard let match = FinnhubAPI.bestMatch(in: response, for: wanted) else {
            throw FinnhubError.symbolNotFound(wanted)
        }
        return StockSymbol(symbol: match.symbol.uppercased(), companyName: FinnhubAPI.displayName(for: match.description))
    }

    func quote(for symbol: String) async throws -> StockQuote {
        let wanted = FinnhubAPI.normalizedSymbol(symbol)
        guard !wanted.isEmpty else { throw FinnhubError.emptySymbol }
        let headers = try authHeaders()
        guard let url = FinnhubAPI.quoteURL(symbol: wanted) else { throw FinnhubError.invalidURL }

        let response: FinnhubQuoteResponse
        do {
            response = try await apiClient.request(url.absoluteString, headers: headers)
        } catch {
            throw Self.mapError(error)
        }

        guard let quote = FinnhubAPI.makeQuote(from: response, symbol: wanted) else {
            throw FinnhubError.symbolNotFound(wanted)
        }
        return quote
    }

    /// Translates Finnhub's HTTP failures into messages the tile can show.
    static func mapError(_ error: Error) -> Error {
        guard let apiError = error as? RESTAPIClient.RESTAPIClientError,
              case .unexpectedStatusCode(let status) = apiError else {
            return error
        }

        switch status {
        case 401, 403:
            return FinnhubError.invalidAPIKey
        case 429:
            return FinnhubError.rateLimited
        default:
            return error
        }
    }

    private func authHeaders() throws -> [String: String] {
        let key = apiKey()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !key.isEmpty else { throw FinnhubError.missingAPIKey }
        return FinnhubAPI.headers(apiKey: key)
    }
}

extension FinnhubError {
    /// Errors that will hit every request, so callers stop instead of retrying per symbol.
    var affectsAllRequests: Bool {
        switch self {
        case .missingAPIKey, .invalidAPIKey, .rateLimited:
            return true
        case .emptySymbol, .invalidURL, .symbolNotFound:
            return false
        }
    }
}
