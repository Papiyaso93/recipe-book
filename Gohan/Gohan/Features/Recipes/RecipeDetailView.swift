//
//  RecipeDetailView.swift
//  Gohan
//

import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    @State private var showingTotalForRecipe = false
    @State private var showingEditForm = false
    @State private var showingSuccessToast = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photo
                header

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
                Button("Modifier") { showingEditForm = true }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            RecipeFormView(mode: .edit(recipe)) {
                showingSuccessToast = true
            }
        }
        .successToast("Recette modifiée", isPresented: $showingSuccessToast)
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

    private var header: some View {
        HStack(spacing: 16) {
            Label("\(recipe.servings)", systemImage: "person.2")
            Label("\(recipe.prepTimeMinutes) min prépa", systemImage: "timer")
            Label("\(recipe.cookTimeMinutes) min cuisson", systemImage: "flame")
        }
        .font(.system(size: 13))
        .foregroundStyle(AppTheme.textSecondary)
    }

    private var tagsSection: some View {
        FlowChips(items: recipe.tags.map {
            [$0.emoji, $0.name].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " ")
        })
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Affichage", selection: $showingTotalForRecipe) {
                Text("Par portion").tag(false)
                Text("Recette entière").tag(true)
            }
            .pickerStyle(.segmented)

            let totals = showingTotalForRecipe ? recipe.totalNutrition : recipe.nutritionPerServing
            HStack(spacing: 10) {
                NutritionMetric(label: "Calories", value: totals.calories, unit: "kcal")
                NutritionMetric(label: "Protéines", value: totals.proteins, unit: "g")
                NutritionMetric(label: "Glucides", value: totals.carbs, unit: "g")
                NutritionMetric(label: "Lipides", value: totals.fat, unit: "g")
            }
        }
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Ingrédients")
            ForEach(recipe.ingredients) { line in
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
        let quantity = line.quantity.formatted(.number.precision(.fractionLength(0...1)))
        return "\(quantity) \(line.unit?.name ?? "")"
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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text)
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }
}

private struct NutritionMetric: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value.formatted(.number.precision(.fractionLength(0...1))))
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.textPrimary)
            Text("\(label) (\(unit))")
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent.opacity(0.08)))
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
