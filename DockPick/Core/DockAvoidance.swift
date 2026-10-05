import CoreGraphics

enum DockAvoidance {
    /// Zone utilisable (Cocoa) une fois retirée la place occupée par le Dock sur cet écran.
    /// Utile quand le Dock se masque automatiquement : visibleFrame l'inclut alors qu'il recouvre la vue.
    static func usableFrame(visibleFrame: CGRect, dockFrames: [CGRect]) -> CGRect {
        var frame = visibleFrame
        for dock in dockFrames {
            let overlap = dock.intersection(visibleFrame)
            guard !overlap.isNull, overlap.width > 0, overlap.height > 0 else { continue }
            // Les fenêtres plein écran transparentes du Dock ne sont pas la barre d'icônes.
            guard overlap.width * overlap.height < visibleFrame.width * visibleFrame.height / 2 else { continue }

            if overlap.width >= overlap.height {
                if overlap.midY < visibleFrame.midY {
                    let top = frame.maxY
                    frame.origin.y = max(frame.minY, overlap.maxY)
                    frame.size.height = top - frame.minY
                } else {
                    frame.size.height = min(frame.maxY, overlap.minY) - frame.minY
                }
            } else if overlap.midX < visibleFrame.midX {
                let right = frame.maxX
                frame.origin.x = max(frame.minX, overlap.maxX)
                frame.size.width = right - frame.minX
            } else {
                frame.size.width = min(frame.maxX, overlap.minX) - frame.minX
            }
        }
        return frame
    }
}
