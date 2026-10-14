//
//  NewsItem.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation

/// One headline shown on the break window.
nonisolated struct NewsItem: Codable, Equatable, Identifiable {
    /// The feed's guid, falling back to the link, then the title.
    let id: String
    let title: String
    let summary: String?
    let link: URL?
    let publishedAt: Date?
    /// Display name of the feed the item came from, e.g. "BBC News".
    let source: String
}

/// An RSS feed the tile can read. Topics are just more feeds, so topic
/// selection later means choosing from `catalog` or adding a URL.
nonisolated struct NewsFeed: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let urlString: String

    var url: URL? {
        URL(string: urlString)
    }
}

nonisolated extension NewsFeed {
    /// Feeds are published for personal, non-commercial use; see
    /// https://www.bbc.co.uk/usingthebbc/terms-of-use/#15metadataandrssfeeds
    static let bbcTopStories = NewsFeed(id: "bbc-top", name: "BBC News", urlString: "https://feeds.bbci.co.uk/news/rss.xml")
    static let bbcWorld = NewsFeed(id: "bbc-world", name: "BBC World", urlString: "https://feeds.bbci.co.uk/news/world/rss.xml")
    static let bbcBusiness = NewsFeed(id: "bbc-business", name: "BBC Business", urlString: "https://feeds.bbci.co.uk/news/business/rss.xml")
    static let bbcTechnology = NewsFeed(id: "bbc-technology", name: "BBC Technology", urlString: "https://feeds.bbci.co.uk/news/technology/rss.xml")
    static let bbcScience = NewsFeed(id: "bbc-science", name: "BBC Science & Environment", urlString: "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml")

    /// The catalog's headline feed; the feed client uses it as its base URL.
    static let `default` = bbcTopStories

    static let catalog: [NewsFeed] = [bbcTopStories, bbcWorld, bbcBusiness, bbcTechnology, bbcScience]

    /// What the tile reads when nothing has been chosen: one story from each
    /// of these per break, in this order.
    static let defaultSelection: [NewsFeed] = [bbcWorld, bbcBusiness, bbcTechnology, bbcScience]
}
