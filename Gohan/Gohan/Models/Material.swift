//
//  Material.swift
//  Gohan
//

import Foundation
import SwiftData

enum MaterialType: String, Codable {
    case cooking = "Cuisson"
    case preparation = "Préparation"
    case measurement = "Mesure"
}

@Model
final class Material {
    var name: String
    var type: MaterialType

    init(name: String, type: MaterialType) {
        self.name = name
        self.type = type
    }
}
