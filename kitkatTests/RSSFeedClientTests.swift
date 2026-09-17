//
//  RSSFeedClientTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation
import Testing
@testable import kitkat

private let feedFixture = """
<?xml version="1.0" encoding="UTF-8"?><rss version="2.0"><channel><title>BBC News</title>
<item><title>First story</title><link>https://example.com/1</link><guid>1</guid><pubDate>Thu, 17 Sep 2026 14:05:38 GMT</pubDate></item>
<item><title>Second story</title><link>https://example.com/2</link><guid>2</guid><pubDate>Thu, 17 Sep 2026 15:05:38 GMT</pubDate></item>
</channel></rss>
"""

private let emptyFeedFixture = """
<rss version="2.0"><channel><title>Quiet</title></channel></rss>
"""

/// Records what the client asked for and returns a canned result.
@MainActor
private final class FetchRecorder: FeedDataFetching {
    var result: Result<Data, Error>
    private(set) var urls: [URL] = []
    private(set) var headers: [[String: String]] = []

    init(_ result: Result<Data, Error>) {
        self.result = result
    }

    func fetchData(from url: URL, headers: [String: String]) async throws -> Data {
        urls.append(url)
        self.headers.append(headers)
        return try result.get()
    }
}

@MainActor
struct RSSFeedClientTests {
    @Test func returnsHeadlinesInFeedOrderWithSourceAndRSSAcceptHeader() async throws {
        let recorder = FetchRecorder(.success(Data(feedFixture.utf8)))
        let client = RSSFeedClient(fetcher: recorder)

        let items = try await client.headlines(from: .bbcTopStories)

        #expect(items.map(\.title) == ["First story", "Second story"], "feed order is editorial and must be preserved")
        #expect(items.allSatisfy { $0.source == "BBC News" })
        #expect(recorder.urls == [NewsFeed.bbcTopStories.url])
        #expect(recorder.headers.first?["Accept"]?.hasPrefix("application/rss+xml") == true)
    }

    @Test func invalidFeedURLFailsBeforeFetching() async {
        let recorder = FetchRecorder(.success(Data()))
        let client = RSSFeedClient(fetcher: recorder)
        let broken = NewsFeed(id: "x", name: "Broken", urlString: "")

        await #expect(throws: NewsError.invalidFeedURL("Broken")) {
            _ = try await client.headlines(from: broken)
        }
        #expect(recorder.urls.isEmpty)
    }

    @Test func emptyChannelIsReportedByFeedName() async {
        let client = RSSFeedClient(fetcher: FetchRecorder(.success(Data(emptyFeedFixture.utf8))))

        await #expect(throws: NewsError.emptyFeed("BBC News")) {
            _ = try await client.headlines(from: .bbcTopStories)
        }
    }

    @Test func httpStatusFailureNamesTheFeed() async {
        let client = RSSFeedClient(fetcher: FetchRecorder(.failure(RESTAPIClient.RESTAPIClientError.unexpectedStatusCode(503))))

        await #expect(throws: NewsError.unavailable("BBC News", status: 503)) {
            _ = try await client.headlines(from: .bbcTopStories)
        }
        #expect(NewsError.unavailable("BBC News", status: 503).errorDescription?.contains("503") == true)
    }

    @Test func networkAndParserErrorsPassThrough() async {
        let offline = RSSFeedClient(fetcher: FetchRecorder(.failure(URLError(.notConnectedToInternet))))
        await #expect(throws: URLError.self) {
            _ = try await offline.headlines(from: .bbcTopStories)
        }

        let garbage = RSSFeedClient(fetcher: FetchRecorder(.success(Data("<html><body/></html>".utf8))))
        await #expect(throws: RSSParserError.notAFeed) {
            _ = try await garbage.headlines(from: .bbcTopStories)
        }
    }

    @Test func acceptHeaderOverridesTheJSONDefault() throws {
        let request = try RESTAPIClient(baseURL: NewsFeed.default.urlString)
            .buildRequest(endpoint: NewsFeed.default.urlString, method: .get, parameters: nil, headers: RSSFeedClient.acceptHeaders)
        #expect(request.value(forHTTPHeaderField: "Accept")?.hasPrefix("application/rss+xml") == true)
        #expect(request.url?.host() == "feeds.bbci.co.uk")
    }

    @Test func rawDataRequestSurfacesURLErrorsWithoutNetwork() async {
        let client = RESTAPIClient(baseURL: "   ")
        await #expect(throws: RESTAPIClient.RESTAPIClientError.self) {
            _ = try await client.requestData("/news/rss.xml")
        }
    }
}
