//
//  SIDHeaderReader.swift
//  SIDPLAY
//
//  Ultra-fast binary header parser for PSID and RSID C64 audio files.
//

import Foundation

public struct SIDHeaderInfo: Sendable, Equatable {
    public let format: String        // "PSID" or "RSID"
    public let version: UInt16
    public let loadAddress: UInt16
    public let initAddress: UInt16
    public let playAddress: UInt16
    public let subtuneCount: Int
    public let defaultSubtune: Int
    public let title: String
    public let author: String
    public let released: String
    public let chipModel: String     // "MOS 6581", "MOS 8580", or "Unknown"
    public let clockSpeed: String    // "PAL", "NTSC", or "Any"
}

public enum SIDHeaderReader {
    public static func parse(url: URL) -> SIDHeaderInfo? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        
        let headerData: Data
        do {
            guard let data = try handle.read(upToCount: 128), data.count >= 0x76 else {
                return nil
            }
            headerData = data
        } catch {
            return nil
        }
        
        return parse(data: headerData)
    }
    
    public static func parse(data: Data) -> SIDHeaderInfo? {
        guard data.count >= 0x76 else { return nil }
        
        // Magic ID (PSID or RSID)
        guard let magic = String(data: data[0..<4], encoding: .ascii),
              magic == "PSID" || magic == "RSID" else {
            return nil
        }
        
        let version = readUInt16BigEndian(data, offset: 0x04)
        var loadAddr = readUInt16BigEndian(data, offset: 0x08)
        let initAddr = readUInt16BigEndian(data, offset: 0x0A)
        let playAddr = readUInt16BigEndian(data, offset: 0x0C)
        let subtunes = Int(readUInt16BigEndian(data, offset: 0x0E))
        var defSubtune = Int(readUInt16BigEndian(data, offset: 0x10))
        if defSubtune < 1 { defSubtune = 1 }
        
        let title = readString(data, offset: 0x16, length: 32)
        let author = readString(data, offset: 0x36, length: 32)
        let released = readString(data, offset: 0x56, length: 32)
        
        var chipModel = "Unknown"
        var clockSpeed = "PAL"
        
        if version >= 2 && data.count >= 0x78 {
            let flags = readUInt16BigEndian(data, offset: 0x76)
            let sidModelBits = (flags >> 4) & 0x03
            switch sidModelBits {
            case 1: chipModel = "MOS 6581"
            case 2: chipModel = "MOS 8580"
            case 3: chipModel = "MOS 6581 + 8580"
            default: chipModel = "MOS 6581"
            }
            
            let clockBits = (flags >> 2) & 0x03
            switch clockBits {
            case 1: clockSpeed = "PAL"
            case 2: clockSpeed = "NTSC"
            case 3: clockSpeed = "PAL / NTSC"
            default: clockSpeed = "PAL"
            }
            
            if version >= 3 && data.count >= 0x7B {
                let base2 = data[0x7A]
                if base2 != 0 && (base2 & 1) == 0 && (base2 > 0x41) && (base2 < 0x80 || base2 > 0xDF) {
                    var sidCount = 2
                    let m2Bits = (flags >> 6) & 0x03
                    let chip2Model = (m2Bits == 2) ? "MOS 8580" : (m2Bits == 1 ? "MOS 6581" : chipModel)
                    var chip3Model = chipModel
                    
                    if version >= 4 && data.count >= 0x7C {
                        let base3 = data[0x7B]
                        if base3 != 0 && base3 != base2 && (base3 & 1) == 0 && (base3 > 0x41) && (base3 < 0x80 || base3 > 0xDF) {
                            sidCount = 3
                            let m3Bits = (flags >> 8) & 0x03
                            chip3Model = (m3Bits == 2) ? "MOS 8580" : (m3Bits == 1 ? "MOS 6581" : chipModel)
                        }
                    }
                    
                    if sidCount == 2 {
                        if chipModel == chip2Model {
                            chipModel = "2x \(chipModel)"
                        } else {
                            chipModel = "2x (\(chipModel) + \(chip2Model))"
                        }
                    } else if sidCount >= 3 {
                        if chipModel == chip2Model && chip2Model == chip3Model {
                            chipModel = "\(sidCount)x \(chipModel)"
                        } else {
                            chipModel = "\(sidCount)x SID (Mixed)"
                        }
                    }
                }
            }
        }
        
        return SIDHeaderInfo(
            format: magic,
            version: version,
            loadAddress: loadAddr,
            initAddress: initAddr,
            playAddress: playAddr,
            subtuneCount: max(1, subtunes),
            defaultSubtune: defSubtune,
            title: title.isEmpty ? "Unknown" : title,
            author: author.isEmpty ? "Unknown" : author,
            released: released.isEmpty ? "Unknown" : released,
            chipModel: chipModel,
            clockSpeed: clockSpeed
        )
    }
    
    private static func readUInt16BigEndian(_ data: Data, offset: Int) -> UInt16 {
        guard offset + 1 < data.count else { return 0 }
        return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }
    
    private static func readString(_ data: Data, offset: Int, length: Int) -> String {
        guard offset + length <= data.count else { return "" }
        let slice = data[offset..<(offset + length)]
        // Strip trailing nulls or whitespace
        if let nullIdx = slice.firstIndex(of: 0) {
            let validSlice = slice[offset..<nullIdx]
            return String(data: validSlice, encoding: .isoLatin1)?.trimmingCharacters(in: .whitespaces) ?? ""
        }
        return String(data: slice, encoding: .isoLatin1)?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}
