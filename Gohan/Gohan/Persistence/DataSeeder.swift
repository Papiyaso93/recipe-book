//
//  DataSeeder.swift
//  Gohan
//

import Foundation
import SwiftData

enum DataSeeder {

    /// Insère les données de référence (groupes, unités, matériel, ingrédients) si la base est vide.
    /// Ne touche jamais une base déjà peuplée — voir la note "jamais nettoyer les exercices"
    /// côté ObjectifsFit pour le même principe appliqué ici à la bibliothèque d'ingrédients.
    static func seedIfNeeded(context: ModelContext) {
        let ingredientCount = (try? context.fetchCount(FetchDescriptor<Ingredient>())) ?? 0
        guard ingredientCount == 0 else { return }

        // Les groupes sont insérés comme données de référence, mais pas encore rattachés
        // aux ingrédients ci-dessous : le CSV d'origine ne contient pas ce mapping.
        // À faire dans une passe dédiée avant que la liste de courses (issue #11) en ait besoin.
        for name in SeedData.groups {
            context.insert(IngredientGroup(name: name))
        }

        for unit in SeedData.units {
            context.insert(MeasurementUnit(name: unit.name, conversionToGrams: unit.conversionToGrams))
        }

        for material in SeedData.materials {
            context.insert(Material(name: material.name, type: material.type))
        }

        for seed in SeedData.ingredients {
            context.insert(
                Ingredient(
                    name: seed.name,
                    ciqualCode: seed.ciqualCode,
                    caloriesPer100g: seed.calories,
                    proteinsPer100g: seed.proteins,
                    carbsPer100g: seed.carbs,
                    fatPer100g: seed.fat,
                    fiberPer100g: seed.fiber
                )
            )
        }

        try? context.save()
    }
}
