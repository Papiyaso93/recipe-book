//
//  Recipe+Characteristics.swift
//  Gohan
//

import Foundation

/// Caractéristiques déduites de la recette elle-même plutôt que taguées à la main —
/// toujours justes, même si la recette est modifiée après coup. Pas encore affichées/
/// utilisées comme filtres nulle part : c'est le rôle de l'issue #13 (recherche/filtres).
extension Recipe {
    var isSansCuisson: Bool {
        cookTimeMinutes == 0
    }

    var isRapide: Bool {
        totalTimeMinutes < 20
    }

    var hasPeuDIngredients: Bool {
        ingredients.count <= 5
    }

    var isHyperproteine: Bool {
        nutritionPerServing.proteins >= 25
    }
}
