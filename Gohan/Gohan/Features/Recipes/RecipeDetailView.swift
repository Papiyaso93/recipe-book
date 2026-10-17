//
//  RecipeDetailView.swift
//  Gohan
//

import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe

    @State private var showingTotalForRecipe = false
    @State private var showingEditForm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                photo
                header
                nutritionSection

                if !recipe.ingredients.isEmpty {
                    ingredientsSection
                }

                if !recipe.materials.isEmpty {
                    materialsSection
                }

                if !recipe.steps.isEmpty {
                    stepsSection
                }

                notesSection
            }
            .padding(16)
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Modifier") { showingEditForm = true }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            RecipeFormView(mode: .edit(recipe))
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
                .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 16).fill(Color.accentColor.opacity(0.15))
                Image(systemName: "fork.knife")
                    .font(.system(size: 40))
                    .foregroundStyle(.accent)
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
        .font(.subheadline)
        .foregroundStyle(.secondary)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingrédients").font(.headline)
            ForEach(recipe.ingredients) { line in
                HStack {
                    Text(line.ingredient?.name ?? "Ingrédient supprimé")
                    Spacer()
                    Text(quantityLabel(for: line))
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
        }
    }

    private func quantityLabel(for line: RecipeIngredient) -> String {
        let quantity = line.quantity.formatted(.number.precision(.fractionLength(0...1)))
        return "\(quantity) \(line.unit?.name ?? "")"
    }

    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Matériel").font(.headline)
            FlowChips(items: recipe.materials.map(\.name))
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Étapes").font(.headline)
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.caption.weight(.semibold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.accentColor.opacity(0.2)))
                    Text(step)
                        .font(.subheadline)
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes").font(.headline)
            if recipe.notes.isEmpty {
                Text("Aucune note pour l'instant.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(recipe.notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.text).font(.subheadline)
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                .font(.subheadline.weight(.medium))
            Text("\(label) (\(unit))")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.08)))
    }
}

private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                }
            }
        }
    }
}
