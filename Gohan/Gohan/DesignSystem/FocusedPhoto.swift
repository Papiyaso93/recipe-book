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

    var body: some View {
        GeometryReader { geo in
            let containerSize = geo.size
            let imageSize = image.size
            if containerSize.width > 0, containerSize.height > 0, imageSize.width > 0, imageSize.height > 0 {
                let scale = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
                let scaledWidth = imageSize.width * scale
                let scaledHeight = imageSize.height * scale
                let overflowX = max(scaledWidth - containerSize.width, 0)
                let overflowY = max(scaledHeight - containerSize.height, 0)
                let offsetX = ((0.5 - focusX) * scaledWidth).clamped(to: -overflowX / 2...overflowX / 2)
                let offsetY = ((0.5 - focusY) * scaledHeight).clamped(to: -overflowY / 2...overflowY / 2)

                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: containerSize.width, height: containerSize.height)
                    .offset(x: offsetX, y: offsetY)
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
