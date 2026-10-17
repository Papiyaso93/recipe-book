//
//  FavoritesView.swift
//  Gohan
//

import SwiftUI

struct FavoritesView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Aucun favori",
                systemImage: "heart",
                description: Text("Marque une recette en favori pour la retrouver ici.")
            )
            .background(AppTheme.background)
            .navigationTitle("Favoris")
        }
    }
}

#Preview {
    FavoritesView()
}
