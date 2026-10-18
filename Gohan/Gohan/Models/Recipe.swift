//
//  Recipe.swift
//  Gohan
//

import Foundation
import SwiftData

@Model
final class Recipe {
    var name: String
    var photoData: Data?
    var servings: Int
    var prepTimeMinutes: Int
    var cookTimeMinutes: Int
    var steps: [String]
    var sourceURL: String?
    var isFavorite: Bool
    var createdAt: Date
    /// Date du dernier ajout aux favoris (`nil` si jamais favori) — distincte de `createdAt`,
    /// sert au tri "Ajout récent/ancien" de l'onglet Favoris.
    var favoritedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var ingredients: [RecipeIngredient] = []

    @Relationship(deleteRule: .cascade, inverse: \Note.recipe)
    var notes: [Note] = []

    var materials: [Material] = []
    var tags: [Tag] = []

    init(
        name: String,
        photoData: Data? = nil,
        servings: Int = 1,
        prepTimeMinutes: Int = 0,
        cookTimeMinutes: Int = 0,
        steps: [String] = [],
        sourceURL: String? = nil,
        isFavorite: Bool = false,
        createdAt: Date = .now,
        favoritedAt: Date? = nil
    ) {
        self.name = name
        self.photoData = photoData
        self.servings = servings
        self.prepTimeMinutes = prepTimeMinutes
        self.cookTimeMinutes = cookTimeMinutes
        self.steps = steps
        self.sourceURL = sourceURL
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.favoritedAt = favoritedAt
    }
}
