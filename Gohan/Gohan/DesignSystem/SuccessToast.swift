//
//  SuccessToast.swift
//  Gohan
//

import SwiftUI

/// Confirmation non bloquante, disparaît seule — une réussite n'a pas besoin d'un tap pour être
/// fermée, contrairement à une alerte qui demande une action.
struct SuccessToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
            Text(message)
                .font(.system(size: 14, weight: .medium))
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
    func successToast(_ message: String, isPresented: Binding<Bool>, duration: Double = 2) -> some View {
        overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                SuccessToast(message: message)
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
