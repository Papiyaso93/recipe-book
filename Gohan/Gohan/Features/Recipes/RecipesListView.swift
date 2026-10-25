//
//  RecipesListView.swift
//  Gohan
//

import SwiftUI
import SwiftData
import PhotosUI

struct RecipesListView: View {
    @Query private var recipes: [Recipe]
    @Query(sort: \Ingredient.name) private var allIngredients: [Ingredient]
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

    // MARK: - Import par photo (issue #18)
    @State private var showingNewRecipeChoice = false
    @State private var showingPhotoSourceDialog = false
    @State private var showingLibraryPicker = false
    @State private var showingCamera = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    /// Photos accumulées en prenant plusieurs clichés à la suite (ex: les pages successives
    /// d'un livre) avant de lancer l'import — voir `showingAddAnotherPhotoAlert`.
    @State private var capturedPhotos: [Data] = []
    @State private var showingAddAnotherPhotoAlert = false
    @State private var isImporting = false
    @State private var showingReviewForm = false
    @State private var reviewDraft: ExtractedRecipeDraft?
    @State private var importError: RecipeImportError?
    @State private var showingImportErrorAlert = false

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
                    EmptyStateView(
                        icon: "fork.knife",
                        title: "Aucune recette",
                        description: "Tes recettes apparaîtront ici.",
                        actionTitle: "Ajouter ma première recette"
                    ) {
                        showingNewRecipeChoice = true
                    }
                } else if filteredRecipes.isEmpty {
                    if !searchText.isEmpty {
                        EmptyStateView(
                            icon: "magnifyingglass",
                            title: "Aucun résultat",
                            description: "Aucune recette ne correspond à « \(searchText) »."
                        )
                    } else {
                        EmptyStateView(
                            icon: "line.3.horizontal.decrease.circle",
                            title: "Aucun résultat",
                            description: "Aucune recette ne correspond aux filtres sélectionnés."
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
                            showingNewRecipeChoice = true
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
            .sheet(isPresented: $showingReviewForm) {
                if let reviewDraft {
                    RecipeFormView(mode: .review(reviewDraft)) {
                        showingSuccessToast = true
                    }
                }
            }
            // `.alert` plutôt que `.confirmationDialog` : sur iOS 27, ce dernier s'affiche en
            // bulle "verre liquide" avec une queue pointant vers rien dès que l'ancrage n'est
            // pas net — `.alert` reste une boîte centrée sans queue, dans les deux cas un
            // composant natif du système.
            .alert("Nouvelle recette", isPresented: $showingNewRecipeChoice) {
                Button("Importer depuis une photo") { showingPhotoSourceDialog = true }
                Button("Créer manuellement") { showingCreateForm = true }
                Button("Annuler", role: .cancel) {}
            }
            .alert("Importer depuis une photo", isPresented: $showingPhotoSourceDialog) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Prendre une photo") { showingCamera = true }
                }
                Button("Choisir dans la bibliothèque") { showingLibraryPicker = true }
                Button("Annuler", role: .cancel) {}
            }
            // Le sélecteur de bibliothèque permet nativement une sélection multiple (issue #60,
            // ex: plusieurs captures d'écran du même post) — rien à construire, juste autoriser
            // plusieurs éléments.
            .photosPicker(isPresented: $showingLibraryPicker, selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { data in
                    capturedPhotos.append(data)
                    // `showingCamera` doit repasser à false avant de pouvoir le remettre à true
                    // pour reprendre une photo — sinon SwiftUI ne détecte aucun changement et ne
                    // représente pas l'appareil photo. Le délai laisse le temps à l'animation de
                    // fermeture de se terminer avant de présenter l'alerte (deux présentations
                    // modales dans le même cycle se marchent dessus sinon).
                    showingCamera = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showingAddAnotherPhotoAlert = true
                    }
                }
                .ignoresSafeArea()
            }
            .alert("Photo ajoutée (\(capturedPhotos.count))", isPresented: $showingAddAnotherPhotoAlert) {
                Button("Prendre une autre photo") { showingCamera = true }
                Button("Terminer l'import") {
                    startImport(with: capturedPhotos)
                    capturedPhotos = []
                }
            } message: {
                Text("Pour une recette sur plusieurs pages, tu peux continuer à prendre des photos avant de lancer l'import.")
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    var photosData: [Data] = []
                    for item in newItems {
                        if let raw = try? await item.loadTransferable(type: Data.self) {
                            photosData.append(raw)
                        }
                    }
                    selectedPhotoItems = []
                    startImport(with: photosData)
                }
            }
            .overlay {
                if isImporting {
                    ImportLoadingOverlay()
                }
            }
            .alert("Import impossible", isPresented: $showingImportErrorAlert, presenting: importError) { error in
                if error == .noAPIKey || error == .invalidKey {
                    Button("Aller dans Réglages") {
                        NotificationCenter.default.post(name: .switchToSettingsTab, object: nil)
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: { error in
                Text(error.errorDescription ?? "")
            }
            .successToast("Recette créée", isPresented: $showingSuccessToast)
            .successToast("Recette supprimée", isPresented: $showingDeleteToast, duration: 4, undo: deleteUndoAction)
            .successToast(favoriteToastMessage, isPresented: $showingFavoriteToast)
        }
    }

    private func startImport(with rawPhotosData: [Data]) {
        guard !rawPhotosData.isEmpty else { return }
        let downscaled = rawPhotosData.map { ImageUtilities.downscaledJPEG(from: $0) }
        isImporting = true
        Task {
            let result = await RecipeImportService.importRecipe(from: downscaled, knownIngredientNames: allIngredients.map(\.name))
            isImporting = false
            switch result {
            case .success(let draft):
                reviewDraft = draft
                showingReviewForm = true
            case .failure(let error):
                importError = error
                showingImportErrorAlert = true
            }
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

}

/// Carte de chargement affichée pendant l'appel d'extraction IA (quelques secondes) — par-dessus
/// l'écran Recettes assombri, pour que l'attente soit visible plutôt que silencieuse.
private struct ImportLoadingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.25).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .tint(AppTheme.accent)
                Text("Analyse de la photo...")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Quelques secondes, l'IA lit les ingrédients et les étapes.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
            .frame(width: 260)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        }
    }
}

#Preview {
    RecipesListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
