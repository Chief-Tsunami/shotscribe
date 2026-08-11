import Foundation

/// Turns a label + capture time into a findable filename, and decides which
/// files are safe to rename.
///
/// Date FIRST so name-sort stays chronological, then the label for scanning
/// and search — the tail (what truncating UIs keep) is the meaningful part.
public enum Naming {
    /// macOS default capture names, e.g. "Screenshot 2026-08-11 at 3.41.07 PM.png"
    /// (and the older "Screen Shot …"). ONLY these are renamed — a file the
    /// user named themselves is never touched.
    public static func isRawCapture(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        return lower.hasPrefix("screenshot ") || lower.hasPrefix("screen shot ")
    }

    /// Strip characters that break paths or read badly, collapse spaces, cap length.
    public static func sanitize(_ label: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:*?\"<>|\n\t")
        let cleaned = label.components(separatedBy: illegal).joined(separator: " ")
        let collapsed = cleaned.split(separator: " ").joined(separator: " ")
        return String(collapsed.prefix(60)).trimmingCharacters(in: .whitespaces)
    }

    /// "2026-08-11 1541 AWS Billing Console.png" — sortable, scannable.
    /// nil when there's no usable label, so the caller leaves the file alone.
    public static func filename(label: String, capturedAt: Date, ext: String) -> String? {
        let clean = sanitize(label)
        guard !clean.isEmpty else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HHmm"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        let stamp = fmt.string(from: capturedAt)
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        return "\(stamp) \(clean)\(suffix)"
    }

    /// Resolve a collision by suffixing " (2)", " (3)", … Pure: the caller
    /// supplies the existence check so this stays testable.
    public static func uniqueName(_ desired: String, exists: (String) -> Bool) -> String {
        guard exists(desired) else { return desired }
        let url = URL(fileURLWithPath: desired)
        let ext = url.pathExtension
        let stem = url.deletingPathExtension().lastPathComponent
        for n in 2...99 {
            let candidate = ext.isEmpty ? "\(stem) (\(n))" : "\(stem) (\(n)).\(ext)"
            if !exists(candidate) { return candidate }
        }
        return desired
    }
}
