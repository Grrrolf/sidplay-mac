//
//  SIDTuneMetadata.swift
//  SIDPLAY
//
//  Strongly-typed metadata model for C64 SID music files.
//

import Foundation

/// Detailed model and address specification for an individual SID chip in a tune.
public struct SIDChipInfo: Identifiable, Sendable, Equatable {
    public var id: Int { chipIndex }
    public let chipIndex: Int
    public let baseAddress: UInt16
    public let model: String
    
    public init(chipIndex: Int, baseAddress: UInt16, model: String) {
        self.chipIndex = chipIndex
        self.baseAddress = baseAddress
        self.model = model
    }
    
    public var formattedAddress: String {
        String(format: "$%04X", baseAddress)
    }
    
    public var displayText: String {
        "SID \(chipIndex + 1): \(model) (\(formattedAddress))"
    }
}

public struct SIDTuneMetadata: Identifiable, Sendable, Equatable {
    public var id: String { filePath }
    
    public let filePath: String
    public let fileName: String
    public let title: String
    public let author: String
    public let releaseInfo: String
    public let format: String
    public let chipModel: String
    public let loadAddress: UInt16
    public let initAddress: UInt16
    public let playAddress: UInt16
    public let fileSize: Int
    public let songLengthSeconds: Int
    public let subtuneCount: Int
    public let defaultSubtune: Int
    public let sidChipCount: Int
    public let secondSidAddress: UInt16
    public let thirdSidAddress: UInt16
    public let fourthSidAddress: UInt16
    public let chips: [SIDChipInfo]
    
    public init(
        filePath: String,
        title: String,
        author: String,
        releaseInfo: String,
        format: String,
        chipModel: String,
        loadAddress: UInt16,
        initAddress: UInt16,
        playAddress: UInt16,
        fileSize: Int,
        songLengthSeconds: Int,
        subtuneCount: Int,
        defaultSubtune: Int,
        sidChipCount: Int = 1,
        secondSidAddress: UInt16 = 0,
        thirdSidAddress: UInt16 = 0,
        fourthSidAddress: UInt16 = 0,
        chips: [SIDChipInfo] = []
    ) {
        self.filePath = filePath
        self.fileName = (filePath as NSString).lastPathComponent
        self.title = title.isEmpty ? (filePath as NSString).lastPathComponent : title
        self.author = author.isEmpty ? "Unknown" : author
        self.releaseInfo = releaseInfo
        self.format = format
        self.chipModel = chipModel
        self.loadAddress = loadAddress
        self.initAddress = initAddress
        self.playAddress = playAddress
        self.fileSize = fileSize
        self.songLengthSeconds = songLengthSeconds
        self.subtuneCount = subtuneCount
        self.defaultSubtune = defaultSubtune
        self.sidChipCount = sidChipCount
        self.secondSidAddress = secondSidAddress
        self.thirdSidAddress = thirdSidAddress
        self.fourthSidAddress = fourthSidAddress
        
        if !chips.isEmpty {
            self.chips = chips
        } else {
            var list: [SIDChipInfo] = [
                SIDChipInfo(chipIndex: 0, baseAddress: 0xD400, model: chipModel)
            ]
            if sidChipCount >= 2 {
                list.append(SIDChipInfo(chipIndex: 1, baseAddress: secondSidAddress > 0 ? secondSidAddress : 0xD500, model: chipModel))
            }
            if sidChipCount >= 3 {
                list.append(SIDChipInfo(chipIndex: 2, baseAddress: thirdSidAddress > 0 ? thirdSidAddress : 0xDE00, model: chipModel))
            }
            if sidChipCount >= 4 {
                list.append(SIDChipInfo(chipIndex: 3, baseAddress: fourthSidAddress > 0 ? fourthSidAddress : 0xDF00, model: chipModel))
            }
            self.chips = list
        }
    }
    
    public var isMultiSID: Bool {
        sidChipCount > 1
    }
    
    public var sidConfigurationDescription: String {
        if chips.isEmpty {
            if sidChipCount <= 1 {
                return "\(chipModel) ($D400)"
            } else if sidChipCount == 2 {
                let addr2 = secondSidAddress > 0 ? String(format: "$%04X", secondSidAddress) : "$D500"
                return "2x SID ($D400, \(addr2))"
            } else {
                let addr2 = secondSidAddress > 0 ? String(format: "$%04X", secondSidAddress) : "$D500"
                let addr3 = thirdSidAddress > 0 ? String(format: "$%04X", thirdSidAddress) : "$DE00"
                return "\(sidChipCount)x SID ($D400, \(addr2), \(addr3))"
            }
        }
        
        if chips.count == 1 {
            return "\(chips[0].model) (\(chips[0].formattedAddress))"
        }
        
        let firstModel = chips[0].model
        let allSame = chips.allSatisfy { $0.model == firstModel }
        
        if allSame {
            let addrs = chips.map { $0.formattedAddress }.joined(separator: ", ")
            return "\(chips.count)x \(firstModel) (\(addrs))"
        } else {
            let details = chips.map { "SID \($0.chipIndex + 1): \($0.model) (\($0.formattedAddress))" }.joined(separator: ", ")
            return "\(chips.count)x SID (\(details))"
        }
    }
    
    public var formattedLoadAddress: String {
        String(format: "$%04X", loadAddress)
    }
    
    public var formattedInitAddress: String {
        String(format: "$%04X", initAddress)
    }
    
    public var formattedPlayAddress: String {
        String(format: "$%04X", playAddress)
    }
    
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
    
    public var formattedSongLength: String {
        if songLengthSeconds <= 0 {
            return "--:--"
        }
        let minutes = songLengthSeconds / 60
        let seconds = songLengthSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
