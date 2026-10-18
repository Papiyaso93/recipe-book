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

    /// Présence de cette ligne dans la liste de courses — distincte d'une simple quantité,
    /// plusieurs recettes peuvent contribuer au même ingrédient/unité (cumul dans ShoppingListView).
    var isInShoppingList: Bool = false
    /// Coché pendant les courses — suit la ligne, pas l'agrégat, pour rester cohérent si on
    /// retire une recette qui contribuait à un ingrédient déjà coché.
    var isCheckedInShoppingList: Bool = false

    init(quantity: Double, ingredient: Ingredient? = nil, unit: MeasurementUnit? = nil) {
        self.quantity = quantity
        self.ingredient = ingredient
        self.unit = unit
    }
}
