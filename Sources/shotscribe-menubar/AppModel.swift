import Foundation
import SwiftUI
import ShotScribeCore

/// One rename the app performed — shown in the panel's history.
struct RenameEvent: Codable, Identifiable, Equatable {
    var id = UUID()
    var date: Date
    var from: String
    var to: String
}

/// The menu bar app's state: the watch toggle (wraps `FolderWatcher`), the
/// titler preference, and a small persisted history of renames.
///
/// `ObservableObject` (not `@Observable`) on purpose — keeps the package's
/// macOS 13 floor for open-source reach.
@MainActor
final class AppModel: ObservableObject {
    static let watchingKey = "shotscribe.watching"
    static let useClaudeKey = "shotscribe.useClaude"
    static let eventsKey = "shotscribe.events"
    private static let maxEvents = 20

    /// Auto-rename new captures as they land. ON by default: launching an app
    /// whose one job is renaming screenshots is the opt-in.
    @Published var watching: Bool {
        didSet {
            UserDefaults.standard.set(watching, forKey: Self.watchingKey)
            watching ? startWatcher() : stopWatcher()
        }
    }

    /// Title via the local `claude` CLI (sharper labels) vs the offline
    /// keyword titler. Only meaningful when `claudeAvailable`.
    @Published var useClaude: Bool {
        didSet { UserDefaults.standard.set(useClaude, forKey: Self.useClaudeKey) }
    }

    @Published private(set) var events: [RenameEvent] = []
    @Published private(set) var lastError: String?
    /// True while a rename (OCR + titling) is in flight — the panel shows a spinner.
    @Published private(set) var busy = false

    let claudeAvailable = ClaudeTitler.isAvailable()
    let folder = FolderWatcher.defaultScreenshotDirectory()
    private var watcher: FolderWatcher?

    init() {
        let ud = UserDefaults.standard
        watching = ud.object(forKey: Self.watchingKey) == nil
            ? true : ud.bool(forKey: Self.watchingKey)
        useClaude = ud.object(forKey: Self.useClaudeKey) == nil
            ? true : ud.bool(forKey: Self.useClaudeKey)
        if let data = ud.data(forKey: Self.eventsKey),
           let saved = try? JSONDecoder().decode([RenameEvent].self, from: data) {
            events = saved
        }
        if watching { startWatcher() }
    }

    // MARK: - Watching

    private func startWatcher() {
        guard watcher == nil else { return }
        let w = FolderWatcher(directory: folder) { url in
            // A capture can land before macOS finishes writing it (the floating
            // thumbnail lingers) — give the file a beat before reading.
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await self?.rename(url)
            }
        }
        if w.start() {
            watcher = w
        } else {
            lastError = "Can't watch \(folder.path)"
            watching = false
        }
    }

    private func stopWatcher() {
        watcher?.stop()
        watcher = nil
    }

    // MARK: - Renaming

    private var titler: Titler {
        (useClaude && claudeAvailable) ? ClaudeTitler() : KeywordTitler()
    }

    func rename(_ url: URL) async {
        busy = true
        defer { busy = false }
        do {
            // Compose OCR → title here (not inside Renamer) so a titler
            // failure is VISIBLE — logged and shown in the panel — instead of
            // silently falling back to the generic label.
            let path = url.path
            let ocr = await Task.detached(priority: .utility) {
                OCR.recognizeText(atPath: path)
            }.value
            Log.write("new capture \(url.lastPathComponent): ocr=\(ocr.count) chars")
            var label: String?
            do {
                label = try await titler.title(forOCRText: ocr)
                Log.write("title: \(label ?? "nil")")
            } catch {
                Log.write("titler FAILED: \(error)")
                lastError = "Titling failed — used the offline label. (\(error.localizedDescription))"
            }
            // label == nil → Renamer falls back to its own titler (offline).
            let outcome = try await Renamer(titler: KeywordTitler())
                .rename(fileAt: url, label: label)
            Log.write("outcome: \(outcome)")
            if case .renamed(let from, let to) = outcome {
                record(from: from.lastPathComponent, to: to.lastPathComponent)
                if label != nil { lastError = nil }
            }
        } catch {
            Log.write("rename FAILED: \(error)")
            lastError = error.localizedDescription
        }
    }

    /// The panel's "Rename latest now" — newest raw capture still wearing its
    /// default name. nil-safe: does nothing when everything's already tidy.
    func renameLatest() {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff"]
        let candidates = ((try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles])) ?? [])
            .filter { imageExts.contains($0.pathExtension.lowercased()) }
            .filter { Naming.isRawCapture($0.lastPathComponent) }
        let newest = candidates.max {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return a < b
        }
        guard let newest else {
            lastError = "No un-renamed captures in \(folder.lastPathComponent)."
            return
        }
        Task { await rename(newest) }
    }

    private func record(from: String, to: String) {
        events.insert(RenameEvent(date: Date(), from: from, to: to), at: 0)
        if events.count > Self.maxEvents { events.removeLast(events.count - Self.maxEvents) }
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: Self.eventsKey)
        }
    }
}
