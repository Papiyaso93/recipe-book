//
//  RecipeDetailView.swift
//  Gohan
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe
    var onDelete: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingTotalForRecipe = false
    @State private var showingEditForm = false
    @State private var showingSuccessToast = false
    @State private var showingDeleteConfirmation = false
    @State private var showingFavoriteToast = false
    @State private var favoriteToastMessage = ""
    @State private var showingNoteEditor = false
    @State private var editingNote: Note?
    @State private var noteToDelete: Note?
    @State private var showingNoteDeleteConfirmation = false
    @State private var showingNoteToast = false
    @State private var noteToastMessage = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photo
                statsRow

                if !recipe.tags.isEmpty {
                    tagsSection
                }

                AppCard { nutritionSection }

                if !recipe.ingredients.isEmpty {
                    AppCard { ingredientsSection }
                }

                if !recipe.materials.isEmpty {
                    AppCard { materialsSection }
                }

                if !recipe.steps.isEmpty {
                    AppCard { stepsSection }
                }

                AppCard { notesSection }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    recipe.isFavorite.toggle()
                    if recipe.isFavorite { recipe.favoritedAt = .now }
                    try? modelContext.save()
                    favoriteToastMessage = recipe.isFavorite ? "Ajouté aux favoris" : "Retiré des favoris"
                    showingFavoriteToast = true
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(recipe.isFavorite ? AppTheme.accent : AppTheme.textSecondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Modifier") { showingEditForm = true }
                    Button("Supprimer", role: .destructive) { showingDeleteConfirmation = true }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            RecipeFormView(mode: .edit(recipe)) {
                showingSuccessToast = true
            }
        }
        .successToast("Recette modifiée", isPresented: $showingSuccessToast)
        .successToast(favoriteToastMessage, isPresented: $showingFavoriteToast)
        .successToast(noteToastMessage, isPresented: $showingNoteToast)
        .confirmationDialog(
            "Supprimer « \(recipe.name) » ?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                modelContext.delete(recipe)
                try? modelContext.save()
                onDelete?()
                dismiss()
            }
            Button("Annuler", role: .cancel) {}
        } message: {
            Text("Cette action est irréversible.")
        }
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(recipe: recipe, note: editingNote) {
                noteToastMessage = editingNote == nil ? "Note ajoutée" : "Note modifiée"
                showingNoteToast = true
            }
        }
        .confirmationDialog(
            "Supprimer cette note ?",
            isPresented: $showingNoteDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let noteToDelete {
                    modelContext.delete(noteToDelete)
                    try? modelContext.save()
                    noteToastMessage = "Note supprimée"
                    showingNoteToast = true
                }
                noteToDelete = nil
            }
            Button("Annuler", role: .cancel) { noteToDelete = nil }
        }
    }

    @ViewBuilder
    private var photo: some View {
        if let data = recipe.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius).fill(AppTheme.accent.opacity(0.12))
                Image(systemName: "fork.knife")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(height: 220)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            DetailStat(icon: "person.2", value: "\(recipe.servings)", label: "Portions")
            DetailStat(icon: "timer", value: "\(recipe.prepTimeMinutes) min", label: "Préparation")
            DetailStat(
                icon: "flame",
                value: recipe.cookTimeMinutes > 0 ? "\(recipe.cookTimeMinutes) min" : "–",
                label: "Cuisson"
            )
        }
    }

    private var tagsSection: some View {
        let sorted = recipe.tags.sorted {
            let lhs = categoryPriority($0.category)
            let rhs = categoryPriority($1.category)
            return lhs != rhs ? lhs < rhs : $0.name < $1.name
        }
        return FlowChips(items: sorted.map(\.name))
    }

    private func categoryPriority(_ category: TagCategory) -> Int {
        switch category {
        case .typeDePlat: return 0
        case .regime: return 1
        case .autre: return 2
        }
    }

    private var incompleteNutritionBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            Text("Valeurs incomplètes : certains ingrédients saisis en \"Unité\" ne sont pas encore pris en compte.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)))
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Valeurs nutritionnelles")

            if recipe.hasIncompleteNutrition {
                incompleteNutritionBanner
            }

            Picker("Affichage", selection: $showingTotalForRecipe) {
                Text("Par portion").tag(false)
                Text("Recette entière").tag(true)
            }
            .pickerStyle(.segmented)

            let totals = showingTotalForRecipe ? recipe.totalNutrition : recipe.nutritionPerServing

            VStack(spacing: 2) {
                (
                    Text(totals.calories.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    + Text(" kcal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                )
                Text("Calories")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent.opacity(0.08)))

            HStack(spacing: 8) {
                NutritionMetric(label: "Protéines", value: totals.proteins, unit: "g")
                NutritionMetric(label: "Glucides", value: totals.carbs, unit: "g")
                NutritionMetric(label: "Lipides", value: totals.fat, unit: "g")
            }
        }
    }

    private var ingredientsSection: some View {
        let sorted = recipe.ingredients.sorted {
            ($0.ingredient?.name ?? "") < ($1.ingredient?.name ?? "")
        }
        return VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Ingrédients")
            ForEach(sorted) { line in
                HStack {
                    Text(line.ingredient?.name ?? "Ingrédient supprimé")
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(quantityLabel(for: line))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .font(.system(size: 14))
            }
        }
    }

    private func quantityLabel(for line: RecipeIngredient) -> String {
        let quantity = line.quantity.formatted(.number.precision(.fractionLength(0)))
        return "\(quantity) \(line.unit?.shortLabel ?? "")"
    }

    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Matériel")
            FlowChips(items: recipe.materials.map(\.name))
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Étapes")
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppTheme.accent.opacity(0.12)))
                    Text(step)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Notes")
            if recipe.notes.isEmpty {
                Text("Aucune note pour l'instant.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(recipe.notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                    noteRow(note)
                }
            }
            Button {
                editingNote = nil
                showingNoteEditor = true
            } label: {
                Text("+ Ajouter une note")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func noteRow(_ note: Note) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                editingNote = note
                showingNoteEditor = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.text)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                noteToDelete = note
                showingNoteDeleteConfirmation = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 0.5)
        }
    }
}

private struct NutritionMetric: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value.formatted(.number.precision(.fractionLength(0)))) \(unit)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent.opacity(0.08)))
    }
}

private struct DetailStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }
}

private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.accentDark)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                }
            }
        }
    }
}
