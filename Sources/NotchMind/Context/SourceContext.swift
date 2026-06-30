import Foundation

/// Everything we know about where a selection came from.
///
/// All fields are best-effort: any may be `nil` if the frontmost app doesn't
/// expose it via AX / AppleScript. The LLM prompt only uses these for tone.
public struct SourceContext: Sendable, Equatable {
    public let appName: String?
    public let appBundleID: String?
    public let windowTitle: String?
    public let url: String?
    public let capturedAt: Date

    public init(
        appName: String? = nil,
        appBundleID: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil,
        capturedAt: Date = Date()
    ) {
        self.appName = appName
        self.appBundleID = appBundleID
        self.windowTitle = windowTitle
        self.url = url
        self.capturedAt = capturedAt
    }

    /// Single-line human-readable context string suitable for the LLM prompt.
    public var promptString: String {
        var parts: [String] = []
        if let appName { parts.append("app: \(appName)") }
        if let windowTitle { parts.append("window: \(windowTitle)") }
        if let url { parts.append("url: \(url)") }
        return parts.isEmpty ? "(none)" : parts.joined(separator: " | ")
    }
}
