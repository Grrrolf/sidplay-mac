//
//  SIDPlayerAppView.swift
//  SIDPLAY
//
//  Main application container view faithfully reproducing the classic
//  SIDPLAY interface from Screenshot 2:
//  - Top Toolbar with playback buttons, tempo, retro LCD, search, and volume
//  - Breadcrumb bar with < | > navigation and folder path trail
//  - Three-pane layout: Sidebar, Center Table, and classic Info HUD Inspector
//

import SwiftUI

public struct SIDPlayerAppView: View {
    private let player = SIDPlayer.shared
    @ObservedObject private var library = SIDLibraryManager.shared
    @State private var showSidebar = true
    @State private var showInspector = true
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - 1. Top Toolbar (Controls, LCD, Search, Volume)
            TransportBarView(player: player, library: library, showSidebar: $showSidebar, showInspector: $showInspector)
            
            Divider()
            
            // MARK: - 2. Main Area: Sidebar, Center (Breadcrumb + Table), and Info HUD Inspector
            HSplitView {
                if showSidebar {
                    SidebarView(library: library)
                        .frame(minWidth: 180, idealWidth: 200, maxWidth: 300)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                
                VStack(spacing: 0) {
                    BreadcrumbBarView(library: library, showSidebar: $showSidebar, showInspector: $showInspector)
                    Divider()
                    TuneTableView(library: library, player: player)
                }
                .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
                
                if showInspector {
                    SIDInspectorView(player: player, isPresented: $showInspector)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 980, minHeight: 620)
        .sheet(item: $library.activeSheet) { sheet in
            switch sheet {
            case .newPlaylist:
                NewPlaylistSheetView(library: library)
            case .smartPlaylist(let playlist):
                SmartPlaylistEditorSheetView(library: library, playlist: playlist)
            }
        }
    }
}
