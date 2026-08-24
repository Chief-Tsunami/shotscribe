import SwiftUI

/// The tool's own app icon in its title bar, falling back to a glyph.
///
/// **The rail and the board already draw the app icon; a different symbol in
/// the title made one tool look like two.** Drawn larger than a symbol would
/// be, because these are illustrations with a face on them and at symbol size
/// the face is the first thing lost.
///
/// The icon is never tinted — it is artwork. The `tint` applies only to the
/// fallback glyph, for a build where the resource did not ship.
struct ToolIcon: View {
    let icon: Image?
    let fallback: String
    var tint: Color = .accentColor
    var size: CGFloat = 42

    var body: some View {
        Group {
            if let icon {
                icon.resizable().aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: fallback)
                    .font(.system(size: size * 0.62))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
