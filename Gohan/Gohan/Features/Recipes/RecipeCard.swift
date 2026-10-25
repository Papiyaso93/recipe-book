//
//  RecipeCard.swift
//  Gohan
//

import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe
    var onToggleFavorite: ((Bool) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @State private var decodedPhoto: UIImage?

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
                statLabel(recipe.totalTimeLabel, systemImage: "clock", iconColor: AppTheme.accent)
                statLabel(recipe.caloriesPerServingLabel, systemImage: "flame", iconColor: AppTheme.calorieOrange)
            }
            .font(.system(size: 12))
        }
        .padding(10)
        .background(AppTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cardRadius)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        // Décoder la photo à chaque réévaluation du body coûte cher une fois multiplié par le
        // nombre de cartes visibles dans la grille — décodage unique, hors thread principal.
        .task(id: recipe.photoData) {
            guard let data = recipe.photoData else { decodedPhoto = nil; return }
            decodedPhoto = await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
        }
    }

    private func statLabel(_ text: String, systemImage: String, iconColor: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .foregroundStyle(iconColor)
            Text(text)
                .foregroundStyle(AppTheme.textSecondary)
        }
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
        if let uiImage = decodedPhoto {
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
