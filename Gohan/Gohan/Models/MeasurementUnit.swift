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
}
