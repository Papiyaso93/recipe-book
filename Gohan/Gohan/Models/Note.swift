//
//  Note.swift
//  Gohan
//

import Foundation
import SwiftData

@Model
final class Note {
    var text: String
    var createdAt: Date

    var recipe: Recipe?

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }
}
