//
//  SettingsView.swift
//  MobileOrg
//
//  Modern SwiftUI settings view
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.

import SwiftUI

// MARK: - Settings View

/// Main settings view with form-based configuration
struct SettingsView: View {
    @StateObject private var settings = Settings.shared
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var dataController: DataController
    
    @State private var showingResetAlert = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationStack {
            Form {
                syncSection
                serverSection
                organizationSection
                appearanceSection
                advancedSection
                aboutSection
            }
            .navigationTitle("Settings")
        }
        .alert("Reset All Data?", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetAllData()
            }
        } message: {
            Text("This will delete all local data. This action cannot be undone.")
        }
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
    
    // MARK: - Sections
    
    private var syncSection: some View {
        Section {
            // Sync type picker
            Picker("Sync Service", selection: $settings.syncService) {
                Text("Dropbox").tag(SyncService.dropbox)
                Text("WebDAV").tag(SyncService.webdav)
            }
            
            // Last sync info
            if let lastSync = syncManager.lastSyncDate {
                LabeledContent("Last Sync", value: lastSync.formatted())
            } else {
                LabeledContent("Last Sync", value: "Never")
            }
            
            // Sync button
            Button {
                Task {
                    await syncManager.sync()
                }
            } label: {
                HStack {
                    Text("Sync Now")
                    Spacer()
                    if syncManager.isSyncing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
            }
            .disabled(syncManager.isSyncing)
            
            // Auto-sync toggle
            Toggle("Auto Sync on Launch", isOn: $settings.autoSyncOnLaunch)
            
        } header: {
            Text("Synchronization")
        }
    }
    
    private var serverSection: some View {
        Section {
            switch settings.syncService {
            case .dropbox:
                dropboxSettings
            case .webdav:
                webdavSettings
            }
        } header: {
            Text("Server Settings")
        }
    }
    
    private var dropboxSettings: some View {
        Group {
            if settings.dropboxLinked {
                LabeledContent("Status", value: "Connected")
                
                Button("Unlink Dropbox Account", role: .destructive) {
                    settings.dropboxLinked = false
                }
            } else {
                Button("Link Dropbox Account") {
                    // TODO: Implement Dropbox OAuth
                    settings.dropboxLinked = true
                }
            }
            
            TextField("Path", text: $settings.dropboxPath)
                .textContentType(.none)
                .autocapitalization(.none)
        }
    }
    
    private var webdavSettings: some View {
        Group {
            TextField("Server URL", text: $settings.webdavURL)
                .textContentType(.URL)
                .keyboardType(.URL)
                .autocapitalization(.none)
            
            TextField("Username", text: $settings.webdavUsername)
                .textContentType(.username)
                .autocapitalization(.none)
            
            SecureField("Password", text: $settings.webdavPassword)
                .textContentType(.password)
            
            TextField("Path", text: $settings.webdavPath)
                .textContentType(.none)
                .autocapitalization(.none)
            
            Button("Test Connection") {
                testWebDAVConnection()
            }
        }
    }
    
    private var organizationSection: some View {
        Section {
            TextField("Index File", text: $settings.indexFilename)
                .textContentType(.none)
            
            Toggle("Show Breadcrumbs", isOn: $settings.showBreadcrumbs)
            
            Picker("Default TODO State", selection: $settings.defaultTodoState) {
                Text("None").tag("")
                Text("TODO").tag("TODO")
                Text("NEXT").tag("NEXT")
            }
            
            TextField("TODO Keywords", text: $settings.todoKeywords)
                .textContentType(.none)
            
            TextField("DONE Keywords", text: $settings.doneKeywords)
                .textContentType(.none)
            
        } header: {
            Text("Organization")
        } footer: {
            Text("Configure how org-mode content is displayed and edited")
        }
    }
    
    private var appearanceSection: some View {
        Section {
            Picker("Font Size", selection: $settings.fontSize) {
                Text("Small").tag(FontSize.small)
                Text("Medium").tag(FontSize.medium)
                Text("Large").tag(FontSize.large)
                Text("Extra Large").tag(FontSize.extraLarge)
            }
            
            Toggle("Use System Font Size", isOn: $settings.useSystemFontSize)
            
            ColorPicker("Todo Color", selection: $settings.todoColor)
            ColorPicker("Done Color", selection: $settings.doneColor)
            
        } header: {
            Text("Appearance")
        }
    }
    
    private var advancedSection: some View {
        Section {
            Toggle("Offline Mode", isOn: $settings.offlineMode)
            
            Stepper("Sync Timeout: \(settings.syncTimeout)s", 
                   value: $settings.syncTimeout, 
                   in: 10...120, 
                   step: 10)
            
            Toggle("Enable Debug Logging", isOn: $settings.debugLogging)
            
            Button("Export Logs") {
                exportLogs()
            }
            
            Button("Reset All Data", role: .destructive) {
                showingResetAlert = true
            }
            
        } header: {
            Text("Advanced")
        }
    }
    
    private var aboutSection: some View {
        Section {
            Button("About MobileOrg") {
                showingAbout = true
            }
            
            LabeledContent("Version", value: appVersion)
            
            Link("Privacy Policy", destination: URL(string: "https://mobileorg.github.io/privacy")!)
            
            Link("Report an Issue", destination: URL(string: "https://github.com/webframp/mobileorg/issues")!)
            
        } header: {
            Text("About")
        }
    }
    
    // MARK: - Helper Methods
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
    
    private func testWebDAVConnection() {
        Task {
            // TODO: Implement WebDAV connection test
        }
    }
    
    private func exportLogs() {
        // TODO: Implement log export
    }
    
    private func resetAllData() {
        Task {
            do {
                try await dataController.deleteAllData()
            } catch {
                print("Error resetting data: \(error)")
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // App icon
                    Image(systemName: "note.text")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)
                        .padding(.top, 40)
                    
                    // App name and version
                    VStack(spacing: 8) {
                        Text("MobileOrg")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Version \(appVersion)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    // Description
                    Text("MobileOrg is an iOS application for viewing and editing your Org-mode files. It supports synchronization with Dropbox and WebDAV servers.")
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    // License
                    VStack(alignment: .leading, spacing: 8) {
                        Text("License")
                            .font(.headline)
                        
                        Text("This program is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    // Links
                    VStack(spacing: 12) {
                        Link(destination: URL(string: "https://mobileorg.github.io")!) {
                            Label("Website", systemImage: "globe")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Link(destination: URL(string: "https://github.com/webframp/mobileorg")!) {
                            Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        
                        Link(destination: URL(string: "https://orgmode.org")!) {
                            Label("Org-mode", systemImage: "doc.text")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                    
                    // Credits
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Credits")
                            .font(.headline)
                        
                        Text("Created by Richard Moreland\nContributions from the open source community")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        return "\(version) (\(build))"
    }
}

// MARK: - Settings Model

class Settings: ObservableObject {
    static let shared = Settings()
    
    // Sync settings
    @Published var syncService: SyncService {
        didSet { UserDefaults.standard.set(syncService.rawValue, forKey: "syncService") }
    }
    
    @Published var autoSyncOnLaunch: Bool {
        didSet { UserDefaults.standard.set(autoSyncOnLaunch, forKey: "autoSyncOnLaunch") }
    }
    
    // Dropbox settings
    @Published var dropboxLinked: Bool {
        didSet { UserDefaults.standard.set(dropboxLinked, forKey: "dropboxLinked") }
    }
    
    @Published var dropboxPath: String {
        didSet { UserDefaults.standard.set(dropboxPath, forKey: "dropboxPath") }
    }
    
    // WebDAV settings
    @Published var webdavURL: String {
        didSet { UserDefaults.standard.set(webdavURL, forKey: "webdavURL") }
    }
    
    @Published var webdavUsername: String {
        didSet { UserDefaults.standard.set(webdavUsername, forKey: "webdavUsername") }
    }
    
    // NOTE: In production, passwords should be stored in Keychain, not UserDefaults
    // This is simplified for the example. Use Security framework APIs:
    // SecItemAdd, SecItemUpdate, SecItemCopyMatching for secure password storage
    @Published var webdavPassword: String {
        didSet { UserDefaults.standard.set(webdavPassword, forKey: "webdavPassword") }
    }
    
    @Published var webdavPath: String {
        didSet { UserDefaults.standard.set(webdavPath, forKey: "webdavPath") }
    }
    
    // Organization settings
    @Published var indexFilename: String {
        didSet { UserDefaults.standard.set(indexFilename, forKey: "indexFilename") }
    }
    
    @Published var showBreadcrumbs: Bool {
        didSet { UserDefaults.standard.set(showBreadcrumbs, forKey: "showBreadcrumbs") }
    }
    
    @Published var defaultTodoState: String {
        didSet { UserDefaults.standard.set(defaultTodoState, forKey: "defaultTodoState") }
    }
    
    @Published var todoKeywords: String {
        didSet { UserDefaults.standard.set(todoKeywords, forKey: "todoKeywords") }
    }
    
    @Published var doneKeywords: String {
        didSet { UserDefaults.standard.set(doneKeywords, forKey: "doneKeywords") }
    }
    
    // Appearance settings
    @Published var fontSize: FontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: "fontSize") }
    }
    
    @Published var useSystemFontSize: Bool {
        didSet { UserDefaults.standard.set(useSystemFontSize, forKey: "useSystemFontSize") }
    }
    
    @Published var todoColor: Color
    @Published var doneColor: Color
    
    // Advanced settings
    @Published var offlineMode: Bool {
        didSet { UserDefaults.standard.set(offlineMode, forKey: "offlineMode") }
    }
    
    @Published var syncTimeout: Int {
        didSet { UserDefaults.standard.set(syncTimeout, forKey: "syncTimeout") }
    }
    
    @Published var debugLogging: Bool {
        didSet { UserDefaults.standard.set(debugLogging, forKey: "debugLogging") }
    }
    
    private init() {
        // Load from UserDefaults or use defaults
        self.syncService = SyncService(rawValue: UserDefaults.standard.string(forKey: "syncService") ?? "") ?? .dropbox
        self.autoSyncOnLaunch = UserDefaults.standard.bool(forKey: "autoSyncOnLaunch")
        self.dropboxLinked = UserDefaults.standard.bool(forKey: "dropboxLinked")
        self.dropboxPath = UserDefaults.standard.string(forKey: "dropboxPath") ?? "/MobileOrg"
        self.webdavURL = UserDefaults.standard.string(forKey: "webdavURL") ?? ""
        self.webdavUsername = UserDefaults.standard.string(forKey: "webdavUsername") ?? ""
        self.webdavPassword = UserDefaults.standard.string(forKey: "webdavPassword") ?? ""
        self.webdavPath = UserDefaults.standard.string(forKey: "webdavPath") ?? "/MobileOrg"
        self.indexFilename = UserDefaults.standard.string(forKey: "indexFilename") ?? "index.org"
        self.showBreadcrumbs = UserDefaults.standard.bool(forKey: "showBreadcrumbs")
        self.defaultTodoState = UserDefaults.standard.string(forKey: "defaultTodoState") ?? "TODO"
        self.todoKeywords = UserDefaults.standard.string(forKey: "todoKeywords") ?? "TODO NEXT"
        self.doneKeywords = UserDefaults.standard.string(forKey: "doneKeywords") ?? "DONE"
        self.fontSize = FontSize(rawValue: UserDefaults.standard.string(forKey: "fontSize") ?? "") ?? .medium
        self.useSystemFontSize = UserDefaults.standard.bool(forKey: "useSystemFontSize")
        self.todoColor = .orange
        self.doneColor = .green
        self.offlineMode = UserDefaults.standard.bool(forKey: "offlineMode")
        self.syncTimeout = UserDefaults.standard.integer(forKey: "syncTimeout") == 0 ? 60 : UserDefaults.standard.integer(forKey: "syncTimeout")
        self.debugLogging = UserDefaults.standard.bool(forKey: "debugLogging")
    }
}

// MARK: - Supporting Types

enum SyncService: String, CaseIterable {
    case dropbox = "Dropbox"
    case webdav = "WebDAV"
}

enum FontSize: String, CaseIterable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"
    
    var pointSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 20
        case .extraLarge: return 24
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environmentObject(SyncManager())
        .environmentObject(DataController.preview)
}
