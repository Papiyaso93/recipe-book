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
    @State private var showingDeleteToast = false
    @State private var deleteUndoAction: (() -> Void)? = nil
    @State private var searchText = ""
    @State private var filters = RecipeFilterSelection()
    @State private var showingFilterSheet = false
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
        sortedRecipes.filter { recipe in
            (searchText.isEmpty || recipe.name.localizedCaseInsensitiveContains(searchText))
                && filters.matches(recipe)
        }
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
                        if !searchText.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        } else {
                            ContentUnavailableView(
                                "Aucun résultat",
                                systemImage: "line.3.horizontal.decrease.circle",
                                description: Text("Aucune recette ne correspond aux filtres sélectionnés.")
                            )
                        }
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
                RecipeDetailView(recipe: recipe) { undo in
                    deleteUndoAction = undo
                    showingDeleteToast = true
                }
            }
            .successToast(favoriteToastMessage, isPresented: $showingFavoriteToast)
            .successToast("Recette supprimée", isPresented: $showingDeleteToast, duration: 4, undo: deleteUndoAction)
        }
    }

    private var sortBar: some View {
        HStack {
            filterChip
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

    private var filterChip: some View {
        Button {
            showingFilterSheet = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11, weight: .semibold))
                Text(filters.isEmpty ? "Filtrer" : "Filtrer (\(filters.activeCount))")
                    .font(.system(size: 13, weight: filters.isEmpty ? .regular : .semibold))
            }
            .foregroundStyle(filters.isEmpty ? AppTheme.textPrimary : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(filters.isEmpty ? AppTheme.surface : AppTheme.accent)
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(filters.isEmpty ? AppTheme.border : .clear, lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingFilterSheet) {
            RecipeFilterSheet(filters: $filters)
        }
    }
}

#Preview {
    FavoritesView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
