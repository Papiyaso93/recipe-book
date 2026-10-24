//
//  EmptyStateView.swift
//  Gohan
//

import SwiftUI

/// Remplace `ContentUnavailableView` (natif) partout dans l'app : son texte suit les couleurs
/// système adaptatives (blanc en dark mode) alors que `AppTheme.background`/`surface` restent
/// volontairement fixes (pas de variante sombre) — texte blanc sur fond clair = illisible en
/// dark mode. En reprenant les couleurs fixes d'`AppTheme`, ce composant reste lisible quel que
/// soit le mode d'apparence du téléphone.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var description: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(AppTheme.accent.opacity(0.12)).frame(width: 72, height: 72)
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                if let description {
                    Text(description)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(AppTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
