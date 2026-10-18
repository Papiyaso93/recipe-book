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
}

private struct DraftIngredientLine: Identifiable {
    let id = UUID()
    var ingredient: Ingredient?
    var quantity: Double = 0
    var unit: MeasurementUnit?
}

struct RecipeFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: RecipeFormMode
    var onSave: (() -> Void)? = nil

    @Query(sort: \MeasurementUnit.name) private var allUnits: [MeasurementUnit]
    @Query(sort: \Material.name) private var allMaterials: [Material]
    @Query(sort: \Tag.name) private var allTags: [Tag]

    @State private var name = ""
    @State private var photoData: Data?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var servings = 4
    @State private var prepTimeMinutes = 0
    @State private var cookTimeMinutes = 0
    @State private var sourceURL = ""
    @State private var steps: [String] = [""]
    @State private var ingredientLines: [DraftIngredientLine] = []
    @State private var selectedMaterials: Set<Material> = []
    @State private var selectedTags: Set<Tag> = []
    @State private var didPopulate = false
    @State private var showingValidationError = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    photoHero
                    nameField

                    FormSectionCard(title: "Type de plat") {
                        chipFlow(allTags.filter { $0.category == .typeDePlat }, selection: $selectedTags, label: tagLabel)
                    }
                    FormSectionCard(title: "Régime") {
                        chipFlow(allTags.filter { $0.category == .regime }, selection: $selectedTags, label: tagLabel)
                    }

                    statsRow

                    FormSectionCard(title: "Ingrédients") {
                        ingredientsContent
                    }
                    FormSectionCard(title: "Étapes") {
                        stepsContent
                    }
                    FormSectionCard(title: "Matériel") {
                        NavigationLink {
                            MaterialSelectionView(selection: $selectedMaterials)
                        } label: {
                            materialsSummary
                        }
                    }
                    FormSectionCard(title: "Source (optionnel)") {
                        TextField("Lien de la recette d'origine", text: $sourceURL)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                }
                .padding(.bottom, 24)
            }
            .background(AppTheme.background)
            .navigationTitle(isEditing ? "Modifier la recette" : "Nouvelle recette")
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

    // MARK: - Photo & name

    private var photoHero: some View {
        ZStack(alignment: .topTrailing) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ZStack {
                    if let photoData, let uiImage = UIImage(data: photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 160)
                    } else {
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
                }
                .frame(maxWidth: .infinity)
                .clipped()
            }
            .buttonStyle(.plain)

            if photoData != nil {
                Button {
                    photoData = nil
                    selectedPhotoItem = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(.black.opacity(0.45)))
                }
                .padding(10)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task { photoData = try? await newItem?.loadTransferable(type: Data.self) }
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
                            .foregroundStyle(AppTheme.accentDark)
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
                IngredientLineRow(line: $line, allUnits: allUnits) {
                    ingredientLines.removeAll { $0.id == line.id }
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

    @ViewBuilder
    private func chipFlow<Item: Hashable>(
        _ items: [Item],
        selection: Binding<Set<Item>>,
        label: @escaping (Item) -> String
    ) -> some View {
        if items.isEmpty {
            Text("Aucune pour l'instant.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    let isSelected = selection.wrappedValue.contains(item)
                    Button {
                        if isSelected {
                            selection.wrappedValue.remove(item)
                        } else {
                            selection.wrappedValue.insert(item)
                        }
                    } label: {
                        Text(label(item))
                            .font(.system(size: 14))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                                    .fill(isSelected ? AppTheme.accent : AppTheme.border.opacity(0.35))
                            )
                            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Populate (edit mode)

    private func populateIfNeeded() {
        guard case .edit(let recipe) = mode, !didPopulate else { return }
        didPopulate = true
        name = recipe.name
        photoData = recipe.photoData
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
        case .create:
            recipe = Recipe(name: trimmedName)
            modelContext.insert(recipe)
        case .edit(let existing):
            recipe = existing
            for line in recipe.ingredients {
                modelContext.delete(line)
            }
        }

        recipe.name = trimmedName
        recipe.photoData = photoData
        recipe.servings = servings
        recipe.prepTimeMinutes = prepTimeMinutes
        recipe.cookTimeMinutes = cookTimeMinutes
        recipe.steps = cleanedSteps
        recipe.sourceURL = trimmedSource.isEmpty ? nil : trimmedSource
        recipe.materials = Array(selectedMaterials)
        recipe.tags = Array(selectedTags)

        for line in ingredientLines where line.ingredient != nil && line.quantity > 0 {
            let recipeIngredient = RecipeIngredient(quantity: line.quantity, ingredient: line.ingredient, unit: line.unit)
            modelContext.insert(recipeIngredient)
            recipeIngredient.recipe = recipe
        }

        try? modelContext.save()
        onSave?()
        dismiss()
    }
}

private struct FormSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: title)
                content
            }
        }
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
                        .frame(width: 26)
                        .focused($isFocused)
                        .onChange(of: text) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            text = digits
                            minutes = Int(digits) ?? 0
                        }
                    Text("min")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.textSecondary)
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
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                NavigationLink {
                    IngredientPickerView(selection: $line.ingredient)
                } label: {
                    HStack(spacing: 6) {
                        Text(line.ingredient?.name ?? "Choisir un ingrédient")
                            .font(.system(size: 15))
                            .foregroundStyle(line.ingredient == nil ? AppTheme.textSecondary : AppTheme.textPrimary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
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
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(AppTheme.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 11))
    }
}
