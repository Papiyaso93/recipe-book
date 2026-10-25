//
//  ExtractedRecipeDraft.swift
//  Gohan
//

import Foundation

/// Résultat brut d'un import IA (photo ou réseau social, voir issues #18/#19) — jamais persisté
/// tel quel : passé à `RecipeFormView` en mode `.review` pour relecture/correction avant
/// sauvegarde définitive comme une recette normale.
struct ExtractedRecipeDraft {
    struct IngredientLine {
        var rawName: String
        var quantity: Double?
        var unitName: String?
        /// L'IA n'était pas sûre de cette valeur (ex: texte manuscrit ambigu) — signalé à
        /// l'utilisateur dans l'écran de relecture plutôt qu'acceptée silencieusement.
        var quantityUncertain: Bool = false
    }

    var name: String = ""
    var photoData: Data?
    var servings: Int?
    var prepTimeMinutes: Int?
    var cookTimeMinutes: Int?
    var steps: [String] = []
    var ingredientLines: [IngredientLine] = []
}
