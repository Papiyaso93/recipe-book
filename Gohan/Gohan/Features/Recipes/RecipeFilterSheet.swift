//
//  RecipeFilterSheet.swift
//  Gohan
//

import SwiftUI
import SwiftData

/// Partagée entre Recettes et Favoris pour garder le même comportement de filtrage partout.
struct RecipeFilterSheet: View {
    @Binding var filters: RecipeFilterSelection
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Tag.name) private var allTags: [Tag]

    private var typeDePlatTags: [Tag] { allTags.filter { $0.category == .typeDePlat } }
    private var regimeTags: [Tag] { allTags.filter { $0.category == .regime } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormSectionCard(title: "Type de plat") {
                        chipFlow(typeDePlatTags, selection: $filters.typeDePlat) { $0.name }
                    }
                    FormSectionCard(title: "Régime") {
                        chipFlow(regimeTags, selection: $filters.regime) { $0.name }
                    }
                    FormSectionCard(title: "Caractéristiques") {
                        chipFlow(RecipeCharacteristicFilter.allCases, selection: characteristicsBinding) { $0.label }
                    }
                }
                .padding(16)
            }
            .background(AppTheme.background)
            .navigationTitle("Filtres")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Réinitialiser") { filters.reset() }
                        .disabled(filters.isEmpty)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminé") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    /// Adapte les 4 booléens à l'API `Set<Item>` de `chipFlow`, pour réutiliser le même composant.
    private var characteristicsBinding: Binding<Set<RecipeCharacteristicFilter>> {
        Binding(
            get: {
                var set = Set<RecipeCharacteristicFilter>()
                if filters.sansCuisson { set.insert(.sansCuisson) }
                if filters.rapide { set.insert(.rapide) }
                if filters.peuDIngredients { set.insert(.peuDIngredients) }
                if filters.hyperproteine { set.insert(.hyperproteine) }
                return set
            },
            set: { newValue in
                filters.sansCuisson = newValue.contains(.sansCuisson)
                filters.rapide = newValue.contains(.rapide)
                filters.peuDIngredients = newValue.contains(.peuDIngredients)
                filters.hyperproteine = newValue.contains(.hyperproteine)
            }
        )
    }
}

private enum RecipeCharacteristicFilter: CaseIterable, Hashable {
    case sansCuisson, rapide, peuDIngredients, hyperproteine

    var label: String {
        switch self {
        case .sansCuisson: return "Sans cuisson"
        case .rapide: return "Rapide"
        case .peuDIngredients: return "Peu d'ingrédients"
        case .hyperproteine: return "Hyperprotéiné"
        }
    }
}

private struct FormSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel(text: title)
                content
            }
        }
    }
}
