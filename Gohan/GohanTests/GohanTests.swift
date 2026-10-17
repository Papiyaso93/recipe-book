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

    @Test func totalNutritionVersusPerServing() async throws {
        let flour = Ingredient(name: "Farine de blé", caloriesPer100g: 350, proteinsPer100g: 9, carbsPer100g: 73.7, fatPer100g: 1, fiberPer100g: 3.2)
        let gram = MeasurementUnit(name: "g", conversionToGrams: 1)

        let line = RecipeIngredient(quantity: 200, ingredient: flour, unit: gram)
        let recipe = Recipe(name: "Pain", servings: 4)
        recipe.ingredients = [line]

        // Total : 200g -> 700 kcal, 18g protéines, 147.4g glucides, 2g lipides.
        let total = recipe.totalNutrition
        #expect(total.calories == 700)
        #expect(total.proteins == 18)
        #expect(total.carbs == 147.4)
        #expect(total.fat == 2)

        // Par portion (/4) : 175 kcal, 4.5g protéines, 36.85g glucides, 0.5g lipides.
        let perServing = recipe.nutritionPerServing
        #expect(perServing.calories == 175)
        #expect(perServing.proteins == 4.5)
        #expect(perServing.carbs == 36.85)
        #expect(perServing.fat == 0.5)
    }

}
