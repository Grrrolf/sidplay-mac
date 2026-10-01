//
//  STILManager.swift
//  SIDPLAY
//
//  High-performance in-memory parser and query engine for the High Voltage
//  SID Collection STIL (SID Tune Information List - DOCUMENTS/STIL.txt).
//

import Foundation

public struct STILField: Identifiable, Sendable {
    public var id: String { "\(name):\(value.prefix(20))" }
    public let name: String     // TITLE, ARTIST, AUTHOR, COMMENT, etc.
    public let value: String
    
    public init(name: String, value: String) {
        self.name = name
        self.value = value
    }
}

public struct STILSubtune: Identifiable, Sendable {
    public var id: Int { subtuneNumber }
    public let subtuneNumber: Int
    public let fields: [STILField]
    
    public init(subtuneNumber: Int, fields: [STILField]) {
        self.subtuneNumber = subtuneNumber
        self.fields = fields
    }
}

public struct STILEntry: Sendable {
    public let path: String
    public let globalFields: [STILField]
    public let subtunes: [STILSubtune]
    public let rawText: String
    
    public init(path: String, globalFields: [STILField], subtunes: [STILSubtune], rawText: String) {
        self.path = path
        self.globalFields = globalFields
        self.subtunes = subtunes
        self.rawText = rawText
    }
    
    public var title: String? {
        globalFields.first(where: { $0.name == "TITLE" })?.value
    }
    
    public var artist: String? {
        globalFields.first(where: { $0.name == "ARTIST" || $0.name == "AUTHOR" })?.value
    }
    
    public var comment: String? {
        globalFields.first(where: { $0.name == "COMMENT" || $0.name == "NOTE" })?.value
    }
}

public final class STILManager: ObservableObject, @unchecked Sendable {
    public static let shared = STILManager()
    
    @Published public private(set) var isLoaded: Bool = false
    @Published public private(set) var totalEntries: Int = 0
    
    private let lock = NSLock()
    private var entries: [String: STILEntry] = [:]
    private var loadedRootPath: String = ""
    
    public init() {}
    
    public func start(rootPath: String) {
        lock.lock()
        if loadedRootPath == rootPath && !entries.isEmpty {
            lock.unlock()
            return
        }
        loadedRootPath = rootPath
        lock.unlock()
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            self.loadSTIL(rootPath: rootPath)
        }
    }
    
    private func loadSTIL(rootPath: String) {
        let stilPath = (rootPath as NSString).appendingPathComponent("DOCUMENTS/STIL.txt")
        guard FileManager.default.fileExists(atPath: stilPath),
              let data = try? Data(contentsOf: URL(fileURLWithPath: stilPath)),
              let content = String(data: data, encoding: .isoLatin1) ?? String(data: data, encoding: .utf8) else {
            return
        }
        
        var parsedEntries: [String: STILEntry] = [:]
        parsedEntries.reserveCapacity(20000)
        
        var curPath: String?
        var curLines: [String] = []
        
        func commitCurrent() {
            guard let path = curPath, !curLines.isEmpty else { return }
            let text = curLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let entry = Self.parseEntry(path: path, text: text)
                parsedEntries[path] = entry
            }
            curLines = []
        }
        
        content.enumerateLines { line, _ in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("/") && trimmed.hasSuffix(".sid") {
                commitCurrent()
                curPath = trimmed
            } else if curPath != nil {
                if line.hasPrefix("###") || (line.hasPrefix("/") && !trimmed.hasSuffix(".sid")) {
                    commitCurrent()
                    curPath = nil
                } else {
                    curLines.append(line)
                }
            }
        }
        commitCurrent()
        
        lock.lock()
        self.entries = parsedEntries
        let count = parsedEntries.count
        lock.unlock()
        
        DispatchQueue.main.async {
            self.totalEntries = count
            self.isLoaded = true
        }
    }
    
    // MARK: - Path Lookup
    
    public func entry(forPath path: String) -> STILEntry? {
        let relKey = Self.normalizeToHVSCKey(path)
        lock.lock()
        let result = entries[relKey]
        lock.unlock()
        return result
    }
    
    public static func normalizeToHVSCKey(_ path: String) -> String {
        for prefix in ["/MUSICIANS/", "/DEMOS/", "/GAMES/", "/DOCUMENTS/"] {
            if let range = path.range(of: prefix) {
                return String(path[range.lowerBound...])
            }
        }
        return path.hasPrefix("/") ? path : "/\(path)"
    }
    
    // MARK: - Entry Parsing
    
    private static func parseEntry(path: String, text: String) -> STILEntry {
        var globalFields: [STILField] = []
        var subtunes: [STILSubtune] = []
        
        var curSubtuneNum: Int? = nil
        var curFields: [STILField] = []
        
        var curTag: String? = nil
        var curVal: [String] = []
        
        func flushField() {
            guard let tag = curTag else { return }
            let val = curVal.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            if !val.isEmpty {
                curFields.append(STILField(name: tag, value: val))
            }
            curTag = nil
            curVal = []
        }
        
        func flushSubtune() {
            flushField()
            if let num = curSubtuneNum {
                subtunes.append(STILSubtune(subtuneNumber: num, fields: curFields))
            } else {
                globalFields.append(contentsOf: curFields)
            }
            curFields = []
        }
        
        let validTags: Set<String> = [
            "TITLE", "ARTIST", "AUTHOR", "COMMENT", "NAME", "NOTE",
            "ALBUM", "COMPOSER", "COPYRIGHT", "WWW", "TIMESTAMP"
        ]
        
        let lines = text.components(separatedBy: "\n")
        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            // Subtune marker e.g. "(#1)" or "(#2)"
            if line.hasPrefix("(#") && line.hasSuffix(")") {
                let numStr = line.dropFirst(2).dropLast(1)
                if let num = Int(numStr) {
                    flushSubtune()
                    curSubtuneNum = num
                    continue
                }
            }
            
            // Field Tag: Value
            if let colonIdx = line.firstIndex(of: ":"), colonIdx < line.index(line.startIndex, offsetBy: min(15, line.count)) {
                let potentialTag = String(line[..<colonIdx]).trimmingCharacters(in: .whitespaces).uppercased()
                if validTags.contains(potentialTag) {
                    flushField()
                    curTag = potentialTag
                    let afterColon = String(line[line.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                    curVal.append(afterColon)
                    continue
                }
            }
            
            // Continuation line
            if curTag != nil {
                curVal.append(line)
            }
        }
        
        flushSubtune()
        return STILEntry(path: path, globalFields: globalFields, subtunes: subtunes, rawText: text)
    }
}
