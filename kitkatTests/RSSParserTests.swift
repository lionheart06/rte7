//
//  RSSParserTests.swift
//  kitkatTests
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation
import Testing
@testable import kitkat

// Structure copied from the live BBC feed on 2026-09-17: CDATA everywhere, an entity in the
// link, a media namespace element, and a channel-level image title that must not be mistaken
// for the channel title. The third item adds HTML in the description as Guardian-style feeds do.
private let bbcFixture = """
<?xml version="1.0" encoding="UTF-8"?><rss xmlns:media="http://search.yahoo.com/mrss/" version="2.0">
    <channel>
        <title><![CDATA[BBC News]]></title>
        <description><![CDATA[BBC News - News Front Page]]></description>
        <link>https://www.bbc.co.uk/news</link>
        <image>
            <url>https://news.bbcimg.co.uk/nol/shared/img/bbc_news_120x60.gif</url>
            <title>BBC News Image</title>
            <link>https://www.bbc.co.uk/news</link>
        </image>
        <lastBuildDate>Thu, 17 Sep 2026 17:50:55 GMT</lastBuildDate>
        <ttl>15</ttl>
        <item>
            <title><![CDATA[Interest rates held but Bank signals rise if energy prices stay high]]></title>
            <description><![CDATA[Rates are held for the sixth time in a row but the Bank of England says high energy prices make a future rise more likely.]]></description>
            <link>https://www.bbc.co.uk/news/articles/cm4gjrxez1q0o?at_medium=RSS&amp;at_campaign=rss</link>
            <guid isPermaLink="false">https://www.bbc.co.uk/news/articles/cm4gjrxez1q0o#1</guid>
            <pubDate>Thu, 17 Sep 2026 14:05:38 GMT</pubDate>
            <media:thumbnail width="240" height="135" url="https://ichef.bbci.co.uk/ace/standard/240/example.jpg"/>
        </item>
        <item>
            <title><![CDATA[New telescope captures first images of distant galaxy cluster]]></title>
            <link>https://www.bbc.co.uk/news/articles/c0000000002o</link>
            <pubDate>not a date</pubDate>
        </item>
        <item>
            <title>Chip maker &amp; rival agree to share factories</title>
            <description><![CDATA[<p>The deal covers   plants in <b>Arizona</b> &amp; Dresden.</p><p>Regulators&#39; approval is &#x201C;likely&#x201D;.</p>]]></description>
            <pubDate>17 Sep 2026 09:00:00 +0000</pubDate>
        </item>
        <item>
            <description><![CDATA[An item with no title must be skipped.]]></description>
        </item>
    </channel>
</rss>
"""

private func expectedDate(_ iso: String) -> Date? {
    ISO8601DateFormatter().date(from: iso)
}

struct RSSParserTests {
    private func parsed() throws -> RSSDocument {
        try RSSParser.parse(Data(bbcFixture.utf8), source: "BBC News")
    }

    @Test func readsChannelTitleAndSkipsTitlelessItems() throws {
        let document = try parsed()
        #expect(document.title == "BBC News")
        #expect(document.items.count == 3)
        #expect(document.items.allSatisfy { $0.source == "BBC News" })
    }

    @Test func parsesACompleteItem() throws {
        let item = try #require(try parsed().items.first)
        #expect(item.id == "https://www.bbc.co.uk/news/articles/cm4gjrxez1q0o#1")
        #expect(item.title == "Interest rates held but Bank signals rise if energy prices stay high")
        #expect(item.summary?.hasPrefix("Rates are held for the sixth time") == true)
        #expect(item.link?.absoluteString == "https://www.bbc.co.uk/news/articles/cm4gjrxez1q0o?at_medium=RSS&at_campaign=rss")
        #expect(item.publishedAt == expectedDate("2026-09-17T14:05:38Z"))
    }

    @Test func missingFieldsBecomeNilAndLinkBecomesID() throws {
        let item = try parsed().items[1]
        #expect(item.id == "https://www.bbc.co.uk/news/articles/c0000000002o")
        #expect(item.summary == nil)
        #expect(item.publishedAt == nil, "an unparseable date should not fail the item")
    }

    @Test func stripsHTMLDecodesEntitiesAndFallsBackToTitleAsID() throws {
        let item = try parsed().items[2]
        #expect(item.title == "Chip maker & rival agree to share factories")
        #expect(item.summary == "The deal covers plants in Arizona & Dresden. Regulators' approval is “likely”.")
        #expect(item.link == nil)
        #expect(item.id == item.title)
        #expect(item.publishedAt == expectedDate("2026-09-17T09:00:00Z"))
    }

    @Test func malformedXMLThrows() {
        let broken = Data("<rss><channel><item><title>Unclosed".utf8)
        #expect(throws: RSSParserError.self) {
            _ = try RSSParser.parse(broken, source: "x")
        }
    }

    @Test func wellFormedNonFeedThrowsNotAFeed() {
        let html = Data("<html><body><p>Not a feed</p></body></html>".utf8)
        #expect(throws: RSSParserError.notAFeed) {
            _ = try RSSParser.parse(html, source: "x")
        }
    }

    @Test func emptyChannelYieldsNoItems() throws {
        let empty = Data("<rss version=\"2.0\"><channel><title>Quiet</title></channel></rss>".utf8)
        let document = try RSSParser.parse(empty, source: "Quiet")
        #expect(document.title == "Quiet")
        #expect(document.items.isEmpty)
    }
}

struct RSSDateParsingTests {
    @Test(arguments: [
        ("Thu, 17 Sep 2026 14:05:38 GMT", "2026-09-17T14:05:38Z"),
        ("Thu, 17 Sep 2026 14:05:38 +0000", "2026-09-17T14:05:38Z"),
        ("Thu, 17 Sep 2026 10:05:38 -0400", "2026-09-17T14:05:38Z"),
        ("Thu, 17 Sep 2026 14:05:38 EST", "2026-09-17T19:05:38Z"),
        ("Fri, 3 Oct 2026 08:00:00 GMT", "2026-10-03T08:00:00Z"),
        ("17 Sep 2026 14:05:38 GMT", "2026-09-17T14:05:38Z"),
        ("2026-09-17T14:05:38Z", "2026-09-17T14:05:38Z"),
    ])
    func parsesCommonFeedDateForms(raw: String, iso: String) {
        #expect(RSSParser.parseDate(raw) == expectedDate(iso), "failed for \(raw)")
    }

    @Test func rejectsGarbageAndBlank() {
        #expect(RSSParser.parseDate("yesterday") == nil)
        #expect(RSSParser.parseDate("   ") == nil)
    }
}

struct RSSTextCleaningTests {
    @Test func stripsTagsAndCollapsesWhitespace() {
        #expect(RSSParser.cleanText("<p>Hello,\n   <em>world</em>!</p>  ") == "Hello, world !")
    }

    @Test func decodesNamedDecimalAndHexEntities() {
        #expect(RSSParser.decodeEntities("Fish &amp; chips &#39;n&#x27; &ldquo;peas&rdquo; &pound;5") == "Fish & chips 'n' “peas” £5")
    }

    @Test func leavesUnknownEntitiesAlone() {
        #expect(RSSParser.decodeEntities("&bogus; stays") == "&bogus; stays")
    }
}

struct NewsFeedCatalogTests {
    @Test func catalogHasUniqueIDsAndValidHTTPSURLs() {
        let ids = NewsFeed.catalog.map(\.id)
        #expect(Set(ids).count == ids.count)
        for feed in NewsFeed.catalog {
            let url = feed.url
            #expect(url?.scheme == "https", "\(feed.id) must be https")
            #expect(url?.host() == "feeds.bbci.co.uk", "\(feed.id) should be a BBC feed")
        }
    }

    @Test func defaultFeedIsBBCTopStories() {
        #expect(NewsFeed.default == NewsFeed.bbcTopStories)
        #expect(NewsFeed.catalog.first == NewsFeed.default)
        #expect(NewsFeed.default.url?.path() == "/news/rss.xml")
    }

    @Test func newsItemRoundTripsThroughJSON() throws {
        let item = NewsItem(id: "1", title: "T", summary: "S", link: URL(string: "https://example.com"),
                            publishedAt: expectedDate("2026-09-17T14:05:38Z"), source: "BBC News")
        let data = try JSONEncoder().encode(item)
        #expect(try JSONDecoder().decode(NewsItem.self, from: data) == item)
    }
}
