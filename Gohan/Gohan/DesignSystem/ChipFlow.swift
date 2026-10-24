//
//  ChipFlow.swift
//  Gohan
//

import SwiftUI

/// Flux de chips multi-sélectionnables (toggle au tap) — partagé entre le formulaire de
/// recette (Type de plat/Régime) et la feuille de filtres, pour garder le même composant visuel.
/// Utilise `FlowLayout` (chaque chip prend sa largeur naturelle) plutôt qu'une grille à colonnes
/// égales : avec des libellés de longueur très variable (ex. "Rapide" vs "Hyperprotéiné"), une
/// grille force une largeur de colonne commune et casse les mots longs au milieu.
@ViewBuilder
func chipFlow<Item: Hashable>(
    _ items: [Item],
    selection: Binding<Set<Item>>,
    label: @escaping (Item) -> String
) -> some View {
    if items.isEmpty {
        Text("Aucune pour l'instant.")
            .font(.system(size: 13))
            .foregroundStyle(AppTheme.textSecondary)
    } else {
        FlowLayout(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = selection.wrappedValue.contains(item)
                Button {
                    if isSelected {
                        selection.wrappedValue.remove(item)
                    } else {
                        selection.wrappedValue.insert(item)
                    }
                } label: {
                    Text(label(item))
                        .font(.system(size: 14))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.buttonRadius)
                                .fill(isSelected ? AppTheme.accent : AppTheme.border.opacity(0.35))
                        )
                        .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
