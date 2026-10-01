//
//  SIDModernAppController.swift
//  SIDPLAY
//
//  Window controller presenting the modern SwiftUI user interface.
//

import AppKit
import SwiftUI

@objc(SPSwiftModernAppController)
@MainActor
public final class SIDModernAppController: NSObject {
    @objc public static let shared = SIDModernAppController()
    
    private var window: NSWindow?
    private var hostingController: NSHostingController<SIDPlayerAppView>?
    private let autosaveFrameName = "SIDPLAYModernMainWindow"
    
    override private init() {
        super.init()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.clampCurrentWindow()
            }
        }
    }
    
    @objc public static var currentMainWindow: NSWindow? {
        return shared.window
    }
    
    @objc public static func showMainWindow() {
        shared.presentMainWindow()
    }
    
    @objc(openFileWithPath:)
    public static func openFile(path: String) {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: path, isDirectory: &isDir) {
            if isDir.boolValue {
                SIDLibraryManager.shared.navigateTo(path: path)
            } else {
                let parent = (path as NSString).deletingLastPathComponent
                SIDLibraryManager.shared.navigateTo(path: parent)
                let item = SIDTuneItem.from(url: URL(fileURLWithPath: path))
                SIDLibraryManager.shared.playItem(item)
            }
        }
        shared.presentMainWindow()
    }
    
    @objc public func performFindPanelAction(_ sender: Any?) {
        NotificationCenter.default.post(name: Notification.Name("SIDFocusSearchField"), object: nil)
    }
    
    @objc public func showAboutWindow(_ sender: Any? = nil) {
        SIDAboutWindowController.shared.showWindow()
    }
    
    @objc public static func openAbout() {
        SIDAboutWindowController.shared.showWindow()
    }
    
    @objc public func showPreferencesWindow(_ sender: Any? = nil) {
        SIDPreferencesWindowController.shared.showWindow()
    }
    
    @objc public static func openPreferences() {
        SIDPreferencesWindowController.shared.showWindow()
    }
    
    @objc public static func newPlaylist() {
        SIDLibraryManager.shared.promptNewPlaylist()
        shared.presentMainWindow()
    }
    
    @objc public static func newSmartPlaylist() {
        SIDLibraryManager.shared.promptNewSmartPlaylist()
        shared.presentMainWindow()
    }
    
    @objc public static func editSmartPlaylist() {
        SIDLibraryManager.shared.editSelectedSmartPlaylist()
        shared.presentMainWindow()
    }
    
    @objc public static func canEditSmartPlaylist() -> Bool {
        if case .smartPlaylist = SIDLibraryManager.shared.selectedSidebarItem {
            return true
        }
        return false
    }
    
    @objc public static func playNextInQueue() {
        SIDLibraryManager.shared.playNextInQueue()
    }
    
    @objc public static func playPreviousInQueue() {
        SIDLibraryManager.shared.playPreviousInQueue()
    }
    
    @objc public static func nextSubtune() {
        if !SIDPlayer.shared.nextSubtune() {
            SIDLibraryManager.shared.playNextInQueue()
        }
    }
    
    @objc public static func previousSubtune() {
        if !SIDPlayer.shared.previousSubtune() {
            SIDLibraryManager.shared.playPreviousInQueue()
        }
    }
    
    // MARK: - Control Menu Handlers
    private static var savedVolumeBeforeMute: Float = 0.8
    
    @objc public static func isPlaying() -> Bool {
        return SIDPlayer.shared.isPlaying
    }
    
    @objc public static func subtuneCount() -> Int {
        return SIDPlayer.shared.subtuneCount
    }
    
    @objc public static func currentSubtune() -> Int {
        return SIDPlayer.shared.currentSubtune
    }
    
    @objc public static func rootCollectionPath() -> String {
        return SIDLibraryManager.shared.rootPath
    }
    
    @objc public static func togglePlayPause() {
        if SIDPlayer.shared.isPlaying {
            SIDPlayer.shared.pause()
        } else {
            if SIDPlayer.shared.isTuneLoaded {
                SIDPlayer.shared.play()
            } else {
                let items = SIDLibraryManager.shared.displayedItems.filter { !$0.isDirectory }
                if let selectedPath = SIDLibraryManager.shared.selectedTunePaths.first,
                   let item = items.first(where: { ($0.path as NSString).standardizingPath == (selectedPath as NSString).standardizingPath }) {
                    SIDLibraryManager.shared.playItem(item)
                } else if let first = items.first {
                    SIDLibraryManager.shared.playItem(first)
                }
            }
        }
        shared.presentMainWindow()
    }
    
    @objc public static func stopPlayback() {
        SIDPlayer.shared.stop()
        shared.presentMainWindow()
    }
    
    @objc public static func playRandomTune() {
        if let path = SIDLibraryManager.shared.pathOfRandomCollectionItem() {
            openFile(path: path)
            return
        }
        let playable = SIDLibraryManager.shared.displayedItems.filter { !$0.isDirectory }
        if let randomItem = playable.randomElement() {
            SIDLibraryManager.shared.playItem(randomItem)
            shared.presentMainWindow()
        }
    }
    
    @objc(selectSubtuneWithTag:)
    public static func selectSubtune(tag: Int) {
        if tag > 0 && tag <= SIDPlayer.shared.subtuneCount {
            SIDPlayer.shared.selectSubtune(tag)
        }
    }
    
    @objc public static func increaseVolume() {
        let newVol = min(1.0, SIDPlayer.shared.volume + 0.05)
        SIDPlayer.shared.volume = newVol
    }
    
    @objc public static func decreaseVolume() {
        let newVol = max(0.0, SIDPlayer.shared.volume - 0.05)
        SIDPlayer.shared.volume = newVol
    }
    
    @objc public static func toggleMute() {
        if SIDPlayer.shared.volume > 0.001 {
            savedVolumeBeforeMute = SIDPlayer.shared.volume
            SIDPlayer.shared.volume = 0.0
        } else {
            SIDPlayer.shared.volume = savedVolumeBeforeMute > 0.001 ? savedVolumeBeforeMute : 0.8
        }
    }
    
    // MARK: - Browser Menu Handlers
    @objc public static func navigateBack() {
        SIDLibraryManager.shared.navigateBack()
        shared.presentMainWindow()
    }
    
    @objc public static func navigateForward() {
        SIDLibraryManager.shared.navigateForward()
        shared.presentMainWindow()
    }
    
    @objc public static func canNavigateBack() -> Bool {
        return SIDLibraryManager.shared.canNavigateBack
    }
    
    @objc public static func canNavigateForward() -> Bool {
        return SIDLibraryManager.shared.canNavigateForward
    }
    
    @objc public static func showCurrentSong() {
        SIDLibraryManager.shared.showCurrentSong()
        shared.presentMainWindow()
    }
    
    @objc public static func revealSelectedItemInFinder() {
        var targetPath: String? = SIDLibraryManager.shared.selectedTunePaths.first
        if targetPath == nil || targetPath!.isEmpty {
            targetPath = SIDPlayer.shared.metadata?.filePath
        }
        guard let path = targetPath, FileManager.default.fileExists(atPath: path) else { return }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
    
    @objc public static func revealSelectedItemInBrowser() {
        SIDLibraryManager.shared.revealSelectedItemInBrowser()
        shared.presentMainWindow()
    }
    
    @objc public static func switchToFavorites() {
        SIDLibraryManager.shared.selectedSidebarItem = .favorites
        shared.presentMainWindow()
    }
    
    @objc public static func syncCurrentCollection() {
        SIDLibraryManager.shared.rescanCurrentCollection()
    }
    
    // MARK: - Export Bridge
    @objc public static func getExportItems() -> [[String: Any]] {
        return SIDLibraryManager.shared.getItemsForExport()
    }
    
    @objc public static func exportTune(path: String, title: String, author: String, subtune: Int, loopCount: Int, formatTag: Int) {
        let dict: [String: Any] = [
            "path": path,
            "title": title,
            "author": author,
            "subtune": subtune,
            "loopCount": loopCount
        ]
        NotificationCenter.default.post(
            name: Notification.Name("SPTriggerExportNotification"),
            object: nil,
            userInfo: [
                "items": [dict],
                "formatTag": formatTag
            ]
        )
    }
    
    public func presentMainWindow() {
        if let existing = window {
            positionAndClampWindow(existing)
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let hosting = NSHostingController(rootView: SIDPlayerAppView())
        self.hostingController = hosting
        
        let newWindow = SIDModernMainWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1050, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.title = "SIDPLAY"
        newWindow.titlebarAppearsTransparent = true
        newWindow.titleVisibility = .hidden
        newWindow.toolbarStyle = .unified
        newWindow.contentViewController = hosting
        newWindow.isReleasedWhenClosed = false
        newWindow.minSize = NSSize(width: 900, height: 580)
        
        positionAndClampWindow(newWindow)
        
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        self.window = newWindow
    }
    
    public func clampCurrentWindow() {
        guard let win = window, win.isVisible else { return }
        positionAndClampWindow(win)
    }
    
    private func positionAndClampWindow(_ win: NSWindow) {
        let screen = win.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }
        let visible = targetScreen.visibleFrame
        
        let hasSaved = UserDefaults.standard.string(forKey: "NSWindow Frame \(autosaveFrameName)") != nil
        if hasSaved {
            _ = win.setFrameUsingName(autosaveFrameName)
        }
        
        var f = win.frame
        let isUninitialized = f.width <= 50.0 || f.height <= 50.0
        let intersection = f.intersection(visible)
        let visibleArea = intersection.isNull ? 0 : (intersection.width * intersection.height)
        let totalArea = max(1.0, f.width * f.height)
        let visibilityRatio = visibleArea / totalArea
        
        // If there is no previous saved location, or if it was uninitialized, or if the window
        // is partially off-screen (less than 85% visible or any edge overflowing visibleFrame):
        if !hasSaved || isUninitialized || visibilityRatio < 0.85 || f.maxX > visible.maxX || f.maxY > visible.maxY || f.minX < visible.minX || f.minY < visible.minY {
            let defaultWidth: CGFloat = min(1050.0, visible.width - 40)
            let defaultHeight: CGFloat = min(680.0, visible.height - 40)
            win.setContentSize(NSSize(width: defaultWidth, height: defaultHeight))
            win.center()
            f = win.frame
        }
        
        // Strict boundary clamp: guarantee 100% of the window is strictly inside visibleFrame
        if f.width > visible.width { f.size.width = visible.width }
        if f.height > visible.height { f.size.height = visible.height }
        if f.maxX > visible.maxX { f.origin.x = visible.maxX - f.width }
        if f.minX < visible.minX { f.origin.x = visible.minX }
        if f.maxY > visible.maxY { f.origin.y = visible.maxY - f.height }
        if f.minY < visible.minY { f.origin.y = visible.minY }
        
        win.setFrameAutosaveName(autosaveFrameName)
        win.setFrame(f, display: true)
        win.saveFrame(usingName: autosaveFrameName)
    }
}

// MARK: - Modern Main Window with Title Bar Double-Click & Drag Support
public final class SIDModernMainWindow: NSWindow {
    override public func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown && event.clickCount == 2 {
            let loc = event.locationInWindow
            let topBarHeight: CGFloat = 54.0
            
            // Check if the double-click occurred within the top toolbar area (from left to right)
            if loc.y >= frame.height - topBarHeight {
                // If user double-clicked inside an active text editing field (e.g. search box),
                // pass through to let standard text word selection occur.
                if let hit = contentView?.hitTest(loc) {
                    if hit is NSText || hit is NSTextField || hit.isKind(of: NSClassFromString("NSTextView") ?? NSObject.self) {
                        super.sendEvent(event)
                        return
                    }
                }
                
                // Native macOS double-click titlebar action (Zoom/Maximize window, not full screen)
                let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick")
                if action == "Minimize" {
                    self.performMiniaturize(nil)
                } else if action == "None" {
                    // Do nothing
                } else {
                    self.performZoom(nil)
                }
                return
            }
        }
        super.sendEvent(event)
    }
}

