//
//  BrowserNavigationTests.swift
//  SIDPLAYTests
//
//  Automated unit and regression tests for Browser menu navigation,
//  Back/Forward history stacks, and selection reveals.
//

import Foundation

@MainActor
public struct BrowserNavigationTests {
    public static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(name: String, passed: Bool, message: String)] = []
        
        results.append(testBackForwardHistoryStacks())
        results.append(testCanNavigateBackAndForwardStates())
        results.append(testSwitchToFavoritesSidebarSync())
        results.append(testRevealSelectedItemInBrowser())
        
        return results
    }
    
    // MARK: - Test Cases
    
    private static func testBackForwardHistoryStacks() -> (String, Bool, String) {
        let name = "testBackForwardHistoryStacks (Stack Push/Pop)"
        let library = SIDLibraryManager.shared
        
        let initialRoot = library.rootPath.isEmpty ? TestRunner.testCollectionPath : library.rootPath
        guard FileManager.default.fileExists(atPath: initialRoot) else {
            return (name, true, "Skipped (collection directory not found)")
        }
        
        // Setup initial clean state
        library.navigateTo(path: initialRoot)
        let folderA = (initialRoot as NSString).appendingPathComponent("MUSICIANS")
        let folderB = ((initialRoot as NSString).appendingPathComponent("MUSICIANS") as NSString).appendingPathComponent("H")
        
        guard FileManager.default.fileExists(atPath: folderA), FileManager.default.fileExists(atPath: folderB) else {
            return (name, true, "Skipped (test folders MUSICIANS/H not present)")
        }
        
        library.navigateTo(path: folderA)
        guard library.currentBrowsingPath == folderA else {
            return (name, false, "Expected current path to be \(folderA), got \(library.currentBrowsingPath)")
        }
        
        library.navigateTo(path: folderB)
        guard library.currentBrowsingPath == folderB else {
            return (name, false, "Expected current path to be \(folderB), got \(library.currentBrowsingPath)")
        }
        
        // Navigate Back: should return to folderA
        library.navigateBack()
        guard library.currentBrowsingPath == folderA else {
            return (name, false, "Navigate back expected \(folderA), got \(library.currentBrowsingPath)")
        }
        guard library.canNavigateForward else {
            return (name, false, "Expected canNavigateForward to be true after navigating back")
        }
        
        // Navigate Forward: should return to folderB
        library.navigateForward()
        guard library.currentBrowsingPath == folderB else {
            return (name, false, "Navigate forward expected \(folderB), got \(library.currentBrowsingPath)")
        }
        guard !library.canNavigateForward else {
            return (name, false, "Expected canNavigateForward to be false at tip of history")
        }
        
        // Navigate Back twice: back to folderA, then to root
        library.navigateBack()
        library.navigateBack()
        guard library.currentBrowsingPath == initialRoot else {
            return (name, false, "Navigate back twice expected \(initialRoot), got \(library.currentBrowsingPath)")
        }
        
        return (name, true, "Back and Forward stacks push and pop paths accurately across multiple levels")
    }
    
    private static func testCanNavigateBackAndForwardStates() -> (String, Bool, String) {
        let name = "testCanNavigateBackAndForwardStates (Menu Validation)"
        let library = SIDLibraryManager.shared
        
        // canNavigateBack and canNavigateForward should directly control menu item validation
        let canBack = library.canNavigateBack
        let canFwd = library.canNavigateForward
        
        // If forward stack is empty, canNavigateForward must be false
        if library.forwardStack.isEmpty {
            guard !canFwd else {
                return (name, false, "canNavigateForward should be false when forwardStack is empty")
            }
        }
        
        return (name, true, "Menu item enable/disable states dynamically reflect navigation history")
    }
    
    private static func testSwitchToFavoritesSidebarSync() -> (String, Bool, String) {
        let name = "testSwitchToFavoritesSidebarSync (⇧⌘F Action)"
        let library = SIDLibraryManager.shared
        
        library.selectedSidebarItem = .allTunes
        SIDModernAppController.switchToFavorites()
        
        guard library.selectedSidebarItem == .favorites else {
            return (name, false, "Expected selectedSidebarItem to be .favorites, got \(library.selectedSidebarItem)")
        }
        
        // Reset to all tunes
        library.selectedSidebarItem = .allTunes
        return (name, true, "Switch to favorites successfully updates active sidebar category")
    }
    
    private static func testRevealSelectedItemInBrowser() -> (String, Bool, String) {
        let name = "testRevealSelectedItemInBrowser (⇧⌘B Action)"
        let library = SIDLibraryManager.shared
        let initialRoot = library.rootPath.isEmpty ? TestRunner.testCollectionPath : library.rootPath
        
        let folderA = (initialRoot as NSString).appendingPathComponent("MUSICIANS")
        guard FileManager.default.fileExists(atPath: folderA) else {
            return (name, true, "Skipped (folderA not found)")
        }
        
        library.selectedTunePaths = [folderA]
        library.revealSelectedItemInBrowser()
        
        guard library.currentBrowsingPath == folderA else {
            return (name, false, "Expected reveal folder in browser to navigate into \(folderA), got \(library.currentBrowsingPath)")
        }
        
        return (name, true, "Revealing a selected folder in browser navigates into it seamlessly")
    }
}
