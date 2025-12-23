//
//  MobileOrgApp.swift
//  MobileOrg
//
//  SwiftUI Migration Example
//  This file demonstrates the proposed modern app structure
//
//  NOTE: This file references OutlineView, NoteListView, SearchView, and SettingsView
//  which are implemented in separate files in this directory:
//  - OutlineView.swift (full implementation)
//  - SettingsView.swift (full implementation)
//  - NoteListView and SearchView are placeholders to be implemented
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.

import SwiftUI

// MARK: - App Entry Point

/// Modern SwiftUI app entry point replacing main.m and MobileOrgAppDelegate
@main
struct MobileOrgApp: App {
    // Environment objects that will be available throughout the app
    @StateObject private var dataController = DataController()
    @StateObject private var syncManager = SyncManager()
    @StateObject private var networkMonitor = NetworkMonitor()
    
    // Scene phase for handling app lifecycle
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataController)
                .environmentObject(syncManager)
                .environmentObject(networkMonitor)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    /// Handle app lifecycle events
    private func handleScenePhaseChange(_ phase: ScenePhase) {
        switch phase {
        case .active:
            // App became active
            Task {
                await dataController.refreshData()
            }
        case .background:
            // App moved to background, save data
            Task {
                try? await dataController.saveContext()
            }
        case .inactive:
            // App is inactive (e.g., during interruption)
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Main Content View

/// Main container view with tab-based navigation
struct ContentView: View {
    @EnvironmentObject private var syncManager: SyncManager
    @EnvironmentObject private var networkMonitor: NetworkMonitor
    
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Outline Tab
            OutlineView()
                .tabItem {
                    Label("Outline", systemImage: "list.bullet.indent")
                }
                .tag(0)
            
            // Capture Tab
            NoteListView()
                .tabItem {
                    Label("Capture", systemImage: "note.text")
                }
                .badge(captureCount)
                .tag(1)
            
            // Search Tab
            SearchView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(2)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .overlay(alignment: .bottom) {
            // Show sync status banner when syncing
            if syncManager.isSyncing {
                SyncBannerView()
                    .transition(.move(edge: .bottom))
            }
        }
        .overlay(alignment: .bottom) {
            // Show offline banner when no connectivity
            if !networkMonitor.isConnected {
                OfflineBannerView()
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut, value: syncManager.isSyncing)
        .animation(.easeInOut, value: networkMonitor.isConnected)
    }
    
    /// Count of unsynchronized notes
    private var captureCount: Int {
        // TODO: Get actual count from data controller
        0
    }
}

// MARK: - Sync Banner

struct SyncBannerView: View {
    @EnvironmentObject private var syncManager: SyncManager
    
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(.circular)
            
            Text(syncManager.syncStatus)
                .font(.subheadline)
            
            Spacer()
            
            if let progress = syncManager.syncProgress {
                Text(progress.formatted(.percent))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Offline Banner

struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "wifi.slash")
                .foregroundStyle(.secondary)
            
            Text("Offline - Changes will sync when connected")
                .font(.subheadline)
            
            Spacer()
        }
        .padding()
        .background(.yellow.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(DataController())
        .environmentObject(SyncManager())
        .environmentObject(NetworkMonitor())
}
