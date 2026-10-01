//
//  SIDLibraryManager.swift
//  SIDPLAY
//
//  Observable Library and Collection Manager coordinating HVSC browsing,
//  playlists, favorites, and search.
//

import Foundation
import Combine

public enum LibrarySidebarItem: Hashable, Identifiable {
    case allTunes
    case favorites
    case recents
    case folder(String)
    case playlist(String)
    case smartPlaylist(UUID)
    
    public var id: String {
        switch self {
        case .allTunes: return "lib.all"
        case .favorites: return "lib.favorites"
        case .recents: return "lib.recents"
        case .folder(let path): return "folder.\(path)"
        case .playlist(let name): return "playlist.\(name)"
        case .smartPlaylist(let id): return "smartplaylist.\(id.uuidString)"
        }
    }
}

public enum SearchScope: String, CaseIterable, Identifiable {
    case folder = "Folder"
    case hvsc = "Entire HVSC"
    
    public var id: String { rawValue }
}

public struct SIDPlaylist: Identifiable, Codable, Hashable {
    public var id: String { name }
    public var name: String
    public var tunePaths: [String]
    
    public init(name: String, tunePaths: [String] = []) {
        self.name = name
        self.tunePaths = tunePaths
    }
}

public enum SmartPlaylistField: String, CaseIterable, Codable, Identifiable {
    case title = "Title"
    case author = "Author / Composer"
    case released = "Released / Year"
    case path = "Path / Filename"
    
    public var id: String { rawValue }
}

public enum SmartPlaylistOperator: String, CaseIterable, Codable, Identifiable {
    case contains = "contains"
    case doesNotContain = "does not contain"
    case startsWith = "starts with"
    case endsWith = "ends with"
    case isExact = "is"
    
    public var id: String { rawValue }
}

public struct SmartPlaylistRule: Identifiable, Codable, Hashable {
    public var id: UUID
    public var field: SmartPlaylistField
    public var op: SmartPlaylistOperator
    public var value: String
    
    public init(
        id: UUID = UUID(),
        field: SmartPlaylistField = .author,
        op: SmartPlaylistOperator = .contains,
        value: String = ""
    ) {
        self.id = id
        self.field = field
        self.op = op
        self.value = value
    }
}

public enum SmartPlaylistMatchMode: String, CaseIterable, Codable, Identifiable {
    case all = "All"
    case any = "Any"
    
    public var id: String { rawValue }
}

public struct SIDSmartPlaylist: Identifiable, Codable, Hashable {
    public var id: UUID
    public var name: String
    public var matchMode: SmartPlaylistMatchMode
    public var rules: [SmartPlaylistRule]
    public var limitCount: Int?
    
    public init(
        id: UUID = UUID(),
        name: String = "Untitled Smart Playlist",
        matchMode: SmartPlaylistMatchMode = .all,
        rules: [SmartPlaylistRule] = [SmartPlaylistRule()],
        limitCount: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.matchMode = matchMode
        self.rules = rules.isEmpty ? [SmartPlaylistRule()] : rules
        self.limitCount = limitCount
    }
}

public enum LibraryActiveSheet: Identifiable {
    case newPlaylist
    case smartPlaylist(SIDSmartPlaylist?)
    
    public var id: String {
        switch self {
        case .newPlaylist: return "newPlaylist"
        case .smartPlaylist(let sp): return "smartPlaylist.\(sp?.id.uuidString ?? "new")"
        }
    }
}

@MainActor
public final class SIDLibraryManager: ObservableObject {
    public static let shared = SIDLibraryManager()
    
    // MARK: - Published Properties
    @Published public var rootPath: String = ""
    @Published public var currentBrowsingPath: String = ""
    @Published public var currentItems: [SIDTuneItem] = []
    @Published public var isLoading: Bool = false
    @Published public var selectedSidebarItem: LibrarySidebarItem = .allTunes
    
    @Published public var searchScope: SearchScope = .folder {
        didSet {
            UserDefaults.standard.set(searchScope.rawValue, forKey: "SearchScope")
            performSearch()
        }
    }
    @Published public var searchText: String = "" {
        didSet {
            performSearch()
        }
    }
    @Published public var hvscSearchResults: [SIDTuneItem] = []
    @Published public var isSearchingHVSC: Bool = false
    private var searchTask: Task<Void, Never>?
    
    @Published public var favorites: Set<String> = []
    @Published public var recentTunePaths: [String] = []
    @Published public var playlists: [SIDPlaylist] = []
    @Published public var smartPlaylists: [SIDSmartPlaylist] = []
    @Published public var activeSheet: LibraryActiveSheet? = nil
    
    // Top-level HVSC categories (e.g. DEMOS, GAMES, MUSICIANS)
    @Published public var topLevelCategories: [SIDTuneItem] = []
    
    // Queue tracking for continuous playback
    public private(set) var activeQueue: [SIDTuneItem] = []
    public private(set) var activeQueueIndex: Int = -1
    
    // Playback Modes (Advance, Shuffle, Repeat)
    @Published public var isAutoAdvanceEnabled: Bool = UserDefaults.standard.object(forKey: "FadeActive") != nil ? UserDefaults.standard.bool(forKey: "FadeActive") : true {
        didSet {
            UserDefaults.standard.set(isAutoAdvanceEnabled, forKey: "FadeActive")
        }
    }
    @Published public var isShuffleEnabled: Bool = UserDefaults.standard.bool(forKey: "ShuffleActive") {
        didSet {
            UserDefaults.standard.set(isShuffleEnabled, forKey: "ShuffleActive")
        }
    }
    @Published public var isRepeatEnabled: Bool = UserDefaults.standard.bool(forKey: "RepeatActive") {
        didSet {
            UserDefaults.standard.set(isRepeatEnabled, forKey: "RepeatActive")
        }
    }
    
    // Navigation History Stacks
    @Published public private(set) var backStack: [String] = []
    @Published public private(set) var forwardStack: [String] = []

    // Selected tune paths in the current view for export and actions
    @Published public var selectedTunePaths: Set<String> = []
    
    public var canNavigateBack: Bool {
        return !backStack.isEmpty || (currentBrowsingPath != rootPath && !currentBrowsingPath.isEmpty)
    }
    
    public var canNavigateForward: Bool {
        return !forwardStack.isEmpty
    }
    
    private let favoritesKey = "SIDPLAY_Favorites"
    private let recentsKey = "SIDPLAY_Recents"
    private let playlistsKey = "SIDPLAY_Playlists"
    private let smartPlaylistsKey = "SIDPLAY_SmartPlaylists"
    
    public init() {
        if let storedScope = UserDefaults.standard.string(forKey: "SearchScope"),
           let scope = SearchScope(rawValue: storedScope) {
            self.searchScope = scope
        }
        loadPersistedState()
        detectAndSetInitialCollection()
    }
    
    // MARK: - Collection Setup
    
    public func detectAndSetInitialCollection() {
        // 1. Check existing preferences
        if let stored = UserDefaults.standard.array(forKey: "collections") as? [String],
           let first = stored.first, FileManager.default.fileExists(atPath: first) {
            setRootCollection(path: first)
            return
        }
        
        // 2. Check standard HVSC location in user's Music
        let defaultCandidates = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music/C64music").path,
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Music").path
        ]
        
        for candidate in defaultCandidates {
            if FileManager.default.fileExists(atPath: candidate) {
                setRootCollection(path: candidate)
                return
            }
        }
    }
    
    public func setRootCollection(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        rootPath = path
        currentBrowsingPath = path
        backStack.removeAll()
        forwardStack.removeAll()
        
        // Save to NSUserDefaults for interoperability
        var collections = UserDefaults.standard.array(forKey: "collections") as? [String] ?? []
        if !collections.contains(path) {
            collections.insert(path, at: 0)
            UserDefaults.standard.set(collections, forKey: "collections")
        }
        
        // Initialize SongLength database
        SIDEngineBridge.initializeSongLengthDatabase(withRootPath: path)
        
        // Start high-performance HVSC full collection indexing and STIL parser
        HVSCIndexManager.shared.start(rootPath: path)
        STILManager.shared.start(rootPath: path)
        
        loadTopLevelCategories()
        loadDirectory(path: path)
    }
    
    private func loadTopLevelCategories() {
        guard !rootPath.isEmpty else { return }
        let url = URL(fileURLWithPath: rootPath)
        guard let contents = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        topLevelCategories = contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false }
            .map { SIDTuneItem.from(url: $0) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
    
    // MARK: - Navigation
    
    public func navigateBack() {
        selectedSidebarItem = .allTunes
        if !searchText.isEmpty {
            searchText = ""
        }
        if let previous = backStack.popLast() {
            forwardStack.append(currentBrowsingPath)
            loadDirectory(path: previous)
        } else if currentBrowsingPath != rootPath && !currentBrowsingPath.isEmpty {
            let parent = (currentBrowsingPath as NSString).deletingLastPathComponent
            forwardStack.append(currentBrowsingPath)
            loadDirectory(path: parent)
        }
    }
    
    public func navigateForward() {
        guard let next = forwardStack.popLast() else { return }
        selectedSidebarItem = .allTunes
        if !searchText.isEmpty {
            searchText = ""
        }
        backStack.append(currentBrowsingPath)
        loadDirectory(path: next)
    }
    
    public func navigateTo(path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        selectedSidebarItem = .allTunes
        if !searchText.isEmpty {
            searchText = ""
        }
        if !currentBrowsingPath.isEmpty && currentBrowsingPath != path {
            backStack.append(currentBrowsingPath)
            forwardStack.removeAll()
        }
        loadDirectory(path: path)
    }
    
    public func navigateUp() {
        guard currentBrowsingPath != rootPath && !currentBrowsingPath.isEmpty else { return }
        let parent = (currentBrowsingPath as NSString).deletingLastPathComponent
        navigateTo(path: parent)
    }
    
    public func showCurrentSong() {
        guard let filePath = SIDPlayer.shared.metadata?.filePath,
              !filePath.isEmpty,
              FileManager.default.fileExists(atPath: filePath) else { return }
        
        let parent = (filePath as NSString).deletingLastPathComponent
        selectedSidebarItem = .allTunes
        if !searchText.isEmpty {
            searchText = ""
        }
        navigateTo(path: parent)
        selectedTunePaths = [filePath]
    }
    
    public func revealSelectedItemInBrowser() {
        guard let selected = selectedTunePaths.first else { return }
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: selected, isDirectory: &isDir) {
            if isDir.boolValue {
                navigateTo(path: selected)
            } else {
                let parent = (selected as NSString).deletingLastPathComponent
                if currentBrowsingPath != parent {
                    navigateTo(path: parent)
                }
                selectedTunePaths = [selected]
            }
        }
    }
    
    public func rescanCurrentCollection() {
        guard !rootPath.isEmpty else { return }
        loadTopLevelCategories()
        loadDirectory(path: currentBrowsingPath)
        HVSCIndexManager.shared.start(rootPath: rootPath)
        STILManager.shared.start(rootPath: rootPath)
    }
    
    private func loadDirectory(path: String) {
        currentBrowsingPath = path
        isLoading = true
        
        Task.detached(priority: .userInitiated) {
            let items = Self.scanDirectory(path: path)
            await MainActor.run {
                self.currentItems = items
                self.activeQueue = items.filter { !$0.isDirectory }
                self.isLoading = false
            }
        }
    }
    
    public var breadcrumbs: [(name: String, path: String)] {
        switch selectedSidebarItem {
        case .playlist(let name):
            return [(name: "Playlists", path: ""), (name: name, path: "")]
        case .smartPlaylist(let id):
            let spName = smartPlaylists.first(where: { $0.id == id })?.name ?? "Smart Playlist"
            return [(name: "Playlists", path: ""), (name: spName, path: "")]
        case .favorites:
            return [(name: "Favorites", path: "")]
        case .recents:
            return [(name: "Recently Played", path: "")]
        default:
            break
        }
        
        guard !rootPath.isEmpty, currentBrowsingPath.hasPrefix(rootPath) else {
            return [(name: (currentBrowsingPath as NSString).lastPathComponent, path: currentBrowsingPath)]
        }
        
        var crumbs: [(name: String, path: String)] = []
        var path = currentBrowsingPath
        while path.count >= rootPath.count {
            let name = path == rootPath ? "Collection" : (path as NSString).lastPathComponent
            crumbs.insert((name: name, path: path), at: 0)
            if path == rootPath { break }
            path = (path as NSString).deletingLastPathComponent
        }
        return crumbs
    }
    
    // MARK: - Filtered Display Items
    
    public var isSearchingAllHVSC: Bool {
        return searchScope == .hvsc && !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    public var currentFolderName: String {
        guard !currentBrowsingPath.isEmpty else { return "Folder" }
        return (currentBrowsingPath as NSString).lastPathComponent
    }
    
    public func setSearchScope(_ scope: SearchScope) {
        searchScope = scope
    }
    
    public func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchText = ""
        hvscSearchResults = []
        isSearchingHVSC = false
    }
    
    public func performSearch() {
        searchTask?.cancel()
        
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard searchScope == .hvsc else {
            hvscSearchResults = []
            isSearchingHVSC = false
            return
        }
        
        // Require at least 2 characters for HVSC-wide search to eliminate beach balling on single-letter queries
        guard trimmed.count >= 2 else {
            hvscSearchResults = []
            isSearchingHVSC = false
            return
        }
        
        isSearchingHVSC = true
        let currentQuery = trimmed
        let root = rootPath
        
        searchTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            // 200ms debounce to allow fluid typing and instant backspacing without thread contention
            try? await Task.sleep(nanoseconds: 200_000_000)
            if Task.isCancelled { return }
            
            let results = HVSCIndexManager.shared.search(query: currentQuery, rootPath: root, maxResults: 200)
            if Task.isCancelled { return }
            
            await MainActor.run {
                if self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == currentQuery && self.searchScope == .hvsc {
                    self.hvscSearchResults = results
                    self.isSearchingHVSC = false
                    self.activeQueue = results
                }
            }
        }
    }
    
    private struct DisplayedItemsCacheKey: Equatable {
        let sidebarItem: LibrarySidebarItem
        let searchText: String
        let isSearchingAllHVSC: Bool
        let hvscCount: Int
        let currentItemsCount: Int
        let currentPath: String
        let favoritesCount: Int
        let recentsCount: Int
        let playlistsCount: Int
        let smartPlaylistsCount: Int
        let smartPlaylistVersion: Int
    }
    
    private var _cachedDisplayedKey: DisplayedItemsCacheKey? = nil
    private var _cachedDisplayedItems: [SIDTuneItem] = []
    private var _smartPlaylistVersion: Int = 0
    
    public var displayedCount: Int {
        if isSearchingAllHVSC {
            return hvscSearchResults.count
        }
        return displayedItems.count
    }
    
    public var displayedItems: [SIDTuneItem] {
        if isSearchingAllHVSC {
            return hvscSearchResults
        }
        
        let currentKey = DisplayedItemsCacheKey(
            sidebarItem: selectedSidebarItem,
            searchText: searchText,
            isSearchingAllHVSC: isSearchingAllHVSC,
            hvscCount: hvscSearchResults.count,
            currentItemsCount: currentItems.count,
            currentPath: currentBrowsingPath,
            favoritesCount: favorites.count,
            recentsCount: recentTunePaths.count,
            playlistsCount: playlists.count,
            smartPlaylistsCount: smartPlaylists.count,
            smartPlaylistVersion: _smartPlaylistVersion
        )
        
        if let cached = _cachedDisplayedKey, cached == currentKey {
            return _cachedDisplayedItems
        }
        
        var base: [SIDTuneItem]
        
        switch selectedSidebarItem {
        case .allTunes, .folder:
            base = currentItems
        case .favorites:
            base = favorites.compactMap { path in
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                return SIDTuneItem.from(url: URL(fileURLWithPath: path))
            }
        case .recents:
            base = recentTunePaths.compactMap { path in
                guard FileManager.default.fileExists(atPath: path) else { return nil }
                return SIDTuneItem.from(url: URL(fileURLWithPath: path))
            }
        case .playlist(let name):
            if let p = playlists.first(where: { $0.name == name }) {
                base = p.tunePaths.compactMap { path in
                    guard FileManager.default.fileExists(atPath: path) else { return nil }
                    return SIDTuneItem.from(url: URL(fileURLWithPath: path))
                }
            } else {
                base = []
            }
        case .smartPlaylist(let id):
            if let sp = smartPlaylists.first(where: { $0.id == id }) {
                base = tunes(for: sp)
            } else {
                base = []
            }
        }
        
        let finalItems: [SIDTuneItem]
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            finalItems = base
        } else {
            let query = searchText.lowercased()
            finalItems = base.filter { item in
                item.title.lowercased().contains(query) ||
                item.author.lowercased().contains(query) ||
                item.released.lowercased().contains(query) ||
                item.name.lowercased().contains(query)
            }
        }
        
        _cachedDisplayedKey = currentKey
        _cachedDisplayedItems = finalItems
        return finalItems
    }
    
    // MARK: - Playback Queue Management
    
    public func playItem(_ item: SIDTuneItem, subtune: Int? = nil, queue: [SIDTuneItem]? = nil) {
        if item.isDirectory {
            navigateTo(path: item.path)
            return
        }
        
        // Record recent
        recordRecent(path: item.path)
        
        // Update queue
        let nonDirs = queue ?? displayedItems.filter { !$0.isDirectory }
        if let idx = nonDirs.firstIndex(where: { $0.path == item.path }) {
            activeQueue = nonDirs
            activeQueueIndex = idx
        }
        
        let subtuneToPlay = subtune ?? (item.defaultSubtune > 0 ? item.defaultSubtune : 1)
        do {
            try SIDPlayer.shared.loadTune(at: item.path, subtune: subtuneToPlay)
            SIDPlayer.shared.play()
        } catch {
            print("Failed to play tune \(item.path): \(error)")
        }
    }
    
    public func playNextInQueue() {
        var queue = activeQueue
        if queue.isEmpty {
            let nonDirs = displayedItems.filter { !$0.isDirectory }
            if !nonDirs.isEmpty {
                queue = nonDirs
                activeQueue = nonDirs
            } else {
                return
            }
        }
        
        if isShuffleEnabled {
            if queue.count > 1 {
                var nextIdx = Int.random(in: 0..<queue.count)
                var attempts = 0
                while nextIdx == activeQueueIndex && attempts < 10 {
                    nextIdx = Int.random(in: 0..<queue.count)
                    attempts += 1
                }
                activeQueueIndex = nextIdx
            } else {
                activeQueueIndex = 0
            }
            let nextItem = queue[activeQueueIndex]
            playItem(nextItem, queue: queue)
        } else {
            if activeQueueIndex + 1 < queue.count {
                activeQueueIndex += 1
                let nextItem = queue[activeQueueIndex]
                playItem(nextItem, queue: queue)
            } else if isRepeatEnabled {
                // Wrap around to start of queue
                activeQueueIndex = 0
                let nextItem = queue[0]
                playItem(nextItem, queue: queue)
            } else {
                // End of queue reached and repeat disabled: stop playback
                SIDPlayer.shared.stop()
            }
        }
    }
    
    public func playPreviousInQueue() {
        var queue = activeQueue
        if queue.isEmpty {
            let nonDirs = displayedItems.filter { !$0.isDirectory }
            if !nonDirs.isEmpty {
                queue = nonDirs
                activeQueue = nonDirs
            } else {
                return
            }
        }
        
        if isShuffleEnabled {
            if queue.count > 1 {
                var prevIdx = Int.random(in: 0..<queue.count)
                var attempts = 0
                while prevIdx == activeQueueIndex && attempts < 10 {
                    prevIdx = Int.random(in: 0..<queue.count)
                    attempts += 1
                }
                activeQueueIndex = prevIdx
            } else {
                activeQueueIndex = 0
            }
            let prevItem = queue[activeQueueIndex]
            playItem(prevItem, queue: queue)
        } else {
            if activeQueueIndex - 1 >= 0 {
                activeQueueIndex -= 1
                let prevItem = queue[activeQueueIndex]
                playItem(prevItem, queue: queue)
            } else if isRepeatEnabled {
                // Wrap around to end of queue
                activeQueueIndex = queue.count - 1
                let prevItem = queue[activeQueueIndex]
                playItem(prevItem, queue: queue)
            }
        }
    }
    
    // MARK: - Favorites & Playlists
    
    public func isFavorite(path: String) -> Bool {
        favorites.contains(path)
    }
    
    public func toggleFavorite(path: String) {
        if favorites.contains(path) {
            favorites.remove(path)
        } else {
            favorites.insert(path)
        }
        savePersistedState()
    }
    
    public func recordRecent(path: String) {
        recentTunePaths.removeAll { $0 == path }
        recentTunePaths.insert(path, at: 0)
        if recentTunePaths.count > 100 {
            recentTunePaths = Array(recentTunePaths.prefix(100))
        }
        savePersistedState()
    }
    
    public func createPlaylist(name: String) {
        guard !playlists.contains(where: { $0.name == name }) else { return }
        playlists.append(SIDPlaylist(name: name))
        savePersistedState()
    }
    
    public func addToPlaylist(tunePath: String, playlistName: String) {
        if let idx = playlists.firstIndex(where: { $0.name == playlistName }) {
            if !playlists[idx].tunePaths.contains(tunePath) {
                playlists[idx].tunePaths.append(tunePath)
                savePersistedState()
            }
        }
    }
    
    public func deletePlaylist(name: String) {
        playlists.removeAll { $0.name == name }
        if case .playlist(let cur) = selectedSidebarItem, cur == name {
            selectedSidebarItem = .allTunes
        }
        savePersistedState()
    }
    
    // MARK: - File Scanning Helper
    
    nonisolated private static func scanDirectory(path: String) -> [SIDTuneItem] {
        let url = URL(fileURLWithPath: path)
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey]
        
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        var dirs: [SIDTuneItem] = []
        var tunes: [SIDTuneItem] = []
        
        for fileUrl in contents {
            guard let vals = try? fileUrl.resourceValues(forKeys: Set(keys)) else { continue }
            if vals.isDirectory ?? false {
                dirs.append(SIDTuneItem(path: fileUrl.path, isDirectory: true))
            } else {
                let ext = fileUrl.pathExtension.lowercased()
                if ext == "sid" || ext == "mus" || ext == "prg" {
                    tunes.append(SIDTuneItem.from(url: fileUrl))
                }
            }
        }
        
        dirs.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        tunes.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        
        return dirs + tunes
    }
    
    private func loadPersistedState() {
        let defaults = UserDefaults.standard
        if let favs = defaults.array(forKey: favoritesKey) as? [String] {
            favorites = Set(favs)
        }
        if let recents = defaults.array(forKey: recentsKey) as? [String] {
            recentTunePaths = recents
        }
        if let data = defaults.data(forKey: playlistsKey),
           let pls = try? JSONDecoder().decode([SIDPlaylist].self, from: data) {
            playlists = pls
        }
        if let data = defaults.data(forKey: smartPlaylistsKey),
           let pls = try? JSONDecoder().decode([SIDSmartPlaylist].self, from: data) {
            smartPlaylists = pls
        } else {
            smartPlaylists = defaultSmartPlaylists()
        }
    }
    
    private func savePersistedState() {
        let defaults = UserDefaults.standard
        defaults.set(Array(favorites), forKey: favoritesKey)
        defaults.set(recentTunePaths, forKey: recentsKey)
        if let data = try? JSONEncoder().encode(playlists) {
            defaults.set(data, forKey: playlistsKey)
        }
        if let data = try? JSONEncoder().encode(smartPlaylists) {
            defaults.set(data, forKey: smartPlaylistsKey)
        }
        _smartPlaylistVersion += 1
    }
    
    // MARK: - Smart Playlists Management
    
    public func promptNewPlaylist() {
        activeSheet = .newPlaylist
    }
    
    public func promptNewSmartPlaylist() {
        activeSheet = .smartPlaylist(nil)
    }
    
    public func editSmartPlaylist(_ playlist: SIDSmartPlaylist) {
        activeSheet = .smartPlaylist(playlist)
    }
    
    public func editSelectedSmartPlaylist() {
        if case .smartPlaylist(let id) = selectedSidebarItem,
           let sp = smartPlaylists.first(where: { $0.id == id }) {
            editSmartPlaylist(sp)
        }
    }
    
    public func saveSmartPlaylist(_ playlist: SIDSmartPlaylist) {
        if let idx = smartPlaylists.firstIndex(where: { $0.id == playlist.id }) {
            smartPlaylists[idx] = playlist
        } else {
            smartPlaylists.append(playlist)
        }
        selectedSidebarItem = .smartPlaylist(playlist.id)
        savePersistedState()
    }
    
    public func deleteSmartPlaylist(_ playlist: SIDSmartPlaylist) {
        smartPlaylists.removeAll { $0.id == playlist.id }
        if case .smartPlaylist(let id) = selectedSidebarItem, id == playlist.id {
            selectedSidebarItem = .allTunes
        }
        savePersistedState()
    }
    
    public func duplicateSmartPlaylist(_ playlist: SIDSmartPlaylist) {
        var copy = playlist
        copy.id = UUID()
        copy.name = "\(playlist.name) Copy"
        smartPlaylists.append(copy)
        selectedSidebarItem = .smartPlaylist(copy.id)
        savePersistedState()
    }
    
    public func tunes(for smartPlaylist: SIDSmartPlaylist) -> [SIDTuneItem] {
        return HVSCIndexManager.shared.evaluateSmartPlaylist(
            rules: smartPlaylist.rules,
            matchMode: smartPlaylist.matchMode,
            limit: smartPlaylist.limitCount,
            rootPath: rootPath
        )
    }
    
    public func count(for smartPlaylist: SIDSmartPlaylist) -> Int {
        return HVSCIndexManager.shared.countSmartPlaylistMatches(
            rules: smartPlaylist.rules,
            matchMode: smartPlaylist.matchMode,
            limit: smartPlaylist.limitCount
        )
    }
    
    public func count(rules: [SmartPlaylistRule], matchMode: SmartPlaylistMatchMode, limit: Int?) -> Int {
        return HVSCIndexManager.shared.countSmartPlaylistMatches(
            rules: rules,
            matchMode: matchMode,
            limit: limit
        )
    }
    
    private func defaultSmartPlaylists() -> [SIDSmartPlaylist] {
        return [
            SIDSmartPlaylist(
                name: "Rob Hubbard",
                matchMode: .all,
                rules: [SmartPlaylistRule(field: .author, op: .contains, value: "Hubbard")]
            ),
            SIDSmartPlaylist(
                name: "Martin Galway",
                matchMode: .all,
                rules: [SmartPlaylistRule(field: .author, op: .contains, value: "Galway")]
            ),
            SIDSmartPlaylist(
                name: "1987 Classics",
                matchMode: .all,
                rules: [SmartPlaylistRule(field: .released, op: .contains, value: "1987")]
            )
        ]
    }
    
    // MARK: - Export Support
    /// Returns an array of dictionary items for exporting to audio or PRG.
    /// Format: [["path": String, "title": String, "author": String, "subtune": Int, "loopCount": Int]]
    public func getItemsForExport() -> [[String: Any]] {
        var items: [[String: Any]] = []
        
        // 1. Try selected items from the active table view
        for path in selectedTunePaths {
            if let item = displayedItems.first(where: { ($0.path as NSString).standardizingPath == (path as NSString).standardizingPath }), !item.isDirectory {
                let sub = item.defaultSubtune > 0 ? item.defaultSubtune : 1
                items.append([
                    "path": item.path,
                    "title": item.title,
                    "author": item.author,
                    "subtune": sub,
                    "loopCount": 1
                ])
            } else {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue {
                    let tuneItem = SIDTuneItem.from(url: URL(fileURLWithPath: path))
                    let sub = tuneItem.defaultSubtune > 0 ? tuneItem.defaultSubtune : 1
                    items.append([
                        "path": tuneItem.path,
                        "title": tuneItem.title,
                        "author": tuneItem.author,
                        "subtune": sub,
                        "loopCount": 1
                    ])
                }
            }
        }
        
        if !items.isEmpty {
            return items
        }
        
        // 2. Fall back to currently loaded/playing tune in SIDPlayer
        if let meta = SIDPlayer.shared.metadata, !meta.filePath.isEmpty {
            let currentSub = SIDPlayer.shared.currentSubtune
            let sub = currentSub > 0 ? currentSub : (meta.defaultSubtune > 0 ? meta.defaultSubtune : 1)
            return [[
                "path": meta.filePath,
                "title": meta.title,
                "author": meta.author,
                "subtune": sub,
                "loopCount": 1
            ]]
        }
        
        // 3. Fall back to first playable tune in displayed items
        if let first = displayedItems.first(where: { !$0.isDirectory }) {
            let sub = first.defaultSubtune > 0 ? first.defaultSubtune : 1
            return [[
                "path": first.path,
                "title": first.title,
                "author": first.author,
                "subtune": sub,
                "loopCount": 1
            ]]
        }
        
        return []
    }
    
    // MARK: - Random Tune Navigation
    /// Efficiently selects a random .sid tune from the specified root or library root collection
    public func pathOfRandomCollectionItem(in root: String? = nil) -> String? {
        let basePath = root ?? rootPath
        guard !basePath.isEmpty, FileManager.default.fileExists(atPath: basePath) else { return nil }
        
        let fm = FileManager.default
        for _ in 0..<15 {
            var current = basePath
            for _ in 0..<8 {
                guard let entries = try? fm.contentsOfDirectory(atPath: current) else { break }
                let visible = entries.filter { !$0.hasPrefix(".") && $0.uppercased() != "DOCUMENTS" }
                guard !visible.isEmpty, let choice = visible.randomElement() else { break }
                let fullPath = (current as NSString).appendingPathComponent(choice)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir) {
                    if isDir.boolValue {
                        current = fullPath
                    } else if choice.lowercased().hasSuffix(".sid") {
                        return fullPath
                    }
                }
            }
        }
        return nil
    }
}
