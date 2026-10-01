//
//  SIDPreferencesWindowController.swift
//  SIDPLAY
//
//  Window controller presenting the modern SwiftUI Preferences interface centered over the main application window.
//

import AppKit
import SwiftUI

@objc(SIDPreferencesWindowController)
@MainActor
public final class SIDPreferencesWindowController: NSObject {
    @objc public static let shared = SIDPreferencesWindowController()
    
    private var window: NSWindow?
    
    override private init() {
        super.init()
    }
    
    @objc public func showWindow() {
        let windowWidth: CGFloat = 580
        let windowHeight: CGFloat = 640
        
        let targetWindow: NSWindow
        if let existing = window {
            targetWindow = existing
        } else {
            let hosting = NSHostingController(rootView: SIDPreferencesView())
            
            let newWindow = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            
            newWindow.title = "Preferences"
            newWindow.contentViewController = hosting
            newWindow.isReleasedWhenClosed = false
            
            self.window = newWindow
            targetWindow = newWindow
        }
        
        centerOverAppWindow(targetWindow, width: windowWidth, height: windowHeight)
        
        targetWindow.makeKeyAndOrderFront(nil)
        targetWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func centerOverAppWindow(_ win: NSWindow, width: CGFloat, height: CGFloat) {
        let appWindow = SIDModernAppController.currentMainWindow
            ?? NSApp.mainWindow
            ?? NSApp.keyWindow
            ?? NSApp.windows.first(where: {
                $0 !== win && $0.isVisible && ($0.title == "SIDPLAY" || $0.className.contains("ModernMainWindow"))
            })
            ?? NSApp.windows.first(where: { $0 !== win && $0.isVisible })
        
        if let parent = appWindow {
            let parentFrame = parent.frame
            let x = round(parentFrame.midX - (width / 2.0))
            let y = round(parentFrame.midY - (height / 2.0))
            
            if let screen = parent.screen ?? NSScreen.main {
                let visible = screen.visibleFrame
                let clampedX = max(visible.minX, min(x, visible.maxX - width))
                let clampedY = max(visible.minY, min(y, visible.maxY - height))
                win.setFrame(NSRect(x: clampedX, y: clampedY, width: width, height: height), display: true)
                return
            }
            win.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        } else {
            win.center()
        }
    }
}
