//
//  IngredientGroup.swift
//  Gohan
//

import Foundation
import SwiftData

@Model
final class IngredientGroup {
    var name: String

    @Relationship(deleteRule: .nullify, inverse: \Ingredient.group)
    var ingredients: [Ingredient] = []

    init(name: String) {
        self.name = name
    }
}
