import SwiftUI
import AppKit
import ShotScribeCore

/// Owns the model. An `NSApplicationDelegateAdaptor` (not `@StateObject` on
/// the App) because the adaptor is instantiated **at launch** — a
/// `@StateObject` referenced only inside the MenuBarExtra content closure
/// isn't created until the panel first opens, which would mean no folder
/// watching until the first click. Found the hard way.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var welcome: NSWindow?

    /// First launch: a menu-bar-only app looks like "nothing happened" from
    /// Spotlight/Finder — the welcome window says where the app lives.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if !UserDefaults.standard.bool(forKey: "shotscribe.welcomed") {
            UserDefaults.standard.set(true, forKey: "shotscribe.welcomed")
            showWelcome()
        }
    }

    /// Launched again while running (double-click in Finder, Spotlight ↩) —
    /// same answer: point at the menu bar instead of doing nothing.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows: Bool) -> Bool {
        showWelcome()
        return true
    }

    func showWelcome() {
        if welcome == nil {
            let host = NSHostingController(
                rootView: WelcomeView(model: model) { [weak self] in
                    self?.welcome?.close()
                })
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable, .fullSizeContentView]
            w.titleVisibility = .hidden
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.title = "ShotScribe"
            welcome = w
        }
        welcome?.center()
        welcome?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

/// "You just launched a menu bar app" — shown on first run and on reopen.
struct WelcomeView: View {
    @ObservedObject var model: AppModel
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage ?? NSImage())
                .resizable().frame(width: 84, height: 84)
            Text("ShotScribe lives in your menu bar")
                .font(.title2.weight(.semibold))
            Label {
                Text("Look for this icon at the top-right of your screen — click it for settings and history.")
            } icon: {
                Image(systemName: "text.viewfinder")
            }
            .font(.callout)
            .frame(maxWidth: 360, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                row(icon: "folder",
                    text: "Watching **\(model.folder.lastPathComponent)** — new screenshots get renamed to “date + what they show.”")
                row(icon: model.claudeAvailable ? "sparkles" : "keyboard",
                    text: model.claudeAvailable
                        ? "Titles use **your own Claude Code account** — ShotScribe ships no keys and sends only the text read off the image."
                        : "Titles come from the offline titler. Install **Claude Code** and sign in for sharper ones — on your own account, no keys involved.")
                if !model.claudeAvailable {
                    HStack {
                        Spacer().frame(width: 26)
                        Link("Get Claude Code →",
                             destination: URL(string: "https://claude.com/claude-code")!)
                            .font(.caption)
                    }
                }
            }
            .frame(maxWidth: 360, alignment: .leading)

            HStack {
                Button("Choose another folder…") { model.chooseFolder() }
                Spacer()
                Button("Got it") { onClose() }
                    .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: 360)
        }
        .padding(28)
        .frame(width: 430)
    }

    private func row(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon).frame(width: 18).foregroundStyle(.secondary)
            Text(.init(text)).font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// ShotScribe — the menu bar face of the engine. A small always-there panel:
/// watch toggle, titler preference, rename-latest, and recent history.
@main
struct ShotScribeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        // Accessory: no Dock icon even when run unbundled (`swift run`);
        // the bundle's LSUIElement covers the packaged case.
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra("ShotScribe", systemImage: "text.viewfinder") {
            PanelView(model: delegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct PanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            toggles
            actions
            if let err = model.lastError {
                Text(err).font(.caption2).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !model.events.isEmpty {
                Divider()
                history
            }
            Divider()
            footer
        }
        .padding(12)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.viewfinder").font(.title3)
                .foregroundStyle(model.watching ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("ShotScribe").font(.headline)
                Text(model.folder.path)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if model.busy { ProgressView().controlSize(.small) }
        }
    }

    private var toggles: some View {
        VStack(alignment: .leading, spacing: 6) {
            folderRow
            Toggle(isOn: $model.watching) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auto-rename new screenshots")
                    Text("Watches the folder above; only default “Screenshot …” names are touched.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $model.useClaude) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Title with Claude")
                    Text(model.claudeAvailable
                         ? "Uses your own Claude Code account — only the text read off the image is sent."
                         : "Claude Code isn’t installed — using the offline titler.")
                        .font(.caption2).foregroundStyle(.secondary)
                    if !model.claudeAvailable {
                        Link("Get Claude Code — titles run on your own account",
                             destination: URL(string: "https://claude.com/claude-code")!)
                            .font(.caption2)
                    }
                }
            }
            .disabled(!model.claudeAvailable)
            Toggle(isOn: Binding(
                get: { model.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            )) {
                Text("Launch at login")
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private var folderRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "folder").foregroundStyle(.secondary)
            Text(model.folder.lastPathComponent)
                .font(.caption).lineLimit(1).truncationMode(.middle)
                .help(model.folder.path)
            if model.usesCustomFolder {
                Button {
                    model.useSystemFolder()
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .buttonStyle(.plain).controlSize(.mini)
                .help("Back to the system screenshot folder")
            }
            Spacer()
            Button("Change…") { model.chooseFolder() }
                .controlSize(.mini)
        }
    }

    private var actions: some View {
        Button {
            model.renameLatest()
        } label: {
            Label("Rename latest capture now", systemImage: "wand.and.stars")
        }
        .disabled(model.busy)
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Recent").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(model.events.prefix(6)) { e in
                VStack(alignment: .leading, spacing: 0) {
                    Text(e.to).font(.caption).lineLimit(1).truncationMode(.middle)
                    Text(e.from).font(.caption2).foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Open folder") {
                NSWorkspace.shared.open(model.folder)
            }
            .buttonStyle(.link).font(.caption)
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.link).font(.caption)
        }
    }
}
