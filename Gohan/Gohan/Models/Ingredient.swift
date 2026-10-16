//
//  Ingredient.swift
//  Gohan
//

import Foundation
import SwiftData

@Model
final class Ingredient {
    var name: String
    /// Code in the French CIQUAL nutrition database, when available.
    var ciqualCode: String?

    var caloriesPer100g: Double
    var proteinsPer100g: Double
    var carbsPer100g: Double
    var fatPer100g: Double
    var fiberPer100g: Double

    /// Weight in grams of a single "Unité" of this ingredient (e.g. 1 oeuf ≈ 50g).
    /// Only relevant when a recipe ingredient uses the "Unité" measurement unit.
    var gramsPerUnit: Double?

    var group: IngredientGroup?

    init(
        name: String,
        ciqualCode: String? = nil,
        caloriesPer100g: Double,
        proteinsPer100g: Double,
        carbsPer100g: Double,
        fatPer100g: Double,
        fiberPer100g: Double,
        gramsPerUnit: Double? = nil,
        group: IngredientGroup? = nil
    ) {
        self.name = name
        self.ciqualCode = ciqualCode
        self.caloriesPer100g = caloriesPer100g
        self.proteinsPer100g = proteinsPer100g
        self.carbsPer100g = carbsPer100g
        self.fatPer100g = fatPer100g
        self.fiberPer100g = fiberPer100g
        self.gramsPerUnit = gramsPerUnit
        self.group = group
    }
}
