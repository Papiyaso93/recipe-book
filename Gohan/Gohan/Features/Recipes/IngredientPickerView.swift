//
//  IngredientPickerView.swift
//  Gohan
//

import SwiftUI
import SwiftData

/// Sélection simple d'un ingrédient avec recherche — 131 ingrédients, trop pour un Picker natif
/// confortable. Repris du pattern MaterialSelectionView, en sélection unique et avec recherche.
struct IngredientPickerView: View {
    @Binding var selection: Ingredient?
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Ingredient.name) private var allIngredients: [Ingredient]
    @State private var searchText = ""

    private var filteredIngredients: [Ingredient] {
        guard !searchText.isEmpty else { return allIngredients }
        return allIngredients.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            ForEach(filteredIngredients) { ingredient in
                Button {
                    selection = ingredient
                    dismiss()
                } label: {
                    HStack {
                        Text(ingredient.name)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        if selection == ingredient {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Rechercher un ingrédient"
        )
        .navigationTitle("Ingrédient")
        .navigationBarTitleDisplayMode(.inline)
    }
}
