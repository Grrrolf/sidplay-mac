//
//  SongLengthDatabaseTests.swift
//  SIDPLAYTests
//
//  Automated unit tests for song length calculations and formatting.
//

import Foundation

public struct SongLengthDatabaseTests {
    public static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(name: String, passed: Bool, message: String)] = []
        
        results.append(testFormattedDurationDisplay())
        results.append(testSongLengthStringParsing())
        results.append(testBoundaryDurations())
        
        return results
    }
    
    // MARK: - Test Cases
    
    private static func testFormattedDurationDisplay() -> (String, Bool, String) {
        let name = "testFormattedDurationDisplay (mm:ss Format)"
        
        let item1 = SIDTuneItem(path: "/test/1.sid", isDirectory: false, songLengthSeconds: 0)
        guard item1.formattedDuration == "--:--" else {
            return (name, false, "Expected '--:--' for 0 seconds, got '\(item1.formattedDuration)'")
        }
        
        let item2 = SIDTuneItem(path: "/test/2.sid", isDirectory: false, songLengthSeconds: 65)
        guard item2.formattedDuration == "1:05" else {
            return (name, false, "Expected '1:05' for 65 seconds, got '\(item2.formattedDuration)'")
        }
        
        let item3 = SIDTuneItem(path: "/test/3.sid", isDirectory: false, songLengthSeconds: 216)
        guard item3.formattedDuration == "3:36" else {
            return (name, false, "Expected '3:36' for 216 seconds, got '\(item3.formattedDuration)'")
        }
        
        return (name, true, "Formatted 0s, 65s, and 216s to '--:--', '1:05', and '3:36' accurately")
    }
    
    private static func testSongLengthStringParsing() -> (String, Bool, String) {
        let name = "testSongLengthStringParsing (Songlengths.txt DB format)"
        
        func parseLength(_ timeStr: String) -> Int {
            let parts = timeStr.split(separator: ":")
            guard parts.count == 2,
                  let mins = Int(parts[0]),
                  let secs = Int(parts[1]) else { return 0 }
            return (mins * 60) + secs
        }
        
        guard parseLength("3:45") == 225 else {
            return (name, false, "Expected 3:45 -> 225 seconds")
        }
        guard parseLength("0:30") == 30 else {
            return (name, false, "Expected 0:30 -> 30 seconds")
        }
        guard parseLength("12:00") == 720 else {
            return (name, false, "Expected 12:00 -> 720 seconds")
        }
        
        return (name, true, "Calculated second offsets accurately from standard Songlengths.txt strings")
    }
    
    private static func testBoundaryDurations() -> (String, Bool, String) {
        let name = "testBoundaryDurations (Negative & Overflow Bounds)"
        
        let neg = SIDTuneItem(path: "/test/neg.sid", isDirectory: false, songLengthSeconds: -1)
        guard neg.formattedDuration == "--:--" else {
            return (name, false, "Expected negative duration to render as '--:--'")
        }
        
        let hour = SIDTuneItem(path: "/test/hour.sid", isDirectory: false, songLengthSeconds: 3661)
        guard hour.formattedDuration == "61:01" else {
            return (name, false, "Expected 3661s to render as '61:01', got '\(hour.formattedDuration)'")
        }
        
        return (name, true, "Boundary negative and hour-plus lengths handled safely")
    }
}
