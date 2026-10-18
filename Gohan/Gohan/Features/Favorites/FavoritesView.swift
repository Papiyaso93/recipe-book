//
//  FavoritesView.swift
//  Gohan
//

import SwiftUI
import SwiftData

struct FavoritesView: View {
    @Query(filter: #Predicate<Recipe> { $0.isFavorite }) private var recipes: [Recipe]
    @State private var showingFavoriteToast = false
    @State private var favoriteToastMessage = ""
    @State private var searchText = ""
    @AppStorage("favoritesSortOrder") private var sortOrderRaw = FavoriteSortOrder.recentFirst.rawValue

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var sortOrder: Binding<FavoriteSortOrder> {
        Binding(
            get: { FavoriteSortOrder(rawValue: sortOrderRaw) ?? .recentFirst },
            set: { sortOrderRaw = $0.rawValue }
        )
    }

    private var sortedRecipes: [Recipe] {
        switch sortOrder.wrappedValue {
        case .recentFirst: return recipes.sorted { ($0.favoritedAt ?? $0.createdAt) > ($1.favoritedAt ?? $1.createdAt) }
        case .oldestFirst: return recipes.sorted { ($0.favoritedAt ?? $0.createdAt) < ($1.favoritedAt ?? $1.createdAt) }
        case .alphabetical: return recipes.sorted { $0.name < $1.name }
        }
    }

    private var filteredRecipes: [Recipe] {
        guard !searchText.isEmpty else { return sortedRecipes }
        return sortedRecipes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !recipes.isEmpty {
                    sortBar
                }

                Group {
                    if recipes.isEmpty {
                        ContentUnavailableView(
                            "Aucun favori",
                            systemImage: "heart",
                            description: Text("Marque une recette en favori pour la retrouver ici.")
                        )
                    } else if filteredRecipes.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(filteredRecipes) { recipe in
                                    NavigationLink(value: recipe) {
                                        RecipeCard(recipe: recipe) { isFavorite in
                                            favoriteToastMessage = isFavorite ? "Ajouté aux favoris" : "Retiré des favoris"
                                            showingFavoriteToast = true
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Favoris")
            .conditionallySearchable(!recipes.isEmpty, text: $searchText, prompt: "Rechercher une recette")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .successToast(favoriteToastMessage, isPresented: $showingFavoriteToast)
        }
    }

    private var sortBar: some View {
        HStack {
            Spacer()
            Menu {
                Picker("Trier par", selection: sortOrder) {
                    ForEach(FavoriteSortOrder.allCases, id: \.self) { order in
                        Text(order.label).tag(order)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(sortOrder.wrappedValue.label)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
