import Foundation

/// The swappable seam. Given the OCR text pulled off a screenshot, produce a
/// short human title. Implementations: `ClaudeTitler` (local `claude -p`),
/// `KeywordTitler` (offline). A future MCP server satisfies this same shape
/// from the other direction — Claude calling *in* rather than the tool calling
/// *out*.
public protocol Titler: Sendable {
    func title(forOCRText text: String) async throws -> String
}

public enum TitlerPrompt {
    /// Shared instruction so every titler asks for the same shape of answer.
    public static let system = """
    You label a screenshot from its OCR text. Reply with ONLY a 2-3 word Title \
    Case label naming what it shows — e.g. "AWS Billing Console", "Xcode Build \
    Error", "Slack Thread", "Terminal Output", "Figma Canvas". No punctuation, \
    no quotes, max 3 words. If unclear, reply "Screenshot".
    """

    /// Below this many characters of OCR text, don't even bother a model — it's
    /// an image-only shot; the caller uses the generic fallback.
    public static let minOCRChars = 4
}
