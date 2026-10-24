//
//  RecipesListView.swift
//  Gohan
//

import SwiftUI
import SwiftData

struct RecipesListView: View {
    @Query private var recipes: [Recipe]
    @State private var showingCreateForm = false
    @State private var showingSuccessToast = false
    @State private var showingDeleteToast = false
    @State private var deleteUndoAction: (() -> Void)? = nil
    @State private var showingFavoriteToast = false
    @State private var favoriteToastMessage = ""
    @State private var searchText = ""
    @State private var filters = RecipeFilterSelection()
    @State private var showingFilterSheet = false
    @AppStorage("recipesSortOrder") private var sortOrderRaw = RecipeSortOrder.recentFirst.rawValue

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var sortOrder: Binding<RecipeSortOrder> {
        Binding(
            get: { RecipeSortOrder(rawValue: sortOrderRaw) ?? .recentFirst },
            set: { sortOrderRaw = $0.rawValue }
        )
    }

    private var sortedRecipes: [Recipe] {
        switch sortOrder.wrappedValue {
        case .recentFirst: return recipes.sorted { $0.createdAt > $1.createdAt }
        case .oldestFirst: return recipes.sorted { $0.createdAt < $1.createdAt }
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
                    VStack {
                        Spacer()
                        emptyStateContent
                        Spacer()
                    }
                    .padding(32)
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
            }
            .background(AppTheme.background)
            .navigationTitle("Recettes")
            .conditionallySearchable(!recipes.isEmpty, text: $searchText, prompt: "Rechercher une recette")
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe) { undo in
                    deleteUndoAction = undo
                    showingDeleteToast = true
                }
            }
            .sheet(isPresented: $showingCreateForm) {
                RecipeFormView(mode: .create) {
                    showingSuccessToast = true
                }
            }
            .successToast("Recette créée", isPresented: $showingSuccessToast)
            .successToast("Recette supprimée", isPresented: $showingDeleteToast, duration: 4, undo: deleteUndoAction)
            .successToast(favoriteToastMessage, isPresented: $showingFavoriteToast)
        }
    }

    private var sortBar: some View {
        HStack {
            filterChip
            Spacer()
            Menu {
                Picker("Trier par", selection: sortOrder) {
                    ForEach(RecipeSortOrder.allCases, id: \.self) { order in
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
