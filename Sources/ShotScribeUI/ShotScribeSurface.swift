import SwiftUI
import UniformTypeIdentifiers
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
    @State private var folderTargeted = false

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
                // One column, in the order you read it: where shots land, what
                // ShotScribe does to them, then how to find one.
                folderRow
                actionsBlock
                searchField
                errorLine
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

    /// What ShotScribe does to what lands in the folder.
    private var actionsBlock: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                watchToggle
                claudeToggle
                Divider()
                HStack {
                    renameAction
                    Spacer()
                    Button("Open folder") { NSWorkspace.shared.open(model.folder) }
                        .controlSize(.small)
                }
            }
            .padding(4)
        }
    }

    /// One field. It searches what the screenshots SAY, because ShotScribe
    /// already read every one of them to name it and the text is kept.
    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Find a screenshot", text: $model.query)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit { model.runSearch() }
                .onChange(of: model.query) { _ in model.runSearch() }
            if !model.query.isEmpty {
                Button { model.query = ""; model.runSearch() } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.quinary))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
            .strokeBorder(.separator, lineWidth: 1))
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
                HStack(spacing: 10) {
                    Text(model.query.isEmpty
                         ? "\(model.visibleShots.count) screenshots"
                         : "\(model.visibleShots.count) match\(model.visibleShots.count == 1 ? "" : "es")")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)

                    if model.selecting {
                        Text("· \(model.selected.count) selected")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("All") { model.selectAllVisible() }.controlSize(.small)
                        Button(role: .destructive) {
                            model.trashSelected()
                        } label: {
                            Label("Move to Trash", systemImage: "trash")
                        }
                        .controlSize(.small)
                        .disabled(model.selected.isEmpty)
                    }

                    Spacer()

                    Button {
                        model.selecting.toggle()
                    } label: {
                        Image(systemName: model.selecting
                              ? "checkmark.circle.fill" : "checkmark.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.selecting ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .help(model.selecting ? "Done selecting" : "Select screenshots")

                    Picker("", selection: $model.sort) {
                        ForEach(ShotScribeModel.ShotSort.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 132)
                    .help("Sort")

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
                Button {
                    model.selecting ? model.toggleSelected(shot) : model.reveal(shot)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        if model.selecting {
                            Image(systemName: model.selected.contains(shot.path)
                                  ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(model.selected.contains(shot.path)
                                                 ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                        }
                        Text(shot.name).font(.callout.weight(.medium))
                            .lineLimit(1).truncationMode(.middle)
                            .frame(minWidth: 180, alignment: .leading)
                        if let snip = model.snippet(for: shot), !snip.isEmpty {
                            Text(snip).font(.caption).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.tail)
                        }
                        Spacer(minLength: 8)
                        Text(shot.captured, format: .dateTime.year().month().day())
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
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
                Button {
                    model.selecting ? model.toggleSelected(shot) : model.reveal(shot)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Thumbnail(path: shot.path)
                            .overlay(alignment: .topLeading) {
                                if model.selecting {
                                    Image(systemName: model.selected.contains(shot.path)
                                          ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 17))
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.white, model.selected.contains(shot.path)
                                                         ? AnyShapeStyle(.tint) : AnyShapeStyle(.black.opacity(0.35)))
                                        .padding(7)
                                }
                            }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(shot.name).font(.caption.weight(.medium))
                                .lineLimit(1).truncationMode(.middle)
                            Text(shot.captured, format: .dateTime.year().month().day())
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8).padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(.quinary)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(model.selected.contains(shot.path)
                                      ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                                      lineWidth: model.selected.contains(shot.path) ? 2 : 1))
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

    /// The watch folder, as a drop target with one-click alternatives.
    ///
    /// It was a label and a "Change…" button, which put a file picker between
    /// you and a folder already open in Finder. Dropping the folder says the
    /// same thing in one gesture, and the three named choices cover the places
    /// captures actually live without opening anything.
    private var folderRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: folderTargeted ? "folder.fill.badge.plus" : "folder")
                    .foregroundStyle(folderTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("Dropzone").font(.caption2.weight(.bold))
                            .foregroundStyle(.secondary).textCase(.uppercase)
                        Text(model.folder.lastPathComponent)
                            .font(.callout.weight(.medium)).lineLimit(1).truncationMode(.middle)
                    }
                    Text(folderTargeted
                         ? "Drop to watch this folder"
                         : "Screenshots landing here get named for what they show")
                        .font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer(minLength: 8)
                if model.usesCustomFolder {
                    Button { model.useSystemFolder() } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain).controlSize(.small)
                    .help("Back to the system screenshot folder")
                }
                // A menu rather than a button: the answer is almost always one
                // of four known folders, and a file picker for that is a dialog
                // standing between you and a one-click choice.
                Menu {
                    Section("Current") {
                        Button {
                        } label: {
                            Label(model.folder.lastPathComponent, systemImage: "checkmark")
                        }
                        .disabled(true)
                    }
                    Section("Common") {
                        ForEach(ShotScribeModel.quickFolders) { c in
                            Button {
                                model.use(c)
                            } label: {
                                Text(c.label)
                            }
                            .disabled(model.folder.path == c.url.path)
                        }
                    }
                    Divider()
                    Button("Choose another folder…") { model.chooseFolder() }
                    if model.usesCustomFolder {
                        Button("Back to system screenshot folder") { model.useSystemFolder() }
                    }
                } label: {
                    Text("Change")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .controlSize(.small)
            }
            .padding(9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    .foregroundStyle(folderTargeted ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator)))
            .contentShape(Rectangle())
            .onDrop(of: [UTType.fileURL], isTargeted: $folderTargeted) { providers in
                guard let p = providers.first else { return false }
                _ = p.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    Task { @MainActor in model.acceptDrop(url) }
                }
                return true
            }

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
                // Say when the machine's setting overrides this toggle, rather
                // than leaving it on and quietly using the offline titler.
                if let note = model.llmMismatchNote {
                    Text(note).font(.caption2)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
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
                    Text(e.from).font(.caption2).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
        }
    }
}
