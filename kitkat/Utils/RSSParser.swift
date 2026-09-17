//
//  RSSParser.swift
//  kitkat
//
//  Created by Richard El-Kadi on 9/17/26.
//

import Foundation

nonisolated struct RSSDocument: Equatable {
    /// The channel title, e.g. "BBC News".
    let title: String?
    let items: [NewsItem]
}

nonisolated enum RSSParserError: LocalizedError, Equatable {
    case malformed(String)
    case notAFeed

    var errorDescription: String? {
        switch self {
        case .malformed(let detail):
            return "The news feed couldn’t be read. \(detail)"
        case .notAFeed:
            return "That address didn’t return an RSS feed."
        }
    }
}

/// Parses RSS 2.0 with Foundation's XMLParser. Handles CDATA, HTML in
/// descriptions, and the RFC 822 dates feeds use, with no third-party code.
nonisolated enum RSSParser {
    static func parse(_ data: Data, source: String) throws -> RSSDocument {
        let delegate = Delegate(source: source)
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            let detail = parser.parserError?.localizedDescription ?? "Unknown XML error."
            throw RSSParserError.malformed(detail)
        }
        guard delegate.sawChannel else {
            throw RSSParserError.notAFeed
        }
        return RSSDocument(title: delegate.channelTitle, items: delegate.items)
    }

    // MARK: Dates

    nonisolated(unsafe) private static let rfc822Formatters: [DateFormatter] = [
        "EEE, dd MMM yyyy HH:mm:ss zzz",
        "EEE, dd MMM yyyy HH:mm:ss Z",
        "EEE, d MMM yyyy HH:mm:ss zzz",
        "EEE, d MMM yyyy HH:mm:ss Z",
        "dd MMM yyyy HH:mm:ss zzz",
        "dd MMM yyyy HH:mm:ss Z",
    ].map { format in
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = format
        return formatter
    }

    nonisolated(unsafe) private static let iso8601 = ISO8601DateFormatter()

    /// Accepts the RFC 822 forms RSS feeds use ("Thu, 17 Sep 2026 14:05:38 GMT",
    /// "+0000" offsets, no weekday) and ISO 8601 as a fallback.
    static func parseDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in rfc822Formatters {
            if let date = formatter.date(from: trimmed) { return date }
        }
        return iso8601.date(from: trimmed)
    }

    // MARK: Text

    nonisolated(unsafe) private static let tagPattern = try! NSRegularExpression(pattern: "<[^>]+>")
    nonisolated(unsafe) private static let entityPattern = try! NSRegularExpression(pattern: "&(#x[0-9a-fA-F]+|#[0-9]+|[a-zA-Z]+);")
    nonisolated(unsafe) private static let whitespacePattern = try! NSRegularExpression(pattern: "\\s+")

    private static let namedEntities: [String: String] = [
        "amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": " ",
        "ndash": "–", "mdash": "—", "hellip": "…", "lsquo": "‘", "rsquo": "’",
        "ldquo": "“", "rdquo": "”", "copy": "©", "pound": "£", "euro": "€",
    ]

    /// Strips HTML tags, decodes entities, and collapses whitespace so feed
    /// descriptions read as plain sentences.
    static func cleanText(_ raw: String) -> String {
        var text = tagPattern.stringByReplacingMatches(in: raw, range: NSRange(raw.startIndex..., in: raw), withTemplate: " ")
        text = decodeEntities(text)
        text = whitespacePattern.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func decodeEntities(_ raw: String) -> String {
        let nsRaw = raw as NSString
        var result = ""
        var cursor = 0

        for match in entityPattern.matches(in: raw, range: NSRange(location: 0, length: nsRaw.length)) {
            result += nsRaw.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let body = nsRaw.substring(with: match.range(at: 1))
            result += decodeEntity(body) ?? nsRaw.substring(with: match.range)
            cursor = match.range.location + match.range.length
        }
        result += nsRaw.substring(from: cursor)
        return result
    }

    private static func decodeEntity(_ body: String) -> String? {
        if body.hasPrefix("#x") || body.hasPrefix("#X") {
            return UInt32(body.dropFirst(2), radix: 16).flatMap(UnicodeScalar.init).map { String(Character($0)) }
        }
        if body.hasPrefix("#") {
            return UInt32(body.dropFirst()).flatMap(UnicodeScalar.init).map { String(Character($0)) }
        }
        return namedEntities[body]
    }

    // MARK: XML delegate

    private final class Delegate: NSObject, XMLParserDelegate {
        let source: String
        private(set) var channelTitle: String?
        private(set) var items: [NewsItem] = []
        private(set) var sawChannel = false

        private var path: [String] = []
        private var text = ""
        private var currentItem: [String: String]?

        init(source: String) {
            self.source = source
        }

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            path.append(elementName)
            text = ""
            if elementName == "channel" { sawChannel = true }
            if elementName == "item" { currentItem = [:] }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            text += String(decoding: CDATABlock, as: UTF8.self)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            defer {
                path.removeLast()
                text = ""
            }
            let value = text.trimmingCharacters(in: .whitespacesAndNewlines)

            if elementName == "item" {
                finishItem()
                return
            }

            let parent = path.count >= 2 ? path[path.count - 2] : nil
            if var item = currentItem, parent == "item" {
                // Keep the first occurrence; some feeds repeat elements.
                if item[elementName] == nil { item[elementName] = value }
                currentItem = item
            } else if elementName == "title", parent == "channel" {
                channelTitle = value
            }
        }

        private func finishItem() {
            defer { currentItem = nil }
            guard let fields = currentItem else { return }

            let title = RSSParser.cleanText(fields["title"] ?? "")
            guard !title.isEmpty else { return }

            let link = fields["link"].flatMap { URL(string: $0) }
            let summary = fields["description"].map(RSSParser.cleanText).flatMap { $0.isEmpty ? nil : $0 }
            let id = fields["guid"].flatMap { $0.isEmpty ? nil : $0 } ?? link?.absoluteString ?? title

            items.append(NewsItem(
                id: id,
                title: title,
                summary: summary,
                link: link,
                publishedAt: fields["pubDate"].flatMap(RSSParser.parseDate),
                source: source
            ))
        }
    }
}
