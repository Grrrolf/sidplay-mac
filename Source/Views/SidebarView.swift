//
//  SidebarView.swift
//  SIDPLAY
//
//  Left sidebar matching classic SIDPLAY:
//  COLLECTIONS, PLAYLISTS (Manual & Smart Playlists), and bottom action bar.
//

import SwiftUI

public struct SidebarView: View {
    @ObservedObject var library: SIDLibraryManager
    
    public init(library: SIDLibraryManager = .shared) {
        self.library = library
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            List(selection: $library.selectedSidebarItem) {
                // MARK: - COLLECTIONS
                Section(header: Text("COLLECTIONS").font(.system(size: 11, weight: .bold))) {
                    let rootName = library.rootPath.isEmpty ? "HVSC Collection" : (library.rootPath as NSString).lastPathComponent
                    Label(rootName, systemImage: "folder.fill")
                        .font(.system(size: 12))
                        .tag(LibrarySidebarItem.folder(library.rootPath))
                    
                    ForEach(library.topLevelCategories) { category in
                        Label(category.name, systemImage: iconForCategory(category.name))
                            .font(.system(size: 12))
                            .tag(LibrarySidebarItem.folder(category.path))
                    }
                }
                
                // MARK: - PLAYLISTS
                Section(header:
                    HStack {
                        Text("PLAYLISTS")
                            .font(.system(size: 11, weight: .bold))
                        Spacer()
                    }
                    .contextMenu {
                        Button("New Playlist...") { library.promptNewPlaylist() }
                        Button("New Smart Playlist...") { library.promptNewSmartPlaylist() }
                    }
                ) {
                    HStack {
                        Label {
                            Text("Favorites")
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundColor(library.selectedSidebarItem == .favorites ? .white : .yellow)
                        }
                        .font(.system(size: 12))
                        Spacer()
                        if !library.favorites.isEmpty {
                            Text("\(library.favorites.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(LibrarySidebarItem.favorites)
                    
                    Label("Recently Played", systemImage: "clock.arrow.circlepath")
                        .font(.system(size: 12))
                        .tag(LibrarySidebarItem.recents)
                    
                    // Manual Playlists
                    ForEach(library.playlists) { playlist in
                        HStack {
                            Label(playlist.name, systemImage: "music.note")
                                .font(.system(size: 12))
                            Spacer()
                            Text("\(playlist.tunePaths.count)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        .tag(LibrarySidebarItem.playlist(playlist.name))
                        .contextMenu {
                            Button("Delete Playlist", role: .destructive) {
                                library.deletePlaylist(name: playlist.name)
                            }
                        }
                    }
                    
                    // Smart Playlists
                    ForEach(library.smartPlaylists) { sp in
                        HStack {
                            Label(sp.name, systemImage: "gearshape")
                                .font(.system(size: 12))
                            Spacer()
                            let cnt = library.count(for: sp)
                            if cnt > 0 {
                                Text("\(cnt)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .tag(LibrarySidebarItem.smartPlaylist(sp.id))
                        .contextMenu {
                            Button("Edit Smart Playlist...") {
                                library.editSmartPlaylist(sp)
                            }
                            Button("Duplicate") {
                                library.duplicateSmartPlaylist(sp)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                library.deleteSmartPlaylist(sp)
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .onChange(of: library.selectedSidebarItem) { newItem in
                switch newItem {
                case .folder(let path):
                    library.navigateTo(path: path)
                case .allTunes:
                    library.navigateTo(path: library.rootPath)
                default:
                    break
                }
            }
            
            Divider()
            
            // Bottom Action Bar: Settings, Plus, Emulation
            HStack(spacing: 14) {
                Button(action: selectCollectionFolder) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Configure Collection Folder")
                
                Menu {
                    Button(action: { library.promptNewPlaylist() }) {
                        Label("New Playlist", systemImage: "music.note")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    
                    Button(action: { library.promptNewSmartPlaylist() }) {
                        Label("New Smart Playlist...", systemImage: "gearshape")
                    }
                    .keyboardShortcut("n", modifiers: [.command, .option])
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 18, height: 18)
                .help("New Playlist (⌘N) or Smart Playlist (⌥⌘N)")
                
                Button(action: {
                    SIDPreferencesWindowController.shared.showWindow()
                }) {
                    Image(systemName: "cpu")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("SID Emulation Settings")
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func iconForCategory(_ name: String) -> String {
        switch name.uppercased() {
        case "MUSICIANS": return "person.2.fill"
        case "GAMES": return "gamecontroller.fill"
        case "DEMOS": return "sparkles"
        case "DOCUMENTS": return "doc.text.fill"
        default: return "folder.fill"
        }
    }
    
    private func selectCollectionFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose HVSC Folder"
        if panel.runModal() == .OK, let url = panel.url {
            library.setRootCollection(path: url.path)
        }
    }
}

// MARK: - New Playlist Sheet View

public struct NewPlaylistSheetView: View {
    @ObservedObject var library: SIDLibraryManager
    @State private var playlistName = ""
    @Environment(\.dismiss) private var dismiss
    
    public init(library: SIDLibraryManager = .shared) {
        self.library = library
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("New Playlist")
                        .font(.headline)
                    Text("Create a custom playlist to organize your favorite SID tunes.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            TextField("Playlist Name", text: $playlistName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 280)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Create") {
                    let trimmed = playlistName.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty {
                        library.createPlaylist(name: trimmed)
                        library.selectedSidebarItem = .playlist(trimmed)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(playlistName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 340)
    }
}

// MARK: - Smart Playlist Editor Sheet View

public struct SmartPlaylistEditorSheetView: View {
    @ObservedObject var library: SIDLibraryManager
    let existingPlaylist: SIDSmartPlaylist?
    
    @State private var name: String
    @State private var matchMode: SmartPlaylistMatchMode
    @State private var rules: [SmartPlaylistRule]
    @State private var isLimitEnabled: Bool
    @State private var limitCountString: String
    @State private var previewCount: Int = 0
    @State private var previewTimer: Task<Void, Never>?
    
    @Environment(\.dismiss) private var dismiss
    
    public init(library: SIDLibraryManager = .shared, playlist: SIDSmartPlaylist? = nil) {
        self.library = library
        self.existingPlaylist = playlist
        _name = State(initialValue: playlist?.name ?? "Untitled Smart Playlist")
        _matchMode = State(initialValue: playlist?.matchMode ?? .all)
        let initialRules = (playlist?.rules.isEmpty ?? true) ? [SmartPlaylistRule()] : (playlist?.rules ?? [SmartPlaylistRule()])
        _rules = State(initialValue: initialRules)
        _isLimitEnabled = State(initialValue: playlist?.limitCount != nil)
        _limitCountString = State(initialValue: "\(playlist?.limitCount ?? 50)")
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(existingPlaylist == nil ? "New Smart Playlist" : "Edit Smart Playlist")
                        .font(.headline)
                    Text("Tunes matching these rules update dynamically in your library.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            Divider()
            
            // Name Field
            HStack {
                Text("Playlist Name:")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 100, alignment: .trailing)
                TextField("Playlist Name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Match Mode
            HStack {
                Text("Match:")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 100, alignment: .trailing)
                Picker("", selection: $matchMode) {
                    Text("All (AND)").tag(SmartPlaylistMatchMode.all)
                    Text("Any (OR)").tag(SmartPlaylistMatchMode.any)
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
                .onChange(of: matchMode) { _ in updatePreview() }
                
                Text("of the following rules:")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            // Rule rows
            ScrollView(.vertical) {
                VStack(spacing: 8) {
                    ForEach(Array(rules.enumerated()), id: \.element.id) { index, rule in
                        HStack(spacing: 8) {
                            // Field Picker
                            Picker("", selection: Binding(
                                get: { rules[index].field },
                                set: { rules[index].field = $0; updatePreview() }
                            )) {
                                ForEach(SmartPlaylistField.allCases) { field in
                                    Text(field.rawValue).tag(field)
                                }
                            }
                            .frame(width: 165)
                            
                            // Operator Picker
                            Picker("", selection: Binding(
                                get: { rules[index].op },
                                set: { rules[index].op = $0; updatePreview() }
                            )) {
                                ForEach(SmartPlaylistOperator.allCases) { op in
                                    Text(op.rawValue).tag(op)
                                }
                            }
                            .frame(width: 140)
                            
                            // Value Field
                            TextField("Value (e.g. Hubbard, 1987)", text: Binding(
                                get: { rules[index].value },
                                set: { rules[index].value = $0; updatePreview() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 160)
                            
                            // Action Buttons: Remove Rule (-), Add Rule (+)
                            Button(action: {
                                if rules.count > 1 {
                                    rules.remove(at: index)
                                    updatePreview()
                                }
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(rules.count > 1 ? .secondary : .secondary.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                            .disabled(rules.count <= 1)
                            .help("Remove Rule")
                            
                            Button(action: {
                                rules.insert(SmartPlaylistRule(), at: index + 1)
                                updatePreview()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Add Rule")
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .frame(maxHeight: 160)
            
            // Limit Section
            HStack(spacing: 8) {
                Toggle("Limit to", isOn: $isLimitEnabled)
                    .toggleStyle(.checkbox)
                    .onChange(of: isLimitEnabled) { _ in updatePreview() }
                
                TextField("50", text: $limitCountString)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .disabled(!isLimitEnabled)
                    .onChange(of: limitCountString) { _ in updatePreview() }
                
                Text("tunes (ordered by title)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.leading, 108)
            
            Divider()
            
            // Footer: Live preview count & Action Buttons
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "music.note.list")
                        .foregroundColor(.accentColor)
                    Text("\(previewCount) \(previewCount == 1 ? "tune" : "tunes") match in library")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(existingPlaylist == nil ? "Create" : "Save") {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 650)
        .onAppear {
            updatePreview()
        }
    }
    
    private func updatePreview() {
        previewTimer?.cancel()
        let activeRules = rules
        let activeMode = matchMode
        let limit = isLimitEnabled ? Int(limitCountString) : nil
        previewTimer = Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if Task.isCancelled { return }
            let count = library.count(rules: activeRules, matchMode: activeMode, limit: limit)
            await MainActor.run {
                self.previewCount = count
            }
        }
    }
    
    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        let limit = isLimitEnabled ? Int(limitCountString) : nil
        let targetId = existingPlaylist?.id ?? UUID()
        let playlist = SIDSmartPlaylist(
            id: targetId,
            name: trimmedName,
            matchMode: matchMode,
            rules: rules,
            limitCount: limit
        )
        library.saveSmartPlaylist(playlist)
        dismiss()
    }
}
