//
//  RootTabView.swift
//  Gohan
//

import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            RecipesListView()
                .tabItem {
                    Label("Recettes", systemImage: "fork.knife")
                }

            FavoritesView()
                .tabItem {
                    Label("Favoris", systemImage: "heart")
                }

            ShoppingListView()
                .tabItem {
                    Label("Liste de courses", systemImage: "cart")
                }
        }
    }
}

#Preview {
    RootTabView()
}
