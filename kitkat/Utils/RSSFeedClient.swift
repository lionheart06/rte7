//
//  RSSFeedClient.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation

/// Anything that can return the current headlines for a feed.
/// Lets the view model be tested with a fake instead of the network.
protocol NewsProviding {
    func headlines(from feed: NewsFeed) async throws -> [NewsItem]
}

/// The raw download step, separated so the feed client can be tested with
/// canned bytes. `RESTAPIClient` is the production implementation.
protocol FeedDataFetching {
    func fetchData(from url: URL, headers: [String: String]) async throws -> Data
}

extension RESTAPIClient: FeedDataFetching {
    func fetchData(from url: URL, headers: [String: String]) async throws -> Data {
        try await requestData(url.absoluteString, headers: headers)
    }
}

nonisolated enum NewsError: LocalizedError, Equatable {
    case invalidFeedURL(String)
    case emptyFeed(String)
    case unavailable(String, status: Int)

    var errorDescription: String? {
        switch self {
        case .invalidFeedURL(let name):
            return "The address for “\(name)” isn’t a valid URL."
        case .emptyFeed(let name):
            return "“\(name)” has no stories right now."
        case .unavailable(let name, let status):
            return "“\(name)” isn’t available right now (HTTP \(status))."
        }
    }
}

/// Downloads an RSS feed and parses it into headlines, in feed order.
/// Feed order is kept because "top stories" feeds are ordered editorially.
final class RSSFeedClient: NewsProviding {
    /// Asks for RSS first; the REST client's JSON default is overridden by this header.
    static let acceptHeaders = ["Accept": "application/rss+xml, application/xml;q=0.9, text/xml;q=0.8, */*;q=0.5"]

    private let fetcher: any FeedDataFetching

    init(fetcher: any FeedDataFetching = RESTAPIClient(baseURL: NewsFeed.default.urlString)) {
        self.fetcher = fetcher
    }

    func headlines(from feed: NewsFeed) async throws -> [NewsItem] {
        guard let url = feed.url else { throw NewsError.invalidFeedURL(feed.name) }

        let data: Data
        do {
            data = try await fetcher.fetchData(from: url, headers: Self.acceptHeaders)
        } catch {
            throw Self.mapError(error, feed: feed)
        }

        let document = try RSSParser.parse(data, source: feed.name)
        guard !document.items.isEmpty else { throw NewsError.emptyFeed(feed.name) }
        return document.items
    }

    /// Turns an HTTP status failure into a message that names the feed.
    /// Network and parser errors already read well and pass through.
    static func mapError(_ error: Error, feed: NewsFeed) -> Error {
        if let apiError = error as? RESTAPIClient.RESTAPIClientError,
           case .unexpectedStatusCode(let status) = apiError {
            return NewsError.unavailable(feed.name, status: status)
        }
        return error
    }
}
