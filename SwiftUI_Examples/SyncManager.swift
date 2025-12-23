//
//  SyncManager.swift
//  MobileOrg
//
//  Modern sync manager using async/await and Combine
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.

import Foundation
import Combine

/// Manages synchronization with remote storage (Dropbox, WebDAV)
@MainActor
class SyncManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Whether a sync operation is in progress
    @Published var isSyncing: Bool = false
    
    /// Current sync status message
    @Published var syncStatus: String = "Ready"
    
    /// Sync progress (0.0 to 1.0)
    @Published var syncProgress: Double? = nil
    
    /// Last successful sync date
    @Published var lastSyncDate: Date? = nil
    
    /// Last sync error
    @Published var lastSyncError: Error? = nil
    
    // MARK: - Dependencies
    
    private let dataController: DataController
    private let transferService: TransferService
    private let networkMonitor: NetworkMonitor
    
    // MARK: - Initialization
    
    init(dataController: DataController = DataController(),
         transferService: TransferService = TransferService(),
         networkMonitor: NetworkMonitor = NetworkMonitor()) {
        self.dataController = dataController
        self.transferService = transferService
        self.networkMonitor = networkMonitor
        
        // Load last sync date from UserDefaults
        self.lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
    }
    
    // MARK: - Public Methods
    
    /// Perform a full synchronization
    func sync() async {
        guard !isSyncing else {
            print("Sync already in progress")
            return
        }
        
        guard networkMonitor.isConnected else {
            lastSyncError = SyncError.noNetwork
            return
        }
        
        isSyncing = true
        syncProgress = 0.0
        lastSyncError = nil
        defer {
            isSyncing = false
            syncProgress = nil
        }
        
        do {
            // Step 1: Upload local changes
            updateStatus("Uploading local changes...")
            try await uploadLocalChanges()
            syncProgress = 0.3
            
            // Step 2: Download checksums
            updateStatus("Checking for updates...")
            let checksums = try await downloadChecksums()
            syncProgress = 0.4
            
            // Step 3: Download changed files
            updateStatus("Downloading files...")
            let files = try await downloadChangedFiles(checksums: checksums)
            syncProgress = 0.7
            
            // Step 4: Parse and save files
            updateStatus("Processing files...")
            try await parseAndSaveFiles(files)
            syncProgress = 0.9
            
            // Step 5: Cleanup
            updateStatus("Finishing up...")
            try await cleanup()
            syncProgress = 1.0
            
            // Success
            updateStatus("Sync complete")
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastSyncDate")
            
        } catch {
            lastSyncError = error
            updateStatus("Sync failed: \(error.localizedDescription)")
            print("Sync error: \(error)")
        }
    }
    
    /// Quick sync (only checks for updates, no upload)
    func quickSync() async {
        guard !isSyncing else { return }
        guard networkMonitor.isConnected else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            updateStatus("Checking for updates...")
            let checksums = try await downloadChecksums()
            
            // Check if any files have changed
            let hasChanges = try await checkForRemoteChanges(checksums: checksums)
            
            if hasChanges {
                updateStatus("Updates available")
            } else {
                updateStatus("Up to date")
            }
        } catch {
            lastSyncError = error
            print("Quick sync error: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateStatus(_ status: String) {
        syncStatus = status
        print("Sync: \(status)")
    }
    
    /// Upload local changes to remote storage
    private func uploadLocalChanges() async throws {
        // Fetch local edit actions
        let context = dataController.viewContext
        let request = NSFetchRequest<LocalEditAction>(entityName: "LocalEditAction")
        
        let actions = try await context.perform {
            try context.fetch(request)
        }
        
        guard !actions.isEmpty else {
            print("No local changes to upload")
            return
        }
        
        // Generate edits file content
        let editsContent = try generateEditsFile(from: actions)
        
        // Upload to remote
        try await transferService.uploadFile(
            filename: "mobileorg.org",
            content: editsContent.data(using: .utf8) ?? Data()
        )
        
        // Clear local edit actions after successful upload
        try await context.perform {
            for action in actions {
                context.delete(action)
            }
            try context.save()
        }
    }
    
    /// Download checksums file from remote
    private func downloadChecksums() async throws -> [String: String] {
        let data = try await transferService.downloadFile(filename: "checksums.dat")
        let content = String(data: data, encoding: .utf8) ?? ""
        return parseChecksumsFile(content)
    }
    
    /// Download files that have changed
    private func downloadChangedFiles(checksums: [String: String]) async throws -> [String: Data] {
        var files: [String: Data] = [:]
        
        // Get stored checksums
        let context = dataController.viewContext
        let request = NSFetchRequest<FileChecksum>(entityName: "FileChecksum")
        let storedChecksums = try await context.perform {
            try context.fetch(request)
        }
        
        let storedDict = Dictionary(
            storedChecksums.map { ($0.filename ?? "", $0.checksum ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
        
        // Download changed files
        for (filename, checksum) in checksums {
            if storedDict[filename] != checksum {
                print("Downloading \(filename)...")
                let data = try await transferService.downloadFile(filename: filename)
                files[filename] = data
            }
        }
        
        return files
    }
    
    /// Check if there are remote changes without downloading
    private func checkForRemoteChanges(checksums: [String: String]) async throws -> Bool {
        let context = dataController.viewContext
        let request = NSFetchRequest<FileChecksum>(entityName: "FileChecksum")
        let storedChecksums = try await context.perform {
            try context.fetch(request)
        }
        
        let storedDict = Dictionary(
            storedChecksums.map { ($0.filename ?? "", $0.checksum ?? "") },
            uniquingKeysWith: { first, _ in first }
        )
        
        // Check if any checksums differ
        for (filename, checksum) in checksums {
            if storedDict[filename] != checksum {
                return true
            }
        }
        
        return false
    }
    
    /// Parse and save downloaded files
    private func parseAndSaveFiles(_ files: [String: Data]) async throws {
        guard !files.isEmpty else { return }
        
        try await dataController.performBackgroundTask { context in
            for (filename, data) in files {
                guard let content = String(data: data, encoding: .utf8) else { continue }
                
                // Parse org file
                if filename.hasSuffix(".org") {
                    try await self.parseOrgFile(content, filename: filename, context: context)
                }
            }
        }
    }
    
    /// Parse an org-mode file
    private func parseOrgFile(_ content: String, filename: String, context: NSManagedObjectContext) async throws {
        // TODO: Implement org-mode parser
        // This would parse the org-mode syntax and create/update Node objects
        print("Parsing \(filename)...")
    }
    
    /// Cleanup after sync
    private func cleanup() async throws {
        // Refresh data in view context
        await dataController.refreshData()
    }
    
    // MARK: - Helper Methods
    
    /// Generate edits file content from local edit actions
    private func generateEditsFile(from actions: [LocalEditAction]) -> String {
        var content = ""
        
        for action in actions {
            // Format: * action-type node-id
            content += "* \(action.actionType ?? "edit") \(action.nodeId ?? "")\n"
            content += "  \(action.details ?? "")\n\n"
        }
        
        return content
    }
    
    /// Parse checksums file
    private func parseChecksumsFile(_ content: String) -> [String: String] {
        var checksums: [String: String] = [:]
        
        for line in content.components(separatedBy: .newlines) {
            let parts = line.components(separatedBy: .whitespaces)
            guard parts.count >= 2 else { continue }
            
            let checksum = parts[0]
            let filename = parts[1...].joined(separator: " ")
            checksums[filename] = checksum
        }
        
        return checksums
    }
}

// MARK: - Transfer Service

/// Protocol for transfer services (Dropbox, WebDAV)
protocol TransferServiceProtocol {
    func downloadFile(filename: String) async throws -> Data
    func uploadFile(filename: String, content: Data) async throws
}

/// Concrete transfer service implementation
class TransferService: TransferServiceProtocol {
    
    func downloadFile(filename: String) async throws -> Data {
        // TODO: Implement based on selected service (Dropbox/WebDAV)
        throw SyncError.notImplemented
    }
    
    func uploadFile(filename: String, content: Data) async throws {
        // TODO: Implement based on selected service (Dropbox/WebDAV)
        throw SyncError.notImplemented
    }
}

// MARK: - Network Monitor

/// Monitors network connectivity
class NetworkMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    
    // TODO: Implement using Network framework
    // import Network
    // private let monitor = NWPathMonitor()
}

// MARK: - Errors

enum SyncError: LocalizedError {
    case noNetwork
    case notImplemented
    case parseError(String)
    case uploadFailed(String)
    case downloadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noNetwork:
            return "No network connection available"
        case .notImplemented:
            return "Feature not yet implemented"
        case .parseError(let message):
            return "Parse error: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        case .downloadFailed(let message):
            return "Download failed: \(message)"
        }
    }
}
