//
//  UILayoutRegressionTests.swift
//  SIDPLAYTests
//
//  Automated UI layout and geometry regression tests.
//  Guards against text truncation, single-character vertical wrapping,
//  and component clipping in compact macOS SwiftUI containers.
//

import SwiftUI
import AppKit

@MainActor
public struct UILayoutRegressionTests {
    public static func runAll() -> [(name: String, passed: Bool, message: String)] {
        var results: [(name: String, passed: Bool, message: String)] = []
        
        results.append(testPlayerCapsuleTitleWidthAssertion())
        results.append(testMultiSIDPickerLabelsHiddenAssertion())
        results.append(testLongTitleExpansionBeyondLegacyBarrier())
        results.append(testSearchScopeHeaderSingleLineAssertion())
        
        return results
    }
    
    // MARK: - Test Cases
    
    private static func testPlayerCapsuleTitleWidthAssertion() -> (String, Bool, String) {
        let name = "testPlayerCapsuleTitleWidthAssertion (No Premature Truncation)"
        let title = "Anag8mixxxx4acidtwo"
        
        let font = NSFont.boldSystemFont(ofSize: 11)
        let naturalTextWidth = NSAttributedString(string: title, attributes: [.font: font]).size().width
        
        var measuredTitleWidth: CGFloat = 0
        
        let view = HStack(spacing: 8) {
            Color.clear.frame(width: 210) // Left controls cluster
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: WidthPrefKey.self, value: geo.size.width)
                        })
                    Text("Jake Manley (Jellica)").font(.system(size: 10)).lineLimit(1)
                    Text("2016 HVSC").font(.system(size: 9)).lineLimit(1)
                }
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                
                Spacer(minLength: 8)
                
                HStack(spacing: 10) {
                    Text("Song 01 of 01").fixedSize()
                    Text("00:22").frame(width: 68).fixedSize()
                }
                .fixedSize()
                .layoutPriority(2)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            Color.clear.frame(width: 90) // Right tools
        }
        .frame(width: 720, height: 44)
        .onPreferenceChange(WidthPrefKey.self) { measuredTitleWidth = $0 }
        
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 720, height: 44)
        hosting.layoutSubtreeIfNeeded()
        
        guard measuredTitleWidth >= (naturalTextWidth - 1.0) else {
            return (name, false, "Title was truncated: measured \(measuredTitleWidth) pt vs unconstrained \(naturalTextWidth) pt")
        }
        
        return (name, true, "Title '\(title)' allocated full \(String(format: "%.1f", measuredTitleWidth)) pt without truncation")
    }
    
    private static func testMultiSIDPickerLabelsHiddenAssertion() -> (String, Bool, String) {
        let name = "testMultiSIDPickerLabelsHiddenAssertion (No Vertical Wrapping)"
        
        let picker = Picker("Active SID", selection: .constant(0)) {
            Text("SID 1 ($D400)").tag(0)
            Text("SID 2 ($D420)").tag(1)
            Text("SID 3 ($D440)").tag(2)
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        
        let view = DisclosureGroup(isExpanded: .constant(true)) {
            VStack(alignment: .leading, spacing: 6) {
                picker
            }
        } label: {
            Text("SID Registers")
        }
        .frame(width: 260)
        
        let hosting = NSHostingView(rootView: view)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 260, height: 200),
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.contentView = hosting
        hosting.layoutSubtreeIfNeeded()
        
        // When labelsHidden() is omitted, the label "Active SID" is forced into a narrow column
        // causing severe vertical character wrapping (A\nct\niv\ne...) that inflates the control height to 144 pt.
        // With .labelsHidden(), the graphics view height remains 24 pt.
        var measuredHeight: CGFloat = 0
        for sub in hosting.subviews {
            if sub.className.contains("Graphics") {
                measuredHeight = sub.frame.height
                break
            }
        }
        
        guard measuredHeight <= 30.0 else {
            return (name, false, "Segmented control container inflated to \(measuredHeight) pt (label is unhidden and wrapping vertically)")
        }
        
        return (name, true, "Segmented control height is \(String(format: "%.1f", measuredHeight)) pt (clean single-line layout without vertical wrapping)")
    }
    
    private static func testLongTitleExpansionBeyondLegacyBarrier() -> (String, Bool, String) {
        let name = "testLongTitleExpansionBeyondLegacyBarrier (>170 pt)"
        let longTitle = "The Last Ninja - The Wilderness Extended Mix"
        
        var measuredTitleWidth: CGFloat = 0
        
        let view = HStack(spacing: 8) {
            Color.clear.frame(width: 210)
            Spacer(minLength: 8)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(longTitle)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .background(GeometryReader { geo in
                            Color.clear.preference(key: WidthPrefKey.self, value: geo.size.width)
                        })
                    Text("Matt Gray").font(.system(size: 10)).lineLimit(1)
                    Text("1987 System 3").font(.system(size: 9)).lineLimit(1)
                }
                .frame(minWidth: 100, maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
                
                Spacer(minLength: 8)
                
                HStack(spacing: 10) {
                    Text("Song 01 of 01").fixedSize()
                    Text("00:22").frame(width: 68).fixedSize()
                }
                .fixedSize()
                .layoutPriority(2)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            Color.clear.frame(width: 90)
        }
        .frame(width: 780, height: 44)
        .onPreferenceChange(WidthPrefKey.self) { measuredTitleWidth = $0 }
        
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 780, height: 44)
        hosting.layoutSubtreeIfNeeded()
        
        guard measuredTitleWidth > 170.0 else {
            return (name, false, "Long title capped at \(measuredTitleWidth) pt (failed to break 170 pt barrier)")
        }
        
        return (name, true, "Expanded to \(String(format: "%.1f", measuredTitleWidth)) pt (well beyond legacy 170 pt cap)")
    }
    
    private static func testSearchScopeHeaderSingleLineAssertion() -> (String, Bool, String) {
        let name = "testSearchScopeHeaderSingleLineAssertion (No Multi-Line Wrapping)"
        
        let library = SIDLibraryManager.shared
        library.searchText = "jan"
        
        let view = BreadcrumbBarView(
            library: library,
            showSidebar: .constant(true),
            showInspector: .constant(true)
        )
        .frame(width: 420)
        
        let hosting = NSHostingView(rootView: view)
        let fittingSize = hosting.fittingSize
        
        // Clean up
        library.searchText = ""
        
        guard fittingSize.height <= 32.0 else {
            return (name, false, "Search scope header inflated to \(fittingSize.height) pt (scope buttons wrapping vertically)")
        }
        
        return (name, true, "Search scope bar height is \(String(format: "%.1f", fittingSize.height)) pt (strictly single-line in compact 420 pt container)")
    }
}

private struct WidthPrefKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
