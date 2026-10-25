//
//  RecipeIngredient+Nutrition.swift
//  Gohan
//

import Foundation

extension RecipeIngredient {
    /// Équivalent en grammes de cette ligne, utilisé pour les calculs nutritionnels.
    var gramsEquivalent: Double {
        guard let ingredient, let unit else { return 0 }

        // Poids spécifique à l'ingrédient en priorité pour les cuillères (une càs de miel et
        // une càs de farine ne pèsent pas pareil) — retombe sur l'approximation générique de
        // l'unité si rien n'est renseigné pour cet ingrédient précis.
        switch unit.name {
        case "Cuillère à café":
            if let gramsPerTeaspoon = ingredient.gramsPerTeaspoon {
                return quantity * gramsPerTeaspoon
            }
        case "Cuillère à soupe":
            if let gramsPerTablespoon = ingredient.gramsPerTablespoon {
                return quantity * gramsPerTablespoon
            }
        default:
            break
        }

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

    private var factor: Double { gramsEquivalent / 100 }

    var calories: Double { guard let ingredient else { return 0 }; return factor * ingredient.caloriesPer100g }
    var proteins: Double { guard let ingredient else { return 0 }; return factor * ingredient.proteinsPer100g }
    var carbs: Double { guard let ingredient else { return 0 }; return factor * ingredient.carbsPer100g }
    var fat: Double { guard let ingredient else { return 0 }; return factor * ingredient.fatPer100g }
}
