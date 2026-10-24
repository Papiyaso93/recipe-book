//
//  CookingModeView.swift
//  Gohan
//

import SwiftUI
import SwiftData

private struct ChecklistRow: Identifiable {
    let id: PersistentIdentifier
    let label: String
}

private enum CookingPhase: Equatable {
    case beginning
    case step(Int)
    case finished
}

struct CookingModeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phase: CookingPhase = .beginning
    @State private var showingChecklist = false
    @State private var transitionEdge: Edge = .trailing
    @State private var checkedIngredients: Set<PersistentIdentifier> = []
    @State private var checkedMaterials: Set<PersistentIdentifier> = []
    @State private var isIngredientsCollapsed = false
    @State private var isMaterialsCollapsed = false

    private let ingredientRows: [ChecklistRow]
    private let materialRows: [ChecklistRow]
    private let steps: [String]
    private let hasIngredients: Bool
    private let hasMaterials: Bool
    private let hasPrep: Bool
    private let totalTimeMinutes: Int

    init(recipe: Recipe) {
        totalTimeMinutes = recipe.totalTimeMinutes

        let sortedIngredients = recipe.ingredients.sorted {
            ($0.ingredient?.name ?? "") < ($1.ingredient?.name ?? "")
        }
        ingredientRows = sortedIngredients.map { line in
            let quantity = line.quantity.formatted(.number.precision(.fractionLength(0)))
            let unit = line.unit?.shortLabel ?? ""
            return ChecklistRow(
                id: line.persistentModelID,
                label: "\(line.ingredient?.name ?? "Ingrédient supprimé") — \(quantity) \(unit)"
            )
        }

        let sortedMaterials = recipe.materials.sorted { $0.name < $1.name }
        materialRows = sortedMaterials.map { ChecklistRow(id: $0.persistentModelID, label: $0.name) }

        steps = recipe.steps
        hasIngredients = !sortedIngredients.isEmpty
        hasMaterials = !sortedMaterials.isEmpty
        hasPrep = hasIngredients || hasMaterials
    }

    /// Donne un vrai aperçu utile (combien de temps prévoir) plutôt que de répéter des infos déjà
    /// visibles sur la fiche recette — sinon cette page n'a pas lieu d'être. Simple somme
    /// préparation + cuisson, volontairement pas plus précis (le détail est déjà sur la fiche) :
    /// une phrase d'ambiance n'a pas à être une source de vérité.
    private var introSubtitle: String {
        guard totalTimeMinutes > 0 else { return "Prêt ?" }
        return "\(totalTimeMinutes) minutes top chrono. Prêt ?"
    }

    private var totalSegments: Int {
        max(steps.count, 1)
    }

    private var currentSegmentIndex: Int {
        switch phase {
        case .beginning:
            return 0
        case .step(let index):
            return index
        case .finished:
            return totalSegments - 1
        }
    }

    /// Volontairement constant pour tous les `.step` (pas un id par index) : ça garde l'écran
    /// d'étape comme une seule identité de vue stable à travers la navigation, pour que les
    /// boutons Précédent/Suivant restent fixes — seul le contenu au centre (avec son propre id)
    /// doit glisser d'une étape à l'autre, voir `stepView`.
    private var phaseID: String {
        switch phase {
        case .beginning: return "beginning"
        case .step: return "step"
        case .finished: return "finished"
        }
    }

    private func goForward(to newPhase: CookingPhase) {
        transitionEdge = .trailing
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            phase = newPhase
        }
    }

    private func goBackward(to newPhase: CookingPhase) {
        transitionEdge = .leading
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            phase = newPhase
        }
    }

    private var oppositeTransitionEdge: Edge {
        switch transitionEdge {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if case .step = phase {
                header
                progressBar
            }

            Group {
                switch phase {
                case .beginning:
                    beginningView
                case .step(let index):
                    stepView(index: index)
                case .finished:
                    finishedView
                }
            }
            .id(phaseID)
            .transition(.asymmetric(
                insertion: .move(edge: transitionEdge).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
                removal: .move(edge: oppositeTransitionEdge).combined(with: .opacity).combined(with: .scale(scale: 0.96))
            ))
        }
        .background(AppTheme.background)
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(AppTheme.surface))
                    .overlay(Circle().stroke(AppTheme.border, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(headerLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 10)
    }

    private var headerLabel: String {
        switch phase {
        case .beginning, .finished:
            return ""
        case .step(let index):
            return "Étape \(index + 1) sur \(max(steps.count, 1))"
        }
    }

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(0..<totalSegments, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentSegmentIndex ? AppTheme.accent : AppTheme.border)
                    .frame(height: 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Beginning (intro + checklist morph into one screen)

    private var totalCheckedCount: Int {
        checkedIngredients.count + checkedMaterials.count
    }

    private var totalRowCount: Int {
        ingredientRows.count + materialRows.count
    }

    private func checkCompletion() {
        guard totalCheckedCount == totalRowCount else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            goForward(to: .step(0))
        }
    }

    private var beginningView: some View {
        VStack(spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(AppTheme.surface))
                        .overlay(Circle().stroke(AppTheme.border, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 20)

            Group {
                if showingChecklist {
                    checklistContent
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    introContent
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Button {
                if showingChecklist {
                    goForward(to: .step(0))
                } else if hasPrep {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        showingChecklist = true
                    }
                } else {
                    goForward(to: .step(0))
                }
            } label: {
                Text(showingChecklist ? "Commencer à cuisiner" : "C'est parti")
                    .contentTransition(.opacity)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    private var introContent: some View {
        VStack(spacing: 14) {
            Text("👨‍🍳")
                .font(.system(size: 52))
            Text("À vos fourneaux !")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .multilineTextAlignment(.center)
            Text(introSubtitle)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    private var checklistContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Tu as tout sous la main ?")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .padding(.horizontal, 16)
                .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if hasIngredients {
                        checklistSection(
                            title: "Ingrédients",
                            rows: ingredientRows,
                            checked: $checkedIngredients,
                            isCollapsed: $isIngredientsCollapsed
                        )
                    }
                    if hasMaterials {
                        checklistSection(
                            title: "Matériel",
                            rows: materialRows,
                            checked: $checkedMaterials,
                            isCollapsed: $isMaterialsCollapsed
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func checklistSection(
        title: String,
        rows: [ChecklistRow],
        checked: Binding<Set<PersistentIdentifier>>,
        isCollapsed: Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isCollapsed.wrappedValue.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .rotationEffect(.degrees(isCollapsed.wrappedValue ? -90 : 0))
                        SectionLabel(text: title)
                        Text("· \(checked.wrappedValue.count) sur \(rows.count)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
                if !isCollapsed.wrappedValue {
                    Button {
                        checked.wrappedValue = Set(rows.map(\.id))
                        checkCompletion()
                    } label: {
                        Text("Tout cocher")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }
            }
            if !isCollapsed.wrappedValue {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    let isChecked = checked.wrappedValue.contains(row.id)
                    Button {
                        if isChecked {
                            checked.wrappedValue.remove(row.id)
                        } else {
                            checked.wrappedValue.insert(row.id)
                            checkCompletion()
                        }
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(isChecked ? AppTheme.accent : Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isChecked ? Color.clear : AppTheme.border, lineWidth: 1.5)
                                )
                                .frame(width: 22, height: 22)
                                .overlay {
                                    if isChecked {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            Text(row.label)
                                .font(.system(size: 16))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(AppTheme.border).frame(height: 0.5)
                    }
                }
            }
            .transition(.opacity)
            }
        }
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack {
            HStack {
                Spacer()
            }
            .padding(.top, 16)

            Spacer()

            FinishedCelebration()

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Fermer")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
            }
            .buttonStyle(.plain)
            .padding(16)
        }
    }

    // MARK: - Steps

    private func stepView(index: Int) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 24) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 56, height: 56)
                    Text("\(index + 1)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
                if steps.indices.contains(index) {
                    Text(steps[index])
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            .padding(.horizontal, 28)
            .id(index)
            .transition(.asymmetric(
                insertion: .move(edge: transitionEdge).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
                removal: .move(edge: oppositeTransitionEdge).combined(with: .opacity).combined(with: .scale(scale: 0.96))
            ))
            Spacer()

            HStack(spacing: 10) {
                Button {
                    goToPreviousStep(from: index)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Précédent")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.surface)
                    .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonRadius).stroke(AppTheme.border, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                }
                .buttonStyle(.plain)

                Button {
                    if index + 1 < steps.count {
                        goForward(to: .step(index + 1))
                    } else {
                        goForward(to: .finished)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text(index + 1 < steps.count ? "Suivant" : "Terminer")
                        if index + 1 < steps.count {
                            Image(systemName: "chevron.right")
                        }
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(AppTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30)
                .onEnded { value in
                    if value.translation.width < -40, index + 1 < steps.count {
                        goForward(to: .step(index + 1))
                    } else if value.translation.width > 40 {
                        goToPreviousStep(from: index)
                    }
                }
        )
    }

    private func goToPreviousStep(from index: Int) {
        if index > 0 {
            goBackward(to: .step(index - 1))
        } else {
            showingChecklist = true
            goBackward(to: .beginning)
        }
    }
}

/// Emoji en rebond (spring, léger dépassement) suivi du titre en fondu décalé — deux temps
/// plutôt qu'une apparition d'un coup, pour que ça se sente comme un petit évènement.
private struct FinishedCelebration: View {
    @State private var emojiScale: CGFloat = 0.3
    @State private var showingHeadline = false

    var body: some View {
        VStack(spacing: 14) {
            Text("🍽️")
                .font(.system(size: 52))
                .scaleEffect(emojiScale)
            Text("Bon appétit !")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
                .opacity(showingHeadline ? 1 : 0)
                .offset(y: showingHeadline ? 0 : 8)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) {
                emojiScale = 1
            }
            withAnimation(.easeOut(duration: 0.35).delay(0.2)) {
                showingHeadline = true
            }
        }
    }
}
