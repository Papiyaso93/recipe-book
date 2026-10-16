//
//  Tag.swift
//  Gohan
//

import Foundation
import SwiftData

/// Minimal for now — the multi-facette taxonomy (type de plat / régime / caractéristiques)
/// is defined when filtering is implemented (see issue #13).
@Model
final class Tag {
    var name: String
    var emoji: String?

    init(name: String, emoji: String? = nil) {
        self.name = name
        self.emoji = emoji
    }
}
