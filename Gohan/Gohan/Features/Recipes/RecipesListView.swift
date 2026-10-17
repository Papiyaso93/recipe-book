//
//  RecipesListView.swift
//  Gohan
//

import SwiftUI
import SwiftData

struct RecipesListView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var showingCreateForm = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    ContentUnavailableView {
                        Label("Aucune recette", systemImage: "fork.knife")
                    } description: {
                        Text("Tes recettes apparaîtront ici.")
                    } actions: {
                        Button("Créer une recette") { showingCreateForm = true }
                    }
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
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateForm = true
                    } label: {
                        Label("Nouvelle recette", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateForm) {
                RecipeFormView(mode: .create)
            }
        }
    }
}

#Preview {
    RecipesListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
