//
//  SIDPreferencesView.swift
//  SIDPLAY
//
//  Modern macOS 14+ SwiftUI Preferences / Settings interface replacing
//  legacy 2008 Preferences.xib.
//

import SwiftUI
import AppKit

public enum PreferencesTab: String, CaseIterable, Identifiable {
    case general = "General"
    case playback = "Playback"
    case sync = "Collection Sync"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .general: return "gearshape"
        case .playback: return "speaker.wave.3"
        case .sync: return "arrow.triangle.2.circlepath"
        }
    }
}

public struct SIDPreferencesView: View {
    @ObservedObject private var player = SIDPlayer.shared
    @ObservedObject private var library = SIDLibraryManager.shared
    
    @State private var selectedTab: PreferencesTab = .playback
    
    // MARK: - General Settings Storage
    @AppStorage("DefaultPlayTime") private var defaultPlayTime: Int = 180
    
    // MARK: - Playback Settings Storage
    @AppStorage("PlaybackFrequency") private var sampleRate: Int = 48000
    @AppStorage("ResamplingMethod") private var resamplingMethod: String = "sinc"
    @AppStorage("MultiSidPanning") private var multiSidPanning: String = "stereo"
    @AppStorage("ForceSidModel") private var forceSidModel: Bool = false
    @AppStorage("EnableOld6581Caps") private var enableOld6581Caps: Bool = false
    
    // MARK: - Sync Settings Storage
    @AppStorage("SyncUrl") private var syncUrl: String = "rsync://www.sidmusic.org/hvsc"
    @AppStorage("SyncInterval") private var syncInterval: Int = 0
    @AppStorage("LastSyncTime") private var lastSyncTimestamp: Double = 0
    
    private var lastSyncFormattedDate: String {
        if let date = UserDefaults.standard.object(forKey: "LastSyncTime") as? Date {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        if lastSyncTimestamp > 0 {
            return Date(timeIntervalSince1970: lastSyncTimestamp).formatted(date: .abbreviated, time: .shortened)
        }
        return "Never"
    }
    
    // MARK: - Live Sync State
    @State private var isSyncing: Bool = false
    @State private var syncStatusMessage: String = "Ready"
    @State private var syncProcess: Process?
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Modern macOS Segmented Toolbar / Tab Selector
            HStack(spacing: 12) {
                ForEach(PreferencesTab.allCases) { tab in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 13, weight: selectedTab == tab ? .semibold : .regular))
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == tab ? Color.accentColor.opacity(0.18) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(selectedTab == tab ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                        .foregroundColor(selectedTab == tab ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 12)
            
            Divider()
            
            // Tab Content
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    switch selectedTab {
                    case .general:
                        generalPane
                    case .playback:
                        playbackPane
                    case .sync:
                        syncPane
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .frame(width: 580, height: 640)
    }
    
    // MARK: - 1. General Preferences Pane
    @ViewBuilder
    private var generalPane: some View {
        // High Voltage SID Collection
        GroupBox(label: Label("High Voltage SID Collection (HVSC)", systemImage: "folder.fill")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Library Folder Location:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 8) {
                    Text(library.rootPath.isEmpty ? "No HVSC folder selected" : library.rootPath)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(5)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    
                    Button("Change...") {
                        selectHvscFolder()
                    }
                    .font(.system(size: 12))
                    
                    if !library.rootPath.isEmpty {
                        Button("Reveal") {
                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: library.rootPath)
                        }
                        .font(.system(size: 12))
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("\(library.topLevelCategories.count) root categories available in collection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Search Scope
        GroupBox(label: Label("Search Behavior", systemImage: "magnifyingglass")) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Default Search Scope:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    Picker("", selection: $library.searchScope) {
                        Text("Entire HVSC").tag(SearchScope.hvsc)
                        Text("Current Folder").tag(SearchScope.folder)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
                Text("Specifies whether ⌘F searches all 56,000+ files or only the active folder.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Playback Defaults
        GroupBox(label: Label("Playback Defaults", systemImage: "clock")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Default Song Duration:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    
                    Text(String(format: "%02d:%02d", defaultPlayTime / 60, defaultPlayTime % 60))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                    
                    Stepper("", value: $defaultPlayTime, in: 15...3600, step: 15)
                        .labelsHidden()
                }
                Text("Applied as a fallback when tune duration is not found in HVSC Songlengths.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 2. Playback Preferences Pane
    @ViewBuilder
    private var playbackPane: some View {
        // Emulation Core Engine
        GroupBox(label: Label("Emulation Core Engine", systemImage: "cpu")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Audio Engine Core:")
                        .font(.system(size: 12, weight: .medium))
                    Spacer(minLength: 16)
                    Picker("", selection: $player.engineBackend) {
                        Text("Cycle-Exact (fp)").tag(SIDEngineBackend.cycleExact)
                        Text("Legacy (sidplay2)").tag(SIDEngineBackend.legacy)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                    .disabled(!player.isLegacyEngineAvailable)
                }
                
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.accentColor)
                        .font(.caption)
                    Text(player.engineBackend == .cycleExact
                         ? "Cycle-Exact: libsidplayfp 3.1.1 + resid-fp 1.2.2 non-linear op-amp circuit modeling. (Recommended)"
                         : "Legacy: Original vintage 2008 libsidplay2 + reSID engine.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Output Quality
        GroupBox(label: Label("Audio Output & Resampling", systemImage: "waveform")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Sample Rate:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    Picker("", selection: $sampleRate) {
                        Text("44,100 Hz (CD Quality)").tag(44100)
                        Text("48,000 Hz (macOS Studio)").tag(48000)
                        Text("96,000 Hz (High Resolution)").tag(96000)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 280, alignment: .trailing)
                }
                
                HStack {
                    Text("Resampling Quality:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    Picker("", selection: $resamplingMethod) {
                        Text("Sinc Resampling (Highest)").tag("sinc")
                        Text("Linear Interpolation").tag("interpolate")
                        Text("Fast Resampling").tag("fast")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 280, alignment: .trailing)
                }
                
                HStack {
                    Text("Multi-SID Stereo Panning:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    Picker("", selection: $multiSidPanning) {
                        Text("Classic Stereo (L/R)").tag("stereo")
                        Text("Spatial 3D Spread").tag("spatial")
                        Text("Centered (Mono)").tag("centered")
                    }
                    .pickerStyle(.menu)
                    .frame(width: 280, alignment: .trailing)
                }
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Spatial Audio Processing
        GroupBox(label: Label("Spatial Processing & Bass Anchor", systemImage: "headphones")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Stereo Soundstage Width:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    Slider(value: $player.stereoWidth, in: 0.0...3.0, step: 0.05)
                        .frame(width: 200)
                    Text(String(format: "%.1fx", player.stereoWidth))
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }
                
                Toggle("Enable 180 Hz Mono Bass Anchor (Recommended for Headphones)", isOn: $player.bassAnchorEnabled)
                    .font(.system(size: 12))
                
                Text("Summing sub-180 Hz frequencies to mono prevents ear fatigue on headphones while preserving wide leads and ambient stereo spread.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Hardware Defaults
        GroupBox(label: Label("Hardware Defaults & Preferences", systemImage: "slider.horizontal.3")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Preferred Clock Timing:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    Picker("", selection: $player.clockSpeed) {
                        Text("PAL (50 Hz)").tag(SIDClockSpeed.pal)
                        Text("NTSC (60 Hz)").tag(SIDClockSpeed.ntsc)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
                
                HStack {
                    Text("Preferred SID Chip:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    Picker("", selection: $player.sidModel) {
                        Text("MOS 6581 (Warm)").tag(SIDChipModel.mos6581)
                        Text("MOS 8580 (Crisp)").tag(SIDChipModel.mos8580)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 280)
                }
                
                Divider()
                
                Toggle("Force preferred chip and timing for all tunes", isOn: $forceSidModel)
                    .font(.system(size: 12))
                
                Text("Overrides any hardware specifications embedded in the .sid file header.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Cycle-Exact Filter Customization
        GroupBox(label: Label("Filter Simulation (Cycle-Exact)", systemImage: "waveform.path.ecg")) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("6581 Center Frequency:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    HStack(spacing: 8) {
                        FixedSizeSlider(value: $player.filterCurve, in: 0.0...1.0, trackHeight: 4, knobSize: 12)
                        Text(String(format: "%.2f", player.filterCurve))
                            .font(.system(size: 11, design: .monospaced))
                            .frame(width: 42, alignment: .trailing)
                    }
                    .frame(width: 280, alignment: .trailing)
                }
                
                Toggle("Enable early 2200pF filter capacitors (ASSY 326298)", isOn: $enableOld6581Caps)
                    .font(.system(size: 12))
                
                Text("Simulates the distinctive darker response of early 1982-1983 Commodore 64 boards.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - 3. Collection Sync Pane
    @ViewBuilder
    private var syncPane: some View {
        GroupBox(label: Label("HVSC Collection Sync Server", systemImage: "network")) {
            VStack(alignment: .leading, spacing: 10) {
                Text("rsync Mirror Server URL:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("rsync URL", text: $syncUrl)
                    .font(.system(size: 12, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                
                HStack {
                    Text("Automatic Sync Schedule:")
                        .font(.system(size: 12))
                    Spacer(minLength: 16)
                    Picker("", selection: $syncInterval) {
                        Text("Manual Only").tag(0)
                        Text("On App Launch").tag(1)
                        Text("Monthly").tag(2)
                    }
                    .pickerStyle(.menu)
                    .frame(width: 280, alignment: .trailing)
                }
            }
            .padding(6)
        }
        
        GroupBox(label: Label("Collection Status & Actions", systemImage: "arrow.triangle.2.circlepath")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Last Synchronized:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lastSyncFormattedDate)
                            .font(.system(size: 12, weight: .medium))
                    }
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 3) {
                        Text("Local Library:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(library.topLevelCategories.count) Categories Indexed")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                
                Divider()
                
                // Live Sync Status
                HStack(spacing: 8) {
                    if isSyncing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.secondary)
                    }
                    
                    Text(syncStatusMessage)
                        .font(.system(size: 11))
                        .foregroundColor(isSyncing ? .primary : .secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if isSyncing {
                        Button("Cancel") {
                            cancelSync()
                        }
                        .font(.system(size: 12))
                    } else {
                        Button("Sync Collection Now") {
                            performSync()
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .buttonStyle(.borderedProminent)
                        .disabled(library.rootPath.isEmpty)
                    }
                }
                
                if library.rootPath.isEmpty {
                    Text("Please select an HVSC folder in the General tab first.")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            .padding(6)
        }
    }
    
    // MARK: - Folder Picker
    private func selectHvscFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select HVSC Folder"
        panel.message = "Choose your High Voltage SID Collection (HVSC) root folder."
        
        if panel.runModal() == .OK, let url = panel.url {
            library.setRootCollection(path: url.path)
            UserDefaults.standard.set([url.path], forKey: "collections")
        }
    }
    
    // MARK: - rsync Synchronization Execution
    private func performSync() {
        guard !library.rootPath.isEmpty else { return }
        
        isSyncing = true
        syncStatusMessage = "Connecting to \(syncUrl)..."
        
        let dest = library.rootPath
        let url = syncUrl
        
        Task.detached(priority: .userInitiated) {
            let rsyncPath: String
            if FileManager.default.fileExists(atPath: "/usr/bin/rsync") {
                rsyncPath = "/usr/bin/rsync"
            } else if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/rsync") {
                rsyncPath = "/opt/homebrew/bin/rsync"
            } else {
                rsyncPath = "/usr/bin/rsync"
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: rsyncPath)
            process.arguments = ["-rtvz", "--safe-links", "--delete", "--progress", url, dest]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            await MainActor.run {
                self.syncProcess = process
            }
            
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if let str = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    let lastLine = str.components(separatedBy: "\n").last ?? str
                    Task { @MainActor in
                        self.syncStatusMessage = lastLine
                    }
                }
            }
            
            do {
                try process.run()
                process.waitUntilExit()
                
                pipe.fileHandleForReading.readabilityHandler = nil
                let success = process.terminationStatus == 0
                
                await MainActor.run {
                    self.isSyncing = false
                    self.syncProcess = nil
                    if success {
                        self.lastSyncTimestamp = Date().timeIntervalSince1970
                        self.syncStatusMessage = "Sync finished successfully."
                        self.library.setRootCollection(path: dest)
                    } else {
                        self.syncStatusMessage = "Sync completed with code \(process.terminationStatus)."
                    }
                }
            } catch {
                await MainActor.run {
                    self.isSyncing = false
                    self.syncProcess = nil
                    self.syncStatusMessage = "Sync error: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func cancelSync() {
        syncProcess?.terminate()
        syncProcess = nil
        isSyncing = false
        syncStatusMessage = "Sync cancelled by user."
    }
}
