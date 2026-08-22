import AppKit
import QuickLookThumbnailing
import SwiftUI

/// Thumbnails for the tile view.
///
/// Uses `QLThumbnailGenerator` rather than loading the PNG and scaling it: the
/// system already keeps thumbnails for files you have looked at, so this is
/// mostly a cache read, and it never decodes a full 6MB retina screenshot to
/// draw a 200pt tile. With 125 captures the difference is the grid appearing
/// versus the grid stuttering.
@MainActor
final class ThumbnailCache: ObservableObject {
    static let shared = ThumbnailCache()
    private let cache = NSCache<NSString, NSImage>()
    private var inFlight: Set<String> = []

    private init() { cache.countLimit = 400 }

    func cached(_ path: String) -> NSImage? { cache.object(forKey: path as NSString) }

    func load(_ path: String, size: CGSize, scale: CGFloat) async -> NSImage? {
        if let hit = cached(path) { return hit }
        guard !inFlight.contains(path) else { return nil }
        inFlight.insert(path)
        defer { inFlight.remove(path) }

        let req = QLThumbnailGenerator.Request(
            fileAt: URL(fileURLWithPath: path), size: size,
            scale: scale, representationTypes: .thumbnail)
        let image: NSImage? = await withCheckedContinuation { cont in
            QLThumbnailGenerator.shared.generateBestRepresentation(for: req) { rep, _ in
                cont.resume(returning: rep.map { NSImage(cgImage: $0.cgImage, size: .zero) })
            }
        }
        if let image { cache.setObject(image, forKey: path as NSString) }
        return image
    }
}

struct Thumbnail: View {
    let path: String
    var height: CGFloat = 116
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable().aspectRatio(contentMode: .fill)
            } else {
                Rectangle().fill(.quaternary)
                    .overlay(Image(systemName: "photo")
                        .foregroundStyle(.tertiary).font(.system(size: 18)))
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .task(id: path) {
            image = ThumbnailCache.shared.cached(path)
            if image == nil {
                image = await ThumbnailCache.shared.load(
                    path, size: CGSize(width: 480, height: 300), scale: 2)
            }
        }
    }
}
