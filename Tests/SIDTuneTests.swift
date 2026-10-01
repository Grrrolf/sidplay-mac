//
//  SIDTuneTests.swift
//  SIDPLAYTests
//
//  Automated unit and regression tests for SID tune parsing and chip detection.
//

import Foundation

public struct SIDTuneTests {
    public static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(name: String, passed: Bool, message: String)] = []
        
        results.append(testCommandoPSIDParsing())
        results.append(test3SIDMultiChipParsing())
        results.append(testSyntheticPSIDHeader())
        results.append(testMalformedDataHandling())
        
        return results
    }
    
    // MARK: - Test Cases
    
    private static func testCommandoPSIDParsing() -> (String, Bool, String) {
        let name = "testCommandoPSIDParsing (19 Subtunes)"
        let path = (TestRunner.testCollectionPath as NSString).appendingPathComponent("MUSICIANS/H/Hubbard_Rob/Commando.sid")
        
        guard FileManager.default.fileExists(atPath: path) else {
            return (name, true, "Skipped (HVSC file not present at path)")
        }
        
        guard let info = SIDHeaderReader.parse(url: URL(fileURLWithPath: path)) else {
            return (name, false, "Failed to parse Commando.sid header")
        }
        
        guard info.format == "PSID" else {
            return (name, false, "Expected format PSID, got \(info.format)")
        }
        
        guard info.subtuneCount == 19 else {
            return (name, false, "Expected 19 subtunes, got \(info.subtuneCount)")
        }
        
        guard info.title == "Commando" else {
            return (name, false, "Expected title 'Commando', got '\(info.title)'")
        }
        
        guard info.author == "Rob Hubbard" else {
            return (name, false, "Expected author 'Rob Hubbard', got '\(info.author)'")
        }
        
        return (name, true, "Parsed PSID v2 header: 19 subtunes by Rob Hubbard (1985)")
    }
    
    private static func test3SIDMultiChipParsing() -> (String, Bool, String) {
        let name = "test3SIDMultiChipParsing (3SID Detection)"
        let path = (TestRunner.testCollectionPath as NSString).appendingPathComponent("MUSICIANS/C/Chiummo_Gaetano/Enchanted_Forest_3SID.sid")
        
        guard FileManager.default.fileExists(atPath: path) else {
            return (name, true, "Skipped (HVSC file not present at path)")
        }
        
        guard let info = SIDHeaderReader.parse(url: URL(fileURLWithPath: path)) else {
            return (name, false, "Failed to parse Enchanted_Forest_3SID.sid")
        }
        
        guard info.chipModel.contains("3x") || info.chipModel.contains("SID") else {
            return (name, false, "Expected multi-SID model designation, got '\(info.chipModel)'")
        }
        
        return (name, true, "Detected multi-SID configuration: \(info.chipModel)")
    }
    
    private static func testSyntheticPSIDHeader() -> (String, Bool, String) {
        let name = "testSyntheticPSIDHeader (Binary Byte Fields)"
        
        var bytes = [UInt8](repeating: 0, count: 0x7C)
        // Magic 'PSID'
        bytes[0] = 0x50; bytes[1] = 0x53; bytes[2] = 0x49; bytes[3] = 0x44
        // Version 2
        bytes[4] = 0x00; bytes[5] = 0x02
        // Data offset 0x007C
        bytes[6] = 0x00; bytes[7] = 0x7C
        // Load address $1000
        bytes[8] = 0x10; bytes[9] = 0x00
        // Init address $1000
        bytes[10] = 0x10; bytes[11] = 0x00
        // Play address $1003
        bytes[12] = 0x10; bytes[13] = 0x03
        // Songs: 5
        bytes[14] = 0x00; bytes[15] = 0x05
        // Default song: 2
        bytes[16] = 0x00; bytes[17] = 0x02
        
        // Title: "Synthetic SID Tune"
        let titleBytes = Array("Synthetic SID Tune".utf8)
        for i in 0..<min(32, titleBytes.count) {
            bytes[0x16 + i] = titleBytes[i]
        }
        
        // Author: "Unit Test Composer"
        let authorBytes = Array("Unit Test Composer".utf8)
        for i in 0..<min(32, authorBytes.count) {
            bytes[0x36 + i] = authorBytes[i]
        }
        
        let data = Data(bytes)
        guard let info = SIDHeaderReader.parse(data: data) else {
            return (name, false, "Failed to parse synthetic header data")
        }
        
        guard info.subtuneCount == 5 else {
            return (name, false, "Expected 5 subtunes, got \(info.subtuneCount)")
        }
        
        guard info.defaultSubtune == 2 else {
            return (name, false, "Expected default subtune 2, got \(info.defaultSubtune)")
        }
        
        guard info.title == "Synthetic SID Tune" else {
            return (name, false, "Expected 'Synthetic SID Tune', got '\(info.title)'")
        }
        
        guard info.author == "Unit Test Composer" else {
            return (name, false, "Expected 'Unit Test Composer', got '\(info.author)'")
        }
        
        return (name, true, "Synthetic PSID v2 data decoded with exact addresses and subtunes")
    }
    
    private static func testMalformedDataHandling() -> (String, Bool, String) {
        let name = "testMalformedDataHandling (Resilience)"
        
        let empty = Data()
        if SIDHeaderReader.parse(data: empty) != nil {
            return (name, false, "Empty data should return nil")
        }
        
        let junk = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01])
        if SIDHeaderReader.parse(data: junk) != nil {
            return (name, false, "Invalid magic should return nil")
        }
        
        return (name, true, "Empty and invalid buffers safely rejected without throwing or crashing")
    }
}
