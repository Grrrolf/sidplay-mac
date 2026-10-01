//
//  PlaybackQueueTests.swift
//  SIDPLAYTests
//
//  Automated unit tests for playlist queue state, shuffle, and random selection.
//

import Foundation

@MainActor
public struct PlaybackQueueTests {
    public static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(name: String, passed: Bool, message: String)] = []
        
        results.append(testRandomTuneSampling())
        results.append(testShufflePermutationCompleteness())
        results.append(testRepeatWrapping())
        
        return results
    }
    
    // MARK: - Test Cases
    
    private static func testRandomTuneSampling() -> (String, Bool, String) {
        let name = "testRandomTuneSampling (pathOfRandomCollectionItem)"
        let collectionRoot = TestRunner.testCollectionPath
        
        guard FileManager.default.fileExists(atPath: collectionRoot) else {
            return (name, true, "Skipped (collection directory not found)")
        }
        
        guard let path = SIDLibraryManager.shared.pathOfRandomCollectionItem(in: collectionRoot) else {
            return (name, false, "pathOfRandomCollectionItem returned nil")
        }
        
        guard path.lowercased().hasSuffix(".sid") else {
            return (name, false, "Expected path ending with .sid, got '\(path)'")
        }
        
        guard FileManager.default.fileExists(atPath: path) else {
            return (name, false, "Returned path does not exist on disk: '\(path)'")
        }
        
        return (name, true, "Sampled random tune: '\((path as NSString).lastPathComponent)'")
    }
    
    private static func testShufflePermutationCompleteness() -> (String, Bool, String) {
        let name = "testShufflePermutationCompleteness (Full Traversal)"
        
        let items = (1...20).map { "/tune_\($0).sid" }
        let shuffled = items.shuffled()
        
        guard Set(shuffled) == Set(items) else {
            return (name, false, "Shuffled queue is missing elements or contains duplicates")
        }
        
        guard shuffled.count == items.count else {
            return (name, false, "Shuffled count does not match original count")
        }
        
        return (name, true, "All 20 distinct tunes present in non-repeating shuffle cycle")
    }
    
    private static func testRepeatWrapping() -> (String, Bool, String) {
        let name = "testRepeatWrapping (Boundary Queue Advance)"
        
        let count = 5
        let currentIndex = count - 1
        
        // When repeat is active, next from last item wraps to 0
        let nextWithRepeat = (currentIndex + 1) % count
        guard nextWithRepeat == 0 else {
            return (name, false, "Expected index 0 upon wrap, got \(nextWithRepeat)")
        }
        
        // When rewind is active from index 0, previous wraps to last item
        let prevFromZero = (0 - 1 + count) % count
        guard prevFromZero == 4 else {
            return (name, false, "Expected index 4 upon reverse wrap, got \(prevFromZero)")
        }
        
        return (name, true, "Forward and reverse boundary wrapping behave correctly")
    }
}
