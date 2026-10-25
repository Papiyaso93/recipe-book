//
//  ZoomableImageCropper.swift
//  Gohan
//

import SwiftUI
import UIKit

/// Repositionnement/zoom d'une photo via un vrai `UIScrollView` plutôt que des gestes SwiftUI
/// composés à la main (`DragGesture` + `MagnificationGesture`) — plusieurs tentatives ont montré
/// que SwiftUI ne combine pas ces deux gestes de façon fiable (limitation documentée, pas un bug
/// ponctuel de code). `UIScrollView` gère le pincement + glissement nativement depuis toujours ;
/// c'est le même mécanisme que l'app Photos utilise pour son propre écran de recadrage.
struct ZoomableImageCropper: UIViewRepresentable {
    let image: UIImage
    @Binding var focusX: Double
    @Binding var focusY: Double
    @Binding var zoomScale: Double

    static let maxZoom: CGFloat = 3

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = Self.maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = true

        let imageView = UIImageView(image: image)
        context.coordinator.imageView = imageView
        scrollView.addSubview(imageView)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard scrollView.bounds.width > 0, scrollView.bounds.height > 0 else { return }
        context.coordinator.layoutIfNeeded(scrollView: scrollView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: ZoomableImageCropper
        weak var imageView: UIImageView?
        /// Tant que l'utilisateur n'a pas commencé à toucher la vue, on réapplique la position
        /// initiale à chaque passe de layout plutôt qu'une seule fois — `scrollView.bounds`
        /// n'a pas forcément sa taille finale dès le premier appel (SwiftUI peut proposer une
        /// taille intermédiaire avant que la largeur réelle du formulaire soit établie), ce qui
        /// figeait un décalage calculé sur la mauvaise taille et faisait "sauter" l'image à
        /// l'entrée en mode recadrage.
        private var isUserInteracting = false

        init(_ parent: ZoomableImageCropper) {
            self.parent = parent
        }

        /// Taille "naturelle" (zoom 1x) de l'image affichée : couvre tout le cadre, comme
        /// `scaledToFill` — c'est à cette taille que `contentSize` est déclaré ; `UIScrollView`
        /// redimensionne lui-même la vue de `viewForZooming` d'un facteur `zoomScale` par-dessus.
        func layoutIfNeeded(scrollView: UIScrollView) {
            guard let imageView else { return }
            let containerSize = scrollView.bounds.size
            let imageSize = parent.image.size
            guard imageSize.width > 0, imageSize.height > 0 else { return }
            let fillScale = max(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
            let fillSize = CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)

            if imageView.frame.size != fillSize, scrollView.zoomScale == 1 {
                imageView.frame = CGRect(origin: .zero, size: fillSize)
                scrollView.contentSize = fillSize
            }

            guard !isUserInteracting else { return }

            scrollView.zoomScale = min(max(CGFloat(parent.zoomScale), 1), Self.parentMaxZoom)
            scrollView.layoutIfNeeded()
            let zoomedSize = imageView.frame.size
            guard zoomedSize.width > 0, zoomedSize.height > 0 else { return }
            let offsetX = CGFloat(parent.focusX) * zoomedSize.width - containerSize.width / 2
            let offsetY = CGFloat(parent.focusY) * zoomedSize.height - containerSize.height / 2
            scrollView.contentOffset = CGPoint(
                x: min(max(offsetX, 0), max(zoomedSize.width - containerSize.width, 0)),
                y: min(max(offsetY, 0), max(zoomedSize.height - containerSize.height, 0))
            )
        }

        private static let parentMaxZoom = ZoomableImageCropper.maxZoom

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            isUserInteracting = true
        }

        func scrollViewWillBeginZooming(_ scrollView: UIScrollView, with view: UIView?) {
            isUserInteracting = true
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            commit(scrollView)
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            commit(scrollView)
        }

        private func commit(_ scrollView: UIScrollView) {
            guard let imageView else { return }
            let zoomedSize = imageView.frame.size
            guard zoomedSize.width > 0, zoomedSize.height > 0 else { return }
            let visibleCenter = CGPoint(
                x: scrollView.contentOffset.x + scrollView.bounds.width / 2,
                y: scrollView.contentOffset.y + scrollView.bounds.height / 2
            )
            parent.focusX = min(max(visibleCenter.x / zoomedSize.width, 0), 1)
            parent.focusY = min(max(visibleCenter.y / zoomedSize.height, 0), 1)
            parent.zoomScale = Double(scrollView.zoomScale)
        }
    }
}
