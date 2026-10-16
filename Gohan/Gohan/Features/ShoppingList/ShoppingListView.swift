//
//  ShoppingListView.swift
//  Gohan
//

import SwiftUI

struct ShoppingListView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Liste de courses vide",
                systemImage: "cart",
                description: Text("Ajoute des ingrédients depuis une recette pour les retrouver ici.")
            )
            .navigationTitle("Liste de courses")
        }
    }
}

#Preview {
    ShoppingListView()
}
