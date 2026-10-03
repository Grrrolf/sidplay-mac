//
//  SIDInspectorView.swift
//  SIDPLAY
//
//  HUD Info Panel matching the classic SIDPLAY screenshot 2:
//  Tune Details, Cyan CRT Oscilloscope, 3-Column SID Registers,
//  Mixer with pill Mute/Solo buttons, and Filter Controls.
//

import SwiftUI

public struct SIDInspectorView: View {
    @ObservedObject var player: SIDPlayer
    @Binding var isPresented: Bool
    
    @ObservedObject private var stilManager = STILManager.shared
    @ObservedObject private var telemetry: SIDRegisterTelemetry
    @State private var tuneDetailsExpanded = true
    @State private var stilExpanded = true
    @State private var oscilloscopeExpanded = true
    @State private var registersExpanded = true
    @State private var mixerExpanded = true
    @State private var spatialExpanded = true
    @State private var filterExpanded = true
    @State private var distortionExpanded = true
    
    public init(player: SIDPlayer = .shared, isPresented: Binding<Bool> = .constant(true)) {
        self.player = player
        self._isPresented = isPresented
        self.telemetry = player.registerTelemetry
    }
    
    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - HUD Header Bar
            HStack {
                Spacer()
                
                Text("Info")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
            
            Divider()
            
            GeometryReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 12) {
                        // MARK: - 1. Tune Details Section
                        DisclosureGroup(isExpanded: $tuneDetailsExpanded) {
                            VStack(alignment: .leading, spacing: 0) {
                                if let meta = player.metadata {
                                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 3) {
                                        GridRow {
                                            Text("Title")
                                                .foregroundColor(.secondary)
                                            Text(meta.title)
                                                .fontWeight(.medium)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        GridRow {
                                            Text("Author")
                                                .foregroundColor(.secondary)
                                            Text(meta.author)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        GridRow {
                                            Text("Released")
                                                .foregroundColor(.secondary)
                                            Text(meta.releaseInfo)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        GridRow {
                                            Text("Songs")
                                                .foregroundColor(.secondary)
                                            Text("\(meta.subtuneCount) (default: \(meta.defaultSubtune))")
                                        }
                                        GridRow(alignment: .top) {
                                            Text("Used SIDs")
                                                .foregroundColor(.secondary)
                                            if meta.chips.count <= 1 {
                                                Text(meta.sidConfigurationDescription)
                                                    .lineLimit(1)
                                                    .truncationMode(.tail)
                                            } else {
                                                VStack(alignment: .leading, spacing: 3) {
                                                    ForEach(meta.chips) { chip in
                                                        HStack(spacing: 4) {
                                                            Text("SID \(chip.chipIndex + 1):")
                                                                .fontWeight(.semibold)
                                                            Text(chip.model)
                                                            Text("(\(chip.formattedAddress))")
                                                                .font(.system(size: 10, design: .monospaced))
                                                                .foregroundColor(.secondary)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        GridRow {
                                            Text("Length")
                                                .foregroundColor(.secondary)
                                            Text(meta.formattedSongLength)
                                        }
                                        GridRow {
                                            Text("Load Address")
                                                .foregroundColor(.secondary)
                                            Text(meta.formattedLoadAddress)
                                                .font(.system(size: 11, design: .monospaced))
                                        }
                                        GridRow {
                                            Text("Init Address")
                                                .foregroundColor(.secondary)
                                            Text(meta.formattedInitAddress)
                                                .font(.system(size: 11, design: .monospaced))
                                        }
                                        GridRow {
                                            Text("Play Address")
                                                .foregroundColor(.secondary)
                                            Text(meta.formattedPlayAddress)
                                                .font(.system(size: 11, design: .monospaced))
                                        }
                                        GridRow {
                                            Text("Format")
                                                .foregroundColor(.secondary)
                                            Text(meta.format)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                        }
                                        GridRow {
                                            Text("File size")
                                                .foregroundColor(.secondary)
                                            Text("\(meta.fileSize) bytes")
                                        }
                                    }
                                    .font(.system(size: 11))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                } else {
                                    Text("No tune loaded")
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                        } label: {
                            Text("Tune Details")
                                .font(.system(size: 11, weight: .bold))
                        }
                    
                    Divider()
                    
                    // MARK: - 2. STIL Information Section
                    DisclosureGroup(isExpanded: $stilExpanded) {
                        if let path = player.metadata?.filePath,
                           let entry = stilManager.entry(forPath: path) {
                            VStack(alignment: .leading, spacing: 8) {
                                // Global tune fields (e.g. TITLE, ARTIST, COMMENT)
                                if !entry.globalFields.isEmpty {
                                    VStack(alignment: .leading, spacing: 4) {
                                        ForEach(entry.globalFields) { field in
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(field.name)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .foregroundColor(.accentColor)
                                                Text(field.value)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(field.name == "COMMENT" ? .primary : .secondary)
                                                    .textSelection(.enabled)
                                            }
                                        }
                                    }
                                    .padding(6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.primary.opacity(0.04))
                                    .cornerRadius(4)
                                }
                                
                                // Subtune-specific fields
                                if !entry.subtunes.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(entry.subtunes) { sub in
                                            let isCurrent = sub.subtuneNumber == player.currentSubtune
                                            VStack(alignment: .leading, spacing: 3) {
                                                HStack(spacing: 4) {
                                                    if isCurrent && player.isPlaying {
                                                        Image(systemName: "speaker.wave.2.fill")
                                                            .font(.system(size: 8))
                                                            .foregroundColor(.accentColor)
                                                    }
                                                    Text("Subtune #\(sub.subtuneNumber)")
                                                        .font(.system(size: 10, weight: isCurrent ? .bold : .semibold))
                                                        .foregroundColor(isCurrent ? .accentColor : .primary)
                                                    if isCurrent {
                                                        Text("(Playing)")
                                                            .font(.system(size: 9))
                                                            .foregroundColor(.secondary)
                                                    }
                                                }
                                                
                                                ForEach(sub.fields) { field in
                                                    VStack(alignment: .leading, spacing: 1) {
                                                        Text(field.name)
                                                            .font(.system(size: 8, weight: .bold))
                                                            .foregroundColor(.secondary)
                                                        Text(field.value)
                                                            .font(.system(size: 10))
                                                            .foregroundColor(.primary)
                                                            .textSelection(.enabled)
                                                    }
                                                    .padding(.leading, 4)
                                                }
                                            }
                                            .padding(5)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(isCurrent ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
                                            .cornerRadius(4)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(isCurrent ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                            }
                            .padding(.top, 4)
                        } else if player.isTuneLoaded {
                            HStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                                Text("No STIL notes available for this tune")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        } else {
                            Text("No tune loaded")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 4)
                        }
                    } label: {
                        HStack {
                            Text("STIL Information")
                                .font(.system(size: 11, weight: .bold))
                            
                            Spacer()
                            
                            if let path = player.metadata?.filePath,
                               let entry = stilManager.entry(forPath: path) {
                                Button(action: {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(entry.rawText, forType: .string)
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("Copy STIL notes to clipboard")
                            }
                        }
                    }
                    
                    Divider()
                    
                    // MARK: - 3. Oscilloscope Section
                    DisclosureGroup(isExpanded: $oscilloscopeExpanded) {
                        ClassicOscilloscopeView(player: player, isPlaying: player.isPlaying, isExpanded: oscilloscopeExpanded)
                            .frame(height: 72)
                            .background(Color.black)
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                            )
                            .padding(.top, 4)
                    } label: {
                        Text("Oscilloscope")
                            .font(.system(size: 11, weight: .bold))
                    }
                    
                    Divider()
                    
                    // MARK: - 3. SID Registers Section (3 Columns)
                    DisclosureGroup(isExpanded: $registersExpanded) {
                        VStack(alignment: .leading, spacing: 6) {
                            if let chips = player.metadata?.chips, chips.count > 1 {
                                Picker("Active SID", selection: $player.selectedSidChip) {
                                    ForEach(chips) { chip in
                                        Text("SID \(chip.chipIndex + 1) (\(chip.formattedAddress))").tag(chip.chipIndex)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .labelsHidden()
                                .padding(.bottom, 2)
                            }
                            
                            // 3-Column Voice Register Grid
                            HStack(alignment: .top, spacing: 6) {
                                VoiceColumnView(title: "Voice 1", voice: telemetry.registers.voice1)
                                VoiceColumnView(title: "Voice 2", voice: telemetry.registers.voice2)
                                VoiceColumnView(title: "Voice 3", voice: telemetry.registers.voice3)
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            // Filter Registers Info
                            let filt = telemetry.registers.filter
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(format: "Filter Cutoff: $%04X", filt.cutoff))
                                Text("Resonance/Filter: \(String(format: "$%02X (%@)", filt.resonance, filt.routedVoicesDescription))")
                                Text("Filtermode/Volume: \(String(format: "$%02X (%@)", filt.volume, filt.modeDescription))")
                            }
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    } label: {
                        HStack {
                            Text("SID Registers")
                                .font(.system(size: 11, weight: .bold))
                            if let chips = player.metadata?.chips, chips.count > 1 {
                                Text("(\(player.selectedSidChip + 1) of \(chips.count))")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // MARK: - 4. Mixer Section
                    DisclosureGroup(isExpanded: $mixerExpanded) {
                        VStack(spacing: 8) {
                            if let chips = player.metadata?.chips, chips.count > 1 {
                                HStack {
                                    Text("Mixing:")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Picker("SID Chip", selection: $player.selectedSidChip) {
                                        ForEach(chips) { chip in
                                            Text("SID \(chip.chipIndex + 1)").tag(chip.chipIndex)
                                        }
                                    }
                                    .pickerStyle(.segmented)
                                    .labelsHidden()
                                }
                                .padding(.bottom, 2)
                            }
                            
                            ClassicMixerRow(
                                title: "Voice 1",
                                volume: Binding(
                                    get: { player.voiceVolumes[0] },
                                    set: { player.setVoice(0, volume: $0) }
                                ),
                                isMuted: player.voiceMuted[0],
                                isSolo: player.voiceSolo[0],
                                onMute: { player.setVoice(0, muted: !player.voiceMuted[0]) },
                                onSolo: { player.setVoice(0, solo: !player.voiceSolo[0]) }
                            )
                            
                            ClassicMixerRow(
                                title: "Voice 2",
                                volume: Binding(
                                    get: { player.voiceVolumes[1] },
                                    set: { player.setVoice(1, volume: $0) }
                                ),
                                isMuted: player.voiceMuted[1],
                                isSolo: player.voiceSolo[1],
                                onMute: { player.setVoice(1, muted: !player.voiceMuted[1]) },
                                onSolo: { player.setVoice(1, solo: !player.voiceSolo[1]) }
                            )
                            
                            ClassicMixerRow(
                                title: "Voice 3",
                                volume: Binding(
                                    get: { player.voiceVolumes[2] },
                                    set: { player.setVoice(2, volume: $0) }
                                ),
                                isMuted: player.voiceMuted[2],
                                isSolo: player.voiceSolo[2],
                                onMute: { player.setVoice(2, muted: !player.voiceMuted[2]) },
                                onSolo: { player.setVoice(2, solo: !player.voiceSolo[2]) }
                            )
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    } label: {
                        Text("Mixer")
                            .font(.system(size: 11, weight: .bold))
                    }
                    
                    Divider()
                    
                    // MARK: - 5. Spatial Audio & Stereo Width
                    DisclosureGroup(isExpanded: $spatialExpanded) {
                        VStack(alignment: .leading, spacing: 10) {
                            // Stereo Width Slider
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text("Stereo Width:")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(stereoWidthLabel(player.stereoWidth))
                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundColor(player.stereoWidth > 1.05 ? .accentColor : .primary)
                                }
                                FixedSizeSlider(
                                    value: $player.stereoWidth,
                                    in: 0.0...3.0,
                                    trackHeight: 4,
                                    knobSize: 12
                                )
                                HStack {
                                    Text("Mono")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("Native")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("+200%")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Divider()
                                .padding(.vertical, 2)
                            
                            // Mono Bass Anchor Toggle
                            Toggle(isOn: $player.bassAnchorEnabled) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Mono Bass Anchor (180 Hz)")
                                        .font(.system(size: 10, weight: .semibold))
                                    Text("Centers sub-bass on headphones")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                            
                            // Reset Button
                            HStack {
                                Spacer()
                                Button(action: {
                                    player.resetSpatialSettings()
                                }) {
                                    Text("Reset Spatial")
                                        .font(.system(size: 10))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(player.stereoWidth == 1.0 && player.bassAnchorEnabled)
                            }
                            .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    } label: {
                        HStack(spacing: 5) {
                            Text("Spatial Audio")
                                .font(.system(size: 11, weight: .bold))
                            if player.stereoWidth != 1.0 || player.bassAnchorEnabled {
                                Circle()
                                    .fill(Color.accentColor)
                                    .frame(width: 5, height: 5)
                            }
                        }
                    }

                    Divider()
                    
                    // MARK: - 6. Emulation & Filter Section
                    DisclosureGroup(isExpanded: $filterExpanded) {
                        VStack(alignment: .leading, spacing: 10) {
                            // Emulation Engine Core (A/B Testing Switcher)
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Emulation Core:")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(player.engineBackend == .cycleExact ? "Cycle-Exact" : "Legacy 2008")
                                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                                        .foregroundColor(.accentColor)
                                }
                                Picker("", selection: $player.engineBackend) {
                                    Text("Cycle-Exact (fp)").tag(SIDEngineBackend.cycleExact)
                                    Text("Legacy (sidplay2)").tag(SIDEngineBackend.legacy)
                                }
                                .pickerStyle(.segmented)
                                
                                HStack(spacing: 3) {
                                    Image(systemName: "cpu")
                                        .font(.system(size: 8))
                                        .foregroundColor(.secondary)
                                    Text(player.engineName)
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .padding(.top, 1)
                            }
                            
                            Divider()
                                .padding(.vertical, 2)

                            // SID Chip Model
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("SID Model:")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if player.sidModel == .auto, let chip = player.metadata?.chipModel {
                                        Text(chip)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.accentColor)
                                    }
                                }
                                Picker("", selection: $player.sidModel) {
                                    Text("Auto").tag(SIDChipModel.auto)
                                    Text("MOS 6581").tag(SIDChipModel.mos6581)
                                    Text("MOS 8580").tag(SIDChipModel.mos8580)
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Clock Speed
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Clock Speed:")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Picker("", selection: $player.clockSpeed) {
                                    Text("Auto").tag(SIDClockSpeed.auto)
                                    Text("PAL (50Hz)").tag(SIDClockSpeed.pal)
                                    Text("NTSC (60Hz)").tag(SIDClockSpeed.ntsc)
                                }
                                .pickerStyle(.segmented)
                            }
                            
                            // Filter Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 10) {
                                    // Left side: Preset selector & info
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack {
                                            Text("Filter Preset:")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            if player.sidModel == .auto {
                                                Text(player.filterType == .filter8580 ? "AUTO: 8580" : "AUTO: 6581")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .foregroundColor(.accentColor)
                                                    .cornerRadius(3)
                                            }
                                        }
                                        
                                        Picker("", selection: Binding(
                                            get: { player.filterType },
                                            set: { newType in
                                                player.selectFilterPreset(newType)
                                            }
                                        )) {
                                            Text("6581 Standard (ReSID-fp)").tag(SIDFilterType.filter6581Resid)
                                            Text("6581 R3 (Rich Harmonics)").tag(SIDFilterType.filter6581R3)
                                            Text("6581 Galway (Deep Bass)").tag(SIDFilterType.filter6581Galway)
                                            Text("6581 R4 (2200pF Vintage)").tag(SIDFilterType.filter6581R4)
                                            Text("8580 (Clean & Linear)").tag(SIDFilterType.filter8580)
                                            if player.filterType == .filterCustom {
                                                Text("Custom Tuned").tag(SIDFilterType.filterCustom)
                                            }
                                        }
                                        .pickerStyle(.menu)
                                        
                                        Text(filterPresetDescription(for: player.filterType))
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                        
                                        if player.filterType == .filterCustom {
                                            Button(action: {
                                                player.resetFilterToDefaults()
                                            }) {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "arrow.counterclockwise")
                                                        .font(.system(size: 8, weight: .bold))
                                                    Text("Reset to Defaults")
                                                        .font(.system(size: 9, weight: .medium))
                                                }
                                                .foregroundColor(.accentColor)
                                                .padding(.vertical, 2)
                                                .padding(.horizontal, 4)
                                                .background(Color.accentColor.opacity(0.12))
                                                .cornerRadius(3)
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(Rectangle())
                                            .padding(.top, 2)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    // Right side: Filter Curve Visualizer Graph matching the original SIDPLAY design
                                    SIDFilterCurveGraphView(player: player, telemetry: telemetry)
                                        .frame(width: 114, height: 72)
                                }
                                
                                // Real-time Filter Telemetry Status Bar (Prominently placed directly below the graph)
                                if player.isPlaying {
                                    HStack(spacing: 6) {
                                        Text("Cutoff: $\(String(format: "%04X", telemetry.registers.filter.cutoff))")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.primary)
                                        Text("•")
                                            .foregroundColor(.secondary.opacity(0.4))
                                        Text("Mode: \(telemetry.registers.filter.modeDescription)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Text("•")
                                            .foregroundColor(.secondary.opacity(0.4))
                                        Text("Res: \(telemetry.registers.filter.resonance)")
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 3)
                                    .padding(.horizontal, 6)
                                    .background(Color.secondary.opacity(0.08))
                                    .cornerRadius(4)
                                }
                                
                                Divider()
                                    .padding(.vertical, 1)
                                
                                // Sliders to adjust the curve: Steepness & Offset & Range
                                VStack(alignment: .leading, spacing: 6) {
                                    // Steepness Slider
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Steepness:")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(String(format: "%.0f", player.filterSteepness))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.primary)
                                        }
                                        FixedSizeSlider(
                                            value: Binding(
                                                get: { player.filterSteepness },
                                                set: { player.filterSteepness = $0; player.userTunedFilterParameter() }
                                            ),
                                            in: 50...390,
                                            trackHeight: 4,
                                            knobSize: 12
                                        )
                                    }
                                    
                                    // Offset Slider
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Offset:")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(String(format: "%+.0f Hz", player.filterOffset))
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.primary)
                                        }
                                        FixedSizeSlider(
                                            value: Binding(
                                                get: { player.filterOffset },
                                                set: { player.filterOffset = $0; player.userTunedFilterParameter() }
                                            ),
                                            in: -800...300,
                                            trackHeight: 4,
                                            knobSize: 12
                                        )
                                    }
                                    
                                    // Center Curve Slider
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Center Curve:")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int(player.filterCurve * 100))%")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.primary)
                                        }
                                        HStack(spacing: 6) {
                                            Text("Dark")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                            FixedSizeSlider(
                                                value: Binding(
                                                    get: { player.filterCurve },
                                                    set: { player.filterCurve = $0; player.userTunedFilterParameter() }
                                                ),
                                                in: 0.05...0.95,
                                                trackHeight: 4,
                                                knobSize: 12
                                            )
                                            Text("Bright")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Range / Span Slider
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("Range / Span:")
                                                .font(.system(size: 10, weight: .semibold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int(player.filterRange * 100))%")
                                                .font(.system(size: 10, design: .monospaced))
                                                .foregroundColor(.primary)
                                        }
                                        HStack(spacing: 6) {
                                            Text("Narrow")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                            FixedSizeSlider(
                                                value: Binding(
                                                    get: { player.filterRange },
                                                    set: { player.filterRange = $0; player.userTunedFilterParameter() }
                                                ),
                                                in: 0.05...0.95,
                                                trackHeight: 4,
                                                knobSize: 12
                                            )
                                            Text("Wide")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Vintage Capacitors Checkbox (6581)
                                    if player.filterType != .filter8580 {
                                        Toggle(isOn: Binding(
                                            get: { player.old6581Caps },
                                            set: { player.old6581Caps = $0; player.userTunedFilterParameter() }
                                        )) {
                                            VStack(alignment: .leading, spacing: 1) {
                                                Text("Vintage 2200 pF Capacitors")
                                                    .font(.system(size: 10, weight: .semibold))
                                                Text("Early ASSY 326298 breadbin dark filtering")
                                                    .font(.system(size: 8))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .toggleStyle(.checkbox)
                                        .padding(.top, 4)
                                        .padding(.bottom, 2)
                                    }
                                }
                                
                                Divider()
                                    .padding(.vertical, 1)
                                
                                // Distortion Controls (Rate & Headroom)
                                VStack(alignment: .leading, spacing: 6) {
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            distortionExpanded.toggle()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundColor(.secondary)
                                                .rotationEffect(.degrees(distortionExpanded ? 90 : 0))
                                            Text("Distortion Controls")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            if player.distortionEnabled {
                                                Text("ON")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .padding(.horizontal, 4)
                                                    .padding(.vertical, 1)
                                                    .background(Color.accentColor.opacity(0.15))
                                                    .foregroundColor(.accentColor)
                                                    .cornerRadius(3)
                                            }
                                        }
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    if distortionExpanded {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Toggle(isOn: Binding(
                                                get: { player.distortionEnabled },
                                                set: { player.distortionEnabled = $0; player.userTunedFilterParameter() }
                                            )) {
                                                Text("Enable Non-Linear Distortion")
                                                    .font(.system(size: 10, weight: .medium))
                                            }
                                            .toggleStyle(.checkbox)
                                            
                                            if player.distortionEnabled {
                                                // Rate Slider
                                                VStack(alignment: .leading, spacing: 2) {
                                                    HStack {
                                                        Text("Rate:")
                                                            .font(.system(size: 10, weight: .semibold))
                                                            .foregroundColor(.secondary)
                                                        Spacer()
                                                        Text("\(player.distortionRate)")
                                                            .font(.system(size: 10, design: .monospaced))
                                                            .foregroundColor(.primary)
                                                    }
                                                    FixedSizeSlider(
                                                        value: Binding(
                                                            get: { Double(player.distortionRate) },
                                                            set: { player.distortionRate = Int($0); player.userTunedFilterParameter() }
                                                        ),
                                                        in: 100...3200,
                                                        trackHeight: 4,
                                                        knobSize: 12
                                                    )
                                                }
                                                
                                                // Headroom Slider
                                                VStack(alignment: .leading, spacing: 2) {
                                                    HStack {
                                                        Text("Headroom:")
                                                            .font(.system(size: 10, weight: .semibold))
                                                            .foregroundColor(.secondary)
                                                        Spacer()
                                                        Text("\(player.distortionHeadroom)")
                                                            .font(.system(size: 10, design: .monospaced))
                                                            .foregroundColor(.primary)
                                                    }
                                                    FixedSizeSlider(
                                                        value: Binding(
                                                            get: { Double(player.distortionHeadroom) },
                                                            set: { player.distortionHeadroom = Int($0); player.userTunedFilterParameter() }
                                                        ),
                                                        in: 192...512,
                                                        trackHeight: 4,
                                                        knobSize: 12
                                                    )
                                                }
                                            }
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.leading, 12)
                                        .padding(.top, 2)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                    } label: {
                        Text("Emulation & Filter")
                            .font(.system(size: 11, weight: .bold))
                    }
                    }
                    .padding(12)
                    .frame(width: proxy.size.width, alignment: .leading)
                }
                .background(NoHorizontalScrollHelper())
            }
        }
        .frame(minWidth: 320, idealWidth: 330, maxWidth: 380)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func filterPresetDescription(for type: SIDFilterType) -> String {
        switch type {
        case .filter6581Resid:
            return "Standard MOS 6581 curve (470pF caps)"
        case .filter6581R3:
            return "6581 R3 chip with rich resonance harmonics"
        case .filter6581Galway:
            return "Martin Galway sound, warm & deep bass"
        case .filter6581R4:
            return "Vintage breadbin 2200pF capacitor model"
        case .filter8580:
            return "Clean linear cutoff, zero DAC kink"
        case .filterCustom:
            return "Custom tuned filter response"
        @unknown default:
            return "Standard filter response"
        }
    }

    private func stereoWidthLabel(_ width: Float) -> String {
        if width < 0.05 {
            return "Mono (0%)"
        } else if abs(width - 1.0) < 0.05 {
            return "Native (1.0x)"
        } else if width > 1.0 {
            let pct = (width - 1.0) * 100
            return String(format: "+%.0f%% (%.1fx)", pct, width)
        } else {
            let pct = width * 100
            return String(format: "%.0f%% (%.1fx)", pct, width)
        }
    }
}

// MARK: - SID Filter Curve Visualizer Graph (matching original SIDPLAY)

struct SIDFilterCurvePoint {
    let fc: Double
    let f: Double
}

struct SIDFilterCurveGraphView: View {
    @ObservedObject var player: SIDPlayer
    @ObservedObject var telemetry: SIDRegisterTelemetry
    
    init(player: SIDPlayer, telemetry: SIDRegisterTelemetry? = nil) {
        self.player = player
        self.telemetry = telemetry ?? player.registerTelemetry
    }
    
    // Physical calibration points from reSID/reSID-fp (MOS 6581)
    private static let points6581: [SIDFilterCurvePoint] = [
        SIDFilterCurvePoint(fc: 0, f: 220),
        SIDFilterCurvePoint(fc: 128, f: 230),
        SIDFilterCurvePoint(fc: 256, f: 250),
        SIDFilterCurvePoint(fc: 384, f: 300),
        SIDFilterCurvePoint(fc: 512, f: 420),
        SIDFilterCurvePoint(fc: 640, f: 780),
        SIDFilterCurvePoint(fc: 768, f: 1600),
        SIDFilterCurvePoint(fc: 832, f: 2300),
        SIDFilterCurvePoint(fc: 896, f: 3200),
        SIDFilterCurvePoint(fc: 960, f: 4300),
        SIDFilterCurvePoint(fc: 992, f: 5000),
        SIDFilterCurvePoint(fc: 1008, f: 5400),
        SIDFilterCurvePoint(fc: 1016, f: 5700),
        SIDFilterCurvePoint(fc: 1023, f: 6000), // Discontinuity
        SIDFilterCurvePoint(fc: 1024, f: 4600), // Step down (DAC kink)
        SIDFilterCurvePoint(fc: 1032, f: 4800),
        SIDFilterCurvePoint(fc: 1056, f: 5300),
        SIDFilterCurvePoint(fc: 1088, f: 6000),
        SIDFilterCurvePoint(fc: 1120, f: 6600),
        SIDFilterCurvePoint(fc: 1152, f: 7200),
        SIDFilterCurvePoint(fc: 1280, f: 9500),
        SIDFilterCurvePoint(fc: 1408, f: 12000),
        SIDFilterCurvePoint(fc: 1536, f: 14500),
        SIDFilterCurvePoint(fc: 1664, f: 16000),
        SIDFilterCurvePoint(fc: 1792, f: 17100),
        SIDFilterCurvePoint(fc: 1920, f: 17700),
        SIDFilterCurvePoint(fc: 2047, f: 18000)
    ]
    
    // Linear calibration points (MOS 8580)
    private static let points8580: [SIDFilterCurvePoint] = [
        SIDFilterCurvePoint(fc: 0, f: 0),
        SIDFilterCurvePoint(fc: 128, f: 800),
        SIDFilterCurvePoint(fc: 256, f: 1600),
        SIDFilterCurvePoint(fc: 384, f: 2500),
        SIDFilterCurvePoint(fc: 512, f: 3300),
        SIDFilterCurvePoint(fc: 640, f: 4100),
        SIDFilterCurvePoint(fc: 768, f: 4800),
        SIDFilterCurvePoint(fc: 896, f: 5600),
        SIDFilterCurvePoint(fc: 1024, f: 6500),
        SIDFilterCurvePoint(fc: 1152, f: 7500),
        SIDFilterCurvePoint(fc: 1280, f: 8400),
        SIDFilterCurvePoint(fc: 1408, f: 9200),
        SIDFilterCurvePoint(fc: 1536, f: 9800),
        SIDFilterCurvePoint(fc: 1664, f: 10500),
        SIDFilterCurvePoint(fc: 1792, f: 11000),
        SIDFilterCurvePoint(fc: 1920, f: 11700),
        SIDFilterCurvePoint(fc: 2047, f: 12500)
    ]
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            if w > 10 && h > 10 {
                ZStack(alignment: .topLeading) {
                    // Recessed dark well background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.16, green: 0.16, blue: 0.16))
                    
                    // Subtle oscilloscope grid lines
                    Path { p in
                        for frac in [0.25, 0.50, 0.75] {
                            let y = (h - 4) * CGFloat(frac) + 2
                            p.move(to: CGPoint(x: 2, y: y))
                            p.addLine(to: CGPoint(x: w - 2, y: y))
                        }
                        for frac in [0.25, 0.50, 0.75] {
                            let x = (w - 4) * CGFloat(frac) + 2
                            p.move(to: CGPoint(x: x, y: 2))
                            p.addLine(to: CGPoint(x: x, y: h - 2))
                        }
                    }
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                    
                    // Center DAC kink reference marker at x = 50%
                    if player.filterType != .filter8580 {
                        Path { p in
                            let midX = (w - 4) * 0.50 + 2
                            p.move(to: CGPoint(x: midX, y: 2))
                            p.addLine(to: CGPoint(x: midX, y: h - 2))
                        }
                        .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 0.5, dash: [1, 2]))
                    }
                    
                    let curveCoords = computeNormalizedCurve(width: w - 4, height: h - 4)
                    
                    // Subtle gradient fill under curve
                    Path { path in
                        guard !curveCoords.isEmpty else { return }
                        path.move(to: CGPoint(x: curveCoords[0].x + 2, y: h - 2))
                        for pt in curveCoords {
                            path.addLine(to: CGPoint(x: pt.x + 2, y: pt.y + 2))
                        }
                        path.addLine(to: CGPoint(x: (curveCoords.last?.x ?? (w - 4)) + 2, y: h - 2))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Transfer curve stroke line (light silver)
                    Path { path in
                        guard !curveCoords.isEmpty else { return }
                        path.move(to: CGPoint(x: curveCoords[0].x + 2, y: curveCoords[0].y + 2))
                        for i in 1..<curveCoords.count {
                            path.addLine(to: CGPoint(x: curveCoords[i].x + 2, y: curveCoords[i].y + 2))
                        }
                    }
                    .stroke(
                        Color(red: 0.88, green: 0.88, blue: 0.90),
                        style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round)
                    )
                    
                    // Real-time live Cutoff Playhead Marker
                    if player.isPlaying && telemetry.registers.filter.cutoff > 0 {
                        let cutoffRatio = min(1.0, max(0.0, Double(telemetry.registers.filter.cutoff) / 2048.0))
                        let markerX = CGFloat(cutoffRatio) * (w - 4) + 2
                        let markerY = interpolateY(forXRatio: cutoffRatio, coords: curveCoords, height: h - 4) + 2
                        
                        // Vertical dashed tracking line
                        Path { p in
                            p.move(to: CGPoint(x: markerX, y: 2))
                            p.addLine(to: CGPoint(x: markerX, y: h - 2))
                        }
                        .stroke(Color.cyan.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                        
                        // Glowing marker dot on the curve
                        Circle()
                            .fill(Color.cyan.opacity(0.35))
                            .frame(width: 8, height: 8)
                            .position(x: markerX, y: markerY)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 3.5, height: 3.5)
                            .position(x: markerX, y: markerY)
                    }
                    
                    // Chip model and live frequency badges
                    VStack {
                        HStack {
                            Text(player.filterType == .filter8580 ? "8580" : "6581")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.leading, 4)
                                .padding(.top, 3)
                            Spacer()
                        }
                        Spacer()
                        HStack {
                            Spacer()
                            if player.isPlaying && telemetry.registers.filter.cutoff > 0 {
                                let cutoffHz = estimatedCutoffFrequency(fc: Int(telemetry.registers.filter.cutoff))
                                Text(formatFrequency(cutoffHz))
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundColor(.cyan.opacity(0.9))
                                    .padding(.trailing, 4)
                                    .padding(.bottom, 3)
                            } else {
                                Text("FC: 0...2048")
                                    .font(.system(size: 7, design: .monospaced))
                                    .foregroundColor(.secondary.opacity(0.6))
                                    .padding(.trailing, 4)
                                    .padding(.bottom, 3)
                            }
                        }
                    }
                    
                    // Double-beveled border matching original SIDPLAY
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.black.opacity(0.8), lineWidth: 1)
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        .padding(1)
                }
            }
        }
        .help("SID Filter Cutoff Frequency Transfer Function (ReSID-fp)")
    }
    
    private static let graphMinFrequency: Double = 80.0
    private static let graphMaxFrequency: Double = 22000.0

    private func computeNormalizedCurve(width: CGFloat, height: CGFloat) -> [CGPoint] {
        guard width > 10 && height > 10 else { return [] }
        let is8580 = (player.filterType == .filter8580)
        let pts = is8580 ? Self.points8580 : Self.points6581
        
        let slider = max(0.05, min(0.95, player.filterCurve))
        let steepness = player.filterSteepness
        let offsetHz = player.filterOffset
        let range = max(0.05, min(0.95, player.filterRange))
        let kinkiness = max(0.0, min(1.0, player.filterKinkiness))
        let oldCaps = player.old6581Caps
        
        let scaleY = log(Self.graphMaxFrequency)
        let minOffset = log(Self.graphMinFrequency) / scaleY
        let denom = max(0.001, 1.0 - minOffset)
        
        var result: [CGPoint] = []
        for p in pts {
            let xNorm = min(1.0, max(0.0, p.fc / 2048.0))
            let adjF: Double
            if is8580 {
                let steepnessScale = steepness / 132.0
                let curveScale = slider / 0.50
                let rangeScale = range / 0.50
                let rawF = (p.f * steepnessScale * curveScale * rangeScale) + offsetHz
                adjF = max(Self.graphMinFrequency, min(Self.graphMaxFrequency, rawF))
            } else {
                let steepnessFactor = pow(steepness / 120.0, 0.90)
                let rangeScale = pow(range / 0.50, 0.75)
                let power = pow(0.50 / slider, 0.65)
                let gain = pow(slider / 0.50, 0.70)
                let capsFactor = oldCaps ? 0.38 : 1.0
                
                var baseF = p.f
                if p.fc >= 1024 {
                    // DAC kink discontinuity modulation at FC = 1024
                    let kinkMod = kinkiness / 0.17
                    let rawDrop = 1400.0 * (kinkMod - 1.0)
                    baseF = max(200.0, baseF - rawDrop)
                }
                
                let shapeFactor = (xNorm > 0.01) ? pow(xNorm, power - 1.0) : 1.0
                let rawF = ((baseF * steepnessFactor * rangeScale) + offsetHz) * gain * pow(shapeFactor, 0.40) * capsFactor
                adjF = max(Self.graphMinFrequency, min(Self.graphMaxFrequency, rawF))
            }
            
            let logVal = (adjF > 0) ? log(adjF) / scaleY : 0.0
            let yNorm = min(1.0, max(0.0, (logVal - minOffset) / denom))
            
            let x = CGFloat(xNorm) * width
            let y = CGFloat(1.0 - yNorm) * height
            result.append(CGPoint(x: x, y: y))
        }
        return result
    }
    
    private func interpolateY(forXRatio: Double, coords: [CGPoint], height: CGFloat) -> CGFloat {
        guard coords.count > 1 else { return height / 2.0 }
        let targetX = CGFloat(forXRatio) * (coords.last?.x ?? 1.0)
        for i in 0..<(coords.count - 1) {
            let p0 = coords[i]
            let p1 = coords[i + 1]
            if targetX >= p0.x && targetX <= p1.x {
                let dx = p1.x - p0.x
                if dx > 0.001 {
                    let frac = (targetX - p0.x) / dx
                    return p0.y + frac * (p1.y - p0.y)
                }
                return p0.y
            }
        }
        return coords.last?.y ?? height / 2.0
    }
    
    private func estimatedCutoffFrequency(fc: Int) -> Double {
        let is8580 = (player.filterType == .filter8580)
        let pts = is8580 ? Self.points8580 : Self.points6581
        let fcD = Double(fc)
        var baseF: Double = pts.last?.f ?? 18000.0
        for i in 0..<(pts.count - 1) {
            let p0 = pts[i]
            let p1 = pts[i + 1]
            if fcD >= p0.fc && fcD <= p1.fc {
                let span = p1.fc - p0.fc
                if span > 0 {
                    let fFrac = (fcD - p0.fc) / span
                    baseF = p0.f + fFrac * (p1.f - p0.f)
                } else {
                    baseF = p0.f
                }
                break
            }
        }
        
        let slider = max(0.05, min(0.95, player.filterCurve))
        let steepness = player.filterSteepness
        let offsetHz = player.filterOffset
        let range = max(0.05, min(0.95, player.filterRange))
        
        if is8580 {
            let steepnessScale = steepness / 132.0
            let curveScale = slider / 0.50
            let rangeScale = range / 0.50
            return max(20.0, (baseF * steepnessScale * curveScale * rangeScale) + offsetHz)
        } else {
            let xNorm = min(1.0, max(0.0, fcD / 2048.0))
            let steepnessFactor = pow(steepness / 120.0, 0.90)
            let rangeScale = pow(range / 0.50, 0.75)
            let power = pow(0.50 / slider, 0.65)
            let gain = pow(slider / 0.50, 0.70)
            let capsFactor = player.old6581Caps ? 0.38 : 1.0
            
            if fc >= 1024 {
                let kinkMod = player.filterKinkiness / 0.17
                let rawDrop = 1400.0 * (kinkMod - 1.0)
                baseF = max(200.0, baseF - rawDrop)
            }
            
            let shapeFactor = (xNorm > 0.01) ? pow(xNorm, power - 1.0) : 1.0
            let rawF = ((baseF * steepnessFactor * rangeScale) + offsetHz) * gain * pow(shapeFactor, 0.40) * capsFactor
            return max(20.0, rawF)
        }
    }
    
    private func formatFrequency(_ hz: Double) -> String {
        if hz >= 1000.0 {
            return String(format: "%.1f kHz", hz / 1000.0)
        } else {
            return String(format: "%.0f Hz", hz)
        }
    }
}

// MARK: - 3-Column Voice Register View

struct VoiceColumnView: View {
    let title: String
    let voice: SIDVoiceRegisters
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.primary)
            
            Text("Freq: \(String(format: "$%04X", voice.frequency))")
            Text("PW:   \(String(format: "$%03X", voice.pulseWidth))")
            Text("Wave: \(String(format: "$%02X", voice.controlRegister))")
            Text(voice.formattedADSR)
        }
        .font(.system(size: 9, design: .monospaced))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Classic Mixer Row with Pill Buttons

struct ClassicMixerRow: View {
    let title: String
    @Binding var volume: Float
    let isMuted: Bool
    let isSolo: Bool
    let onMute: () -> Void
    let onSolo: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .leading)
            
            FixedSizeSlider(value: $volume, in: 0.0...1.0, trackHeight: 4, knobSize: 12)
                .frame(maxWidth: .infinity)
            
            Button(action: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    onMute()
                }
            }) {
                Text("Mute")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 38, height: 18)
                    .background(isMuted ? Color.red.opacity(0.8) : Color.primary.opacity(0.1))
                    .foregroundColor(isMuted ? .white : .primary)
                    .cornerRadius(9)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    onSolo()
                }
            }) {
                Text("Solo")
                    .font(.system(size: 10, weight: .medium))
                    .frame(width: 38, height: 18)
                    .background(isSolo ? Color.yellow.opacity(0.8) : Color.primary.opacity(0.1))
                    .foregroundColor(isSolo ? .black : .primary)
                    .cornerRadius(9)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Classic Glowing Cyan CRT Oscilloscope

struct ClassicOscilloscopeView: View {
    var player: SIDPlayer? = nil
    let isPlaying: Bool
    var isExpanded: Bool = true
    
    var body: some View {
        FastOscilloscopeRepresentable(player: player, isPlaying: isPlaying, isExpanded: isExpanded)
    }
}

struct FastOscilloscopeRepresentable: NSViewRepresentable {
    var player: SIDPlayer? = nil
    let isPlaying: Bool
    let isExpanded: Bool
    
    func makeNSView(context: Context) -> FastOscilloscopeNSView {
        let view = FastOscilloscopeNSView()
        view.player = player
        view.isPlaying = isPlaying
        view.isExpanded = isExpanded
        return view
    }
    
    func updateNSView(_ nsView: FastOscilloscopeNSView, context: Context) {
        nsView.player = player
        nsView.isPlaying = isPlaying
        nsView.isExpanded = isExpanded
    }
}

final class FastOscilloscopeNSView: NSView {
    weak var player: SIDPlayer?
    var isPlaying: Bool = false {
        didSet {
            if isPlaying != oldValue {
                updateDisplayLinkState()
                needsDisplay = true
            }
        }
    }
    
    var isExpanded: Bool = true {
        didSet {
            if isExpanded != oldValue {
                updateDisplayLinkState()
                if isExpanded {
                    needsDisplay = true
                }
            }
        }
    }
    
    private var displayLink: CADisplayLink?
    private var sampleBuffer = [Float](repeating: 0, count: 512)
    private var currentPeak: CGFloat = 0.25
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            setupDisplayLink()
        } else {
            tearDownDisplayLink()
        }
    }
    
    private func setupDisplayLink() {
        guard displayLink == nil else { return }
        let link = self.displayLink(target: self, selector: #selector(displayLinkDidFire(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
        updateDisplayLinkState()
    }
    
    private func tearDownDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    private func updateDisplayLinkState() {
        displayLink?.isPaused = !(isPlaying && isExpanded && window != nil)
    }
    
    @objc private func displayLinkDidFire(_ link: CADisplayLink) {
        guard isPlaying, isExpanded, window != nil else { return }
        needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let bounds = self.bounds
        context.setFillColor(NSColor.black.cgColor)
        context.fill(bounds)
        
        let midY = bounds.height / 2.0
        let width = bounds.width
        let height = bounds.height
        
        guard isPlaying else {
            // Draw idle glowing cyan zero-line with classic CRT phosphor styling
            context.setStrokeColor(CGColor(red: 0.2, green: 0.8, blue: 0.9, alpha: 0.35))
            context.setLineWidth(1.2)
            context.move(to: CGPoint(x: 0, y: midY))
            context.addLine(to: CGPoint(x: width, y: midY))
            context.strokePath()
            return
        }
        
        // Fetch fresh audio samples directly from the player or engine bridge
        let count = min(512, max(64, Int(width)))
        if sampleBuffer.count < count {
            sampleBuffer = [Float](repeating: 0, count: count)
        }
        
        sampleBuffer.withUnsafeMutableBufferPointer { ptr in
            if let base = ptr.baseAddress {
                if let p = player {
                    p.copyOscilloscopeSamples(base, count: count)
                } else {
                    SIDEngineBridge.shared().copyOscilloscopeSamples(base, count: count)
                }
            }
        }
        
        // 1. Analyze instantaneous peak and smoothly adapt visual sensitivity
        var framePeak: CGFloat = 0.001
        for i in 0..<count {
            let v = abs(CGFloat(sampleBuffer[i]))
            if v > framePeak { framePeak = v }
        }
        currentPeak = max(framePeak, currentPeak * 0.92, 0.02)
        let visualGain = min(14.0, 0.75 / currentPeak)
        let amp = height * 0.45
        
        // 2. Rising zero-crossing trigger for crystal-clear waveform phase stabilization
        var triggerOffset = 0
        let searchLimit = min(128, count / 3)
        for i in 1..<searchLimit {
            if sampleBuffer[i - 1] <= 0 && sampleBuffer[i] > 0 {
                triggerOffset = i
                break
            }
        }
        
        let drawCount = max(16, count - triggerOffset)
        let stepX = width / CGFloat(drawCount)
        
        let path = CGMutablePath()
        for i in 0..<drawCount {
            let x = CGFloat(i) * stepX
            let rawSample = CGFloat(sampleBuffer[i + triggerOffset])
            let compressed = tanh(rawSample * visualGain)
            let y = midY - (compressed * amp)
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        
        // Pass 1: CRT Cyan Glow
        context.addPath(path)
        context.setStrokeColor(CGColor(red: 0.2, green: 0.85, blue: 0.95, alpha: 0.35))
        context.setLineWidth(2.8)
        context.strokePath()
        
        // Pass 2: Bright Crisp Cyan CRT Core
        context.addPath(path)
        context.setStrokeColor(CGColor(red: 0.25, green: 0.95, blue: 1.0, alpha: 1.0))
        context.setLineWidth(1.4)
        context.strokePath()
    }
    
    deinit {
        tearDownDisplayLink()
    }
}

// MARK: - AppKit Scroll View Horizontal Lock Helper

struct NoHorizontalScrollHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        NonScrollingNSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? NonScrollingNSView)?.configureScrollView()
    }
}

final class NonScrollingNSView: NSView {
    private var observer: NSObjectProtocol?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureScrollView()
    }
    
    func configureScrollView() {
        guard let scrollView = enclosingScrollView else { return }
        scrollView.hasHorizontalScroller = false
        scrollView.horizontalScrollElasticity = .none
        
        let clipView = scrollView.contentView
        clipView.postsBoundsChangedNotifications = true
        
        if clipView.bounds.origin.x != 0 {
            var origin = clipView.bounds.origin
            origin.x = 0
            clipView.scroll(to: origin)
        }
        
        if observer == nil {
            observer = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: clipView,
                queue: .main
            ) { [weak clipView] _ in
                guard let clip = clipView else { return }
                if clip.bounds.origin.x != 0 {
                    var newOrigin = clip.bounds.origin
                    newOrigin.x = 0
                    clip.scroll(to: newOrigin)
                }
            }
        }
    }
    
    deinit {
        if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
        }
    }
}

