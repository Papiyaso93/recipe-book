//
//  FocusedPhoto.swift
//  Gohan
//

import SwiftUI

/// Affiche une photo en mode "scaledToFill" qui garde un point précis centré (`focusX`/`focusY`,
/// 0...1 sur chaque axe) au lieu de toujours centrer l'image elle-même — utilisé partout où une
/// photo de recette s'affiche (carte, fiche, formulaire, partage), pour qu'un recadrage choisi
/// une fois dans le formulaire (issue #58) s'applique de façon cohérente malgré les formats
/// différents de chaque écran.
struct FocusedPhoto: View {
    let image: UIImage
    var focusX: Double = 0.5
    var focusY: Double = 0.5
    /// 1 = pas de zoom (comportement d'origine) ; >1 = zoomée sur le point de focus.
    var zoomScale: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let imageSize = image.size
            if containerSize.width > 0, containerSize.height > 0, imageSize.width > 0, imageSize.height > 0 {
                let scale = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height) * max(zoomScale, 1.0)
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                let overflowX = max(scaledWidth - containerSize.width, 0)
                let overflowY = max(scaledHeight - containerSize.height, 0)
                let offsetX = ((0.5 - focusX) * scaledWidth).clamped(to: -overflowX / 2...overflowX / 2)
                let offsetY = ((0.5 - focusY) * scaledHeight).clamped(to: -overflowY / 2...overflowY / 2)

                // Taille explicite (pas `.scaledToFill()`, qui recalculerait lui-même la taille
                // pour remplir le cadre et ignorerait `zoomScale`) — `scaledWidth`/`scaledHeight`
                // incluent déjà le zoom, `.resizable()` seul se contente de les respecter.
                Image(uiImage: image)
                    .resizable()
                    .frame(width: scaledWidth, height: scaledHeight)
                    .offset(x: offsetX, y: offsetY)
                    .frame(width: containerSize.width, height: containerSize.height)
                    .clipped()
            }
        }
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
