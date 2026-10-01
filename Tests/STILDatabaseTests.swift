//
//  STILDatabaseTests.swift
//  SIDPLAYTests
//
//  Automated unit tests for STIL HVSC key normalization and entry parsing.
//

import Foundation

public struct STILDatabaseTests {
    public static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(name: String, passed: Bool, message: String)] = []
        
        results.append(testNormalizeToHVSCKey())
        results.append(testSTILFieldExtraction())
        
        return results
    }
    
    // MARK: - Test Cases
    
    private static func testNormalizeToHVSCKey() -> (String, Bool, String) {
        let name = "testNormalizeToHVSCKey (Path Canonicalization)"
        
        let path1 = "/Users/Shared/HVSC/MUSICIANS/H/Hubbard_Rob/Commando.sid"
        let key1 = STILManager.normalizeToHVSCKey(path1)
        guard key1 == "/MUSICIANS/H/Hubbard_Rob/Commando.sid" else {
            return (name, false, "Expected '/MUSICIANS/H/Hubbard_Rob/Commando.sid', got '\(key1)'")
        }
        
        let path2 = "/Volumes/External/HVSC/GAMES/A-F/Archon.sid"
        let key2 = STILManager.normalizeToHVSCKey(path2)
        guard key2 == "/GAMES/A-F/Archon.sid" else {
            return (name, false, "Expected '/GAMES/A-F/Archon.sid', got '\(key2)'")
        }
        
        let path3 = "/DEMOS/Edge_of_Disgrace.sid"
        let key3 = STILManager.normalizeToHVSCKey(path3)
        guard key3 == "/DEMOS/Edge_of_Disgrace.sid" else {
            return (name, false, "Expected '/DEMOS/Edge_of_Disgrace.sid', got '\(key3)'")
        }
        
        return (name, true, "HVSC prefixes stripped to canonical database keys correctly")
    }
    
    private static func testSTILFieldExtraction() -> (String, Bool, String) {
        let name = "testSTILFieldExtraction (Entry Model)"
        
        let fields = [
            STILField(name: "TITLE", value: "Master of the Lamps"),
            STILField(name: "ARTIST", value: "Russell Lieblich"),
            STILField(name: "COMMENT", value: "Arranged from musical scale motifs.")
        ]
        let entry = STILEntry(path: "/MUSICIANS/L/Lieblich_Russell/Master_of_the_Lamps.sid", globalFields: fields, subtunes: [], rawText: "raw")
        
        guard entry.title == "Master of the Lamps" else {
            return (name, false, "Expected title 'Master of the Lamps', got '\(entry.title ?? "nil")'")
        }
        guard entry.artist == "Russell Lieblich" else {
            return (name, false, "Expected artist 'Russell Lieblich', got '\(entry.artist ?? "nil")'")
        }
        guard entry.comment?.contains("musical scale motifs") == true else {
            return (name, false, "Expected comment to contain 'musical scale motifs'")
        }
        
        return (name, true, "STILEntry fields correctly retrieved via typed property accessors")
    }
}
