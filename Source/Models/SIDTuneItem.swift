//
//  SIDTuneItem.swift
//  SIDPLAY
//
//  Unified model representing a SID tune or folder in the library browser.
//

import Foundation

public struct SIDTuneItem: Identifiable, Hashable, Sendable {
    public var id: String { path }
    
    public let path: String
    public let name: String
    public let isDirectory: Bool
    public let title: String
    public let author: String
    public let released: String
    public let subtuneCount: Int
    public let defaultSubtune: Int
    public let chipModel: String
    public let format: String
    public let loadAddress: UInt16
    public let initAddress: UInt16
    public let playAddress: UInt16
    public let fileSize: Int
    public let songLengthSeconds: Int
    public let folderDisplayPath: String
    
    public init(
        path: String,
        isDirectory: Bool,
        title: String = "",
        author: String = "",
        released: String = "",
        subtuneCount: Int = 1,
        defaultSubtune: Int = 1,
        chipModel: String = "MOS 6581",
        format: String = "PSID",
        loadAddress: UInt16 = 0,
        initAddress: UInt16 = 0,
        playAddress: UInt16 = 0,
        fileSize: Int = 0,
        songLengthSeconds: Int = 0,
        folderDisplayPath: String? = nil
    ) {
        self.path = path
        let url = URL(fileURLWithPath: path)
        self.name = url.lastPathComponent
        self.isDirectory = isDirectory
        self.title = title.isEmpty ? (isDirectory ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent) : title
        self.author = author.isEmpty ? (isDirectory ? "" : "Unknown") : author
        self.released = released
        self.subtuneCount = subtuneCount
        self.defaultSubtune = defaultSubtune
        self.chipModel = chipModel
        self.format = format
        self.loadAddress = loadAddress
        self.initAddress = initAddress
        self.playAddress = playAddress
        self.fileSize = fileSize
        self.songLengthSeconds = songLengthSeconds
        
        if let explicit = folderDisplayPath {
            self.folderDisplayPath = explicit
        } else {
            let parent = (path as NSString).deletingLastPathComponent
            var computed = (parent as NSString).lastPathComponent
            for prefix in ["/MUSICIANS/", "/DEMOS/", "/GAMES/", "/DOCUMENTS/"] {
                if let range = parent.range(of: prefix) {
                    let sub = String(parent[range.lowerBound...])
                    computed = sub.hasPrefix("/") ? String(sub.dropFirst()) : sub
                    break
                }
            }
            self.folderDisplayPath = computed
        }
    }
    
    /// Create item by parsing file metadata on disk
    public static func from(url: URL) -> SIDTuneItem {
        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir)
        
        if isDir.boolValue {
            return SIDTuneItem(path: url.path, isDirectory: true)
        }
        
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        
        if let info = SIDHeaderReader.parse(url: url) {
            let length = SIDEngineBridge.songLength(forPath: url.path, subtune: info.defaultSubtune)
            return SIDTuneItem(
                path: url.path,
                isDirectory: false,
                title: info.title,
                author: info.author,
                released: info.released,
                subtuneCount: info.subtuneCount,
                defaultSubtune: info.defaultSubtune,
                chipModel: info.chipModel,
                format: info.format,
                loadAddress: info.loadAddress,
                initAddress: info.initAddress,
                playAddress: info.playAddress,
                fileSize: fileSize,
                songLengthSeconds: length
            )
        } else {
            let length = SIDEngineBridge.songLength(forPath: url.path, subtune: 1)
            return SIDTuneItem(
                path: url.path,
                isDirectory: false,
                title: url.deletingPathExtension().lastPathComponent,
                author: "Unknown",
                released: "",
                fileSize: fileSize,
                songLengthSeconds: length
            )
        }
    }
    
    public var formattedDuration: String {
        if songLengthSeconds <= 0 {
            return "--:--"
        }
        let mins = songLengthSeconds / 60
        let secs = songLengthSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
    
    public var formattedAddresses: String {
        String(format: "L:$%04X I:$%04X P:$%04X", loadAddress, initAddress, playAddress)
    }
}
