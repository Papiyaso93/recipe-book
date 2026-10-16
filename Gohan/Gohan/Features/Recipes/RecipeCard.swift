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
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(recipe.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Label(recipe.totalTimeLabel, systemImage: "clock")
                Label(recipe.caloriesPerServingLabel, systemImage: "flame")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let data = recipe.photoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Color.accentColor.opacity(0.15)
                Image(systemName: "fork.knife")
                    .foregroundStyle(.accent)
            }
        }
    }
}
