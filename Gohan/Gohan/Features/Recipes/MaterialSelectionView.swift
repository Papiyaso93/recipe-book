//
//  MaterialSelectionView.swift
//  Gohan
//

import SwiftUI
import SwiftData

/// Écran de sélection multiple du matériel — poussé depuis le formulaire de recette plutôt
/// que d'afficher les 23 matériels en grille dans la page (repris du pattern
/// QualitySelectionView d'ObjectifsFit).
struct MaterialSelectionView: View {
    @Binding var selection: Set<Material>

    @Query(sort: \Material.name) private var allMaterials: [Material]

    var body: some View {
        List {
            ForEach(allMaterials) { material in
                Button {
                    if selection.contains(material) {
                        selection.remove(material)
                    } else {
                        selection.insert(material)
                    }
                } label: {
                    HStack {
                        Text(material.name)
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        if selection.contains(material) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Matériel")
        .navigationBarTitleDisplayMode(.inline)
    }
}
