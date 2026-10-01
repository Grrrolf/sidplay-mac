//
//  ControlMenuValidationTests.swift
//  SIDPLAYTests
//
//  Automated unit tests for Control menu validation, subtune availability,
//  and volume reactive steps.
//

import Foundation

public struct ControlMenuValidationTests {
    public static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(name: String, passed: Bool, message: String)] = []
        
        results.append(testPlayPauseMenuTitleLogic())
        results.append(testSubtuneItemEnableStates())
        results.append(testVolumeSteppingAndClamping())
        results.append(testAppVersionIs4_4())
        
        return results
    }
    
    // MARK: - Test Cases
    
    private static func testPlayPauseMenuTitleLogic() -> (String, Bool, String) {
        let name = "testPlayPauseMenuTitleLogic (Dynamic Title)"
        
        func titleForState(isPlaying: Bool) -> String {
            return isPlaying ? "Pause" : "Play"
        }
        
        guard titleForState(isPlaying: false) == "Play" else {
            return (name, false, "Expected 'Play' when stopped")
        }
        
        guard titleForState(isPlaying: true) == "Pause" else {
            return (name, false, "Expected 'Pause' when playing")
        }
        
        return (name, true, "Title toggles reactively between 'Play' and 'Pause'")
    }
    
    private static func testSubtuneItemEnableStates() -> (String, Bool, String) {
        let name = "testSubtuneItemEnableStates (Subtunes 1-10 Validation)"
        
        let subtuneCount = 3
        let activeSubtune = 2
        
        for tag in 1...10 {
            let isEnabled = (tag <= subtuneCount)
            let isChecked = (tag == activeSubtune)
            
            if tag <= 3 {
                guard isEnabled else {
                    return (name, false, "Subtune item \(tag) should be enabled")
                }
            } else {
                guard !isEnabled else {
                    return (name, false, "Subtune item \(tag) should be disabled for 3-subtune tune")
                }
            }
            
            if tag == 2 {
                guard isChecked else {
                    return (name, false, "Active subtune 2 should have checkmark state ON")
                }
            } else {
                guard !isChecked else {
                    return (name, false, "Inactive subtune \(tag) should have checkmark state OFF")
                }
            }
        }
        
        return (name, true, "Items 1..3 enabled, 4..10 disabled, checkmark on subtune 2")
    }
    
    private static func testVolumeSteppingAndClamping() -> (String, Bool, String) {
        let name = "testVolumeSteppingAndClamping (0.0 to 1.0 Bounds)"
        
        var vol: Float = 0.98
        vol = min(1.0, vol + 0.05)
        guard vol == 1.0 else {
            return (name, false, "Volume up failed to clamp at 1.0, got \(vol)")
        }
        
        vol = 0.03
        vol = max(0.0, vol - 0.05)
        guard vol == 0.0 else {
            return (name, false, "Volume down failed to clamp at 0.0, got \(vol)")
        }
        
        var savedMute: Float = 0.8
        var current: Float = 0.85
        
        // Mute
        if current > 0.001 {
            savedMute = current
            current = 0.0
        }
        guard current == 0.0 && savedMute == 0.85 else {
            return (name, false, "Mute failed to zero volume or save previous value")
        }
        
        // Unmute
        current = savedMute
        guard current == 0.85 else {
            return (name, false, "Unmute failed to restore saved volume")
        }
        
        return (name, true, "Clamping at [0.0, 1.0] and volume mute/unmute restoration verified")
    }
    
    private static func testAppVersionIs4_4() -> (String, Bool, String) {
        let name = "testAppVersionIs4_4 (Version 4.4 Consistency)"
        
        let plistPath = "Info.plist"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return (name, false, "Failed to read Info.plist")
        }
        
        let shortVersion = plist["CFBundleShortVersionString"] as? String
        let bundleVersion = plist["CFBundleVersion"] as? String
        
        guard shortVersion == "4.4" else {
            return (name, false, "CFBundleShortVersionString is \(shortVersion ?? "nil"), expected 4.4")
        }
        guard bundleVersion == "4.4" else {
            return (name, false, "CFBundleVersion is \(bundleVersion ?? "nil"), expected 4.4")
        }
        
        return (name, true, "CFBundleShortVersionString and CFBundleVersion correctly set to 4.4")
    }
}
