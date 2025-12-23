//
//  NoteListView.swift
//  MobileOrg
//
//  SwiftUI Note/Capture view placeholder
//  This file provides a placeholder for the capture/notes feature
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.

import SwiftUI

// MARK: - Note List View (Placeholder)

/// Placeholder for the note list view - to be fully implemented
/// This should replace NoteListController.m from the original codebase
struct NoteListView: View {
    @EnvironmentObject private var dataController: DataController
    
    @State private var notes: [Note] = []
    @State private var showingNewNote = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(notes) { note in
                    NavigationLink {
                        // TODO: Implement note detail view
                        Text("Note details")
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            if let text = note.text {
                                Text(text)
                                    .lineLimit(2)
                            }
                            if let date = note.createdAt {
                                Text(date.formatted())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Capture")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewNote = true
                    } label: {
                        Label("New Note", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewNote) {
                NewNoteView()
            }
            .task {
                await loadNotes()
            }
        }
    }
    
    private func loadNotes() async {
        do {
            notes = try await dataController.fetchNotes()
        } catch {
            print("Error loading notes: \(error)")
        }
    }
}

// MARK: - New Note View (Placeholder)

struct NewNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataController: DataController
    
    @State private var noteText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNote()
                    }
                    .disabled(noteText.isEmpty)
                }
            }
        }
    }
    
    private func saveNote() {
        Task {
            do {
                _ = try await dataController.createNote(text: noteText)
                dismiss()
            } catch {
                print("Error saving note: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NoteListView()
        .environmentObject(DataController.preview)
}
