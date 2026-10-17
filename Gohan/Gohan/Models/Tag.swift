//
//  Tag.swift
//  Gohan
//

import Foundation
import SwiftData

/// Famille à laquelle appartient un tag, pour pouvoir le ranger dans la bonne section
/// à la création d'une recette (et plus tard le proposer dans le bon groupe de filtres,
/// voir issue #13).
enum TagCategory: String, Codable {
    case typeDePlat
    case regime
    /// Tags créés librement par l'utilisateur (bouton "Ajouter" du formulaire), pas encore
    /// rattachés à une famille connue.
    case autre
}

@Model
final class Tag {
    var name: String
    var emoji: String?
    // Valeur par défaut nécessaire ici (pas juste dans l'init) pour que SwiftData sache
    // quoi faire des tags déjà enregistrés avant l'ajout de ce champ, sans ça il plante
    // au chargement ("Passed nil for a non-optional keypath").
    var category: TagCategory = TagCategory.autre

    init(name: String, emoji: String? = nil, category: TagCategory = .autre) {
        self.name = name
        self.emoji = emoji
        self.category = category
    }
}
