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
    /// Point de la photo à garder centré quel que soit le format d'affichage (carte, fiche,
    /// partage...) — 0...1 sur chaque axe, (0.5, 0.5) = centre (comportement par défaut
    /// inchangé). Voir issue #58.
    var photoFocusX: Double = 0.5
    var photoFocusY: Double = 0.5
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
        photoFocusX: Double = 0.5,
        photoFocusY: Double = 0.5,
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
        self.photoFocusX = photoFocusX
        self.photoFocusY = photoFocusY
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
