//
//  RecipeFilterSelection.swift
//  Gohan
//

import Foundation

/// État des filtres combinables (issue #13) — OU à l'intérieur d'une facette (type de plat,
/// régime), ET entre facettes. Volontairement non persisté entre les lancements (comme la
/// recherche) : c'est un état de navigation ponctuel, pas une préférence durable comme le tri.
struct RecipeFilterSelection: Equatable {
    var typeDePlat: Set<Tag> = []
    var regime: Set<Tag> = []
    var sansCuisson = false
    var rapide = false
    var peuDIngredients = false
    var hyperproteine = false

    var activeCount: Int {
        typeDePlat.count + regime.count + [sansCuisson, rapide, peuDIngredients, hyperproteine].filter { $0 }.count
    }

    var isEmpty: Bool { activeCount == 0 }

    mutating func reset() {
        self = RecipeFilterSelection()
    }

    func matches(_ recipe: Recipe) -> Bool {
        if !typeDePlat.isEmpty {
            let ids = Set(typeDePlat.map(\.persistentModelID))
            guard recipe.tags.contains(where: { ids.contains($0.persistentModelID) }) else { return false }
        }
        if !regime.isEmpty {
            let ids = Set(regime.map(\.persistentModelID))
            guard recipe.tags.contains(where: { ids.contains($0.persistentModelID) }) else { return false }
        }
        if sansCuisson && !recipe.isSansCuisson { return false }
        if rapide && !recipe.isRapide { return false }
        if peuDIngredients && !recipe.hasPeuDIngredients { return false }
        if hyperproteine && !recipe.isHyperproteine { return false }
        return true
    }
}
