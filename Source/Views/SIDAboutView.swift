//
//  SIDAboutView.swift
//  SIDPLAY
//
//  Modern SwiftUI About interface presenting app details, emulation engine credits,
//  contributors, and licensing information without layout clipping.
//

import AppKit
import SwiftUI

public struct SIDAboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AboutTab = .overview
    
    enum AboutTab: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case engines = "Audio Engines"
        case credits = "Credits"
        case license = "License"
        
        var id: String { rawValue }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "4.4"
    }
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header Section
            headerView
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
            
            // Tab Picker
            Picker("Section", selection: $selectedTab) {
                ForEach(AboutTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 24)
            .padding(.bottom, 14)
            
            Divider()
            
            // Tab Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .overview:
                        overviewSection
                    case .engines:
                        enginesSection
                    case .credits:
                        creditsSection
                    case .license:
                        licenseSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
            
            Divider()
            
            // Footer Section
            footerView
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 520, height: 640)
    }
    
    // MARK: - Header
    private var headerView: some View {
        HStack(alignment: .center, spacing: 18) {
            // App Icon
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 76, height: 76)
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("SIDPLAY")
                        .font(.system(size: 24, weight: .bold, design: .default))
                    
                    Text("Version \(appVersion)")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.18))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
                
                Text("Commodore 64 Music Player & SID Synthesizer")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Application (v1.0–v4.3) © Andreas Varga")
                    Text("Modernization 2026 by Rolf Greven")
                }
                .font(.system(size: 10.5))
                .foregroundColor(.secondary.opacity(0.85))
            }
            
            Spacer()
        }
    }
    
    // MARK: - Overview Tab
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("About SIDPLAY")
                .font(.system(size: 14, weight: .bold))
            
            Text("SIDPLAY is the premier Commodore 64 audio player and SID chip emulator for macOS, engineered to play classic game and demo tunes from the golden era of 8-bit computing with authentic cycle-exact accuracy.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(3)
            
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.accentColor)
                    .font(.system(size: 12))
                    .padding(.top, 1)
                
                Text("Created by Andreas Varga (versions 1.0–4.3). Version 4.4 is an independent modernization by Rolf Greven with AI engineering assistance from Google Gemini.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(10)
            .background(Color.accentColor.opacity(0.07))
            .cornerRadius(6)
            
            VStack(spacing: 8) {
                featureRow(icon: "waveform.path.ecg", title: "Dual Emulation Engines", detail: "Cycle-accurate libsidplayfp 3.1.1 (reSIDfp 1.2.2) and classic libsidplay2.")
                featureRow(icon: "cpu", title: "Apple Silicon & Universal Architecture", detail: "Native 64-bit performance on Apple Silicon (M1/M2/M3/M4) and Intel Macs, first introduced in v4.3.")
                featureRow(icon: "speaker.wave.3.fill", title: "Multi-SID Architecture", detail: "Support for up to 4 SID chips ($D400, $D420, $D500, $DE00) and 12-voice mixing.")
                featureRow(icon: "chart.xyaxis.line", title: "Analog Filter Curve Modeling", detail: "Real-time non-linear transconductance curve and op-amp distortion simulation.")
                featureRow(icon: "books.vertical.fill", title: "High Voltage SID Collection", detail: "Deep integration with HVSC Songlengths, STIL comments, and BUG trivia.")
                featureRow(icon: "tv.fill", title: "Hardware-Driven CRT Visualizer", detail: "Phosphor-glow oscilloscope driven directly by CADisplayLink at display refresh.")
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
        }
    }
    
    private func featureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 20, alignment: .center)
                .padding(.top, 1)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    // MARK: - Audio Engines Tab
    private var enginesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Emulation Engines & Libraries")
                .font(.system(size: 14, weight: .bold))
            
            engineCard(
                name: "libsidplayfp 3.1.1 & reSIDfp 1.2.2",
                author: "Leandro Nardi",
                url: "https://github.com/libsidplayfp/libsidplayfp",
                description: "Modern cycle-accurate C64 music player library and MOS 6581 / 8580 SID emulation engine featuring non-linear filter curve simulation, 2200 pF capacitor modeling, and op-amp distortion."
            )
            
            engineCard(
                name: "libsidplay2 & reSID 0.16",
                author: "Simon White & Dag Lem",
                url: "https://sidplay2.sourceforge.net/",
                description: "The classic portable C64 music player engine and foundational cycle-based SID emulator that powered earlier generations of SIDPLAY."
            )
            
            engineCard(
                name: "reSID Distortion Patch",
                author: "Antti Lankila",
                url: "https://web.archive.org/web/20140919022151/https://bel.fi/alankila/c64-sw/",
                description: "Non-linear filter distortion modeling and slew-rate op-amp simulation for analog 6581 sound synthesis."
            )
            
            engineCard(
                name: "LAME MP3 Encoder",
                author: "The LAME Project Team",
                url: "https://lame.sourceforge.net/",
                description: "High quality audio encoding engine used for exporting SID subtunes to MP3."
            )
            
            engineCard(
                name: "PSID64",
                author: "Roland Hermans",
                url: "https://psid64.sourceforge.net/",
                description: "Utility for packaging PSID files into standalone Commodore 64 PRG executables."
            )
        }
    }
    
    private func engineCard(name: String, author: String, url: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                if let targetURL = URL(string: url) {
                    Link(destination: targetURL) {
                        Text("Website ↗")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.accentColor)
                    }
                }
            }
            
            Text("by \(author)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.85))
                .padding(.top, 2)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.12), lineWidth: 1))
    }
    
    // MARK: - Credits Tab
    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Project Credits & Acknowledgements")
                .font(.system(size: 14, weight: .bold))
            
            VStack(alignment: .leading, spacing: 6) {
                // Section 1: Modernization
                creditSubheading("Version 4.4 Modernization")
                creditRow(role: "Modernization", person: "Rolf Greven")
                creditRow(role: "AI Engineering Assistant", person: "Google Gemini")
                
                Divider()
                    .padding(.vertical, 1)
                
                // Section 2: Original Mac Application
                creditSubheading("Application Creator (v1.0 – v4.3)")
                creditRow(role: "Architecture & Implementation", person: "Andreas Varga")
                
                Divider()
                    .padding(.vertical, 1)
                
                // Section 3: Emulation Engines & Audio Libraries
                creditSubheading("Emulation Engines & Audio Libraries")
                creditRow(role: "Cycle-Exact Engine (libsidplayfp)", person: "Leandro Nardi")
                creditRow(role: "Classic Engine (libsidplay2)", person: "Simon White")
                creditRow(role: "Classic SID Emulation (reSID)", person: "Dag Lem")
                creditRow(role: "Filter Distortion Modeling", person: "Antti Lankila")
                creditRow(role: "C64 PRG Executable Support (PSID64)", person: "Roland Hermans")
                
                Divider()
                    .padding(.vertical, 1)
                
                // Section 4: Visual Assets & Music Collection
                creditSubheading("Visual Assets & Music Collection")
                creditRow(role: "Application Icon & Visual Assets", person: "Deekay")
                creditRow(role: "Additional Artwork & Color Palette", person: "Pepto")
                creditRow(role: "HVSC Collection & STIL Database", person: "The HVSC Crew")
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
            
            // Explicit Disclaimer Box
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                    .padding(.top, 1)
                
                Text("Notice: SIDPLAY was originally designed and implemented by Andreas Varga (v1.0–v4.3). Version 4.4 is an independent modernization by Rolf Greven with AI engineering assistance from Google Gemini. Andreas Varga is not affiliated with this v4.4 release.")
                    .font(.system(size: 10.5))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)
            }
            .padding(10)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(6)
            
            Text("Thanks to all beta testers, musicians, and scene enthusiasts whose contributions helped shape SIDPLAY over the years.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .italic()
        }
    }
    
    private func creditSubheading(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.accentColor)
    }
    
    private func creditRow(role: String, person: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(role)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 230, alignment: .leading)
            
            Text(person)
                .font(.system(size: 11, weight: .semibold))
            
            Spacer()
        }
    }
    
    // MARK: - License Tab
    private var licenseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("GNU General Public License v2")
                .font(.system(size: 14, weight: .bold))
            
            Text("SIDPLAY is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 2 of the License, or (at your option) any later version.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)
            
            Text("This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.")
                .font(.system(size: 11))
                .foregroundColor(.secondary.opacity(0.85))
                .lineSpacing(2)
            
            HStack(spacing: 12) {
                if let gplURL = URL(string: "https://www.gnu.org/licenses/old-licenses/gpl-2.0.html") {
                    Link(destination: gplURL) {
                        Label("View GPL v2 License", systemImage: "doc.text")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
                
                if let srcURL = URL(string: "https://github.com/Grrrolf/sidplay-mac") {
                    Link(destination: srcURL) {
                        Label("GitHub Repository", systemImage: "arrow.up.right.square")
                            .font(.system(size: 11, weight: .medium))
                    }
                }
            }
            .padding(.top, 6)
        }
    }
    
    // MARK: - Footer
    private var footerView: some View {
        HStack {
            if let siteURL = URL(string: "https://github.com/Grrrolf/sidplay-mac") {
                Button(action: { NSWorkspace.shared.open(siteURL) }) {
                    Text("GitHub Repository")
                        .font(.system(size: 11))
                }
                .buttonStyle(.link)
            }
            
            Text("•")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            if let hvscURL = URL(string: "https://www.hvsc.c64.org/") {
                Button(action: { NSWorkspace.shared.open(hvscURL) }) {
                    Text("HVSC Project")
                        .font(.system(size: 11))
                }
                .buttonStyle(.link)
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
                if let window = NSApp.windows.first(where: { $0.title == "About SIDPLAY" }) {
                    window.close()
                }
            }
            .keyboardShortcut(.defaultAction)
            .controlSize(.small)
        }
    }
}
