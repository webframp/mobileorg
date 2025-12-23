//
//  OutlineView.swift
//  MobileOrg
//
//  Modern SwiftUI outline view implementation
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.

import SwiftUI
import CoreData

// MARK: - Outline View

/// Main outline view showing hierarchical nodes
struct OutlineView: View {
    @EnvironmentObject private var dataController: DataController
    @EnvironmentObject private var syncManager: SyncManager
    
    @StateObject private var viewModel: OutlineViewModel
    
    @State private var searchText = ""
    @State private var showingNewNodeSheet = false
    
    init() {
        _viewModel = StateObject(wrappedValue: OutlineViewModel())
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.nodes.isEmpty {
                    emptyView
                } else {
                    nodeList
                }
            }
            .navigationTitle("Outline")
            .toolbar {
                toolbarContent
            }
            .searchable(text: $searchText, prompt: "Search nodes")
            .refreshable {
                await viewModel.refresh()
            }
            .sheet(isPresented: $showingNewNodeSheet) {
                NewNodeView(parent: nil)
            }
            .task {
                await viewModel.loadNodes()
            }
            .onChange(of: searchText) { _, newValue in
                Task {
                    await viewModel.search(query: newValue)
                }
            }
        }
    }
    
    // MARK: - Views
    
    private var nodeList: some View {
        List {
            ForEach(filteredNodes) { node in
                NodeRowView(node: node, level: 0)
            }
            .onDelete(perform: deleteNodes)
        }
        .listStyle(.insetGrouped)
    }
    
    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("No Nodes")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap + to create a new node or sync to download from your org files")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button {
                Task {
                    await syncManager.sync()
                }
            } label: {
                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button {
                Task {
                    await syncManager.sync()
                }
            } label: {
                Label("Sync", systemImage: "arrow.triangle.2.circlepath")
            }
            .disabled(syncManager.isSyncing)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showingNewNodeSheet = true
            } label: {
                Label("New Node", systemImage: "plus")
            }
        }
    }
    
    private var filteredNodes: [Node] {
        if searchText.isEmpty {
            return viewModel.nodes
        } else {
            return viewModel.searchResults
        }
    }
    
    private func deleteNodes(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let node = filteredNodes[index]
                await viewModel.deleteNode(node)
            }
        }
    }
}

// MARK: - Node Row View

struct NodeRowView: View {
    @ObservedObject var node: Node
    let level: Int
    
    @State private var isExpanded = false
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Main row
            HStack(spacing: 12) {
                // Indentation
                if level > 0 {
                    Color.clear
                        .frame(width: CGFloat(level * 20))
                }
                
                // Expand/collapse button
                if node.hasChildren {
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                // Node content
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // TODO indicator
                        if let todoState = node.todoState, !todoState.isEmpty {
                            Text(todoState)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(todoStateColor(todoState))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        
                        // Heading
                        Text(node.heading ?? "Untitled")
                            .font(.body)
                            .fontWeight(level == 0 ? .semibold : .regular)
                        
                        Spacer()
                        
                        // Priority
                        if let priority = node.priority, !priority.isEmpty {
                            Text(priority)
                                .font(.caption2)
                                .padding(4)
                                .background(.red.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    
                    // Tags
                    if let tags = node.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 4) {
                                ForEach(tags.components(separatedBy: ":").filter { !$0.isEmpty }, id: \.self) { tag in
                                    Text(":\(tag):")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.blue.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    
                    // Body preview
                    if let body = node.body, !body.isEmpty {
                        Text(body)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // Navigation chevron
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingDetail = true
            }
            
            // Child nodes
            if isExpanded {
                ForEach(node.childrenArray) { child in
                    NodeRowView(node: child, level: level + 1)
                }
            }
        }
        .navigationDestination(isPresented: $showingDetail) {
            NodeDetailView(node: node)
        }
    }
    
    private func todoStateColor(_ state: String) -> Color {
        switch state.uppercased() {
        case "TODO": return .orange
        case "DONE": return .green
        case "NEXT": return .blue
        case "WAITING": return .purple
        case "CANCELLED": return .gray
        default: return .secondary
        }
    }
}

// MARK: - Node Detail View

struct NodeDetailView: View {
    @ObservedObject var node: Node
    @EnvironmentObject private var dataController: DataController
    
    @State private var isEditing = false
    @State private var showingActionMenu = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let todoState = node.todoState {
                            Text(todoState)
                                .font(.caption)
                                .fontWeight(.bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        
                        if let priority = node.priority {
                            Text("[\(priority)]")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                        }
                        
                        Spacer()
                    }
                    
                    Text(node.heading ?? "Untitled")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    if let tags = node.tags {
                        Text(tags)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Body
                if let body = node.body, !body.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Content")
                            .font(.headline)
                        
                        Text(body)
                            .font(.body)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                // Metadata
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                    
                    if let createdAt = node.createdAt {
                        DetailRow(label: "Created", value: createdAt.formatted())
                    }
                    
                    if node.hasChildren {
                        DetailRow(label: "Child Nodes", value: "\(node.childrenArray.count)")
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Child nodes
                if node.hasChildren {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Child Nodes")
                            .font(.headline)
                        
                        ForEach(node.childrenArray) { child in
                            NavigationLink {
                                NodeDetailView(node: child)
                            } label: {
                                HStack {
                                    Text(child.heading ?? "Untitled")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.vertical, 8)
                            
                            if child != node.childrenArray.last {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingActionMenu = true
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Actions", isPresented: $showingActionMenu) {
            Button("Edit") {
                isEditing = true
            }
            
            Button("Change TODO State") {
                // TODO: Implement
            }
            
            Button("Add Child Node") {
                // TODO: Implement
            }
            
            Button("Delete", role: .destructive) {
                // TODO: Implement
            }
        }
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}

// MARK: - New Node View

struct NewNodeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var dataController: DataController
    
    let parent: Node?
    
    @State private var heading = ""
    @State private var body = ""
    @State private var todoState = ""
    @State private var priority = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Basic Info") {
                    TextField("Heading", text: $heading)
                    
                    Picker("TODO State", selection: $todoState) {
                        Text("None").tag("")
                        Text("TODO").tag("TODO")
                        Text("NEXT").tag("NEXT")
                        Text("DONE").tag("DONE")
                    }
                    
                    Picker("Priority", selection: $priority) {
                        Text("None").tag("")
                        Text("A").tag("A")
                        Text("B").tag("B")
                        Text("C").tag("C")
                    }
                }
                
                Section("Content") {
                    TextEditor(text: $body)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("New Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveNode()
                    }
                    .disabled(heading.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveNode() {
        isSaving = true
        
        Task {
            do {
                _ = try await dataController.createNode(
                    heading: heading,
                    body: body.isEmpty ? nil : body,
                    parent: parent
                )
                dismiss()
            } catch {
                print("Error saving node: \(error)")
                isSaving = false
            }
        }
    }
}

// MARK: - View Model

@MainActor
class OutlineViewModel: ObservableObject {
    @Published var nodes: [Node] = []
    @Published var searchResults: [Node] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func loadNodes() async {
        isLoading = true
        defer { isLoading = false }
        
        // TODO: Load from DataController
        // This is a placeholder
    }
    
    func refresh() async {
        await loadNodes()
    }
    
    func search(query: String) async {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        
        // TODO: Search using DataController
        searchResults = []
    }
    
    func deleteNode(_ node: Node) async {
        // TODO: Delete using DataController
    }
}

// MARK: - Preview

#Preview {
    OutlineView()
        .environmentObject(DataController.preview)
        .environmentObject(SyncManager())
}
