import AppKit
import Vision

/// On-device OCR for screenshot labeling. Uses the Vision framework (free,
/// private, no network) to pull the visible text out of a screenshot; that
/// text is what gets summarized into a 2–3 word label. Text-heavy shots
/// (code, consoles, dashboards) OCR well; image-only shots return little and
/// fall back to a generic label upstream.
public enum OCR {
    /// Recognize text in the image at `path`. Runs synchronously — call it off
    /// the main thread. Returns up to `maxChars` of joined text ("" on failure
    /// or an image with no text).
    public static func recognizeText(atPath path: String, maxChars: Int = 900) -> String {
        guard let image = NSImage(contentsOfFile: path),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return ""
        }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast        // a label doesn't need .accurate
        request.usesLanguageCorrection = false
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let joined = lines.joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(joined.prefix(maxChars))
    }
}
