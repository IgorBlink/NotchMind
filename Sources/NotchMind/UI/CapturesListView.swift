import SwiftUI

/// Searchable list of recent captures shown in the menu-bar popover.
struct CapturesListView: View {
    let query: String
    @EnvironmentObject private var captureIndex: CaptureIndex
    @EnvironmentObject private var captureStore: CaptureStore

    var body: some View {
        if snippets.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 22))
                    .foregroundStyle(.secondary)
                Text(query.isEmpty ? "No captures yet" : "No matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 60)
        } else {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(snippets) { snippet in
                        row(for: snippet)
                    }
                }
            }
        }
    }

    private var snippets: [Snippet] {
        captureIndex.search(query)
    }

    private func row(for snippet: Snippet) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(snippet.summary ?? String(snippet.text.prefix(60)))
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
            HStack(spacing: 6) {
                if let app = snippet.appName {
                    Text(app)
                }
                if snippet.appName != nil && snippet.url != nil {
                    Text("·")
                }
                if let url = snippet.url, let host = URL(string: url)?.host {
                    Text(host)
                }
                Spacer()
                Text(relativeDate(snippet.capturedAt))
            }
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            Text(snippet.text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
        .onTapGesture { captureStore.reveal(snippet) }
        .contextMenu {
            Button("Reveal in Finder") { captureStore.reveal(snippet) }
            Button("Copy text") { copy(snippet.text) }
            Divider()
            Button("Delete") { captureStore.delete(snippet) }
        }
    }

    private func copy(_ s: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(s, forType: .string)
    }

    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: date, relativeTo: Date())
    }
}
