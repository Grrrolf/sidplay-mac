//
//  SpatialAudioTests.swift
//  SIDPLAYTests
//
//  Unit tests verifying spatial audio processing parameters, boundary clamping,
//  bridge synchronization, and persistence.
//

import Foundation

public struct SpatialAudioTests {
    @MainActor
    public static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(name: String, passed: Bool, message: String)] = []
        
        let player = SIDPlayer.shared
        
        // 1. Default Spatial Settings
        let defaultWidth = player.stereoWidth
        let defaultAnchor = player.bassAnchorEnabled
        let test1Passed = (defaultWidth >= 0.0 && defaultWidth <= 3.0)
        results.append((
            name: "Initial Spatial Audio Defaults",
            passed: test1Passed,
            message: "Initial stereo width is \(defaultWidth) and bass anchor is \(defaultAnchor)"
        ))
        
        // 2. Stereo Width Boundary Clamping
        player.stereoWidth = -1.5
        let clampedMin = player.stereoWidth
        player.stereoWidth = 4.5
        let clampedMax = player.stereoWidth
        player.stereoWidth = 1.0
        let test2Passed = (clampedMin == 0.0 && clampedMax == 3.0)
        results.append((
            name: "Stereo Width Boundary Clamping",
            passed: test2Passed,
            message: "Clamped -1.5 -> \(clampedMin) (min 0.0) and 4.5 -> \(clampedMax) (max 3.0)"
        ))
        
        // 3. Reset Spatial Settings Method
        player.stereoWidth = 2.5
        player.bassAnchorEnabled = false
        player.resetSpatialSettings()
        let resetPassed = (player.stereoWidth == 1.0 && player.bassAnchorEnabled == true)
        results.append((
            name: "Reset Spatial Settings to Defaults",
            passed: resetPassed,
            message: "Reset restored width to \(player.stereoWidth) and bass anchor to \(player.bassAnchorEnabled)"
        ))
        
        // 4. Bridge Interop Synchronization
        player.stereoWidth = 1.75
        let bridgeWidth = SIDEngineBridge.shared().stereoWidth
        player.bassAnchorEnabled = false
        let bridgeAnchor = SIDEngineBridge.shared().bassAnchorEnabled
        player.resetSpatialSettings()
        let test4Passed = (abs(bridgeWidth - 1.75) < 0.001 && bridgeAnchor == false)
        results.append((
            name: "Bridge Interop Synchronization",
            passed: test4Passed,
            message: "Bridge synchronized width=\(bridgeWidth) and anchor=\(bridgeAnchor)"
        ))
        
        // 5. UserDefaults Persistence
        player.stereoWidth = 2.0
        let savedWidth = UserDefaults.standard.float(forKey: "SPSpatialStereoWidth")
        player.bassAnchorEnabled = false
        let savedAnchor = UserDefaults.standard.bool(forKey: "SPSpatialBassAnchorEnabled")
        player.resetSpatialSettings()
        let test5Passed = (abs(savedWidth - 2.0) < 0.001 && savedAnchor == false)
        results.append((
            name: "UserDefaults Persistence Tracking",
            passed: test5Passed,
            message: "UserDefaults successfully persisted width=\(savedWidth) and anchor=\(savedAnchor)"
        ))
        
        return results
    }
}
