import Foundation

/// User-customizable prompt templates.
///
/// `{text}` and `{context}` are replaced at request time. Everything else is
/// passed verbatim to the provider. Keep the default short — the notch has
/// limited vertical room.
public enum PromptTemplates {

    public static let defaultExplain = """
    Explain this concisely in 2–4 short sentences, plain language, no preamble:

    {text}

    Context (for tone and domain only — do not restate): {context}
    """

    public static let captureSummary = """
    In one short line (<= 12 words), summarize what this snippet is about,
    no punctuation at the end:

    {text}
    """

    /// Substitute `{text}` and `{context}` placeholders. Missing placeholders
    /// are replaced with empty strings.
    public static func render(_ template: String, text: String, context: String) -> String {
        template
            .replacingOccurrences(of: "{text}", with: text)
            .replacingOccurrences(of: "{context}", with: context)
    }
}
