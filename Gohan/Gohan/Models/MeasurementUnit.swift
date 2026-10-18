//
//  MeasurementUnit.swift
//  Gohan
//

import Foundation
import SwiftData

/// Named `MeasurementUnit` rather than `Unit` to avoid shadowing Foundation's `Unit` (base class of `UnitLength` etc.).
@Model
final class MeasurementUnit {
    var name: String

    /// Grams per 1 of this unit, shared across all ingredients (e.g. 1 cuillère à café = 5g regardless of ingredient).
    /// `nil` for units that aren't generically convertible — "Unité" depends on the specific ingredient,
    /// see `Ingredient.gramsPerUnit`.
    var conversionToGrams: Double?

    init(name: String, conversionToGrams: Double? = nil) {
        self.name = name
        self.conversionToGrams = conversionToGrams
    }

    /// Les noms longs ("Cuillère à café/soupe") ne tiennent pas dans un champ ou une ligne
    /// compacte — affiché partout où l'unité apparaît à côté d'une quantité, le nom complet
    /// reste disponible via `name` (ex: dans un menu de sélection).
    var shortLabel: String {
        switch name {
        case "Cuillère à café": return "càc"
        case "Cuillère à soupe": return "càs"
        default: return name
        }
    }
}
