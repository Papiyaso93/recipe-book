//
//  RecipeFormView.swift
//  Gohan
//

import SwiftUI
import SwiftData
import PhotosUI

enum RecipeFormMode {
    case create
    case edit(Recipe)
    /// Relecture post-extraction IA (issue #17) — préremplit le formulaire habituel depuis un
    /// import par photo (#18) ou réseau social (#19), jamais encore persisté.
    case review(ExtractedRecipeDraft)
}

private struct DraftIngredientLine: Identifiable {
    let id = UUID()
    var ingredient: Ingredient?
    var quantity: Double = 0
    var unit: MeasurementUnit?
    /// Nom tel qu'extrait par l'IA quand aucun ingrédient existant n'a pu y être rapproché —
    /// sans ça, la ligne retombe silencieusement sur "Choisir un ingrédient" et l'utilisateur
    /// ne sait plus ce que la photo disait réellement.
    var unmatchedRawName: String?
}

struct RecipeFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: RecipeFormMode
    var onSave: (() -> Void)? = nil

    @Query(sort: \MeasurementUnit.name) private var allUnits: [MeasurementUnit]
    @Query(sort: \Material.name) private var allMaterials: [Material]
    @Query(sort: \Tag.name) private var allTags: [Tag]
    @Query(sort: \Ingredient.name) private var allIngredients: [Ingredient]

    @State private var name = ""
    @State private var photoData: Data?
    @State private var photoFocusX: Double = 0.5
    @State private var photoFocusY: Double = 0.5
    @State private var photoZoomScale: Double = 1.0
    @State private var isRepositioningPhoto = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showingPhotoSourceDialog = false
    @State private var showingLibraryPicker = false
    @State private var showingCamera = false
    @State private var servings = 4
    @State private var prepTimeMinutes = 0
    @State private var cookTimeMinutes = 0
    @State private var sourceURL = ""
    @State private var steps: [String] = [""]
    @State private var ingredientLines: [DraftIngredientLine] = []
    @State private var selectedMaterials: Set<Material> = []
    @State private var selectedTags: Set<Tag> = []
    @State private var didPopulate = false
    @State private var decodedPhoto: UIImage?
    @State private var showingValidationError = false
    @State private var uncertainIngredientLineIDs: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if isReviewing {
                        reviewBanner
                    }
                    photoHero
                    nameField

                    FormSectionCard(
                        title: "Type de plat",
                        flagLabel: isReviewing && selectedTags.filter({ $0.category == .typeDePlat }).isEmpty ? "Non détecté" : nil
                    ) {
                        chipFlow(allTags.filter { $0.category == .typeDePlat }, selection: $selectedTags, label: tagLabel)
                    }
                    FormSectionCard(
                        title: "Régime",
                        flagLabel: isReviewing && selectedTags.filter({ $0.category == .regime }).isEmpty ? "Non détecté" : nil
                    ) {
                        chipFlow(allTags.filter { $0.category == .regime }, selection: $selectedTags, label: tagLabel)
                    }

                    statsRow

                    FormSectionCard(title: "Ingrédients") {
                        ingredientsContent
                    }
                    FormSectionCard(title: "Étapes") {
                        stepsContent
                    }
                    FormSectionCard(
                        title: "Matériel",
                        flagLabel: isReviewing && selectedMaterials.isEmpty ? "À compléter" : nil
                    ) {
                        NavigationLink {
                            MaterialSelectionView(selection: $selectedMaterials)
                        } label: {
                            materialsSummary
                        }
                    }
                    FormSectionCard(title: "Source (optionnel)") {
                        TextField("Lien ou référence (livre, page...)", text: $sourceURL)
                    }
                }
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture { hideKeyboard() }
            .background(AppTheme.background)
            .navigationTitle(isReviewing ? "Relecture" : (isEditing ? "Modifier" : "Nouvelle recette"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                }
            }
            .onAppear(perform: populateIfNeeded)
            .alert("Le nom de la recette est obligatoire.", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) {}
            }
        }
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var isReviewing: Bool {
        if case .review = mode { return true }
        return false
    }

    // MARK: - Review banner

    private var reviewBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warningText)
            Text("Vérifie les informations extraites avant d'enregistrer — l'IA peut se tromper, surtout sur les quantités et le texte manuscrit.")
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.warningText)
        }
        .padding(12)
        .background(AppTheme.warningBackground)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.warningBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .padding(.horizontal, 16)
    }

    // MARK: - Photo & name

    /// Bouton dédié plutôt qu'un geste combiné avec le tap "changer la photo" (essayé d'abord) :
    /// un `Button` SwiftUI déclenche son action quasi systématiquement au relâchement, même avec
    /// un `.simultaneousGesture` de glissement en parallèle — les deux gestes se marchaient
    /// dessus en usage réel. Un mode dédié, entré/sorti explicitement, élimine l'ambiguïté.
    ///
    /// En mode recadrage, `ZoomableImageCropper` (un vrai `UIScrollView`) remplace tout geste
    /// SwiftUI fait main : plusieurs tentatives de combiner `DragGesture` + `MagnificationGesture`
    /// n'ont pas fonctionné de façon fiable en usage réel (limitation connue de SwiftUI, pas une
    /// erreur ponctuelle) — `UIScrollView` gère ça nativement.
    private var photoHero: some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = decodedPhoto {
                Group {
                    if isRepositioningPhoto {
                        ZoomableImageCropper(image: uiImage, focusX: $photoFocusX, focusY: $photoFocusY, zoomScale: $photoZoomScale)
                            .frame(height: 160)
                            .overlay(alignment: .bottom) {
                                Text("Glisse pour recadrer, pince pour zoomer")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(.black.opacity(0.55), in: Capsule())
                                    .padding(.bottom, 8)
                                    .allowsHitTesting(false)
                            }
                    } else {
                        Button {
                            showingPhotoSourceDialog = true
                        } label: {
                            FocusedPhoto(image: uiImage, focusX: photoFocusX, focusY: photoFocusY, zoomScale: photoZoomScale)
                                .frame(height: 160)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)
                .clipped()
            } else {
                Button {
                    showingPhotoSourceDialog = true
                } label: {
                    ZStack {
                        Rectangle().fill(AppTheme.border.opacity(0.4))
                        VStack(spacing: 4) {
                            Image(systemName: "camera")
                                .font(.system(size: 20))
                            Text("Ajouter une photo")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(height: 96)
                    }
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
                .buttonStyle(.plain)
            }

            if isRepositioningPhoto {
                Button("Terminé") {
                    isRepositioningPhoto = false
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.black.opacity(0.55), in: Capsule())
                .padding(10)
            } else if photoData != nil {
                HStack(spacing: 8) {
                    Button {
                        isRepositioningPhoto = true
                    } label: {
                        Image(systemName: "crop")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                    Button {
                        photoData = nil
                        selectedPhotoItem = nil
                        photoFocusX = 0.5
                        photoFocusY = 0.5
                        photoZoomScale = 1.0
                        isRepositioningPhoto = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                }
                .padding(10)
            }
        }
        // `.alert` plutôt que `.confirmationDialog` : voir RecipesListView.
        .alert("Ajouter une photo", isPresented: $showingPhotoSourceDialog) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Prendre une photo") { showingCamera = true }
            }
            Button("Choisir dans la bibliothèque") { showingLibraryPicker = true }
            Button("Annuler", role: .cancel) {}
        }
        .photosPicker(isPresented: $showingLibraryPicker, selection: $selectedPhotoItem, matching: .images)
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { data in
                photoData = ImageUtilities.downscaledJPEG(from: data)
                photoFocusX = 0.5
                photoFocusY = 0.5
                photoZoomScale = 1.0
            }
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                guard let raw = try? await newItem?.loadTransferable(type: Data.self) else { return }
                photoData = ImageUtilities.downscaledJPEG(from: raw)
                photoFocusX = 0.5
                photoFocusY = 0.5
                photoZoomScale = 1.0
            }
        }
        .task(id: photoData) {
            guard let photoData else { decodedPhoto = nil; return }
            decodedPhoto = await Task.detached(priority: .userInitiated) { UIImage(data: photoData) }.value
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionLabel(text: "Nom")
            TextField("Ex. Ajiaco", text: $name)
                .font(.system(size: 17))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonRadius).stroke(AppTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 10) {
            PortionsStepper(value: servings) { servings = $0 }
            TimeField(label: "Préparation", icon: "timer", minutes: $prepTimeMinutes)
            TimeField(label: "Cuisson", icon: "flame", minutes: $cookTimeMinutes)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Tags

    private func tagLabel(_ tag: Tag) -> String {
        // Pas d'emoji ici : avec certains noms ("Sans gluten"), la combinaison cassait la mise
        // en page des chips. Le champ existe toujours sur Tag pour un usage futur ailleurs.
        tag.name
    }

    // MARK: - Materials

    private var materialsSummary: some View {
        HStack {
            if selectedMaterials.isEmpty {
                Text("Aucun")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(selectedMaterials.sorted(by: { $0.name < $1.name })) { material in
                        Text(material.name)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(AppTheme.accent.opacity(0.12))
                            .foregroundStyle(AppTheme.accentOnTint)
                            .clipShape(Capsule())
                    }
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .contentShape(Rectangle())
    }

    // MARK: - Ingredients

    private var ingredientsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach($ingredientLines) { $line in
                IngredientLineRow(line: $line, allUnits: allUnits, warningLabel: warningLabel(for: line)) {
                    ingredientLines.removeAll { $0.id == line.id }
                    uncertainIngredientLineIDs.remove(line.id)
                }
            }

            Button {
                let gram = allUnits.first { $0.name == "g" }
                ingredientLines.append(DraftIngredientLine(unit: gram))
            } label: {
                Label("Ajouter un ingrédient", systemImage: "plus")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.accent)
        }
    }

    private func warningLabel(for line: DraftIngredientLine) -> String? {
        if line.ingredient == nil, line.unmatchedRawName != nil {
            return "Ingrédient non reconnu"
        }
        if uncertainIngredientLineIDs.contains(line.id) {
            return "Quantité floue"
        }
        return nil
    }

    // MARK: - Steps

    private var stepsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(steps.indices, id: \.self) { index in
                HStack(alignment: .top) {
                    Text("\(index + 1).")
                        .foregroundStyle(AppTheme.textSecondary)
                    TextField("Décris l'étape", text: $steps[index], axis: .vertical)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textPrimary)
                    if steps.count > 1 {
                        Button {
                            steps.remove(at: index)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Button {
                steps.append("")
            } label: {
                Label("Ajouter une étape", systemImage: "plus")
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(AppTheme.accent)
        }
    }

    // MARK: - Populate (edit/review mode)

    private func populateIfNeeded() {
        guard !didPopulate else { return }
        switch mode {
        case .create:
            return
        case .edit(let recipe):
            didPopulate = true
            name = recipe.name
            photoData = recipe.photoData
            photoFocusX = recipe.photoFocusX
            photoFocusY = recipe.photoFocusY
            photoZoomScale = recipe.photoZoomScale
            servings = recipe.servings
            prepTimeMinutes = recipe.prepTimeMinutes
            cookTimeMinutes = recipe.cookTimeMinutes
            sourceURL = recipe.sourceURL ?? ""
            steps = recipe.steps.isEmpty ? [""] : recipe.steps
            ingredientLines = recipe.ingredients.map {
                DraftIngredientLine(ingredient: $0.ingredient, quantity: $0.quantity, unit: $0.unit)
            }
            selectedMaterials = Set(recipe.materials)
            selectedTags = Set(recipe.tags)
        case .review(let draft):
            didPopulate = true
            name = draft.name
            photoData = draft.photoData
            servings = draft.servings ?? servings
            prepTimeMinutes = draft.prepTimeMinutes ?? 0
            cookTimeMinutes = draft.cookTimeMinutes ?? 0
            steps = draft.steps.isEmpty ? [""] : draft.steps
            // Priorité au rapprochement déjà fait par l'IA (`matchedName`, voir
            // RecipeImportService — elle a reçu la bibliothèque et choisi elle-même le plus
            // proche) ; l'égalité stricte locale sur `rawName` ne sert plus que de filet de
            // sécurité si `matchedName` est absent mais que le nom brut correspond déjà tel quel.
            ingredientLines = draft.ingredientLines.map { extracted in
                let matchedIngredient = extracted.matchedName.flatMap { matchedName in
                    allIngredients.first { $0.name.localizedCaseInsensitiveCompare(matchedName) == .orderedSame }
                } ?? allIngredients.first {
                    $0.name.localizedCaseInsensitiveCompare(extracted.rawName) == .orderedSame
                }
                let matchedUnit = extracted.unitName.flatMap { unitName in
                    allUnits.first { $0.name.localizedCaseInsensitiveCompare(unitName) == .orderedSame }
                }
                var draftLine = DraftIngredientLine(ingredient: matchedIngredient, quantity: extracted.quantity ?? 0, unit: matchedUnit)
                if matchedIngredient == nil {
                    draftLine.unmatchedRawName = extracted.rawName
                }
                if extracted.quantityUncertain {
                    uncertainIngredientLineIDs.insert(draftLine.id)
                }
                return draftLine
            }
            // Le matériel est rarement listé à part dans une recette — on rapproche aussi ce que
            // l'IA a repéré au fil des étapes (voir prompt dans RecipeImportService).
            selectedMaterials = Set(draft.materialNames.compactMap { rawName in
                allMaterials.first { $0.name.localizedCaseInsensitiveCompare(rawName) == .orderedSame }
            })
        }
    }

    // MARK: - Actions

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showingValidationError = true
            return
        }

        let cleanedSteps = steps
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let trimmedSource = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)

        let recipe: Recipe
        switch mode {
        case .create, .review:
            recipe = Recipe(name: trimmedName)
            modelContext.insert(recipe)
        case .edit(let existing):
            recipe = existing
        }

        recipe.name = trimmedName
        recipe.photoData = photoData
        recipe.photoFocusX = photoFocusX
        recipe.photoFocusY = photoFocusY
        recipe.photoZoomScale = photoZoomScale
        recipe.servings = servings
        recipe.prepTimeMinutes = prepTimeMinutes
        recipe.cookTimeMinutes = cookTimeMinutes
        recipe.steps = cleanedSteps
        recipe.sourceURL = trimmedSource.isEmpty ? nil : trimmedSource
        recipe.materials = Array(selectedMaterials)
        recipe.tags = Array(selectedTags)

        // Réutilise les lignes existantes (même ingrédient + même unité) au lieu de tout
        // recréer, pour que leur présence/état dans la liste de courses survive à une
        // modification de la recette — seules les lignes vraiment retirées sont supprimées.
        var remainingOldLines = recipe.ingredients
        for line in ingredientLines where line.ingredient != nil && line.quantity > 0 {
            if let matchIndex = remainingOldLines.firstIndex(where: {
                $0.ingredient?.persistentModelID == line.ingredient?.persistentModelID
                    && $0.unit?.persistentModelID == line.unit?.persistentModelID
            }) {
                let reused = remainingOldLines.remove(at: matchIndex)
                reused.quantity = line.quantity
            } else {
                let recipeIngredient = RecipeIngredient(quantity: line.quantity, ingredient: line.ingredient, unit: line.unit)
                modelContext.insert(recipeIngredient)
                recipeIngredient.recipe = recipe
            }
        }
        for leftover in remainingOldLines {
            modelContext.delete(leftover)
        }

        try? modelContext.save()
        onSave?()
        dismiss()
    }
}

private struct FormSectionCard<Content: View>: View {
    let title: String
    /// Non-nil en relecture d'import IA quand cette section n'a rien d'extrait — affiche un
    /// badge et une bordure pointillée pour attirer l'œil, sans bloquer l'enregistrement.
    var flagLabel: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: title)
                if let flagLabel {
                    Spacer()
                    Text(flagLabel)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(AppTheme.warningText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.warningBackground)
                        .clipShape(Capsule())
                }
            }
            content
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .strokeBorder(
                    flagLabel == nil ? AppTheme.border : AppTheme.warningBorder,
                    style: StrokeStyle(lineWidth: flagLabel == nil ? 0.5 : 1, dash: flagLabel == nil ? [] : [5, 4])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .padding(.horizontal, 16)
    }
}

/// Petit bouton icône avec une vraie zone de touche de 32x32 — un `Image(systemName:)` seul
/// n'a que les pixels du glyphe comme zone cliquable (ex: "minus" est un trait fin), ce qui le
/// rend difficile à toucher sans ce `frame`+`contentShape`.
private struct StepperButton: View {
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Pas de 1, adapté aux petits nombres (portions).
private struct PortionsStepper: View {
    let value: Int
    let onChange: (Int) -> Void

    var body: some View {
        VStack(spacing: 6) {
            Label("Portions", systemImage: "person.2")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 2) {
                StepperButton(systemImage: "minus") { onChange(max(1, value - 1)) }
                Text("\(value)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(minWidth: 16)
                StepperButton(systemImage: "plus") { onChange(min(50, value + 1)) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

/// Hybride : +/- arrondit toujours au multiple de 5 le plus proche (dans le bon sens), même
/// si la valeur actuelle n'en est pas un (ex: 48 -> + -> 50, pas 53) — et le nombre reste tapable
/// pour taper une valeur précise au clavier (utile pour un temps de cuisson de plusieurs heures,
/// type 240 min, qu'un stepper seul rendrait pénible à atteindre).
private struct TimeField: View {
    let label: String
    let icon: String
    @Binding var minutes: Int

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 6) {
            Label(label, systemImage: icon)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
            HStack(spacing: 2) {
                StepperButton(systemImage: "minus") { update(previousMultipleOfFive(minutes)) }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    TextField("0", text: $text)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        // 26pt tronquait les temps à 3 chiffres (ex: 120 min) ; une largeur qui
                        // s'ajuste dynamiquement au contenu (`fixedSize`) s'est révélée instable
                        // dans ce card étroit (le "min" voisin se mettait à passer à la ligne de
                        // façon imprévisible). Largeur fixe, assez large pour 3 chiffres (max 600
                        // via les boutons +/-), et "min"/le champ ne doivent jamais s'enrouler.
                        .frame(width: 34)
                        .lineLimit(1)
                        .focused($isFocused)
                        .onChange(of: text) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            text = digits
                            minutes = Int(digits) ?? 0
                        }
                    Text("min")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                        .fixedSize()
                }
                StepperButton(systemImage: "plus") { update(nextMultipleOfFive(minutes)) }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .onAppear { text = minutes == 0 ? "" : "\(minutes)" }
        // En mode édition, `minutes` ne prend sa vraie valeur qu'après `populateIfNeeded()` sur
        // la vue parente, qui s'exécute APRÈS le `.onAppear` ci-dessus (onAppear remonte des
        // enfants vers le parent) — sans ça, `text` restait figé à "" même une fois `minutes`
        // correctement peuplé. On ignore ce resync pendant la saisie pour ne pas se battre avec
        // l'utilisateur.
        .onChange(of: minutes) { _, newValue in
            guard !isFocused else { return }
            text = newValue == 0 ? "" : "\(newValue)"
        }
    }

    private func update(_ newValue: Int) {
        minutes = newValue
        text = newValue == 0 ? "" : "\(newValue)"
    }

    private func nextMultipleOfFive(_ value: Int) -> Int {
        min(600, ((value / 5) + 1) * 5)
    }

    private func previousMultipleOfFive(_ value: Int) -> Int {
        guard value > 0 else { return 0 }
        return max(0, ((value - 1) / 5) * 5)
    }
}

/// Une mini-carte par ligne : le nom ouvre la recherche d'ingrédient (IngredientPickerView),
/// quantité et unité restent sur place juste en dessous. Reste inline dans le formulaire plutôt
/// que de pousser vers un écran de gestion séparé — pour une recette de 5 à 12 ingrédients
/// (le cas courant ici), rester sur un seul écran est plus rapide que de naviguer à chaque ligne.
private struct IngredientLineRow: View {
    @Binding var line: DraftIngredientLine
    let allUnits: [MeasurementUnit]
    var warningLabel: String? = nil
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                NavigationLink {
                    IngredientPickerView(selection: $line.ingredient)
                } label: {
                    HStack(spacing: 6) {
                        Text(line.ingredient?.name ?? line.unmatchedRawName ?? "Choisir un ingrédient")
                            .font(.system(size: 15))
                            .foregroundStyle(line.ingredient == nil ? AppTheme.textSecondary : AppTheme.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
                if let warningLabel {
                    Text(warningLabel)
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(AppTheme.warningText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(AppTheme.warningBackground)
                        .clipShape(Capsule())
                }
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundStyle(AppTheme.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("0", value: $line.quantity, format: .number)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 14))
                    .padding(.horizontal, 10)
                    .frame(width: 64, height: 36)
                    .background(AppTheme.background)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                Menu {
                    ForEach(allUnits) { unit in
                        Button(unit.name) { line.unit = unit }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(line.unit?.shortLabel ?? "—")
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 64, height: 36)
                    .background(AppTheme.background)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }

                Spacer(minLength: 0)
            }
        }
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .strokeBorder(
                    warningLabel == nil ? AppTheme.border : AppTheme.warningBorder,
                    style: StrokeStyle(lineWidth: warningLabel == nil ? 0.5 : 1, dash: warningLabel == nil ? [] : [5, 4])
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}
