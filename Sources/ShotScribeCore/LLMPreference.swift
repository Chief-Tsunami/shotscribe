import Foundation

/// Which model this machine is set up to use.
///
/// **Deliberately a second, independent implementation of the same file.**
/// Toolbelt writes `~/.config/llm/provider.json` and ShotScribe reads it, and
/// neither imports anything from the other — that is the whole point. A shared
/// type would mean a package dependency, and a sidecar that depends on the belt
/// has learned the belt exists.
///
/// The path is named after the *subject*, not after either app, so anything
/// else on this machine can join in without asking permission. The duplication
/// here is roughly forty lines and it buys zero coupling; that is a good trade,
/// and it is the same trade the belt made on its side.
public struct LLMPreference: Sendable, Equatable {

    public enum Provider: String, Sendable {
        case claude, openai, gemini, apple, local

        /// Whether ShotScribe can actually title with it today. Unknown or
        /// unimplemented providers fall back rather than failing — a wrong
        /// setting should cost you good titles, not the feature.
        public var usableHere: Bool {
            switch self {
            case .claude, .local: return true
            case .openai, .gemini, .apple: return false
            }
        }

        public var title: String {
            switch self {
            case .claude: return "Claude"
            case .openai: return "OpenAI"
            case .gemini: return "Gemini"
            case .apple:  return "Apple Intelligence"
            case .local:  return "a local model"
            }
        }
    }

    public var provider: Provider
    public var endpoint: String?
    public var model: String?
    /// False when no file exists — nobody has chosen, so nothing is overridden.
    public var isSet: Bool

    public static var fileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/llm/provider.json")
    }

    /// Read it. Any failure means "not set", never a wrong answer: a corrupt
    /// file must not silently switch which model handles your screenshots.
    public static func load() -> LLMPreference {
        guard let data = try? Data(contentsOf: fileURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = root["provider"] as? String,
              let provider = Provider(rawValue: raw)
        else {
            return LLMPreference(provider: .claude, endpoint: nil, model: nil, isSet: false)
        }
        return LLMPreference(provider: provider,
                             endpoint: root["endpoint"] as? String,
                             model: root["model"] as? String,
                             isSet: true)
    }

    /// What to tell the operator when their choice is not one ShotScribe can
    /// honour. Nil when there is nothing to say.
    public var mismatchNote: String? {
        guard isSet, !provider.usableHere else { return nil }
        return "This machine is set to \(provider.title), which ShotScribe cannot use yet — "
             + "titling falls back to Claude."
    }
}
