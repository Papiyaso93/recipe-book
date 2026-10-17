//
//  RecipesListView.swift
//  Gohan
//

import SwiftUI
import SwiftData

struct RecipesListView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView(
                        "Aucune recette",
                        systemImage: "fork.knife",
                        description: Text("Tes recettes apparaîtront ici.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(recipes) { recipe in
                                NavigationLink(value: recipe) {
                                    RecipeCard(recipe: recipe)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .navigationTitle("Recettes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
        }
    }
}

#Preview {
    RecipesListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
