//
//  RecipeCard.swift
//  Gohan
//

import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius - 2))

            Text(recipe.name)
                .font(AppTheme.Font.cardTitle)
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(2)

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
