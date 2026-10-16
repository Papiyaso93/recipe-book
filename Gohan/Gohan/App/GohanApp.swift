//
//  GohanApp.swift
//  Gohan
//
//  Created by Gus on 17/10/2026.
//

import SwiftUI
import SwiftData

@main
struct GohanApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Recipe.self,
            RecipeIngredient.self,
            Ingredient.self,
            IngredientGroup.self,
            MeasurementUnit.self,
            Material.self,
            Tag.self,
            Note.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            DataSeeder.seedIfNeeded(context: container.mainContext)
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(sharedModelContainer)
    }
}
