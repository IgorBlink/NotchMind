import Foundation

/// A single captured snippet, mirrored in Markdown frontmatter and `index.json`.
public struct Snippet: Codable, Identifiable, Sendable, Equatable, Hashable {
    public let id: UUID
    public let text: String
    public let summary: String?
    public let appName: String?
    public let appBundleID: String?
    public let windowTitle: String?
    public let url: String?
    public let capturedAt: Date
    public let fileRelativePath: String  // relative to the capture folder root

    public init(
        id: UUID = UUID(),
        text: String,
        summary: String? = nil,
        appName: String? = nil,
        appBundleID: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil,
        capturedAt: Date = Date(),
        fileRelativePath: String
    ) {
        self.id = id
        self.text = text
        self.summary = summary
        self.appName = appName
        self.appBundleID = appBundleID
        self.windowTitle = windowTitle
        self.url = url
        self.capturedAt = capturedAt
        self.fileRelativePath = fileRelativePath
    }

    /// ISO8601 string for stable frontmatter regardless of user locale.
    public var capturedAtISO: String {
        ISO8601DateFormatter().string(from: capturedAt)
    }

    /// Filename-safe slug derived from the text, used for the Markdown file.
    public var slug: String {
        let head = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(48)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let stripped = String(head).components(separatedBy: allowed.inverted)
            .joined(separator: "")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
        let lower = stripped.lowercased()
        return lower.isEmpty ? "snippet" : lower
    }
}
