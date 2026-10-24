//
//  RecipeCard.swift
//  Gohan
//

import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe
    var onToggleFavorite: ((Bool) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                thumbnail
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius - 2))
                favoriteBadge
                    .padding(8)
            }

            Text(recipe.name)
                .font(AppTheme.Font.cardTitle)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(height: 42, alignment: .top)

            HStack(spacing: 10) {
                Label(recipe.totalTimeLabel, systemImage: "clock")
                Label(recipe.caloriesPerServingLabel, systemImage: "flame")
            }
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(10)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private var favoriteBadge: some View {
        Button {
            recipe.isFavorite.toggle()
            if recipe.isFavorite { recipe.favoritedAt = .now }
            try? modelContext.save()
            onToggleFavorite?(recipe.isFavorite)
        } label: {
            Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(recipe.isFavorite ? AppTheme.accent : AppTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.white.opacity(0.92)))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = recipe.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                AppTheme.accent.opacity(0.12)
                Image(systemName: "fork.knife")
                    .foregroundStyle(AppTheme.accent)
            }
        }
    }
}
