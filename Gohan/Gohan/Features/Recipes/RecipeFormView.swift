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

    @Query(sort: \Ingredient.name) private var allIngredients: [Ingredient]
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
    @State private var newTagName = ""
    @State private var didPopulate = false
    @State private var showingValidationError = false

    var body: some View {
        NavigationStack {
            Form {
                generalSection
                photoSection
                tagsSection
                ingredientsSection
                stepsSection
                materialsSection
                sourceSection
            }
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

    // MARK: - Sections

    private var generalSection: some View {
        Section("Général") {
            TextField("Nom de la recette", text: $name)
            Stepper("Portions : \(servings)", value: $servings, in: 1...50)
            Stepper("Préparation : \(prepTimeMinutes) min", value: $prepTimeMinutes, in: 0...600, step: 5)
            Stepper("Cuisson : \(cookTimeMinutes) min", value: $cookTimeMinutes, in: 0...600, step: 5)
        }
    }

    private var photoSection: some View {
        Section("Photo") {
            PhotosPicker("Choisir une photo", selection: $selectedPhotoItem, matching: .images)
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 160)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                photoData = try? await newItem?.loadTransferable(type: Data.self)
            }
        }
    }

    private var tagsSection: some View {
        Section("Catégories") {
            chipFlow(allTags, selection: $selectedTags) { $0.name }

            HStack {
                TextField("Nouvelle catégorie", text: $newTagName)
                Button("Ajouter") {
                    addTag()
                }
                .disabled(newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var ingredientsSection: some View {
        Section("Ingrédients") {
            ForEach($ingredientLines) { $line in
                IngredientLineRow(line: $line, allIngredients: allIngredients, allUnits: allUnits)
            }
            .onDelete { ingredientLines.remove(atOffsets: $0) }

            Button("Ajouter un ingrédient") {
                ingredientLines.append(DraftIngredientLine())
            }
        }
    }

    private var stepsSection: some View {
        Section("Étapes") {
            ForEach(steps.indices, id: \.self) { index in
                HStack {
                    Text("\(index + 1).")
                        .foregroundStyle(.secondary)
                    TextField("Décris l'étape", text: $steps[index], axis: .vertical)
                }
            }
            .onDelete { steps.remove(atOffsets: $0) }

            Button("Ajouter une étape") {
                steps.append("")
            }
        }
    }

    private var materialsSection: some View {
        Section("Matériel") {
            chipFlow(allMaterials, selection: $selectedMaterials) { $0.name }
        }
    }

    private var sourceSection: some View {
        Section("Source (optionnel)") {
            TextField("Lien de la recette d'origine", text: $sourceURL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
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
                .font(.caption)
                .foregroundStyle(.secondary)
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
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(
                                Capsule().fill(isSelected ? Color.accentColor.opacity(0.3) : Color.accentColor.opacity(0.08))
                            )
                            .foregroundStyle(isSelected ? Color.accentColor : .primary)
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

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let tag = Tag(name: trimmed)
        modelContext.insert(tag)
        selectedTags.insert(tag)
        newTagName = ""
    }

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
        dismiss()
    }
}

private struct IngredientLineRow: View {
    @Binding var line: DraftIngredientLine
    let allIngredients: [Ingredient]
    let allUnits: [MeasurementUnit]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker("Ingrédient", selection: $line.ingredient) {
                Text("Choisir…").tag(Ingredient?.none)
                ForEach(allIngredients) { ingredient in
                    Text(ingredient.name).tag(Optional(ingredient))
                }
            }

            HStack {
                TextField("Quantité", value: $line.quantity, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 80)

                Picker("Unité", selection: $line.unit) {
                    Text("—").tag(MeasurementUnit?.none)
                    ForEach(allUnits) { unit in
                        Text(unit.name).tag(Optional(unit))
                    }
                }
            }
        }
    }
}
