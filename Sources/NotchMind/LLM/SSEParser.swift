import Foundation

/// Minimal Server-Sent-Events line parser.
///
/// SSE frames are split by `\n`. A frame may have multiple `field: value`
/// lines separated by single `\n` and a blank line terminates the frame.
/// For our purposes (OpenAI / Anthropic streaming) each meaningful payload
/// fits on a single `data:` line, so we parse line-by-line from
/// `URLSession.AsyncBytes.lines` and emit only `data:` payloads.
///
/// Reference: https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events/Using_server-sent_events
/// + Zach Waugh's ChatGPT-streaming article (see RESEARCH.md / THIRD_PARTY_NOTICES.md).
public enum SSEParser {

    /// Parse a single line from `bytes.lines`.
    public static func dataPayload(from line: String) -> String? {
        // Trim a leading BOM or whitespace.
        var line = line
        if line.hasPrefix("\u{FEFF}") { line.removeFirst() }
        guard line.hasPrefix("data:") else { return nil }
        var rest = line.dropFirst("data:".count)
        // SSE allows an optional single space after the colon.
        if rest.hasPrefix(" ") { rest = rest.dropFirst() }
        if rest == "[DONE]" { return .doneSentinel }
        return String(rest)
    }

    /// Extract the `event:` type from a line, if present.
    public static func event(from line: String) -> String? {
        guard line.hasPrefix("event:") else { return nil }
        var rest = line.dropFirst("event:".count)
        if rest.hasPrefix(" ") { rest = rest.dropFirst() }
        return String(rest).trimmingCharacters(in: .whitespaces)
    }
}

extension String {
    /// Sentinel returned by `SSEParser.dataPayload` when the provider signals
    /// the end of the stream (OpenAI's `data: [DONE]`).
    static let doneSentinel = "\u{0000}_DONE_SENTINEL_\u{0000}"
}
