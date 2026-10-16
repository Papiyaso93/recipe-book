//
//  Recipe+Nutrition.swift
//  Gohan
//

import Foundation

extension Recipe {
    var totalTimeMinutes: Int {
        prepTimeMinutes + cookTimeMinutes
    }

    var totalTimeLabel: String {
        "\(totalTimeMinutes) min"
    }

    /// Calcul minimal (calories uniquement) pour l'affichage en liste/carte.
    /// Le détail complet des macros (protéines/glucides/lipides) arrive avec l'issue #8.
    var caloriesPerServing: Double {
        guard servings > 0 else { return 0 }
        let total = ingredients.reduce(0.0) { $0 + $1.calories }
        return total / Double(servings)
    }

    var caloriesPerServingLabel: String {
        "\(Int(caloriesPerServing.rounded())) kcal"
    }
}
