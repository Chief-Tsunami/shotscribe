import Foundation
import ShotScribeCore

// shotscribe — CLI front end over ShotScribeCore.
//
//   shotscribe label  [--no-claude] <file>
//   shotscribe rename [--no-claude] [--dry-run] [--force] <file>
//   shotscribe watch  [--no-claude] [dir]
//
// Zero third-party dependencies — argument parsing is deliberately tiny.

func makeTitler(noClaude: Bool) -> Titler {
    if noClaude { return KeywordTitler() }
    if ClaudeTitler.isAvailable() { return ClaudeTitler() }
    FileHandle.standardError.write(Data(
        "note: `claude` not found — using the offline keyword titler.\n".utf8))
    return KeywordTitler()
}

func expand(_ path: String) -> URL {
    URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
}

func describe(_ outcome: RenameOutcome) -> String {
    switch outcome {
    case .renamed(let from, let to):
        return "renamed  \(from.lastPathComponent)\n      →  \(to.lastPathComponent)"
    case .wouldRename(let from, let to):
        return "would rename  \(from.lastPathComponent)\n           →  \(to.lastPathComponent)"
    case .skippedNotRawCapture(let url):
        return "skipped (not a macOS capture; use --force): \(url.lastPathComponent)"
    case .skippedNoLabel(let url):
        return "skipped (no usable label): \(url.lastPathComponent)"
    case .fileMissing(let url):
        return "error: file not found: \(url.path)"
    }
}

let usage = """
shotscribe — name screenshots so you can find them again.

USAGE:
  shotscribe label  [--no-claude] <file>            Print the title (no rename)
  shotscribe rename [--no-claude] [--dry-run] [--force] <file>
  shotscribe watch  [--no-claude] [dir]             Rename new captures as they land

FLAGS:
  --no-claude   Use the offline keyword titler instead of `claude -p`
  --dry-run     Show the new name without moving the file
  --force       Rename even files you named yourself (default: macOS captures only)
"""

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    print(usage); exit(0)
}
args.removeFirst()

let noClaude = args.contains("--no-claude")
let dryRun   = args.contains("--dry-run")
let force    = args.contains("--force")
let positional = args.filter { !$0.hasPrefix("--") }

let titler = makeTitler(noClaude: noClaude)
let renamer = Renamer(titler: titler)

switch command {
case "label":
    guard let file = positional.first else {
        FileHandle.standardError.write(Data("error: `label` needs a file path.\n".utf8)); exit(2)
    }
    let title = await renamer.label(fileAt: expand(file))
    print(title)

case "rename":
    guard let file = positional.first else {
        FileHandle.standardError.write(Data("error: `rename` needs a file path.\n".utf8)); exit(2)
    }
    do {
        let outcome = try await renamer.rename(fileAt: expand(file), force: force, dryRun: dryRun)
        print(describe(outcome))
    } catch {
        FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8)); exit(1)
    }

case "watch":
    let dir = positional.first.map(expand) ?? FolderWatcher.defaultScreenshotDirectory()
    print("shotscribe: watching \(dir.path)  (Ctrl-C to stop)")
    let watcher = FolderWatcher(directory: dir) { url in
        Task {
            do {
                let outcome = try await renamer.rename(fileAt: url, force: force, dryRun: dryRun)
                print(describe(outcome))
            } catch {
                FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            }
        }
    }
    guard watcher.start() else {
        FileHandle.standardError.write(Data("error: can't watch \(dir.path)\n".utf8)); exit(1)
    }
    dispatchMain()   // run forever

case "-h", "--help", "help":
    print(usage)

default:
    FileHandle.standardError.write(Data("error: unknown command '\(command)'.\n\n".utf8))
    print(usage); exit(2)
}
