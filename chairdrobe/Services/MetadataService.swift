import Foundation

struct MetadataResult {
    var title: String?
    var description: String?
    var faviconURL: URL?
}

actor MetadataService {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.httpAdditionalHeaders = [
            "User-Agent": "chairdrobe/1.0 (macOS; Link Saver)"
        ]
        session = URLSession(configuration: config)
    }

    func fetch(for url: URL) async -> MetadataResult {
        var result = MetadataResult()
        result.faviconURL = url.originFaviconURL

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200..<400).contains(http.statusCode),
                  let html = String(data: data, encoding: .utf8)
                    ?? String(data: data, encoding: .isoLatin1)
            else { return result }

            result.title = Self.parseTitle(from: html) ?? result.title
            result.description = Self.parseDescription(from: html)
            if let icon = Self.parseFavicon(from: html, base: url) {
                result.faviconURL = icon
            }
        } catch {
            // Leave fallbacks — saving must not depend on metadata success
        }

        return result
    }

    private static func parseTitle(from html: String) -> String? {
        if let og = metaContent(html: html, property: "og:title") { return clean(og) }
        if let tw = metaContent(html: html, name: "twitter:title") { return clean(tw) }
        guard let regex = try? NSRegularExpression(
            pattern: #"<title[^>]*>(.*?)</title>"#,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let titleRange = Range(match.range(at: 1), in: html)
        else { return nil }
        return clean(String(html[titleRange]))
    }

    private static func parseDescription(from html: String) -> String? {
        if let og = metaContent(html: html, property: "og:description") { return clean(og) }
        if let meta = metaContent(html: html, name: "description") { return clean(meta) }
        if let tw = metaContent(html: html, name: "twitter:description") { return clean(tw) }
        return nil
    }

    private static func parseFavicon(from html: String, base: URL) -> URL? {
        let patterns = [
            #"<link[^>]+rel=["'](?:shortcut icon|icon|apple-touch-icon)["'][^>]+href=["']([^"']+)["'][^>]*>"#,
            #"<link[^>]+href=["']([^"']+)["'][^>]+rel=["'](?:shortcut icon|icon|apple-touch-icon)["'][^>]*>"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, range: range),
               let hrefRange = Range(match.range(at: 1), in: html) {
                let href = String(html[hrefRange])
                if let absolute = URL(string: href, relativeTo: base)?.absoluteURL {
                    return absolute
                }
            }
        }
        return nil
    }

    private static func metaContent(html: String, property: String) -> String? {
        metaContent(html: html, key: "property", value: property)
    }

    private static func metaContent(html: String, name: String) -> String? {
        metaContent(html: html, key: "name", value: name)
    }

    private static func metaContent(html: String, key: String, value: String) -> String? {
        let patterns = [
            "<meta[^>]+\(key)=[\"']\(NSRegularExpression.escapedPattern(for: value))[\"'][^>]+content=[\"']([^\"']+)[\"'][^>]*>",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]+\(key)=[\"']\(NSRegularExpression.escapedPattern(for: value))[\"'][^>]*>"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { continue }
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            if let match = regex.firstMatch(in: html, range: range),
               let contentRange = Range(match.range(at: 1), in: html) {
                return String(html[contentRange])
            }
        }
        return nil
    }

    private static func clean(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }
}

private extension URL {
    var originFaviconURL: URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        components?.path = "/favicon.ico"
        components?.query = nil
        components?.fragment = nil
        return components?.url
    }
}
