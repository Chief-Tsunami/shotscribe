import SwiftUI
import AppKit

/// How much room the surface has, and therefore which controls make sense.
public enum ShotScribeChrome {
    /// A 340pt menu bar popover: compact, and the place where app-level
    /// controls (launch at login, Quit) belong.
    case menuBar
    /// A roomy detail pane inside some other window. App-level controls are
    /// omitted — `SMAppService.mainApp` would register *that* host at login,
    /// and "Quit" would quit it.
    case hosted
}

/// **ShotScribe's face.** Watch toggle, titler preference, rename-latest, and
/// recent history over a `ShotScribeModel`.
///
/// Self-contained: no arguments, owns its state, one line to mount. Per the
/// repo's doctrine this package has no idea what's hosting it and must never
/// grow one.
public struct ShotScribeSurface: View {
    @StateObject private var model = ShotScribeModel()
    private let chrome: ShotScribeChrome

    public init(chrome: ShotScribeChrome = .hosted) {
        self.chrome = chrome
    }

    public var body: some View {
        ShotScribeView(model: model, chrome: chrome)
    }
}

/// The same surface driven by a model the host already owns — the menu bar app
/// uses it so its welcome window and its panel share one watcher. Note the
/// `@ObservedObject`: a stored `let` here means the view never redraws when a
/// rename lands.
public struct ShotScribeView: View {
    @ObservedObject var model: ShotScribeModel
    let chrome: ShotScribeChrome

    public init(model: ShotScribeModel, chrome: ShotScribeChrome = .hosted) {
        self.model = model
        self.chrome = chrome
    }

    public var body: some View {
        switch chrome {
        case .menuBar: panel
        case .hosted:  pane
        }
    }

    // MARK: Menu bar popover

    private var panel: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            folderRow
            watchToggle
            claudeToggle
            Toggle(isOn: Binding(get: { model.launchAtLogin },
                                 set: { model.setLaunchAtLogin($0) })) {
                Text("Launch at login")
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            renameAction
            errorLine
            if !model.events.isEmpty {
                Divider()
                historyList(limit: 6)
            }
            Divider()
            HStack {
                Button("Open folder") { NSWorkspace.shared.open(model.folder) }
                    .buttonStyle(.link).font(.caption)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.link).font(.caption)
            }
        }
        .padding(12)
        .frame(width: 340)
    }

    // MARK: Hosted detail pane

    private var pane: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if model.otherInstanceRunning { standDownBanner }
                GroupBox {
                    VStack(alignment: .leading, spacing: 10) {
                        folderRow
                        Divider()
                        watchToggle
                        claudeToggle
                    }
                    .padding(4)
                }
                .frame(maxWidth: 620, alignment: .leading)
                HStack {
                    renameAction
                    Spacer()
                    Button("Open folder") { NSWorkspace.shared.open(model.folder) }
                }
                .frame(maxWidth: 620, alignment: .leading)
                errorLine
                searchBlock
                shotsBlock
                if model.visibleShots.isEmpty && model.events.isEmpty {
                    Text("Nothing renamed yet. New captures that land in the folder above get a name that says what they show.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    historyList(limit: 20)
                }
            }
            .padding(22)
            // The controls stay in a readable column; the SHOTS get the window.
            // This pane used to cap everything at 620pt, so on a 1200pt window
            // the scrollbar sat at the pane edge while the content stopped well
            // short of it — the whole surface read as a narrow page floating in
            // dead space.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    /// Finding a screenshot by what it SAID.
    ///
    /// ShotScribe already reads every capture to name it; the index keeps that
    /// text instead of discarding it. A three-word title is a thin hook a month
    /// later — you remember the error message, not the label.
    @ViewBuilder
    private var searchBlock: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Search what your screenshots say…", text: $model.query)
                        .textFieldStyle(.plain)
                        .onSubmit { model.runSearch() }
                        .onChange(of: model.query) { _ in model.runSearch() }
                    if !model.query.isEmpty {
                        Button { model.query = ""; model.runSearch() } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain).foregroundStyle(.tertiary)
                    }
                }

                if model.indexing {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text(model.indexProgress.map { "Reading \($0.0) of \($0.1)…" } ?? "Reading…")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                } else if model.query.isEmpty {
                    HStack(spacing: 8) {
                        Text("\(model.indexedCount) screenshots indexed")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button("Re-read folder") { model.rebuildIndex() }
                            .controlSize(.small)
                    }
                } else if model.visibleShots.isEmpty {
                    Text("Nothing matched. Captures taken before the index was built need one pass — use Re-read folder.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(4)
        }
        .frame(maxWidth: 620, alignment: .leading)
    }

    /// The shots themselves, in whichever view is chosen.
    ///
    /// Both views read `visibleShots` — search hits when searching, the whole
    /// indexed corpus otherwise — so the index doubles as the browser. The
    /// rename history cannot do that job: it is capped and holds no paths.
    @ViewBuilder
    private var shotsBlock: some View {
        if !model.visibleShots.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(model.query.isEmpty
                         ? "All screenshots"
                         : "\(model.visibleShots.count) match\(model.visibleShots.count == 1 ? "" : "es")")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: $model.shotView) {
                        ForEach(ShotScribeModel.ShotView.allCases) { v in
                            Image(systemName: v.symbol).tag(v).help(v.label)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
                switch model.shotView {
                case .list:  shotsList
                case .tiles: shotsTiles
                }
            }
        }
    }

    private var shotsList: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            ForEach(model.visibleShots.prefix(300)) { shot in
                Button { model.reveal(shot) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(shot.name).font(.callout.weight(.medium))
                            .lineLimit(1).truncationMode(.middle)
                            .frame(minWidth: 180, alignment: .leading)
                        if let snip = model.snippet(for: shot), !snip.isEmpty {
                            Text(snip).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.tail)
                        }
                        Spacer(minLength: 8)
                        Text(shot.captured, format: .dateTime.year().month().day())
                            .font(.caption).foregroundStyle(.tertiary).monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(shot.path)
                Divider()
            }
        }
    }

    private var shotsTiles: some View {
        // Adaptive columns rather than a fixed count: the pane is 680pt on the
        // belt and whatever the user drags it to standalone, and a fixed grid
        // wastes exactly the space this change was meant to reclaim.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 190, maximum: 280), spacing: 12)],
                  alignment: .leading, spacing: 12) {
            ForEach(model.visibleShots.prefix(300)) { shot in
                Button { model.reveal(shot) } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Thumbnail(path: shot.path)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(shot.name).font(.caption.weight(.medium))
                                .lineLimit(1).truncationMode(.middle)
                            Text(shot.captured, format: .dateTime.year().month().day())
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(.separator, lineWidth: 1))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(shot.path)
            }
        }
    }

    /// The one thing a hosted copy must say out loud: it is deliberately not
    /// watching, and why.
    private var standDownBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("ShotScribe.app is running").font(.callout.weight(.semibold))
                Text("It already watches this folder. Two watchers would race to rename the same capture, so this copy is standing down — quit ShotScribe.app and it picks up automatically.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Shared pieces

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "text.viewfinder")
                .font(chrome == .hosted ? .largeTitle : .title3)
                .foregroundStyle(model.watching && !model.otherInstanceRunning
                                 ? Color.accentColor : .secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text("ShotScribe").font(chrome == .hosted ? .title2.weight(.semibold) : .headline)
                Text(model.folder.path)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            if model.busy { ProgressView().controlSize(.small) }
        }
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

    private var watchToggle: some View {
        Toggle(isOn: $model.watching) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Auto-rename new screenshots")
                Text("Watches the folder above; only default “Screenshot …” names are touched.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
        .disabled(model.otherInstanceRunning)
    }

    private var claudeToggle: some View {
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
        .toggleStyle(.switch)
        .controlSize(.small)
        .disabled(!model.claudeAvailable)
    }

    private var renameAction: some View {
        Button {
            model.renameLatest()
        } label: {
            Label("Rename latest capture now", systemImage: "wand.and.stars")
        }
        .disabled(model.busy || model.otherInstanceRunning)
    }

    @ViewBuilder
    private var errorLine: some View {
        if let err = model.lastError {
            Text(err).font(.caption2).foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func historyList(limit: Int) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Recent").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(model.events.prefix(limit)) { e in
                VStack(alignment: .leading, spacing: 0) {
                    Text(e.to).font(.caption).lineLimit(1).truncationMode(.middle)
                    Text(e.from).font(.caption2).foregroundStyle(.tertiary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }
}
