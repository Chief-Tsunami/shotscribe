import Foundation

/// Normalizes a raw title from an LLM (or the keyword fallback) into a tidy
/// 2–3 word label: first line only, no echoed "Label:" prefix, no surrounding
/// quotes/punctuation, capped to three words. Never empty — falls back to
/// "Screenshot".
public enum LabelCleaner {
    public static func clean(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // first line only
        if let nl = s.firstIndex(where: { $0 == "\n" || $0 == "\r" }) { s = String(s[..<nl]) }
        // drop a leading "Label:" / "Summary:" echo
        if let colon = s.firstIndex(of: ":"), s[..<colon].count <= 10 {
            s = String(s[s.index(after: colon)...])
        }
        // strip surrounding quotes / stray punctuation
        s = s.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'`.,;:—-–()[]{}"))
        let words = s.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        let capped = words.prefix(3).joined(separator: " ")
        let clean = capped.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "Screenshot" : clean
    }
}
