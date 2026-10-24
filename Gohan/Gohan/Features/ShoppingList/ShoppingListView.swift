//
//  ShoppingListView.swift
//  Gohan
//

import SwiftUI
import SwiftData

enum ShoppingListGrouping: String, CaseIterable {
    case category, recipe

    var label: String {
        switch self {
        case .category: return "Catégorie"
        case .recipe: return "Recette"
        }
    }
}

/// Un ingrédient/unité peut être alimenté par plusieurs recettes — agrégé ici pour le cumul
/// affiché en mode "Catégorie" (mode "Recette" affiche les lignes brutes, sans agrégation).
private struct ShoppingAggregate: Identifiable {
    let ingredient: Ingredient
    let unit: MeasurementUnit?
    var lines: [RecipeIngredient]

    var id: String {
        "\(ingredient.persistentModelID.hashValue)-\(unit?.persistentModelID.hashValue ?? 0)"
    }
    var totalQuantity: Double { lines.reduce(0) { $0 + $1.quantity } }
    var isChecked: Bool { lines.allSatisfy(\.isCheckedInShoppingList) }
}

struct ShoppingListView: View {
    @Query(filter: #Predicate<RecipeIngredient> { $0.isInShoppingList }) private var items: [RecipeIngredient]
    @Environment(\.modelContext) private var modelContext

    @AppStorage("shoppingListGrouping") private var groupingRaw = ShoppingListGrouping.category.rawValue
    @State private var expandedIDs: Set<String> = []
    @State private var showingClearToast = false
    @State private var clearUndoAction: (() -> Void)? = nil

    private var grouping: Binding<ShoppingListGrouping> {
        Binding(
            get: { ShoppingListGrouping(rawValue: groupingRaw) ?? .category },
            set: { groupingRaw = $0.rawValue }
        )
    }

    private var aggregates: [ShoppingAggregate] {
        var buckets: [String: ShoppingAggregate] = [:]
        for line in items {
            guard let ingredient = line.ingredient else { continue }
            let key = "\(ingredient.persistentModelID.hashValue)-\(line.unit?.persistentModelID.hashValue ?? 0)"
            if var existing = buckets[key] {
                existing.lines.append(line)
                buckets[key] = existing
            } else {
                buckets[key] = ShoppingAggregate(ingredient: ingredient, unit: line.unit, lines: [line])
            }
        }
        return buckets.values.sorted(by: aggregateIsBefore)
    }

    /// Ordre strict (nom puis id en départage) — un simple tri par nom n'est pas stable quand
    /// deux lignes partagent le même ingrédient en unités différentes : sans départage, leur
    /// ordre dépend de l'énumération du dictionnaire sous-jacent, qui peut changer d'un rendu à
    /// l'autre (ex: après avoir coché une case) et donne l'impression que la liste "bouge".
    private func aggregateIsBefore(_ lhs: ShoppingAggregate, _ rhs: ShoppingAggregate) -> Bool {
        if lhs.ingredient.name != rhs.ingredient.name {
            return lhs.ingredient.name < rhs.ingredient.name
        }
        return lhs.id < rhs.id
    }

    private func lineIsBefore(_ lhs: RecipeIngredient, _ rhs: RecipeIngredient) -> Bool {
        let lhsName = lhs.ingredient?.name ?? ""
        let rhsName = rhs.ingredient?.name ?? ""
        if lhsName != rhsName { return lhsName < rhsName }
        return String(describing: lhs.persistentModelID) < String(describing: rhs.persistentModelID)
    }

    private var categorySections: [(category: String, aggregates: [ShoppingAggregate])] {
        Dictionary(grouping: aggregates) { $0.ingredient.group?.name ?? "Autres ingrédients" }
            .map { (category: $0.key, aggregates: $0.value.sorted(by: aggregateIsBefore)) }
            .sorted { $0.category < $1.category }
    }

    private var recipeSections: [(recipeName: String, lines: [RecipeIngredient])] {
        Dictionary(grouping: items) { $0.recipe?.name ?? "Recette supprimée" }
            .map { (recipeName: $0.key, lines: $0.value.sorted(by: lineIsBefore)) }
            .sorted { $0.recipeName < $1.recipeName }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !items.isEmpty {
                    controlRow
                }

                Group {
                    if items.isEmpty {
                        ContentUnavailableView(
                            "Liste de courses vide",
                            systemImage: "cart",
                            description: Text("Ajoute des ingrédients depuis une recette pour les retrouver ici.")
                        )
                    } else {
                        List {
                            if grouping.wrappedValue == .category {
                                ForEach(categorySections, id: \.category) { section in
                                    Section {
                                        ForEach(section.aggregates) { aggregate in
                                            aggregateRow(aggregate)
                                        }
                                    } header: {
                                        Text(section.category.uppercased())
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                            } else {
                                ForEach(recipeSections, id: \.recipeName) { section in
                                    Section {
                                        ForEach(section.lines) { line in
                                            lineRow(line)
                                        }
                                    } header: {
                                        Text(section.recipeName.uppercased())
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(AppTheme.accent)
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .background(AppTheme.background)
            .navigationTitle("Liste de courses")
            .successToast(
                "Liste de courses vidée",
                isPresented: $showingClearToast,
                duration: 4,
                undo: clearUndoAction
            )
        }
    }

    private var controlRow: some View {
        HStack {
            Button("Vider la liste") { clearAll() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.red)
            Spacer()
            Menu {
                Picker("Grouper par", selection: grouping) {
                    ForEach(ShoppingListGrouping.allCases, id: \.self) { group in
                        Text(group.label).tag(group)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(grouping.wrappedValue.label)
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 9).stroke(AppTheme.border, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private func aggregateRow(_ aggregate: ShoppingAggregate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                checkbox(isChecked: aggregate.isChecked) { toggleChecked(aggregate) }
                VStack(alignment: .leading, spacing: 1) {
                    Text(itemLabel(aggregate))
                        .font(.system(size: 15))
                        .foregroundStyle(aggregate.isChecked ? AppTheme.textSecondary : AppTheme.textPrimary)
                        .strikethrough(aggregate.isChecked)
                    if aggregate.lines.count == 1, let recipeName = aggregate.lines.first?.recipe?.name {
                        Text(recipeName)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
                if aggregate.lines.count > 1 {
                    Button {
                        toggleExpanded(aggregate)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                            .rotationEffect(.degrees(expandedIDs.contains(aggregate.id) ? 180 : 0))
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)

            if aggregate.lines.count > 1, expandedIDs.contains(aggregate.id) {
                VStack(spacing: 0) {
                    ForEach(aggregate.lines) { line in
                        HStack(spacing: 8) {
                            Text("\(quantityLabel(line)) — \(line.recipe?.name ?? "Recette supprimée")")
                                .font(.system(size: 13))
                                .foregroundStyle(AppTheme.textSecondary)
                            Spacer()
                            Button {
                                removeLine(line)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .frame(width: 22, height: 22)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                    }
                }
                .padding(.leading, 30)
                .background(AppTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.vertical, 4)
            }
        }
        .listRowSeparatorTint(AppTheme.border)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                removeAggregate(aggregate)
            } label: {
                Label("Retirer", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    @ViewBuilder
    private func lineRow(_ line: RecipeIngredient) -> some View {
        HStack(spacing: 10) {
            checkbox(isChecked: line.isCheckedInShoppingList) {
                line.isCheckedInShoppingList.toggle()
                try? modelContext.save()
            }
            Text("\(line.ingredient?.name ?? "Ingrédient supprimé") — \(quantityLabel(line))")
                .font(.system(size: 15))
                .foregroundStyle(line.isCheckedInShoppingList ? AppTheme.textSecondary : AppTheme.textPrimary)
                .strikethrough(line.isCheckedInShoppingList)
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowSeparatorTint(AppTheme.border)
        .listRowBackground(Color.clear)
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                removeLine(line)
            } label: {
                Label("Retirer", systemImage: "trash")
            }
            .tint(.red)
        }
    }

    private func checkbox(isChecked: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isChecked {
                RoundedRectangle(cornerRadius: 5)
                    .fill(AppTheme.accent)
                    .frame(width: 20, height: 20)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(AppTheme.border, lineWidth: 1.5)
                    .frame(width: 20, height: 20)
            }
        }
        .buttonStyle(.plain)
        .padding(.top, 1)
    }

    private func itemLabel(_ aggregate: ShoppingAggregate) -> String {
        "\(aggregate.ingredient.name) — \(aggregate.totalQuantity.formatted(.number.precision(.fractionLength(0)))) \(aggregate.unit?.shortLabel ?? "")"
    }

    private func quantityLabel(_ line: RecipeIngredient) -> String {
        "\(line.quantity.formatted(.number.precision(.fractionLength(0)))) \(line.unit?.shortLabel ?? "")"
    }

    private func toggleChecked(_ aggregate: ShoppingAggregate) {
        let newValue = !aggregate.isChecked
        for line in aggregate.lines {
            line.isCheckedInShoppingList = newValue
        }
        try? modelContext.save()
    }

    private func toggleExpanded(_ aggregate: ShoppingAggregate) {
        if expandedIDs.contains(aggregate.id) {
            expandedIDs.remove(aggregate.id)
        } else {
            expandedIDs.insert(aggregate.id)
        }
    }

    private func removeAggregate(_ aggregate: ShoppingAggregate) {
        for line in aggregate.lines {
            line.isInShoppingList = false
            line.isCheckedInShoppingList = false
        }
        try? modelContext.save()
    }

    private func removeLine(_ line: RecipeIngredient) {
        line.isInShoppingList = false
        line.isCheckedInShoppingList = false
        try? modelContext.save()
    }

    private func clearAll() {
        let snapshot = items.map { ($0, $0.isInShoppingList, $0.isCheckedInShoppingList) }
        for line in items {
            line.isInShoppingList = false
            line.isCheckedInShoppingList = false
        }
        try? modelContext.save()

        let context = modelContext
        clearUndoAction = {
            for (line, wasInList, wasChecked) in snapshot {
                line.isInShoppingList = wasInList
                line.isCheckedInShoppingList = wasChecked
            }
            try? context.save()
        }
        showingClearToast = true
    }
}

#Preview {
    ShoppingListView()
        .modelContainer(for: Recipe.self, inMemory: true)
}
