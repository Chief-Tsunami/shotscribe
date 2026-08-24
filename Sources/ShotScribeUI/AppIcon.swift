import SwiftUI

public extension ShotScribeSurface {

    /// ShotScribe's own app icon, for a host that wants to show it.
    ///
    /// **Loaded from `Bundle.module`, never `Bundle.main`.** Standalone the two
    /// are the same thing; mounted inside another app they are not, and
    /// `Bundle.main` would resolve to the *host's* bundle — returning the host's
    /// icon, or nothing. The same trap as reading `UserDefaults.standard` from
    /// inside somebody else's process.
    ///
    /// Exposed rather than reached for: a host may ask ShotScribe for its face,
    /// and gets whatever ShotScribe decides that is.
    static var appIcon: Image? {
        guard let url = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        return Image(nsImage: image)
    }
}
