//
//  SuccessToast.swift
//  Gohan
//

import SwiftUI

/// Confirmation non bloquante, disparaît seule — une réussite n'a pas besoin d'un tap pour être
/// fermée, contrairement à une alerte qui demande une action.
struct SuccessToast: View {
    let message: String
    var undo: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
            Text(message)
                .font(.system(size: 14, weight: .medium))
            if let undo {
                Button(action: undo) {
                    Text("Annuler")
                        .font(.system(size: 14, weight: .semibold))
                        .underline()
                }
                .buttonStyle(.plain)
                .padding(.leading, 2)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Capsule().fill(AppTheme.accentDark))
    }
}

extension View {
    /// Affiche un `SuccessToast` par-dessus la vue pendant `duration`, piloté par un `Binding<Bool>`
    /// que l'appelant repasse à `true` au moment opportun (ex: juste avant de fermer un formulaire).
    ///
    /// `undo`, quand fourni, ajoute un bouton "Annuler" dans le toast : l'action déjà effectuée
    /// (ex: une suppression) reste réversible tant que le toast est affiché, plutôt que de bloquer
    /// l'utilisateur derrière une bulle de confirmation avant même d'agir.
    func successToast(
        _ message: String,
        isPresented: Binding<Bool>,
        duration: Double = 2,
        undo: (() -> Void)? = nil
    ) -> some View {
        overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                SuccessToast(message: message, undo: undo.map { action in
                    {
                        action()
                        withAnimation { isPresented.wrappedValue = false }
                    }
                })
                .padding(.bottom, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    Task {
                        try? await Task.sleep(for: .seconds(duration))
                        withAnimation { isPresented.wrappedValue = false }
                    }
                }
            }
        }
        .animation(.default, value: isPresented.wrappedValue)
    }
}
