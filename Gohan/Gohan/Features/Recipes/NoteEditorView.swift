//
//  NoteEditorView.swift
//  Gohan
//

import SwiftUI
import SwiftData

struct NoteEditorView: View {
    let recipe: Recipe
    let note: Note?
    var onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(recipe: Recipe, note: Note? = nil, onSave: @escaping () -> Void) {
        self.recipe = recipe
        self.note = note
        self.onSave = onSave
        _text = State(initialValue: note?.text ?? "")
    }

    private var title: String {
        note == nil ? "Nouvelle note" : "Modifier la note"
    }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(8)
                .frame(height: 140)
                .background(AppTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 11)
                        .stroke(isFocused ? AppTheme.accent : AppTheme.border, lineWidth: isFocused ? 1 : 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 11))
                .padding(16)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(AppTheme.background)
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enregistrer") { save() }
                            .fontWeight(.semibold)
                            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .onAppear { isFocused = true }
        }
        .presentationDetents([.height(260)])
        .presentationDragIndicator(.visible)
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let note {
            note.text = trimmed
        } else {
            let newNote = Note(text: trimmed)
            newNote.recipe = recipe
            recipe.notes.append(newNote)
            modelContext.insert(newNote)
        }
        try? modelContext.save()
        onSave()
        dismiss()
    }
}
