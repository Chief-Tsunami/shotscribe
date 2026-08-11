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
            Toggle(isOn: $model.watching) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auto-rename new screenshots")
                    Text("Watches the capture folder; only default “Screenshot …” names are touched.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Toggle(isOn: $model.useClaude) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Title with Claude")
                    Text(model.claudeAvailable
                         ? "Sharper labels via the local claude CLI (only the OCR text is sent)."
                         : "The claude CLI isn’t installed — using the offline titler.")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .disabled(!model.claudeAvailable)
        }
        .toggleStyle(.switch)
        .controlSize(.small)
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
