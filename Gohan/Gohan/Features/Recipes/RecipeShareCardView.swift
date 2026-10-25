//
//  RecipeShareCardView.swift
//  Gohan
//

import SwiftUI

/// Fiche visuelle autonome d'une recette, pensée pour être exportée en image et partagée à
/// quelqu'un qui n'a pas l'app (issue #15) — largeur fixe (indépendante de l'écran qui la génère)
/// pour un rendu identique quel que soit l'iPhone, reprend le même habillage que RecipeDetailView
/// plutôt que d'inventer un nouveau style (option B du mockup, la seule distinguable de l'option A).
struct RecipeShareCardView: View {
    let recipe: Recipe
    /// Décodée en amont par l'appelant (hors thread principal) plutôt que redécodée ici : cette
    /// vue est rendue de façon synchrone par `ImageRenderer`, donc tout travail fait dans son
    /// `body` bloque directement le thread principal le temps du partage.
    var preDecodedPhoto: UIImage?

    private static let cardWidth: CGFloat = 350

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            photo
            Text(recipe.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)

            if !recipe.tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(recipe.tags.sorted { $0.name < $1.name }) { tag in
                        Text(tag.name)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.accentOnTint)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                    }
                }
            }

            HStack(spacing: 10) {
                DetailStat(icon: "person.2.fill", value: "\(recipe.servings)", label: "Portions")
                DetailStat(icon: "clock.fill", value: "\(recipe.prepTimeMinutes) min", label: "Préparation")
                DetailStat(
                    icon: "flame.fill",
                    value: recipe.cookTimeMinutes > 0 ? "\(recipe.cookTimeMinutes) min" : "–",
                    label: "Cuisson"
                )
            }

            if !recipe.ingredients.isEmpty {
                nutritionSection
            }

            if !recipe.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Ingrédients")
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(sortedIngredients) { line in
                            Text("•  \(line.ingredient?.name ?? "Ingrédient supprimé") — \(quantityLabel(for: line))")
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }
            }

            if !recipe.materials.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(text: "Matériel")
                    FlowLayout(spacing: 6) {
                        ForEach(recipe.materials.sorted { $0.name < $1.name }) { material in
                            Text(material.name)
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.accentOnTint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                        }
                    }
                }
            }

            if !recipe.steps.isEmpty {
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

            HStack(spacing: 6) {
                Text("🍴")
                    .font(.system(size: 16))
                Text("Partagé depuis Gohan")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .padding(.top, 6)
            .overlay(alignment: .top) {
                Rectangle().fill(AppTheme.border).frame(height: 0.5)
            }
        }
        .padding(20)
        .frame(width: Self.cardWidth, alignment: .leading)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppTheme.border, lineWidth: 0.5))
        // Image destinée à être envoyée à d'autres personnes : son rendu ne doit pas dépendre
        // du mode clair/sombre du téléphone de qui l'exporte.
        .environment(\.colorScheme, .light)
    }

    private var nutritionSection: some View {
        let totals = recipe.nutritionPerServing
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                SectionLabel(text: "Valeurs nutritionnelles")
                Text("· par portion")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            (
                Text(totals.calories.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                + Text(" kcal")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent.opacity(0.08)))

            HStack(spacing: 8) {
                shareNutritionMetric(label: "Protéines", value: totals.proteins)
                shareNutritionMetric(label: "Glucides", value: totals.carbs)
                shareNutritionMetric(label: "Lipides", value: totals.fat)
            }
        }
    }

    private func shareNutritionMetric(label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text("\(value.formatted(.number.precision(.fractionLength(0)))) g")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var sortedIngredients: [RecipeIngredient] {
        recipe.ingredients.sorted { ($0.ingredient?.name ?? "") < ($1.ingredient?.name ?? "") }
    }

    private func quantityLabel(for line: RecipeIngredient) -> String {
        let quantity = line.quantity.formatted(.number.precision(.fractionLength(0)))
        return "\(quantity) \(line.unit?.shortLabel ?? "")"
    }

    @ViewBuilder
    private var photo: some View {
        if let uiImage = preDecodedPhoto {
            FocusedPhoto(image: uiImage, focusX: recipe.photoFocusX, focusY: recipe.photoFocusY, zoomScale: recipe.photoZoomScale)
                .frame(width: Self.cardWidth - 40, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(AppTheme.accent.opacity(0.12))
                Image(systemName: "fork.knife")
                    .font(.system(size: 36))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: Self.cardWidth - 40, height: 160)
        }
    }
}
