//
//  ImageUtilities.swift
//  Gohan
//

import UIKit

enum ImageUtilities {
    /// Les photos caméra/bibliothèque sortent telles quelles (plusieurs Mo, résolution capteur
    /// complète) — stockées ou envoyées sans retouche, elles rendent tout écran qui les affiche
    /// perceptiblement lent, et gonflent inutilement le coût d'un appel d'import IA. On réduit
    /// une fois, à la source, plutôt que de retoucher chaque point d'usage.
    static func downscaledJPEG(from data: Data, maxDimension: CGFloat = 1600, quality: CGFloat = 0.8) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        guard scale < 1 else { return image.jpegData(compressionQuality: quality) ?? data }
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: targetSize)) }
        return resized.jpegData(compressionQuality: quality) ?? data
    }
}
