import Foundation

/// Watches a directory and reports newly-arrived image files. Uses a
/// `DispatchSource` on the directory's file descriptor (a write to the dir —
/// a new file landing — fires the event), debounced, then diffs against the
/// set of files already seen.
///
/// Deliberately simple: it reports *new* image paths and lets the caller
/// decide what to do (the CLI hands each to `Renamer`). Files present when the
/// watch starts are treated as already-seen, so it only acts on fresh shots.
public final class FolderWatcher: @unchecked Sendable {
    public let directory: URL
    private let onNewFile: @Sendable (URL) -> Void
    private let queue = DispatchQueue(label: "shotscribe.folderwatcher")
    private var source: DispatchSourceFileSystemObject?
    private var fd: Int32 = -1
    private var seen: Set<String> = []
    private var debounce: DispatchWorkItem?

    private static let imageExts: Set<String> = ["png", "jpg", "jpeg", "gif", "tiff", "heic", "bmp"]

    public init(directory: URL, onNewFile: @escaping @Sendable (URL) -> Void) {
        self.directory = directory
        self.onNewFile = onNewFile
    }

    /// Begin watching. Returns false if the directory can't be opened.
    @discardableResult
    public func start() -> Bool {
        fd = open(directory.path, O_EVTONLY)
        guard fd >= 0 else { return false }
        seen = Set(currentImageFiles().map(\.path))   // ignore the existing backlog

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .rename], queue: queue)
        src.setEventHandler { [weak self] in self?.scheduleScan() }
        src.setCancelHandler { [weak self] in
            if let fd = self?.fd, fd >= 0 { close(fd) }
            self?.fd = -1
        }
        source = src
        src.resume()
        return true
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    /// Treat `url` as already seen. An undo puts a file back under the raw
    /// "Screenshot …" name — exactly what this watcher reports as new — so the
    /// caller announces it here first, and the scan that follows skips it.
    public func ignore(_ url: URL) {
        queue.sync { seen.insert(url.path) }
    }

    /// Debounce bursts (a capture can touch the dir several times) into one scan.
    private func scheduleScan() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.scan() }
        debounce = work
        queue.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func scan() {
        for url in currentImageFiles() where !seen.contains(url.path) {
            seen.insert(url.path)
            onNewFile(url)
        }
    }

    private func currentImageFiles() -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]) else { return [] }
        return items.filter { Self.imageExts.contains($0.pathExtension.lowercased()) }
    }

    /// The user's configured macOS screenshot location
    /// (`com.apple.screencapture location`), or ~/Desktop if unset.
    public static func defaultScreenshotDirectory() -> URL {
        if let raw = CFPreferencesCopyAppValue(
            "location" as CFString, "com.apple.screencapture" as CFString) as? String {
            return URL(fileURLWithPath: (raw as NSString).expandingTildeInPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
    }
}
