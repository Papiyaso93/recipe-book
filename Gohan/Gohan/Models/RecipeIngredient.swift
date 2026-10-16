//
//  RecipeIngredient.swift
//  Gohan
//

import Foundation
import SwiftData

/// Join entity: one line "N grammes/unités de X" within a recipe.
@Model
final class RecipeIngredient {
    var quantity: Double

    var ingredient: Ingredient?
    var unit: MeasurementUnit?
    var recipe: Recipe?

    init(quantity: Double, ingredient: Ingredient? = nil, unit: MeasurementUnit? = nil) {
        self.quantity = quantity
        self.ingredient = ingredient
        self.unit = unit
    }
}
