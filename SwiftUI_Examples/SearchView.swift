//
//  SearchView.swift
//  MobileOrg
//
//  SwiftUI Search view placeholder
//  This file provides a placeholder for the search feature
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.

import SwiftUI

// MARK: - Search View (Placeholder)

/// Placeholder for the search view - to be fully implemented
/// This should replace SearchController.m from the original codebase
struct SearchView: View {
    @EnvironmentObject private var dataController: DataController
    
    @State private var searchText = ""
    @State private var searchResults: [Node] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            List {
                if searchResults.isEmpty && !searchText.isEmpty && !isSearching {
                    ContentUnavailableView.search
                } else {
                    ForEach(searchResults) { node in
                        NavigationLink {
                            // TODO: Navigate to node detail
                            Text("Node: \(node.heading ?? "Untitled")")
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(node.heading ?? "Untitled")
                                    .font(.headline)
                                
                                if let body = node.body, !body.isEmpty {
                                    Text(body)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                
                                if let todoState = node.todoState, !todoState.isEmpty {
                                    Text(todoState)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.2))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search nodes...")
            .onChange(of: searchText) { _, newValue in
                Task {
                    await performSearch(query: newValue)
                }
            }
            .overlay {
                if isSearching {
                    ProgressView()
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        defer { isSearching = false }
        
        do {
            // Add small delay to debounce rapid typing
            try await Task.sleep(for: .milliseconds(300))
            
            // Check if search text hasn't changed
            guard query == searchText else { return }
            
            searchResults = try await dataController.searchNodes(query: query)
        } catch {
            print("Error searching: \(error)")
            searchResults = []
        }
    }
}

// MARK: - Preview

#Preview {
    SearchView()
        .environmentObject(DataController.preview)
}
