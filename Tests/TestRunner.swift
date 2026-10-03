//
//  TestRunner.swift
//  SIDPLAYTests
//
//  Unified test orchestrator and CLI reporter for the SIDPLAY test framework.
//

import Foundation

@main
public struct TestRunner {
    public static var testCollectionPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Music/C64music").path,
            home.appendingPathComponent("Documents/HVSC").path,
            home.appendingPathComponent("Music/HVSC").path
        ]
        for candidate in candidates {
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        return candidates[0]
    }
    
    @MainActor
    public static func main() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        print("\n\u{001B}[1;36m================================================================================\u{001B}[0m")
        print("\u{001B}[1;36m                      SIDPLAY AUTOMATED REGRESSION & UNIT TEST SUITE             \u{001B}[0m")
        print("\u{001B}[1;36m================================================================================\u{001B}[0m\n")
        
        let suites: [(name: String, runner: () -> [(name: String, passed: Bool, message: String)])] = [
            ("SID Tune & Header Parsing", SIDTuneTests.runAll),
            ("Song Length Calculations & Formatting", SongLengthDatabaseTests.runAll),
            ("STIL Database Key Normalization & Parsing", STILDatabaseTests.runAll),
            ("Playback Queue & Random Selection", PlaybackQueueTests.runAll),
            ("UI Layout & Geometry Regression (Capsule / Pickers)", UILayoutRegressionTests.runAll),
            ("Control Menu Validation & Volume Clamping", ControlMenuValidationTests.runAll),
            ("Browser Navigation & History Stacks", BrowserNavigationTests.runAll),
            ("Spatial Audio DSP & Stereo Width", SpatialAudioTests.runAll)
        ]
        
        var totalPassed = 0
        var totalFailed = 0
        var suiteReports: [(suiteName: String, passed: Int, failed: Int)] = []
        
        for suite in suites {
            print("\u{001B}[1;33m▶ Suite: \(suite.name)\u{001B}[0m")
            let results = suite.runner()
            var passedInSuite = 0
            var failedInSuite = 0
            
            for res in results {
                if res.passed {
                    passedInSuite += 1
                    totalPassed += 1
                    print("  \u{001B}[32m✓\u{001B}[0m \u{001B}[1m\(res.name)\u{001B}[0m")
                    print("    \u{001B}[90m└─ \(res.message)\u{001B}[0m")
                } else {
                    failedInSuite += 1
                    totalFailed += 1
                    print("  \u{001B}[31m✗\u{001B}[0m \u{001B}[1;31m\(res.name)\u{001B}[0m")
                    print("    \u{001B}[31m└─ FAILURE: \(res.message)\u{001B}[0m")
                }
            }
            suiteReports.append((suite.name, passedInSuite, failedInSuite))
            print("")
        }
        
        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        print("\u{001B}[1;36m┌────────────────────────────────────────────────────────────┬────────┬────────┐\u{001B}[0m")
        print("\u{001B}[1;36m│ Test Suite Summary                                         │ Passed │ Failed │\u{001B}[0m")
        print("\u{001B}[1;36m├────────────────────────────────────────────────────────────┼────────┼────────┤\u{001B}[0m")
        for report in suiteReports {
            let paddedName = report.suiteName.padding(toLength: 58, withPad: " ", startingAt: 0)
            let paddedPassed = String(format: "%6d", report.passed)
            let paddedFailed = String(format: "%6d", report.failed)
            print("│ \(paddedName) │ \(paddedPassed) │ \(paddedFailed) │")
        }
        print("\u{001B}[1;36m├────────────────────────────────────────────────────────────┼────────┼────────┤\u{001B}[0m")
        let totalName = "TOTAL".padding(toLength: 58, withPad: " ", startingAt: 0)
        let totalP = String(format: "%6d", totalPassed)
        let totalF = String(format: "%6d", totalFailed)
        print("│ \u{001B}[1m\(totalName)\u{001B}[0m │ \u{001B}[32m\(totalP)\u{001B}[0m │ \u{001B}[\(totalFailed > 0 ? "31" : "32")m\(totalF)\u{001B}[0m │")
        print("\u{001B}[1;36m└────────────────────────────────────────────────────────────┴────────┴────────┘\u{001B}[0m")
        
        print(String(format: "\nExecution completed in %.3f seconds.\n", elapsed))
        
        if totalFailed > 0 {
            print("\u{001B}[1;31m❌ REGRESSION DETECTED: \(totalFailed) test(s) failed.\u{001B}[0m\n")
            exit(1)
        } else {
            print("\u{001B}[1;32m✅ ALL \(totalPassed) REGRESSION AND UNIT TESTS PASSED CLEANLY.\u{001B}[0m\n")
            exit(0)
        }
    }
}
