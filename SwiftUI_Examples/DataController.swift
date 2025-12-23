//
//  DataController.swift
//  MobileOrg
//
//  Modern Core Data stack with Swift concurrency
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.

import CoreData
import SwiftUI

/// Manages Core Data stack and provides data access
@MainActor
class DataController: ObservableObject {
    
    // MARK: - Properties
    
    /// The persistent container for the Core Data stack
    let container: NSPersistentContainer
    
    /// Published to trigger UI updates when data changes
    @Published var hasUnsyncedChanges: Bool = false
    
    /// Main view context for UI operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }
    
    // MARK: - Initialization
    
    /// Initialize the Core Data stack
    /// - Parameter inMemory: If true, uses an in-memory store (useful for testing)
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MobileOrg")
        
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { [weak self] description, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
            
            // Configure view context
            self?.configureViewContext()
        }
    }
    
    /// Configure the view context for optimal performance
    private func configureViewContext() {
        // Automatically merge changes from parent context
        viewContext.automaticallyMergesChangesFromParent = true
        
        // Merge policy for conflicts
        viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        // Observe context changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(contextDidSave),
            name: .NSManagedObjectContextDidSave,
            object: viewContext
        )
    }
    
    // MARK: - Core Data Operations
    
    /// Save changes to the view context
    func saveContext() async throws {
        guard viewContext.hasChanges else { return }
        
        try await viewContext.perform {
            try self.viewContext.save()
        }
    }
    
    /// Create a background context for long-running operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }
    
    /// Perform a background task
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) async throws -> T) async throws -> T {
        let context = newBackgroundContext()
        return try await context.perform {
            let result = try await block(context)
            if context.hasChanges {
                try context.save()
            }
            return result
        }
    }
    
    // MARK: - Data Refresh
    
    /// Refresh data from persistent store
    func refreshData() async {
        await viewContext.perform {
            self.viewContext.refreshAllObjects()
        }
        
        // Check for unsynchronized changes
        await checkForUnsyncedChanges()
    }
    
    /// Check if there are unsynchronized changes
    private func checkForUnsyncedChanges() async {
        let request = NSFetchRequest<NSManagedObject>(entityName: "LocalEditAction")
        
        do {
            let count = try await viewContext.perform {
                try self.viewContext.count(for: request)
            }
            hasUnsyncedChanges = count > 0
        } catch {
            print("Error checking for unsynced changes: \(error)")
        }
    }
    
    // MARK: - Notifications
    
    @objc private func contextDidSave(_ notification: Notification) {
        Task {
            await checkForUnsyncedChanges()
        }
    }
    
    // MARK: - Node Operations
    
    /// Fetch root nodes
    func fetchRootNodes() async throws -> [Node] {
        let request = Node.fetchRequest()
        request.predicate = NSPredicate(format: "parent == nil")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Node.sequenceIndex, ascending: true)]
        
        return try await viewContext.perform {
            try self.viewContext.fetch(request)
        }
    }
    
    /// Fetch child nodes for a parent
    func fetchChildNodes(for parent: Node) async throws -> [Node] {
        let request = Node.fetchRequest()
        request.predicate = NSPredicate(format: "parent == %@", parent)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Node.sequenceIndex, ascending: true)]
        
        return try await viewContext.perform {
            try self.viewContext.fetch(request)
        }
    }
    
    /// Search nodes by text
    func searchNodes(query: String) async throws -> [Node] {
        let request = Node.fetchRequest()
        request.predicate = NSPredicate(format: "heading CONTAINS[cd] %@ OR body CONTAINS[cd] %@", query, query)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Node.heading, ascending: true)]
        request.fetchLimit = 100
        
        return try await viewContext.perform {
            try self.viewContext.fetch(request)
        }
    }
    
    /// Create a new node
    func createNode(heading: String, body: String? = nil, parent: Node? = nil) async throws -> Node {
        try await viewContext.perform {
            let node = Node(context: self.viewContext)
            node.nodeId = UUID().uuidString
            node.heading = heading
            node.body = body
            node.parent = parent
            node.createdAt = Date()
            
            if let parent = parent {
                // Set sequence index to be last child
                let siblings = parent.children?.allObjects as? [Node] ?? []
                node.sequenceIndex = Int16(siblings.count)
            }
            
            try self.viewContext.save()
            return node
        }
    }
    
    /// Delete a node
    func deleteNode(_ node: Node) async throws {
        try await viewContext.perform {
            self.viewContext.delete(node)
            try self.viewContext.save()
        }
    }
    
    // MARK: - Note Operations
    
    /// Fetch all notes
    func fetchNotes() async throws -> [Note] {
        let request = Note.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
        
        return try await viewContext.perform {
            try self.viewContext.fetch(request)
        }
    }
    
    /// Create a new note
    func createNote(text: String) async throws -> Note {
        try await viewContext.perform {
            let note = Note(context: self.viewContext)
            note.noteId = UUID().uuidString
            note.text = text
            note.createdAt = Date()
            note.locallyModified = true
            
            try self.viewContext.save()
            return note
        }
    }
    
    /// Delete a note
    func deleteNote(_ note: Note) async throws {
        try await viewContext.perform {
            self.viewContext.delete(note)
            try self.viewContext.save()
        }
    }
    
    // MARK: - Bulk Operations
    
    /// Delete all data (for testing or reset)
    func deleteAllData() async throws {
        let entities = ["Node", "Note", "FileChecksum", "LocalEditAction"]
        
        try await performBackgroundTask { context in
            for entityName in entities {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                try context.execute(deleteRequest)
            }
        }
        
        await refreshData()
    }
}

// MARK: - Preview Helper

extension DataController {
    /// Create a data controller with sample data for previews
    static var preview: DataController {
        let controller = DataController(inMemory: true)
        
        Task { @MainActor in
            // Create sample data
            do {
                let root = try await controller.createNode(heading: "Sample Project", body: "This is a sample project")
                _ = try await controller.createNode(heading: "Task 1", body: "TODO First task", parent: root)
                _ = try await controller.createNode(heading: "Task 2", body: "DONE Completed task", parent: root)
                
                _ = try await controller.createNote(text: "Sample note for testing")
            } catch {
                print("Error creating preview data: \(error)")
            }
        }
        
        return controller
    }
}

// MARK: - Core Data Extensions

extension Node {
    /// Convenience property for accessing children as an array
    var childrenArray: [Node] {
        let set = children as? Set<Node> ?? []
        return set.sorted { $0.sequenceIndex < $1.sequenceIndex }
    }
    
    /// Check if node has children
    var hasChildren: Bool {
        (children?.count ?? 0) > 0
    }
}

extension Note {
    /// Check if note has been synchronized
    var isSynced: Bool {
        !locallyModified
    }
}
