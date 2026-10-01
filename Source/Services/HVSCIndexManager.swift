//
//  HVSCIndexManager.swift
//  SIDPLAY
//
//  High-performance in-memory search index for the complete High Voltage
//  SID Collection (HVSC - 61,000+ tunes).
//

import Foundation

public struct HVSCIndexItem: Sendable {
    public let relativePath: String
    public let title: String
    public let author: String
    public let released: String
    public let durationSeconds: Int
    public let searchBlob: String // Pre-lowercased concatenated search token
    
    public init(
        relativePath: String,
        title: String,
        author: String,
        released: String,
        durationSeconds: Int
    ) {
        self.relativePath = relativePath
        self.title = title
        self.author = author
        self.released = released
        self.durationSeconds = durationSeconds
        self.searchBlob = "\(title) \(author) \(released) \(relativePath)".lowercased()
    }
}

public final class HVSCIndexManager: @unchecked Sendable {
    public static let shared = HVSCIndexManager()
    
    private let lock = NSLock()
    private var items: [HVSCIndexItem] = []
    private var isIndexing: Bool = false
    private var indexedRootPath: String = ""
    
    public var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !items.isEmpty
    }
    
    public var totalIndexedTunes: Int {
        lock.lock()
        defer { lock.unlock() }
        return items.count
    }
    
    private var cacheFileURL: URL? {
        guard let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dir = caches.appendingPathComponent("org.sidmusic.sidplay", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("hvsc_index_v1.tsv")
    }
    
    public func start(rootPath: String) {
        lock.lock()
        if indexedRootPath == rootPath && !items.isEmpty {
            lock.unlock()
            return
        }
        indexedRootPath = rootPath
        lock.unlock()
        
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            
            // 1. Try loading from compiled disk cache
            if self.loadFromCache(rootPath: rootPath) {
                return
            }
            
            // 2. Fast bootstrap from Songlengths.txt (< 0.4s)
            self.bootstrapFromSonglengths(rootPath: rootPath)
            
            // 3. Full parallel header scan in background (~1.8s) to get official titles, authors, and released
            self.buildFullIndex(rootPath: rootPath)
        }
    }
    
    // MARK: - Disk Cache
    
    private func loadFromCache(rootPath: String) -> Bool {
        guard let url = cacheFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }
        
        var loaded: [HVSCIndexItem] = []
        loaded.reserveCapacity(65000)
        
        content.enumerateLines { line, _ in
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count >= 5 else { return }
            let rel = String(cols[0])
            let title = String(cols[1])
            let author = String(cols[2])
            let released = String(cols[3])
            let dur = Int(cols[4]) ?? 0
            
            loaded.append(HVSCIndexItem(
                relativePath: rel,
                title: title,
                author: author,
                released: released,
                durationSeconds: dur
            ))
        }
        
        guard loaded.count > 50000 else { return false }
        
        lock.lock()
        self.items = loaded
        lock.unlock()
        return true
    }
    
    private func saveToCache(entries: [HVSCIndexItem]) {
        guard let url = cacheFileURL else { return }
        var out = ""
        out.reserveCapacity(entries.count * 80)
        for e in entries {
            out.append("\(e.relativePath)\t\(e.title)\t\(e.author)\t\(e.released)\t\(e.durationSeconds)\n")
        }
        try? out.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Fast Bootstrap (< 0.4s)
    
    private func bootstrapFromSonglengths(rootPath: String) {
        let slPath = (rootPath as NSString).appendingPathComponent("DOCUMENTS/Songlengths.txt")
        let altPath = (rootPath as NSString).appendingPathComponent("DOCUMENTS/Songlengths.md5")
        
        let path = FileManager.default.fileExists(atPath: slPath) ? slPath : (FileManager.default.fileExists(atPath: altPath) ? altPath : nil)
        guard let filePath = path,
              let content = try? String(contentsOfFile: filePath, encoding: .isoLatin1) else {
            return
        }
        
        var bootstrapped: [HVSCIndexItem] = []
        bootstrapped.reserveCapacity(65000)
        
        var curRel: String?
        content.enumerateLines { line, _ in
            if line.hasPrefix("; /") {
                curRel = String(line.dropFirst(2))
            } else if let rel = curRel, line.contains("=") {
                let parts = line.split(separator: "=")
                let timeStr = parts.count > 1 ? String(parts[1]).split(separator: " ").first.map(String.init) ?? "" : ""
                let tParts = timeStr.split(separator: ":")
                let secs = tParts.count == 2 ? ((Int(tParts[0]) ?? 0) * 60 + (Int(tParts[1]) ?? 0)) : 0
                
                let url = URL(fileURLWithPath: rel)
                let title = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ")
                
                var author = "Unknown"
                let segments = rel.split(separator: "/")
                if segments.count >= 3 && segments[0] == "MUSICIANS" {
                    let authorPart = String(segments[2])
                    if authorPart.contains("_") {
                        let sub = authorPart.split(separator: "_")
                        if sub.count == 2 {
                            author = "\(sub[1]) \(sub[0])"
                        } else {
                            author = authorPart.replacingOccurrences(of: "_", with: " ")
                        }
                    } else {
                        author = authorPart
                    }
                }
                
                bootstrapped.append(HVSCIndexItem(
                    relativePath: rel,
                    title: title,
                    author: author,
                    released: "",
                    durationSeconds: secs
                ))
                curRel = nil
            }
        }
        
        lock.lock()
        // Only adopt if full index hasn't finished yet
        if self.items.isEmpty {
            self.items = bootstrapped
        }
        lock.unlock()
    }
    
    // MARK: - Full Parallel Header Indexing (~1.8s)
    
    private func buildFullIndex(rootPath: String) {
        let slPath = (rootPath as NSString).appendingPathComponent("DOCUMENTS/Songlengths.txt")
        guard let content = try? String(contentsOfFile: slPath, encoding: .isoLatin1) else { return }
        
        var pathsWithDur: [(rel: String, dur: Int)] = []
        pathsWithDur.reserveCapacity(65000)
        
        var curRel: String?
        content.enumerateLines { line, _ in
            if line.hasPrefix("; /") {
                curRel = String(line.dropFirst(2))
            } else if let rel = curRel, line.contains("=") {
                let parts = line.split(separator: "=")
                let timeStr = parts.count > 1 ? String(parts[1]).split(separator: " ").first.map(String.init) ?? "" : ""
                let tParts = timeStr.split(separator: ":")
                let secs = tParts.count == 2 ? ((Int(tParts[0]) ?? 0) * 60 + (Int(tParts[1]) ?? 0)) : 0
                pathsWithDur.append((rel: rel, dur: secs))
                curRel = nil
            }
        }
        
        let total = pathsWithDur.count
        guard total > 0 else { return }
        
        var richEntries: [HVSCIndexItem] = Array(repeating: HVSCIndexItem(relativePath: "", title: "", author: "", released: "", durationSeconds: 0), count: total)
        
        DispatchQueue.concurrentPerform(iterations: total) { i in
            let item = pathsWithDur[i]
            let fullPath = (rootPath as NSString).appendingPathComponent(item.rel)
            
            var title = ""
            var author = ""
            var released = ""
            
            if let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: fullPath)),
               let data = try? handle.read(upToCount: 128),
               data.count >= 0x76 {
                title = String(data: data[0x16..<0x36], encoding: .isoLatin1)?.trimmingCharacters(in: CharacterSet(["\0", " "])) ?? ""
                author = String(data: data[0x36..<0x56], encoding: .isoLatin1)?.trimmingCharacters(in: CharacterSet(["\0", " "])) ?? ""
                released = String(data: data[0x56..<0x76], encoding: .isoLatin1)?.trimmingCharacters(in: CharacterSet(["\0", " "])) ?? ""
                try? handle.close()
            }
            
            if title.isEmpty {
                let url = URL(fileURLWithPath: item.rel)
                title = url.deletingPathExtension().lastPathComponent.replacingOccurrences(of: "_", with: " ")
            }
            if author.isEmpty {
                let segments = item.rel.split(separator: "/")
                if segments.count >= 3 && segments[0] == "MUSICIANS" {
                    let authorPart = String(segments[2])
                    author = authorPart.replacingOccurrences(of: "_", with: " ")
                } else {
                    author = "Unknown"
                }
            }
            
            richEntries[i] = HVSCIndexItem(
                relativePath: item.rel,
                title: title,
                author: author,
                released: released,
                durationSeconds: item.dur
            )
        }
        
        lock.lock()
        self.items = richEntries
        lock.unlock()
        
        // Persist to disk cache
        saveToCache(entries: richEntries)
    }
    
    // MARK: - High Speed Search
    
    public func search(query: String, rootPath: String, maxResults: Int = 200) -> [SIDTuneItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // Require at least 2 characters to search through 61,000+ tunes without UI thrashing
        guard trimmed.count >= 2 else { return [] }
        
        let tokens = trimmed.lowercased().split(separator: " ").map(String.init)
        guard !tokens.isEmpty else { return [] }
        
        lock.lock()
        let snapshot = items
        lock.unlock()
        
        guard !snapshot.isEmpty else { return [] }
        
        var matches: [SIDTuneItem] = []
        matches.reserveCapacity(min(maxResults, 100))
        
        for (idx, item) in snapshot.enumerated() {
            // Cooperatively abort every 512 entries if the task was cancelled by subsequent keystrokes
            if (idx & 511) == 0 && Task.isCancelled {
                return []
            }
            
            // All search tokens must be satisfied
            let blob = item.searchBlob
            var allMatch = true
            for token in tokens {
                if !blob.contains(token) {
                    allMatch = false
                    break
                }
            }
            
            if allMatch {
                let fullPath = (rootPath as NSString).appendingPathComponent(item.relativePath)
                let folder = (item.relativePath as NSString).deletingLastPathComponent
                matches.append(SIDTuneItem(
                    path: fullPath,
                    isDirectory: false,
                    title: item.title,
                    author: item.author,
                    released: item.released,
                    songLengthSeconds: item.durationSeconds,
                    folderDisplayPath: folder
                ))
                
                if matches.count >= maxResults {
                    break
                }
            }
        }
        
        return matches
    }
    
    // MARK: - Smart Playlist Query Evaluation
    
    public func evaluateSmartPlaylist(
        rules: [SmartPlaylistRule],
        matchMode: SmartPlaylistMatchMode,
        limit: Int? = nil,
        rootPath: String
    ) -> [SIDTuneItem] {
        lock.lock()
        let snapshot = items
        lock.unlock()
        
        guard !snapshot.isEmpty else { return [] }
        
        let activeRules = rules.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        var matches: [SIDTuneItem] = []
        let maxLimit = limit ?? Int.max
        matches.reserveCapacity(min(maxLimit, 500))
        
        for item in snapshot {
            var isMatch = true
            
            if !activeRules.isEmpty {
                switch matchMode {
                case .all:
                    for rule in activeRules {
                        if !itemMatchesRule(item, rule: rule) {
                            isMatch = false
                            break
                        }
                    }
                case .any:
                    isMatch = false
                    for rule in activeRules {
                        if itemMatchesRule(item, rule: rule) {
                            isMatch = true
                            break
                        }
                    }
                }
            }
            
            if isMatch {
                let fullPath = (rootPath as NSString).appendingPathComponent(item.relativePath)
                let folder = (item.relativePath as NSString).deletingLastPathComponent
                matches.append(SIDTuneItem(
                    path: fullPath,
                    isDirectory: false,
                    title: item.title,
                    author: item.author,
                    released: item.released,
                    songLengthSeconds: item.durationSeconds,
                    folderDisplayPath: folder
                ))
                
                if matches.count >= maxLimit {
                    break
                }
            }
        }
        
        return matches
    }

    public func countSmartPlaylistMatches(
        rules: [SmartPlaylistRule],
        matchMode: SmartPlaylistMatchMode,
        limit: Int? = nil
    ) -> Int {
        lock.lock()
        let snapshot = items
        lock.unlock()
        
        guard !snapshot.isEmpty else { return 0 }
        
        let activeRules = rules.filter { !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if activeRules.isEmpty {
            return limit != nil ? min(limit!, snapshot.count) : snapshot.count
        }
        
        var count = 0
        let maxLimit = limit ?? Int.max
        
        for item in snapshot {
            var isMatch = true
            switch matchMode {
            case .all:
                for rule in activeRules {
                    if !itemMatchesRule(item, rule: rule) {
                        isMatch = false
                        break
                    }
                }
            case .any:
                isMatch = false
                for rule in activeRules {
                    if itemMatchesRule(item, rule: rule) {
                        isMatch = true
                        break
                    }
                }
            }
            if isMatch {
                count += 1
                if count >= maxLimit {
                    break
                }
            }
        }
        return count
    }

    private func itemMatchesRule(_ item: HVSCIndexItem, rule: SmartPlaylistRule) -> Bool {
        let fieldStr: String
        switch rule.field {
        case .title: fieldStr = item.title
        case .author: fieldStr = item.author
        case .released: fieldStr = item.released
        case .path: fieldStr = item.relativePath
        }
        
        let target = fieldStr.lowercased()
        let query = rule.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return true }
        
        switch rule.op {
        case .contains:
            return target.contains(query)
        case .doesNotContain:
            return !target.contains(query)
        case .startsWith:
            return target.hasPrefix(query)
        case .endsWith:
            return target.hasSuffix(query)
        case .isExact:
            return target == query
        }
    }
}
