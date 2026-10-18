//
//  SortOrder.swift
//  Gohan
//

import Foundation

enum RecipeSortOrder: String, CaseIterable {
    case recentFirst, oldestFirst, alphabetical

    var label: String {
        switch self {
        case .recentFirst: return "Plus récent"
        case .oldestFirst: return "Plus ancien"
        case .alphabetical: return "Alphabétique"
        }
    }
}

enum FavoriteSortOrder: String, CaseIterable {
    case recentFirst, oldestFirst, alphabetical

    var label: String {
        switch self {
        case .recentFirst: return "Ajout récent"
        case .oldestFirst: return "Ajout ancien"
        case .alphabetical: return "Alphabétique"
        }
    }
}
