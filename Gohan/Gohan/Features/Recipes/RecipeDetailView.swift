//
//  RecipeDetailView.swift
//  Gohan
//

import SwiftUI
import SwiftData

struct RecipeDetailView: View {
    let recipe: Recipe
    var onDelete: ((@escaping () -> Void) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showingTotalForRecipe = false
    @State private var showingEditForm = false
    @State private var showingSuccessToast = false
    @State private var showingFavoriteToast = false
    @State private var favoriteToastMessage = ""
    @State private var showingNoteEditor = false
    @State private var editingNote: Note?
    @State private var showingNoteToast = false
    @State private var noteToastMessage = ""
    @State private var noteUndoAction: (() -> Void)? = nil
    @State private var showingShoppingToast = false
    @State private var shoppingToastMessage = ""
    @State private var showingCookingMode = false
    @State private var decodedPhoto: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photo
                Text(recipe.name)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)

                if !recipe.tags.isEmpty {
                    tagsSection
                }

                statsRow

                AppCard { nutritionSection }

                if !recipe.ingredients.isEmpty {
                    AppCard { ingredientsSection }
                }

                if !recipe.materials.isEmpty {
                    AppCard { materialsSection }
                }

                if !recipe.steps.isEmpty {
                    AppCard { stepsSection }
                }

                if let sourceURL = recipe.sourceURL, !sourceURL.isEmpty {
                    AppCard { sourceSection(sourceURL) }
                }

                AppCard { notesSection }
            }
            .padding(16)
        }
        .background(AppTheme.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !recipe.steps.isEmpty {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCookingMode = true
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    recipe.isFavorite.toggle()
                    if recipe.isFavorite { recipe.favoritedAt = .now }
                    try? modelContext.save()
                    favoriteToastMessage = recipe.isFavorite ? "Ajouté aux favoris" : "Retiré des favoris"
                    showingFavoriteToast = true
                } label: {
                    Image(systemName: recipe.isFavorite ? "heart.fill" : "heart")
                        .foregroundStyle(recipe.isFavorite ? AppTheme.accent : AppTheme.textSecondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Modifier") { showingEditForm = true }
                    Button("Partager") { shareRecipe() }
                    Button("Supprimer", role: .destructive) { deleteRecipe() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditForm) {
            RecipeFormView(mode: .edit(recipe)) {
                showingSuccessToast = true
            }
        }
        .fullScreenCover(isPresented: $showingCookingMode) {
            CookingModeView(recipe: recipe)
        }
        .successToast("Recette modifiée", isPresented: $showingSuccessToast)
        .successToast(favoriteToastMessage, isPresented: $showingFavoriteToast)
        .successToast(noteToastMessage, isPresented: $showingNoteToast, duration: 4, undo: noteUndoAction)
        .successToast(shoppingToastMessage, isPresented: $showingShoppingToast)
        .sheet(isPresented: $showingNoteEditor) {
            NoteEditorView(recipe: recipe, note: editingNote) {
                noteUndoAction = nil
                noteToastMessage = editingNote == nil ? "Note ajoutée" : "Note modifiée"
                showingNoteToast = true
            }
        }
        // Décoder la photo (souvent plusieurs centaines de Ko à plusieurs Mo) à chaque
        // réévaluation du body — ce qu'on faisait avant — rendait tout l'écran perceptiblement
        // lent (le menu "•••" semblait mettre plusieurs secondes à réagir). On décode une seule
        // fois, hors du thread principal, et on garde le résultat en cache.
        .task(id: recipe.photoData) {
            guard let data = recipe.photoData else { decodedPhoto = nil; return }
            decodedPhoto = await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
        }
    }

    /// Suppression immédiate (plus de bulle de confirmation) : la recette est bien retirée tout de
    /// suite, mais on garde de quoi la reconstruire à l'identique si l'utilisateur tape "Annuler"
    /// dans le toast affiché par l'écran précédent — matériel/tags survivent déjà à la suppression
    /// (pas de cascade sur eux), seuls les ingrédients et notes sont recréés depuis l'instantané.
    private func deleteRecipe() {
        let name = recipe.name
        let photoData = recipe.photoData
        let servings = recipe.servings
        let prepTimeMinutes = recipe.prepTimeMinutes
        let cookTimeMinutes = recipe.cookTimeMinutes
        let steps = recipe.steps
        let sourceURL = recipe.sourceURL
        let isFavorite = recipe.isFavorite
        let createdAt = recipe.createdAt
        let favoritedAt = recipe.favoritedAt
        let materials = recipe.materials
        let tags = recipe.tags
        let ingredientLines = recipe.ingredients.map {
            (ingredient: $0.ingredient, unit: $0.unit, quantity: $0.quantity,
             isInShoppingList: $0.isInShoppingList, isCheckedInShoppingList: $0.isCheckedInShoppingList)
        }
        let noteSnapshots = recipe.notes.map { (text: $0.text, createdAt: $0.createdAt) }
        let context = modelContext

        modelContext.delete(recipe)
        try? modelContext.save()

        onDelete? {
            let restored = Recipe(
                name: name,
                photoData: photoData,
                servings: servings,
                prepTimeMinutes: prepTimeMinutes,
                cookTimeMinutes: cookTimeMinutes,
                steps: steps,
                sourceURL: sourceURL,
                isFavorite: isFavorite,
                createdAt: createdAt,
                favoritedAt: favoritedAt
            )
            restored.materials = materials
            restored.tags = tags
            context.insert(restored)
            for line in ingredientLines {
                let newLine = RecipeIngredient(quantity: line.quantity, ingredient: line.ingredient, unit: line.unit)
                newLine.isInShoppingList = line.isInShoppingList
                newLine.isCheckedInShoppingList = line.isCheckedInShoppingList
                newLine.recipe = restored
                context.insert(newLine)
            }
            for note in noteSnapshots {
                let newNote = Note(text: note.text, createdAt: note.createdAt)
                newNote.recipe = restored
                context.insert(newNote)
            }
            try? context.save()
        }
        dismiss()
    }

    /// Présentation directe via UIKit plutôt que `.sheet` : un `UIActivityViewController`
    /// imbriqué dans un `.sheet` SwiftUI donne une feuille blanche vide, bug connu.
    /// Le décodage de la photo est de loin la partie la plus coûteuse de la génération — fait
    /// hors thread principal d'abord, pour que le tap sur "Partager" ne bloque pas l'interface
    /// pendant que `ImageRenderer` (lui, forcément sur le thread principal) fait le reste, qui
    /// est rapide une fois la photo déjà prête.
    private func shareRecipe() {
        let photoData = recipe.photoData
        Task {
            let preDecodedPhoto = await Task.detached(priority: .userInitiated) {
                photoData.flatMap(UIImage.init(data:))
            }.value

            let renderer = ImageRenderer(content: RecipeShareCardView(recipe: recipe, preDecodedPhoto: preDecodedPhoto))
            renderer.scale = UIScreen.main.scale
            // Sans largeur imposée ici, ImageRenderer propose une taille non bornée à la vue hors
            // écran et peut produire une image quasi vide (d'où l'icône "cassée" dans la feuille
            // de partage) — on fixe la largeur à celle de la carte, la hauteur reste libre.
            renderer.proposedSize = ProposedViewSize(width: 350, height: nil)
            guard let image = renderer.uiImage else { return }

            guard let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
                  let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController else { return }
            var top = root
            while let presented = top.presentedViewController { top = presented }

            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            top.present(activityVC, animated: true)
        }
    }

    private func deleteNote(_ note: Note) {
        let text = note.text
        let createdAt = note.createdAt
        let context = modelContext
        let targetRecipe = recipe

        modelContext.delete(note)
        try? modelContext.save()

        noteUndoAction = {
            let restored = Note(text: text, createdAt: createdAt)
            restored.recipe = targetRecipe
            context.insert(restored)
            try? context.save()
        }
        noteToastMessage = "Note supprimée"
        showingNoteToast = true
    }

    @ViewBuilder
    private var photo: some View {
        if let uiImage = decodedPhoto {
            FocusedPhoto(image: uiImage, focusX: recipe.photoFocusX, focusY: recipe.photoFocusY)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.cardRadius).fill(AppTheme.accent.opacity(0.12))
                Image(systemName: "fork.knife")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(height: 220)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            DetailStat(icon: "person.2.fill", value: "\(recipe.servings)", label: "Portions")
            DetailStat(icon: "clock.fill", value: "\(recipe.prepTimeMinutes) min", label: "Préparation")
            DetailStat(
                icon: "flame.fill",
                value: recipe.cookTimeMinutes > 0 ? "\(recipe.cookTimeMinutes) min" : "–",
                label: "Cuisson"
            )
        }
    }

    private var tagsSection: some View {
        let sorted = recipe.tags.sorted {
            let lhs = categoryPriority($0.category)
            let rhs = categoryPriority($1.category)
            return lhs != rhs ? lhs < rhs : $0.name < $1.name
        }
        return FlowChips(items: sorted.map(\.name))
    }

    private func categoryPriority(_ category: TagCategory) -> Int {
        switch category {
        case .typeDePlat: return 0
        case .regime: return 1
        case .autre: return 2
        }
    }

    private var incompleteNutritionBanner: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
            Text("Valeurs incomplètes : certains ingrédients saisis en \"Unité\" ne sont pas encore pris en compte.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.orange.opacity(0.1)))
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Valeurs nutritionnelles")

            if recipe.hasIncompleteNutrition {
                incompleteNutritionBanner
            }

            Picker("Affichage", selection: $showingTotalForRecipe) {
                Text("Par portion").tag(false)
                Text("Recette entière").tag(true)
            }
            .pickerStyle(.segmented)

            let totals = showingTotalForRecipe ? recipe.totalNutrition : recipe.nutritionPerServing

            VStack(spacing: 2) {
                (
                    Text(totals.calories.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    + Text(" kcal")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                )
                Text("Calories")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent.opacity(0.08)))

            HStack(spacing: 8) {
                NutritionMetric(label: "Protéines", value: totals.proteins, unit: "g")
                NutritionMetric(label: "Glucides", value: totals.carbs, unit: "g")
                NutritionMetric(label: "Lipides", value: totals.fat, unit: "g")
            }
        }
    }

    private var ingredientsSection: some View {
        let sorted = recipe.ingredients.sorted {
            ($0.ingredient?.name ?? "") < ($1.ingredient?.name ?? "")
        }
        let allInShoppingList = !sorted.isEmpty && sorted.allSatisfy(\.isInShoppingList)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionLabel(text: "Ingrédients")
                Spacer()
                Button {
                    toggleAllInShoppingList(sorted, add: !allInShoppingList)
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "cart.badge.plus")
                            .font(.system(size: 12, weight: .semibold))
                        Text(allInShoppingList ? "Tout retirer" : "Tout ajouter")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            ForEach(sorted) { line in
                HStack {
                    Text(line.ingredient?.name ?? "Ingrédient supprimé")
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    Text(quantityLabel(for: line))
                        .foregroundStyle(AppTheme.textSecondary)
                    Button {
                        toggleAllInShoppingList([line], add: !line.isInShoppingList)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(line.isInShoppingList ? AppTheme.accent.opacity(0.12) : AppTheme.border.opacity(0.35))
                                .frame(width: 26, height: 26)
                            Image(systemName: line.isInShoppingList ? "cart.fill" : "cart.badge.plus")
                                .font(.system(size: 12))
                                .foregroundStyle(line.isInShoppingList ? AppTheme.accent : AppTheme.textSecondary)
                        }
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 14))
            }
        }
    }

    private func toggleAllInShoppingList(_ lines: [RecipeIngredient], add: Bool) {
        for line in lines {
            line.isInShoppingList = add
        }
        try? modelContext.save()
        shoppingToastMessage = add ? "Ajouté à la liste de courses" : "Retiré de la liste de courses"
        showingShoppingToast = true
    }

    private func quantityLabel(for line: RecipeIngredient) -> String {
        let quantity = line.quantity.formatted(.number.precision(.fractionLength(0)))
        return "\(quantity) \(line.unit?.shortLabel ?? "")"
    }

    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Matériel")
            FlowChips(items: recipe.materials.map(\.name))
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(text: "Étapes")
            ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(AppTheme.accent.opacity(0.12)))
                    Text(step)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }

    private func sourceSection(_ source: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Source")
            if let url = validLink(source) {
                Button {
                    openURL(url)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .font(.system(size: 15))
                            .foregroundStyle(AppTheme.accent)
                        Text((url.host ?? source).replacingOccurrences(of: "www.", with: ""))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.accent)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "book")
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                    Text(source)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
    }

    /// Le champ "Source" accepte aussi bien un lien qu'une référence libre (livre, page...) —
    /// on ne le traite comme lien cliquable que si c'est une URL http/https avec un domaine.
    private func validLink(_ source: String) -> URL? {
        guard let url = URL(string: source),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionLabel(text: "Notes")
            if recipe.notes.isEmpty {
                Text("Aucune note pour l'instant.")
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                ForEach(recipe.notes.sorted(by: { $0.createdAt > $1.createdAt })) { note in
                    noteRow(note)
                }
            }
            Button {
                editingNote = nil
                showingNoteEditor = true
            } label: {
                Text("+ Ajouter une note")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func noteRow(_ note: Note) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                editingNote = note
                showingNoteEditor = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.text)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                deleteNote(note)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.textSecondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
        .overlay(alignment: .bottom) {
            Rectangle().fill(AppTheme.border).frame(height: 0.5)
        }
    }
}

private struct NutritionMetric: View {
    let label: String
    let value: Double
    let unit: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value.formatted(.number.precision(.fractionLength(0)))) \(unit)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.accent.opacity(0.08)))
    }
}

struct DetailStat: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 22, height: 22)
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.accent)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

private struct FlowChips: View {
    let items: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Text(item)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.accentOnTint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppTheme.accent.opacity(0.12)))
                }
            }
        }
    }
}
