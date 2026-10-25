//
//  SettingsView.swift
//  Gohan
//

import SwiftUI

struct SettingsView: View {
    static let anthropicAPIKeyStorageKey = "anthropicAPIKey"

    @State private var apiKeyInput = ""
    @State private var isSaved = false
    @State private var isEditing = false
    @State private var isValidating = false
    @State private var errorMessage: String?
    @State private var showingSavedToast = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                apiKeyCard
                    .padding(16)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // Le clavier du champ clé API n'a pas de bouton "Terminé" (SecureField/TextField
            // plein écran, pas de ScrollView) — sans ce geste, rien ne permet de le fermer.
            .onTapGesture { hideKeyboard() }
            .background(AppTheme.background)
            .navigationTitle("Réglages")
            .task { load() }
            .successToast("Clé enregistrée", isPresented: $showingSavedToast)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // `ScrollView` + titre "large" ne cohabitent pas sur cet écran : le titre disparaît
    // complètement dès qu'un `ScrollView` est présent, quel que soit le contenu à l'intérieur
    // (bug SwiftUI constaté empiriquement, voir [[project-gohan-overview]]). Un simple VStack
    // suffit tant qu'il n'y a qu'une carte ; si une 2e section est ajoutée plus tard et que ça
    // déborde de l'écran, retester avec un autre conteneur scrollable (`List` plutôt que
    // `ScrollView`, par exemple) avant de reproduire ce bug.
    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Import par IA")
            Text("Nécessaire pour importer une recette depuis une photo.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textSecondary)

            if isSaved && !isEditing {
                connectedRow
            } else {
                editingFields
            }
        }
        .padding(AppTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.surface)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.cardRadius).stroke(AppTheme.border, lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    /// État "verrouillé" une fois une clé enregistrée — pas de champ ni de bouton "Enregistrer"
    /// qui ne servent plus à rien tant que rien n'a changé (pattern des clés API sur la plupart
    /// des dashboards : Stripe, OpenAI...). "Modifier" rouvre l'édition.
    private var connectedRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(AppTheme.accent.opacity(0.15)).frame(width: 30, height: 30)
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Clé API Anthropic connectée")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(maskedKeyPreview)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Button {
                    isEditing = true
                    errorMessage = nil
                } label: {
                    Text("Modifier")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))

            Button {
                clear()
            } label: {
                Text("Déconnecter")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
        }
    }

    private var editingFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Clé API Anthropic")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                APIKeyField(text: $apiKeyInput)
            }

            if let errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
                .font(.system(size: 12, weight: .medium))
            }

            Button {
                Task { await save() }
            } label: {
                HStack(spacing: 8) {
                    if isValidating {
                        ProgressView().tint(.white)
                    }
                    Text(isValidating ? "Vérification..." : "Enregistrer")
                }
            }
            .primaryButtonStyle()
            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
            .padding(.top, 4)

            if isSaved {
                Button {
                    isEditing = false
                    errorMessage = nil
                } label: {
                    Text("Annuler")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .disabled(isValidating)
            }
        }
    }

    /// Affiche le début et les 4 derniers caractères, masque le reste — permet de reconnaître
    /// sa clé sans jamais la ré-exposer en clair une fois enregistrée.
    private var maskedKeyPreview: String {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 10 else { return "••••••••" }
        let prefix = trimmed.prefix(7)
        let suffix = trimmed.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }

    private func load() {
        if let stored = KeychainStore.load(forKey: Self.anthropicAPIKeyStorageKey), !stored.isEmpty {
            apiKeyInput = stored
            isSaved = true
        }
    }

    /// N'enregistre qu'une fois la clé confirmée valide par un appel test à l'API Anthropic —
    /// avant ça, un texte quelconque était accepté tel quel, sans aucun moyen de savoir s'il
    /// s'agissait réellement d'une clé fonctionnelle.
    private func save() async {
        let trimmed = apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        errorMessage = nil
        isValidating = true
        let result = await AnthropicAPIKeyValidator.validate(trimmed)
        isValidating = false

        switch result {
        case .success:
            KeychainStore.save(trimmed, forKey: Self.anthropicAPIKeyStorageKey)
            apiKeyInput = trimmed
            isSaved = true
            isEditing = false
            showingSavedToast = true
        case .failure(let error):
            errorMessage = error.errorDescription
        }
    }

    private func clear() {
        KeychainStore.delete(forKey: Self.anthropicAPIKeyStorageKey)
        apiKeyInput = ""
        isSaved = false
        isEditing = false
    }
}

private struct APIKeyField: View {
    @Binding var text: String
    @State private var isRevealed = false
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isRevealed {
                    TextField("sk-ant-...", text: $text)
                } else {
                    SecureField("sk-ant-...", text: $text)
                }
            }
            .font(.system(size: 15))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .foregroundStyle(AppTheme.textPrimary)
            .focused($isFocused)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(AppTheme.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(AppTheme.background)
        .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonRadius).stroke(AppTheme.border, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
    }
}

#Preview {
    SettingsView()
}
