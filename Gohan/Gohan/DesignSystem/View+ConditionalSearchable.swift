//
//  View+ConditionalSearchable.swift
//  Gohan
//

import SwiftUI

extension View {
    /// `.searchable()` n'a pas d'équivalent conditionnel intégré — permet de cacher la barre de
    /// recherche quand il n'y a rien à chercher (ex: aucune recette), comme pour la puce de tri.
    @ViewBuilder
    func conditionallySearchable(_ show: Bool, text: Binding<String>, prompt: String) -> some View {
        if show {
            self.searchable(text: text, placement: .navigationBarDrawer(displayMode: .always), prompt: prompt)
        } else {
            self
        }
    }
}
