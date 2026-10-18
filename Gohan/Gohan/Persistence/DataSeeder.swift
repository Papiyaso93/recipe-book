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
        if ingredientCount == 0 {
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
        }

        // Mis à jour (pas juste inséré si vide) : une installation déjà faite avant l'ajout du
        // champ "category" a ses 6 tags existants mais sans leur vraie famille — on les corrige
        // ici plutôt que de les laisser invisibles dans le formulaire.
        let existingTags = (try? context.fetch(FetchDescriptor<Tag>())) ?? []
        for seedTag in SeedData.tags {
            if let existing = existingTags.first(where: { $0.name == seedTag.name }) {
                existing.emoji = seedTag.emoji
                existing.category = seedTag.category
            } else {
                context.insert(Tag(name: seedTag.name, emoji: seedTag.emoji, category: seedTag.category))
            }
        }

        // Même principe : rattache chaque ingrédient à son groupe même sur une base déjà
        // peuplée avant que ce mapping existe (nécessaire pour la liste de courses, issue #11).
        let existingGroups = (try? context.fetch(FetchDescriptor<IngredientGroup>())) ?? []
        let existingIngredients = (try? context.fetch(FetchDescriptor<Ingredient>())) ?? []
        for ingredient in existingIngredients {
            guard let groupName = SeedData.ingredientGroups[ingredient.name] else { continue }
            ingredient.group = existingGroups.first { $0.name == groupName }
        }

        try? context.save()
    }
}
