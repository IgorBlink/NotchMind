import AppKit
import Foundation

/// Writes captured snippets as Markdown files under
/// `~/NotchMind/captures/YYYY-MM/YYYY-MM-DD-HHMMSS-slug.md` and keeps
/// `~/NotchMind/index.json` in sync.
///
/// The Markdown format is Obsidian-friendly: YAML frontmatter with metadata,
/// the captured text as the body, and a footer with a quoted source context
/// block so the snippet is self-contained even outside the app.
@MainActor
public final class CaptureStore: ObservableObject {

    public let rootFolder: URL
    public let index: CaptureIndex

    public init(rootFolder: String, index: CaptureIndex) {
        let expanded = (rootFolder as NSString).expandingTildeInPath
        self.rootFolder = URL(fileURLWithPath: expanded)
        self.index = index
        ensureFolderExists()
    }

    private func ensureFolderExists() {
        try? FileManager.default.createDirectory(
            at: rootFolder,
            withIntermediateDirectories: true
        )
    }

    /// Persist a snippet. Writes the Markdown file and updates the index.
    /// - Returns: the file URL of the written Markdown.
    @discardableResult
    public func save(text: String,
                     summary: String?,
                     context: SourceContext) throws -> URL {
        let now = Date()
        let cal = Calendar.current
        let monthFolder = rootFolder
            .appendingPathComponent(monthString(from: now))

        try FileManager.default.createDirectory(
            at: monthFolder,
            withIntermediateDirectories: true
        )

        let timestamp = timestampString(from: now)
        let snippet = Snippet(
            text: text,
            summary: summary,
            appName: context.appName,
            appBundleID: context.appBundleID,
            windowTitle: context.windowTitle,
            url: context.url,
            capturedAt: now,
            fileRelativePath: relativePath(forFileNamed: "\(timestamp)-\(snippetSlug(text)).md",
                                           from: monthFolder)
        )

        let fileURL = monthFolder.appendingPathComponent("\(timestamp)-\(snippetSlug(text)).md")
        let md = renderMarkdown(for: snippet)
        try md.write(to: fileURL, atomically: true, encoding: .utf8)

        index.upsert(snippet)
        return fileURL
    }

    /// Delete the Markdown file and remove from the index.
    public func delete(_ snippet: Snippet) {
        let url = rootFolder.appendingPathComponent(snippet.fileRelativePath)
        try? FileManager.default.removeItem(at: url)
        index.delete(snippet)
    }

    /// Reveal the snippet's file in Finder.
    public func reveal(_ snippet: Snippet) {
        let url = rootFolder.appendingPathComponent(snippet.fileRelativePath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    // MARK: - Rendering

    private func renderMarkdown(for s: Snippet) -> String {
        var lines: [String] = []
        lines.append("---")
        lines.append("id: \(s.id.uuidString)")
        lines.append("captured_at: \(s.capturedAtISO)")
        if let a = s.appName { lines.append("source_app: \(escape(a))") }
        if let b = s.appBundleID { lines.append("source_bundle: \(escape(b))") }
        if let t = s.windowTitle { lines.append("window_title: \(escape(t))") }
        if let u = s.url { lines.append("url: \(escape(u))") }
        if let sum = s.summary { lines.append("summary: \(escape(sum))") }
        lines.append("---")
        lines.append("")
        lines.append(s.text)
        lines.append("")
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    private func monthString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func timestampString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    private func snippetSlug(_ text: String) -> String {
        let head = text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(48)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let stripped = String(head).components(separatedBy: allowed.inverted)
            .joined(separator: "")
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
        let lower = stripped.lowercased()
        return lower.isEmpty ? "snippet" : lower
    }

    private func relativePath(forFileNamed name: String, from monthFolder: URL) -> String {
        let monthName = monthFolder.lastPathComponent
        return "\(monthName)/\(name)"
    }

    private func escape(_ s: String) -> String {
        // Minimal YAML-safe escaping: wrap in quotes if it contains a colon or
        // starts with a quote, else return as-is. Good enough for our fields.
        if s.contains(":") || s.hasPrefix("\"") || s.hasPrefix("'") {
            let escaped = s.replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        }
        return s
    }
}
