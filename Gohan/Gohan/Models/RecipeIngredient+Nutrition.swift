//
//  RecipeIngredient+Nutrition.swift
//  Gohan
//

import Foundation

extension RecipeIngredient {
    /// Équivalent en grammes de cette ligne, utilisé pour les calculs nutritionnels.
    var gramsEquivalent: Double {
        guard let ingredient, let unit else { return 0 }

        if let conversionToGrams = unit.conversionToGrams {
            return quantity * conversionToGrams
        }

        // Unité sans conversion générique (ex: "Unité") : on retombe sur le poids
        // spécifique à l'ingrédient, quand il est renseigné.
        if let gramsPerUnit = ingredient.gramsPerUnit {
            return quantity * gramsPerUnit
        }

        return 0
    }

    var calories: Double {
        guard let ingredient else { return 0 }
        return gramsEquivalent / 100 * ingredient.caloriesPer100g
    }
}
