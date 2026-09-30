import Foundation

struct Bookmark: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var urlString: String
    var title: String
    var descriptionText: String
    var faviconURLString: String?
    var createdAt: Date
    var updatedAt: Date

    var url: URL? { URL(string: urlString) }

    var displayHost: String {
        url?.host?.replacingOccurrences(of: "www.", with: "") ?? urlString
    }

    init(
        id: UUID = UUID(),
        urlString: String,
        title: String? = nil,
        descriptionText: String = "",
        faviconURLString: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.urlString = urlString
        let host = URL(string: urlString)?.host?.replacingOccurrences(of: "www.", with: "")
        self.title = title ?? host ?? urlString
        self.descriptionText = descriptionText
        self.faviconURLString = faviconURLString
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

enum URLNormalizer {
    /// Returns a normalized http(s) URL string, or nil if invalid.
    static func normalizedHTTPURL(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var candidate = trimmed
        if !candidate.contains("://") {
            candidate = "https://\(candidate)"
        }

        guard var components = URLComponents(string: candidate),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host?.lowercased(),
              isAcceptableHost(host)
        else { return nil }

        components.scheme = scheme
        components.host = host
        components.fragment = nil

        // Drop trailing slash on bare paths for stabler dedupe
        if components.path == "/" {
            components.path = ""
        }

        return components.string
    }

    /// A host must be a domain, localhost, or an IP. A bare token like "710d22af5b47" is not a link.
    private static func isAcceptableHost(_ host: String) -> Bool {
        let host = host.hasSuffix(".") ? String(host.dropLast()) : host
        guard !host.isEmpty, !host.contains(" ") else { return false }
        if host == "localhost" { return true }
        if isIPv4(host) || isIPv6(host) { return true }

        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        guard labels.allSatisfy(isDomainLabel) else { return false }
        guard let tld = labels.last, tld.count >= 2, tld.first?.isLetter == true else { return false }
        return host.contains(where: \.isLetter)
    }

    private static func isDomainLabel(_ label: Substring) -> Bool {
        guard !label.isEmpty, label.count <= 63 else { return false }
        guard !label.hasPrefix("-"), !label.hasSuffix("-") else { return false }
        return label.allSatisfy { $0.isLetter || $0.isNumber || $0 == "-" }
    }

    private static func isIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }
        return parts.allSatisfy { part in
            guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isNumber),
                  let value = Int(part), (0...255).contains(value)
            else { return false }
            return part.count == 1 || !part.hasPrefix("0")
        }
    }

    private static func isIPv6(_ host: String) -> Bool {
        guard host.contains(":") else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
        guard host.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return host.components(separatedBy: "::").count <= 2
    }

    static func dedupeKey(for urlString: String) -> String? {
        normalizedHTTPURL(from: urlString)?.lowercased()
    }
}
