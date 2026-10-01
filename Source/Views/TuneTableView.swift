//
//  TuneTableView.swift
//  SIDPLAY
//
//  Table view matching classic Screenshot 2:
//  Columns: Title, Time, Author, Released with alternating row shading,
//  instant selection loading, and double-click playback.
//

import SwiftUI

public struct TuneTableView: View {
    @ObservedObject var library: SIDLibraryManager
    @ObservedObject var player: SIDPlayer
    @State private var selectedItemId: String?
    @State private var sortOrder: [KeyPathComparator<SIDTuneItem>] = [
        KeyPathComparator(\.title, order: .forward)
    ]
    
    public init(
        library: SIDLibraryManager = .shared,
        player: SIDPlayer = .shared
    ) {
        self.library = library
        self.player = player
    }
    
    private func sortItems(_ items: [SIDTuneItem]) -> [SIDTuneItem] {
        guard !items.isEmpty else { return [] }
        
        let directories = items.filter { $0.isDirectory }
        let files = items.filter { !$0.isDirectory }
        
        let primaryComparator = sortOrder.first
        let isAsc = primaryComparator?.order == .forward
        let primaryKey = primaryComparator?.keyPath
        
        let sortedDirs: [SIDTuneItem]
        if primaryKey == \SIDTuneItem.title {
            sortedDirs = directories.sorted {
                let comp = $0.title.localizedCaseInsensitiveCompare($1.title)
                return isAsc ? comp == .orderedAscending : comp == .orderedDescending
            }
        } else {
            sortedDirs = directories.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        
        let sortedFiles: [SIDTuneItem]
        if primaryKey == \SIDTuneItem.songLengthSeconds {
            sortedFiles = files.sorted {
                if $0.songLengthSeconds != $1.songLengthSeconds {
                    return isAsc ? $0.songLengthSeconds < $1.songLengthSeconds : $0.songLengthSeconds > $1.songLengthSeconds
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        } else if primaryKey == \SIDTuneItem.author {
            sortedFiles = files.sorted {
                let comp = $0.author.localizedCaseInsensitiveCompare($1.author)
                if comp != .orderedSame {
                    return isAsc ? comp == .orderedAscending : comp == .orderedDescending
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        } else if primaryKey == \SIDTuneItem.released {
            sortedFiles = files.sorted {
                let comp = $0.released.localizedCaseInsensitiveCompare($1.released)
                if comp != .orderedSame {
                    return isAsc ? comp == .orderedAscending : comp == .orderedDescending
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        } else if primaryKey == \SIDTuneItem.folderDisplayPath {
            sortedFiles = files.sorted {
                let comp = $0.folderDisplayPath.localizedCaseInsensitiveCompare($1.folderDisplayPath)
                if comp != .orderedSame {
                    return isAsc ? comp == .orderedAscending : comp == .orderedDescending
                }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        } else {
            // Default: Title
            sortedFiles = files.sorted {
                let comp = $0.title.localizedCaseInsensitiveCompare($1.title)
                return isAsc ? comp == .orderedAscending : comp == .orderedDescending
            }
        }
        
        return sortedDirs + sortedFiles
    }
    
    private var sortedDisplayedItems: [SIDTuneItem] {
        sortItems(library.displayedItems)
    }
    
    public var body: some View {
        let items = library.displayedItems
        let sortedItems = sortItems(items)
        let trimmedSearch = library.searchText.trimmingCharacters(in: .whitespaces)
        
        VStack(spacing: 0) {
            if library.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading folder contents...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary.opacity(0.5))
                    
                    if trimmedSearch.isEmpty {
                        if case .smartPlaylist(let id) = library.selectedSidebarItem {
                            let name = library.smartPlaylists.first(where: { $0.id == id })?.name ?? "Smart Playlist"
                            Text("No tunes match the rules for \"\(name)\"")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                            Button("Edit Smart Playlist Rules") {
                                library.editSelectedSmartPlaylist()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .padding(.top, 4)
                        } else {
                            Text("Folder is empty")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    } else if library.searchScope == .hvsc && trimmedSearch.count < 2 {
                        Text("Type at least 2 characters to search the entire HVSC archive")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    } else if library.searchScope == .folder {
                        Text("No tunes match '\(library.searchText)' in \(library.currentFolderName)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Button("Search Entire HVSC Archive") {
                            library.setSearchScope(.hvsc)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                    } else {
                        Text("No tunes match '\(library.searchText)' in the entire HVSC archive")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(sortedItems, selection: $selectedItemId, sortOrder: $sortOrder) {
                    // Column 1: Title (with playing icon & folder icon)
                    TableColumn("Title", value: \.title) { item in
                        HStack(spacing: 6) {
                            if !item.isDirectory && player.metadata?.filePath == item.path && player.isPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(selectedItemId == item.path ? .white : .accentColor)
                            } else if item.isDirectory {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(selectedItemId == item.path ? .white.opacity(0.85) : .secondary)
                            } else {
                                Image(systemName: "music.note")
                                    .font(.system(size: 10))
                                    .foregroundColor(selectedItemId == item.path ? .white.opacity(0.6) : .secondary.opacity(0.4))
                            }
                            
                            Text(item.title)
                                .font(.system(size: 12, weight: item.isDirectory ? .semibold : .regular))
                                .foregroundColor(selectedItemId == item.path ? .white : (player.metadata?.filePath == item.path ? .accentColor : .primary))
                                .lineLimit(1)
                            
                            if library.isFavorite(path: item.path) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                    .width(min: 140, ideal: 200)
                    
                    // Column 2: Time
                    TableColumn("Time", value: \.songLengthSeconds) { item in
                        if !item.isDirectory {
                            Text(item.formattedDuration)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(selectedItemId == item.path ? .white.opacity(0.85) : .secondary)
                        } else {
                            Text("")
                        }
                    }
                    .width(min: 45, ideal: 55, max: 75)
                    
                    // Column 3: Author / Composer
                    TableColumn("Author", value: \.author) { item in
                        Text(item.author)
                            .font(.system(size: 12))
                            .foregroundColor(selectedItemId == item.path ? .white.opacity(0.85) : .secondary)
                            .lineLimit(1)
                    }
                    .width(min: 95, ideal: 140)
                    
                    // Column 4: Released
                    TableColumn("Released", value: \.released) { item in
                        Text(item.released)
                            .font(.system(size: 12))
                            .foregroundColor(selectedItemId == item.path ? .white.opacity(0.85) : .secondary)
                            .lineLimit(1)
                    }
                    .width(min: 65, ideal: 85)
                    
                    // Column 5: Folder / Path
                    TableColumn("Folder", value: \.folderDisplayPath) { item in
                        Text(item.folderDisplayPath)
                            .font(.system(size: 11))
                            .foregroundColor(selectedItemId == item.path ? .white.opacity(0.75) : .secondary)
                            .lineLimit(1)
                    }
                    .width(min: 75, ideal: 120)
                }
                .tableStyle(.bordered)
                .onKeyPress(.return) {
                    if let id = selectedItemId,
                       let item = sortedDisplayedItems.first(where: { isSameFile(path1: $0.path, path2: id) }) {
                        if item.isDirectory {
                            library.navigateTo(path: item.path)
                        } else {
                            let queue = sortedDisplayedItems.filter { !$0.isDirectory }
                            library.playItem(item, queue: queue)
                        }
                        return .handled
                    }
                    return .ignored
                }
                .contextMenu(forSelectionType: String.self) { selection in
                    if let firstId = selection.first,
                       let item = sortedDisplayedItems.first(where: { isSameFile(path1: $0.path, path2: firstId) }) {
                        if !item.isDirectory {
                            Button("Play") {
                                let queue = sortedDisplayedItems.filter { !$0.isDirectory }
                                library.playItem(item, queue: queue)
                            }
                            
                            if item.subtuneCount > 1 {
                                Menu("Play Subtune...") {
                                    ForEach(1...item.subtuneCount, id: \.self) { sub in
                                        Button("Subtune \(sub)") {
                                            let queue = sortedDisplayedItems.filter { !$0.isDirectory }
                                            library.playItem(item, subtune: sub, queue: queue)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Button(library.isFavorite(path: item.path) ? "Remove from Favorites" : "Add to Favorites") {
                                library.toggleFavorite(path: item.path)
                            }
                            
                            if !library.playlists.isEmpty {
                                Menu("Add to Playlist") {
                                    ForEach(library.playlists) { pl in
                                        Button(pl.name) {
                                            library.addToPlaylist(tunePath: item.path, playlistName: pl.name)
                                        }
                                    }
                                }
                            }
                            
                            Divider()
                            
                            Menu("Export As...") {
                                Button("MP3...") {
                                    SIDModernAppController.exportTune(
                                        path: item.path,
                                        title: item.title,
                                        author: item.author,
                                        subtune: item.defaultSubtune > 0 ? item.defaultSubtune : 1,
                                        loopCount: 1,
                                        formatTag: 0
                                    )
                                }
                                Button("AAC...") {
                                    SIDModernAppController.exportTune(
                                        path: item.path,
                                        title: item.title,
                                        author: item.author,
                                        subtune: item.defaultSubtune > 0 ? item.defaultSubtune : 1,
                                        loopCount: 1,
                                        formatTag: 1
                                    )
                                }
                                Button("Apple Lossless...") {
                                    SIDModernAppController.exportTune(
                                        path: item.path,
                                        title: item.title,
                                        author: item.author,
                                        subtune: item.defaultSubtune > 0 ? item.defaultSubtune : 1,
                                        loopCount: 1,
                                        formatTag: 2
                                    )
                                }
                                Button("AIFF (uncompressed)...") {
                                    SIDModernAppController.exportTune(
                                        path: item.path,
                                        title: item.title,
                                        author: item.author,
                                        subtune: item.defaultSubtune > 0 ? item.defaultSubtune : 1,
                                        loopCount: 1,
                                        formatTag: 3
                                    )
                                }
                                Button("PRG (C64 executable)...") {
                                    SIDModernAppController.exportTune(
                                        path: item.path,
                                        title: item.title,
                                        author: item.author,
                                        subtune: item.defaultSubtune > 0 ? item.defaultSubtune : 1,
                                        loopCount: 1,
                                        formatTag: 4
                                    )
                                }
                            }
                            
                            Divider()
                        }
                        
                        if !item.isDirectory {
                            Button("Show in Enclosing Folder") {
                                let parent = (item.path as NSString).deletingLastPathComponent
                                library.clearSearch()
                                library.navigateTo(path: parent)
                            }
                        }
                        
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.selectFile(item.path, inFileViewerRootedAtPath: "")
                        }
                        
                        Button("Copy Path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.path, forType: .string)
                        }
                    }
                } primaryAction: { selection in
                    // Double click: play tune or enter folder!
                    if let firstId = selection.first,
                       let item = sortedDisplayedItems.first(where: { isSameFile(path1: $0.path, path2: firstId) }) {
                        if item.isDirectory {
                            library.navigateTo(path: item.path)
                        } else {
                            let queue = sortedDisplayedItems.filter { !$0.isDirectory }
                            library.playItem(item, queue: queue)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedItemId) { newItemId in
            if let id = newItemId {
                library.selectedTunePaths = [id]
            } else {
                library.selectedTunePaths = []
            }
            guard let id = newItemId,
                  let item = sortedDisplayedItems.first(where: { isSameFile(path1: $0.path, path2: id) }),
                  !item.isDirectory else { return }
            // Single click: if not currently playing, load tune so LCD & buttons are ready
            if !player.isPlaying {
                let sub = item.defaultSubtune > 0 ? item.defaultSubtune : 1
                try? player.loadTune(at: item.path, subtune: sub)
            }
        }
        .onChange(of: player.metadata?.filePath) { newPath in
            syncSelectionWithPlayingTune(newPath)
        }
        .onAppear {
            syncSelectionWithPlayingTune(player.metadata?.filePath)
            if let id = selectedItemId {
                library.selectedTunePaths = [id]
            }
        }
        .onChange(of: library.displayedItems) { _ in
            syncSelectionWithPlayingTune(player.metadata?.filePath)
        }
        .onChange(of: library.isLoading) { loading in
            if !loading {
                syncSelectionWithPlayingTune(player.metadata?.filePath)
            }
        }
        .onChange(of: library.currentBrowsingPath) { _ in
            syncSelectionWithPlayingTune(player.metadata?.filePath)
        }
        .onChange(of: library.searchText) { _ in
            syncSelectionWithPlayingTune(player.metadata?.filePath)
        }
        .background(
            TableScrollHelper(
                targetPath: selectedItemId ?? player.metadata?.filePath,
                items: sortedItems
            )
        )
    }
    
    private func syncSelectionWithPlayingTune(_ path: String?) {
        guard let path = path, !path.isEmpty else { return }
        if let matching = sortedDisplayedItems.first(where: { isSameFile(path1: $0.path, path2: path) }) {
            selectedItemId = matching.path
        }
    }
}

// MARK: - Path Matching Helper

private func isSameFile(path1: String, path2: String) -> Bool {
    if path1 == path2 { return true }
    if path1.caseInsensitiveCompare(path2) == .orderedSame { return true }
    let u1 = URL(fileURLWithPath: path1).standardized.resolvingSymlinksInPath().path
    let u2 = URL(fileURLWithPath: path2).standardized.resolvingSymlinksInPath().path
    if u1 == u2 { return true }
    if u1.caseInsensitiveCompare(u2) == .orderedSame { return true }
    let p1 = URL(fileURLWithPath: path1)
    let p2 = URL(fileURLWithPath: path2)
    return p1.lastPathComponent.caseInsensitiveCompare(p2.lastPathComponent) == .orderedSame &&
           p1.deletingLastPathComponent().lastPathComponent.caseInsensitiveCompare(p2.deletingLastPathComponent().lastPathComponent) == .orderedSame
}

// MARK: - Table Auto-Scroll & Selection Sync Helper

private struct TableScrollHelper: NSViewRepresentable {
    let targetPath: String?
    let items: [SIDTuneItem]
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let target = targetPath,
              let row = items.firstIndex(where: { isSameFile(path1: $0.path, path2: target) }) else {
            return
        }
        
        func applySelection(attempt: Int = 0) {
            guard let tableView = findTableView(from: nsView) else {
                if attempt < 8 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        applySelection(attempt: attempt + 1)
                    }
                }
                return
            }
            
            if row < tableView.numberOfRows {
                tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
                tableView.scrollRowToVisible(row)
                if let window = tableView.window,
                   !(window.firstResponder is NSTextView),
                   window.firstResponder != tableView {
                    window.makeFirstResponder(tableView)
                }
            } else if attempt < 8 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    applySelection(attempt: attempt + 1)
                }
            }
        }
        
        DispatchQueue.main.async {
            applySelection()
        }
    }
    
    private func isTuneTable(_ tv: NSTableView) -> Bool {
        return tv.tableColumns.count >= 3
    }
    
    private func findTableView(from view: NSView) -> NSTableView? {
        if let tv = view.enclosingScrollView?.documentView as? NSTableView, isTuneTable(tv) {
            return tv
        }
        var current: NSView? = view.superview
        while let curr = current {
            if let tv = findTuneTable(in: curr) {
                return tv
            }
            current = curr.superview
        }
        if let root = view.window?.contentView, let tv = findTuneTable(in: root) {
            return tv
        }
        for win in NSApp.windows where win.contentViewController != nil {
            if let root = win.contentView, let tv = findTuneTable(in: root) {
                return tv
            }
        }
        return nil
    }
    
    private func findTuneTable(in root: NSView) -> NSTableView? {
        if let tv = root as? NSTableView, isTuneTable(tv) {
            return tv
        }
        if let sv = root as? NSScrollView, let tv = sv.documentView as? NSTableView, isTuneTable(tv) {
            return tv
        }
        for sub in root.subviews {
            if let tv = findTuneTable(in: sub) {
                return tv
            }
        }
        return nil
    }
}
