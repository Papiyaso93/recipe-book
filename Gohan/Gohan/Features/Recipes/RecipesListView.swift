//
//  RecipesListView.swift
//  Gohan
//

import SwiftUI
import SwiftData

struct RecipesListView: View {
    @Query(sort: \Recipe.name) private var recipes: [Recipe]
    @State private var showingCreateForm = false
    @State private var showingSuccessToast = false
    @State private var showingDeleteToast = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if recipes.isEmpty {
                    VStack {
                        Spacer()
                        emptyStateContent
                        Spacer()
                    }
                    .padding(32)
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
                    .overlay(alignment: .bottomTrailing) {
                        Button {
                            showingCreateForm = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(Circle().fill(AppTheme.accent))
                        }
                        .padding(20)
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Recettes")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe) {
                    showingDeleteToast = true
                }
            }
            .sheet(isPresented: $showingCreateForm) {
                RecipeFormView(mode: .create) {
                    showingSuccessToast = true
                }
            }
            .successToast("Recette créée", isPresented: $showingSuccessToast)
            .successToast("Recette supprimée", isPresented: $showingDeleteToast)
        }
    }

    private var emptyStateContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 72, height: 72)
                Image(systemName: "fork.knife")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(spacing: 6) {
                Text("Aucune recette")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Tes recettes apparaîtront ici.")
                    .font(.system(size: 15))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showingCreateForm = true
            } label: {
                Text("Créer ma première recette")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    RecipesListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
