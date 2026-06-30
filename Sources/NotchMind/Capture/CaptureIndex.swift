import Foundation

/// JSON index of all captures, kept in sync with the Markdown files on disk.
///
/// The Markdown files under `~/NotchMind/captures/` are the source of truth;
/// `index.json` is a denormalized cache for the menu-bar popover's search.
/// If the index ever drifts, `rebuildFromDisk()` reconciles it.
@MainActor
public final class CaptureIndex: ObservableObject {

    @Published public private(set) var snippets: [Snippet] = []

    private let indexURL: URL
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return enc
    }()
    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    public init(indexURL: URL) {
        self.indexURL = indexURL
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let list = try? decoder.decode([Snippet].self, from: data) else {
        snippets = []
        return
        }
        snippets = list.sorted { $0.capturedAt > $1.capturedAt }
    }

    public func save() {
        do {
            let data = try encoder.encode(snippets)
            try FileManager.default.createDirectory(
                at: indexURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: indexURL, options: .atomic)
        } catch {
            // Index failures are non-fatal: the markdown files remain.
            NSLog("NotchMind: failed to write capture index: \(error.localizedDescription)")
        }
    }

    public func upsert(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        snippets.insert(snippet, at: 0)
        snippets.sort { $0.capturedAt > $1.capturedAt }
        save()
    }

    public func delete(_ snippet: Snippet) {
        snippets.removeAll { $0.id == snippet.id }
        save()
    }

    public func search(_ query: String) -> [Snippet] {
        guard !query.isEmpty else { return snippets }
        let q = query.lowercased()
        return snippets.filter {
            $0.text.lowercased().contains(q)
                || ($0.summary?.lowercased().contains(q) ?? false)
                || ($0.windowTitle?.lowercased().contains(q) ?? false)
                || ($0.appName?.lowercased().contains(q) ?? false)
        }
    }
}
