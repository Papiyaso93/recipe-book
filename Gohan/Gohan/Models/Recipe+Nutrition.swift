//
//  Recipe+Nutrition.swift
//  Gohan
//

import Foundation

/// Calcul minimal (pas de cache/stockage) : recalculé à chaque accès à partir des ingrédients.
/// Suffisant pour une bibliothèque personnelle de quelques dizaines/centaines de recettes.
struct NutritionTotals {
    var calories: Double = 0
    var proteins: Double = 0
    var carbs: Double = 0
    var fat: Double = 0

    static func / (totals: NutritionTotals, divisor: Double) -> NutritionTotals {
        guard divisor > 0 else { return totals }
        return NutritionTotals(
            calories: totals.calories / divisor,
            proteins: totals.proteins / divisor,
            carbs: totals.carbs / divisor,
            fat: totals.fat / divisor
        )
    }
}

extension Recipe {
    var totalTimeMinutes: Int {
        prepTimeMinutes + cookTimeMinutes
    }

    var totalTimeLabel: String {
        "\(totalTimeMinutes) min"
    }

    var totalNutrition: NutritionTotals {
        ingredients.reduce(into: NutritionTotals()) { totals, line in
            totals.calories += line.calories
            totals.proteins += line.proteins
            totals.carbs += line.carbs
            totals.fat += line.fat
        }
    }

    var nutritionPerServing: NutritionTotals {
        totalNutrition / Double(servings)
    }

    var caloriesPerServing: Double {
        nutritionPerServing.calories
    }

    var caloriesPerServingLabel: String {
        "\(Int(caloriesPerServing.rounded())) kcal"
    }

    /// `true` si au moins une ligne contribue 0 aux valeurs nutritionnelles sans que ce soit
    /// visible autrement : un ingrédient non reconnu (jamais rapproché de la bibliothèque), ou
    /// saisi en "Unité" (ou toute unité sans conversion générique) sans poids spécifique
    /// renseigné sur l'ingrédient. Sans ce signal, le total affiché a l'air complet alors qu'il
    /// est sous-évalué.
    var hasIncompleteNutrition: Bool {
        ingredients.contains { line in
            guard let ingredient = line.ingredient else { return true }
            guard let unit = line.unit, unit.conversionToGrams == nil else { return false }
            return ingredient.gramsPerUnit == nil
        }
    }
}
