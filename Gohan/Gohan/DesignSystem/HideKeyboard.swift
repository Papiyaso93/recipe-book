//
//  HideKeyboard.swift
//  Gohan
//

import UIKit

/// Les claviers numériques (.numberPad/.decimalPad) n'ont pas de touche "Entrée" — seul moyen
/// fiable de les fermer depuis n'importe quel champ focalisé, sans dépendre de son FocusState.
func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
