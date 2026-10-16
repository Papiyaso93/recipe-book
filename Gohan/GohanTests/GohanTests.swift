//
//  GohanTests.swift
//  GohanTests
//
//  Created by Gus on 17/10/2026.
//

import Testing
@testable import Gohan

struct GohanTests {

    @Test func caloriesPerServingUsesUnitConversion() async throws {
        let flour = Ingredient(name: "Farine de blé", caloriesPer100g: 350, proteinsPer100g: 9, carbsPer100g: 73.7, fatPer100g: 1, fiberPer100g: 3.2)
        let gram = MeasurementUnit(name: "g", conversionToGrams: 1)

        let line = RecipeIngredient(quantity: 200, ingredient: flour, unit: gram)
        let recipe = Recipe(name: "Pain", servings: 2)
        recipe.ingredients = [line]

        // 200g de farine à 350 kcal/100g = 700 kcal, divisé en 2 portions = 350 kcal/portion.
        #expect(recipe.caloriesPerServing == 350)
    }

    @Test func caloriesPerServingFallsBackToIngredientGramsPerUnit() async throws {
        let egg = Ingredient(name: "Oeuf", caloriesPer100g: 140, proteinsPer100g: 12.7, carbsPer100g: 0.3, fatPer100g: 9.8, fiberPer100g: 0, gramsPerUnit: 50)
        let unite = MeasurementUnit(name: "Unité", conversionToGrams: nil)

        let line = RecipeIngredient(quantity: 2, ingredient: egg, unit: unite)
        let recipe = Recipe(name: "Omelette", servings: 1)
        recipe.ingredients = [line]

        // 2 oeufs x 50g = 100g, à 140 kcal/100g = 140 kcal pour 1 portion.
        #expect(recipe.caloriesPerServing == 140)
    }

}
