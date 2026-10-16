//
//  RecipesListView.swift
//  Gohan
//

import SwiftUI

struct RecipesListView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Aucune recette",
                systemImage: "fork.knife",
                description: Text("Tes recettes apparaîtront ici.")
            )
            .navigationTitle("Recettes")
        }
    }
}

#Preview {
    RecipesListView()
}
