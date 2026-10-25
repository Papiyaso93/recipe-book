//
//  RootTabView.swift
//  Gohan
//

import SwiftUI

extension Notification.Name {
    /// Posté depuis n'importe quel onglet (ex: une erreur d'import "clé API invalide") pour
    /// amener l'utilisateur directement sur Réglages, sans faire remonter une dépendance entre
    /// `RecipesListView` et `RootTabView`.
    static let switchToSettingsTab = Notification.Name("switchToSettingsTab")
}

struct RootTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipesListView()
                .tabItem {
                    Label("Recettes", systemImage: "fork.knife")
                }
                .tag(0)

            FavoritesView()
                .tabItem {
                    Label("Favoris", systemImage: "heart")
                }
                .tag(1)

            ShoppingListView()
                .tabItem {
                    Label("Courses", systemImage: "cart")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape")
                }
                .tag(3)
        }
        .tint(AppTheme.accent)
        .onReceive(NotificationCenter.default.publisher(for: .switchToSettingsTab)) { _ in
            selectedTab = 3
        }
    }
}

#Preview {
    RootTabView()
}
