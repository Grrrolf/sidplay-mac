//
//  SIDPlayer.swift
//  SIDPLAY
//
//  Main Swift Audio Service & Observable Model driving playback,
//  real-time register telemetry, and engine control.
//

import Foundation
import Combine

public enum SIDPlayerError: LocalizedError {
    case fileNotFound(String)
    case loadFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "SID file not found at path: \(path)"
        case .loadFailed(let path):
            return "Failed to load SID tune at path: \(path)"
        }
    }
}

public final class SIDRegisterTelemetry: ObservableObject {
    @Published public internal(set) var registers: SIDRegisters = .empty
}

@objc(SPSwiftPlayer)
@MainActor
public final class SIDPlayer: NSObject, ObservableObject, SIDPlaybackEngine {
    @objc public static let shared = SIDPlayer()
    
    // MARK: - Published State
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var isTuneLoaded: Bool = false
    @Published public private(set) var currentSubtune: Int = 0
    @Published public private(set) var subtuneCount: Int = 0
    @Published public private(set) var defaultSubtune: Int = 0
    @Published public private(set) var playbackSeconds: Int = 0
    @Published public private(set) var metadata: SIDTuneMetadata?
    
    /// Dedicated observable object for 30 Hz register telemetry, isolating frequent updates from views that don't need them
    public let registerTelemetry = SIDRegisterTelemetry()
    public var registers: SIDRegisters {
        registerTelemetry.registers
    }
    
    @Published public var volume: Float = 1.0 {
        didSet {
            bridge.volume = volume
        }
    }
    
    @Published public var tempo: Int = 100 {
        didSet {
            bridge.tempo = tempo
        }
    }
    
    // MARK: - Modern Emulation & Filter Controls (libsidplayfp / resid-fp)
    @Published public var engineBackend: SIDEngineBackend = .cycleExact {
        didSet {
            if oldValue != engineBackend {
                bridge.engineBackend = engineBackend
                engineName = bridge.engineName
                updateStateFromBridge()
            }
        }
    }
    @Published public private(set) var isLegacyEngineAvailable: Bool = false
    @Published public private(set) var engineName: String = "Cycle-Exact (libsidplayfp)"
    
    @Published public var sidModel: SIDChipModel = .auto {
        didSet {
            bridge.sidModel = sidModel
            updateFilterForCurrentChipModel()
        }
    }
    
    @Published public var clockSpeed: SIDClockSpeed = .auto {
        didSet {
            bridge.clockSpeed = clockSpeed
        }
    }
    
    @Published public var filterType: SIDFilterType = .filter6581Resid {
        didSet {
            bridge.filterType = filterType
            if filterType != .filter8580 && filterType != .filterCustom {
                last6581FilterType = filterType
            }
        }
    }
    
    /// Remembers the user's preferred 6581 preset (Standard, Galway, R3, R4) when dynamically switching to 8580
    private var last6581FilterType: SIDFilterType = .filter6581Resid
    
    @Published public var filterCurve: Double = 0.50 {
        didSet {
            bridge.filterCurve = filterCurve
        }
    }

    @Published public var filterSteepness: Double = 120.0 {
        didSet {
            bridge.filterSteepness = filterSteepness
        }
    }

    @Published public var filterOffset: Double = -375.0 {
        didSet {
            bridge.filterOffset = filterOffset
        }
    }

    @Published public var filterRange: Double = 0.50 {
        didSet {
            bridge.filterRange = filterRange
        }
    }

    @Published public var filterKinkiness: Double = 0.17 {
        didSet {
            bridge.filterKinkiness = filterKinkiness
        }
    }

    @Published public var old6581Caps: Bool = false {
        didSet {
            bridge.old6581Caps = old6581Caps
        }
    }

    @Published public var distortionEnabled: Bool = true {
        didSet {
            bridge.distortionEnabled = distortionEnabled
        }
    }

    @Published public var distortionRate: Int = 1500 {
        didSet {
            bridge.distortionRate = distortionRate
        }
    }

    @Published public var distortionHeadroom: Int = 400 {
        didSet {
            bridge.distortionHeadroom = distortionHeadroom
        }
    }

    /// Selects a filter preset and configures all related sliders to the preset defaults
    public func selectFilterPreset(_ preset: SIDFilterType) {
        filterType = preset
        applyPresetDefaults(for: preset)
    }

    /// Resets all filter and distortion parameters to default values matching the current preset / chip model
    public func resetFilterToDefaults() {
        let is8580: Bool
        if sidModel == .mos8580 {
            is8580 = true
        } else if sidModel == .mos6581 {
            is8580 = false
        } else {
            let chip0 = bridge.chipModelDescription(forChip: 0)
            let composite = bridge.chipModelDescription
            is8580 = chip0.contains("8580") || composite.contains("8580")
        }
        
        let targetPreset: SIDFilterType
        if is8580 {
            targetPreset = .filter8580
        } else {
            targetPreset = (last6581FilterType == .filter8580 || last6581FilterType == .filterCustom) ? .filter6581Resid : last6581FilterType
        }
        
        selectFilterPreset(targetPreset)
    }

    public func applyPresetDefaults(for preset: SIDFilterType) {
        switch preset {
        case .filter6581Resid:
            filterCurve = 0.50
            filterSteepness = 120.0
            filterOffset = -375.0
            filterRange = 0.50
            filterKinkiness = 0.17
            old6581Caps = false
            distortionEnabled = true
            distortionRate = 1500
            distortionHeadroom = 400
        case .filter6581R3:
            filterCurve = 0.45
            filterSteepness = 120.0
            filterOffset = -375.0
            filterRange = 0.50
            filterKinkiness = 0.17
            old6581Caps = false
            distortionEnabled = true
            distortionRate = 1600
            distortionHeadroom = 400
        case .filter6581Galway:
            filterCurve = 0.65
            filterSteepness = 120.0
            filterOffset = -725.0
            filterRange = 0.60
            filterKinkiness = 0.17
            old6581Caps = false
            distortionEnabled = true
            distortionRate = 1500
            distortionHeadroom = 400
        case .filter6581R4:
            filterCurve = 0.55
            filterSteepness = 132.0
            filterOffset = 0.0
            filterRange = 0.55
            filterKinkiness = 0.17
            old6581Caps = true
            distortionEnabled = true
            distortionRate = 1500
            distortionHeadroom = 400
        case .filter8580:
            filterCurve = 0.50
            filterSteepness = 132.0
            filterOffset = 0.0
            filterRange = 0.50
            filterKinkiness = 0.0
            old6581Caps = false
            distortionEnabled = true
            distortionRate = 3200
            distortionHeadroom = 235
        case .filterCustom:
            break
        }
    }

    /// Called when the user manually tweaks any slider in custom mode
    public func userTunedFilterParameter() {
        if filterType != .filterCustom {
            filterType = .filterCustom
        }
    }
    
    @Published public var selectedSidChip: Int = 0 {
        didSet {
            registerTelemetry.registers = readRegisters(chip: selectedSidChip)
            refreshVoiceState()
        }
    }
    
    // Voice mute / solo status
    @Published public private(set) var voiceMuted: [Bool] = [false, false, false]
    @Published public private(set) var voiceSolo: [Bool] = [false, false, false]
    @Published public private(set) var voiceVolumes: [Float] = [1.0, 1.0, 1.0]
    
    // Oscilloscope audio samples buffer
    @Published public var audioSamples: [Float] = [Float](repeating: 0, count: 256)
    
    // MARK: - Underlying Objective-C++ Engine Bridge
    private let bridge: SIDEngineBridge
    private var telemetryTimer: Timer?
    
    public init(bridge: SIDEngineBridge = SIDEngineBridge.shared()) {
        self.bridge = bridge
        super.init()
        self.engineBackend = bridge.engineBackend
        self.isLegacyEngineAvailable = bridge.isLegacyEngineAvailable
        self.engineName = bridge.engineName
        self.volume = bridge.volume
        self.tempo = bridge.tempo
        self.sidModel = bridge.sidModel
        self.clockSpeed = bridge.clockSpeed
        self.filterType = bridge.filterType
        if bridge.filterType != .filter8580 && bridge.filterType != .filterCustom {
            self.last6581FilterType = bridge.filterType
        }
        self.filterCurve = bridge.filterCurve
        self.filterSteepness = bridge.filterSteepness
        self.filterOffset = bridge.filterOffset
        self.filterRange = bridge.filterRange
        self.filterKinkiness = bridge.filterKinkiness
        self.old6581Caps = bridge.old6581Caps
        self.distortionEnabled = bridge.distortionEnabled
        self.distortionRate = Int(bridge.distortionRate)
        self.distortionHeadroom = Int(bridge.distortionHeadroom)
        self.refreshVoiceState()
    }
    
    public convenience override init() {
        self.init(bridge: SIDEngineBridge.shared())
    }
    
    deinit {
        telemetryTimer?.invalidate()
    }
    
    // MARK: - Playback Controls
    
    public func loadTune(at path: String, subtune: Int = 0) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw SIDPlayerError.fileNotFound(path)
        }
        
        let loaded = bridge.loadTune(atPath: path, subtune: subtune)
        guard loaded else {
            throw SIDPlayerError.loadFailed(path)
        }
        
        updateStateFromBridge()
        isAdvancingTune = false
    }
    
    @discardableResult
    public func play() -> Bool {
        guard isTuneLoaded else { return false }
        let success = bridge.play()
        if success {
            isPlaying = true
            startTelemetryTimer()
        }
        return success
    }
    
    public func pause() {
        bridge.pause()
        isPlaying = false
        stopTelemetryTimer()
    }
    
    public func stop() {
        bridge.stop()
        isPlaying = false
        isAdvancingTune = false
        playbackSeconds = 0
        stopTelemetryTimer()
        registerTelemetry.registers = .empty
    }
    
    @discardableResult
    public func togglePlayPause() -> Bool {
        if isPlaying {
            pause()
            return false
        } else {
            return play()
        }
    }
    
    // MARK: - Subtunes
    
    @discardableResult
    public func selectSubtune(_ index: Int) -> Bool {
        let success = bridge.selectSubtune(index)
        if success {
            updateStateFromBridge()
        }
        return success
    }
    
    @discardableResult
    public func nextSubtune() -> Bool {
        let success = bridge.nextSubtune()
        if success {
            updateStateFromBridge()
        }
        return success
    }
    
    @discardableResult
    public func previousSubtune() -> Bool {
        let success = bridge.previousSubtune()
        if success {
            updateStateFromBridge()
        }
        return success
    }
    
    // MARK: - Voice Mixing
    
    public func refreshVoiceState() {
        for v in 0..<3 {
            voiceVolumes[v] = bridge.voiceVolume(v, chip: selectedSidChip)
            voiceMuted[v] = bridge.isVoiceMuted(v, chip: selectedSidChip)
            voiceSolo[v] = bridge.isVoiceSolo(v, chip: selectedSidChip)
        }
    }
    
    public func setVoice(_ voice: Int, volume: Float) {
        setVoice(voice, chip: selectedSidChip, volume: volume)
    }
    
    public func setVoice(_ voice: Int, chip: Int, volume: Float) {
        guard voice >= 0 && voice < 3 && chip >= 0 && chip < 4 else { return }
        bridge.setVoice(voice, chip: chip, volume: volume)
        if chip == selectedSidChip {
            voiceVolumes[voice] = volume
        }
    }
    
    public func setVoice(_ voice: Int, muted: Bool) {
        setVoice(voice, chip: selectedSidChip, muted: muted)
    }
    
    public func setVoice(_ voice: Int, chip: Int, muted: Bool) {
        guard voice >= 0 && voice < 3 && chip >= 0 && chip < 4 else { return }
        bridge.setVoice(voice, chip: chip, muted: muted)
        if chip == selectedSidChip {
            voiceMuted[voice] = muted
        }
    }
    
    public func setVoice(_ voice: Int, solo: Bool) {
        setVoice(voice, chip: selectedSidChip, solo: solo)
    }
    
    public func setVoice(_ voice: Int, chip: Int, solo: Bool) {
        guard voice >= 0 && voice < 3 && chip >= 0 && chip < 4 else { return }
        bridge.setVoice(voice, chip: chip, solo: solo)
        if chip == selectedSidChip {
            for i in 0..<3 {
                voiceSolo[i] = bridge.isVoiceSolo(i, chip: chip)
                voiceMuted[i] = bridge.isVoiceMuted(i, chip: chip)
            }
        }
    }
    
    public func isVoiceMuted(_ voice: Int) -> Bool {
        isVoiceMuted(voice, chip: selectedSidChip)
    }
    
    public func isVoiceMuted(_ voice: Int, chip: Int) -> Bool {
        guard voice >= 0 && voice < 3 && chip >= 0 && chip < 4 else { return false }
        return bridge.isVoiceMuted(voice, chip: chip)
    }
    
    public func isVoiceSolo(_ voice: Int) -> Bool {
        isVoiceSolo(voice, chip: selectedSidChip)
    }
    
    public func isVoiceSolo(_ voice: Int, chip: Int) -> Bool {
        guard voice >= 0 && voice < 3 && chip >= 0 && chip < 4 else { return false }
        return bridge.isVoiceSolo(voice, chip: chip)
    }
    
    // MARK: - Telemetry & Registers
    
    public func readRegisters() -> SIDRegisters {
        readRegisters(chip: selectedSidChip)
    }
    
    public func readRegisters(chip: Int) -> SIDRegisters {
        var raw = [UInt8](repeating: 0, count: 25)
        raw.withUnsafeMutableBufferPointer { ptr in
            if let baseAddress = ptr.baseAddress {
                bridge.getRegisterFrame(baseAddress, length: 25, chip: chip)
            }
        }
        return SIDRegisters(bytes: raw)
    }
    
    public func copyAudioSamples(into buffer: inout [Float]) {
        guard !buffer.isEmpty else { return }
        buffer.withUnsafeMutableBufferPointer { ptr in
            if let baseAddress = ptr.baseAddress {
                bridge.copyAudioSamples(baseAddress, count: ptr.count)
            }
        }
    }
    
    public func copyOscilloscopeSamples(_ buffer: UnsafeMutablePointer<Float>, count: Int) {
        bridge.copyOscilloscopeSamples(buffer, count: count)
    }
    
    // MARK: - Formatting Helpers
    
    public var currentTimeString: String {
        let mins = playbackSeconds / 60
        let secs = playbackSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
    
    // MARK: - Internal Helpers
    
    private func updateStateFromBridge() {
        self.engineBackend = bridge.engineBackend
        self.isLegacyEngineAvailable = bridge.isLegacyEngineAvailable
        self.engineName = bridge.engineName
        self.isTuneLoaded = bridge.isTuneLoaded
        self.isPlaying = bridge.isPlaying
        self.currentSubtune = bridge.currentSubtune
        self.subtuneCount = bridge.subtuneCount
        self.defaultSubtune = bridge.defaultSubtune
        self.playbackSeconds = bridge.playbackSeconds
        self.selectedSidChip = 0
        self.refreshVoiceState()
        
        if let currentPath = bridge.currentTunePath {
            var chipList: [SIDChipInfo] = []
            let count = max(1, bridge.sidChipCount)
            for i in 0..<count {
                let addr = bridge.sidAddress(forChip: i)
                let model = bridge.chipModelDescription(forChip: i)
                chipList.append(SIDChipInfo(chipIndex: i, baseAddress: addr, model: model.isEmpty ? "MOS 6581" : model))
            }
            
            self.metadata = SIDTuneMetadata(
                filePath: currentPath,
                title: bridge.title,
                author: bridge.author,
                releaseInfo: bridge.releaseInfo,
                format: bridge.format,
                chipModel: bridge.chipModelDescription,
                loadAddress: bridge.loadAddress,
                initAddress: bridge.initAddress,
                playAddress: bridge.playAddress,
                fileSize: bridge.fileSize,
                songLengthSeconds: bridge.songLengthSeconds,
                subtuneCount: bridge.subtuneCount,
                defaultSubtune: bridge.defaultSubtune,
                sidChipCount: count,
                secondSidAddress: bridge.secondSidAddress,
                thirdSidAddress: bridge.thirdSidAddress,
                fourthSidAddress: bridge.fourthSidAddress,
                chips: chipList
            )
        } else {
            self.metadata = nil
        }
        
        updateFilterForCurrentChipModel()
    }
    
    /// Dynamically switches between the user's preferred 6581 filter preset and the 8580 filter
    /// based on the active SID chip model (auto-detected from tune or manual user selection).
    public func updateFilterForCurrentChipModel() {
        let is8580: Bool
        if sidModel == .mos8580 {
            is8580 = true
        } else if sidModel == .mos6581 {
            is8580 = false
        } else {
            // Auto detection based on tune chip model metadata
            let chip0 = bridge.chipModelDescription(forChip: 0)
            let composite = bridge.chipModelDescription
            is8580 = chip0.contains("8580") || composite.contains("8580")
        }
        
        if is8580 {
            if filterType != .filter8580 {
                if filterType != .filterCustom {
                    last6581FilterType = filterType
                }
                selectFilterPreset(.filter8580)
            }
        } else {
            if filterType == .filter8580 {
                selectFilterPreset(last6581FilterType)
            }
        }
    }
    
    private func startTelemetryTimer() {
        stopTelemetryTimer()
        // 30 Hz refresh rate for register visualizer & elapsed time (synchronous on main thread)
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let currentSec = self.bridge.playbackSeconds
            if self.playbackSeconds != currentSec {
                self.playbackSeconds = currentSec
            }
            self.registerTelemetry.registers = self.readRegisters(chip: self.selectedSidChip)
            self.checkEndOfTune()
        }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        telemetryTimer = timer
    }
    
    private func stopTelemetryTimer() {
        telemetryTimer?.invalidate()
        telemetryTimer = nil
    }
    
    // MARK: - Auto-Advance & End-of-Tune Detection
    
    private var isAdvancingTune = false
    
    private func checkEndOfTune() {
        guard isTuneLoaded, isPlaying, !isAdvancingTune else { return }
        
        var targetLength = metadata?.songLengthSeconds ?? 0
        if targetLength <= 0 {
            let prefDefault = UserDefaults.standard.integer(forKey: "DefaultPlayTime")
            targetLength = prefDefault > 0 ? prefDefault : 180
        }
        
        guard targetLength > 0, playbackSeconds >= targetLength else { return }
        
        let library = SIDLibraryManager.shared
        if library.isRepeatEnabled {
            // Repeat current tune: restart from beginning
            _ = selectSubtune(currentSubtune)
            _ = play()
        } else if library.isAutoAdvanceEnabled {
            isAdvancingTune = true
            Task { @MainActor in
                library.playNextInQueue()
                try? await Task.sleep(nanoseconds: 600_000_000)
                self.isAdvancingTune = false
            }
        } else {
            // Reached song length and auto-advance disabled: pause playback
            pause()
        }
    }
    
    // MARK: - Smoke Test
    
    @objc(runSmokeTestWithTunePath:)
    @discardableResult
    public static func runSmokeTest(tunePath: String) -> Bool {
        print("=== SIDPLAY Swift Audio Engine Smoke Test ===")
        print("Loading tune: \(tunePath)")
        do {
            let player = SIDPlayer.shared
            try player.loadTune(at: tunePath, subtune: 0)
            if let meta = player.metadata {
                print("Title:      \(meta.title)")
                print("Author:     \(meta.author)")
                print("Released:   \(meta.releaseInfo)")
                print("Format:     \(meta.format) | Chip: \(meta.chipModel)")
                print("Subtunes:   \(meta.subtuneCount) (default: \(meta.defaultSubtune))")
                print("Addresses:  Load \(meta.formattedLoadAddress), Init \(meta.formattedInitAddress), Play \(meta.formattedPlayAddress)")
            }
            print("Starting audio playback...")
            let started = player.play()
            print("Playback started: \(started)")
            guard started else { return false }
            
            // Pump runloop for 2.0 seconds while sampling real-time registers
            for i in 1...4 {
                RunLoop.current.run(until: Date().addingTimeInterval(0.5))
                let reg = player.readRegisters()
                print("Sample #\(i) [\(Double(i) * 0.5)s] - V1: \(reg.voice1.formattedFrequency) \(reg.voice1.waveformDescription) | V2: \(reg.voice2.formattedFrequency) \(reg.voice2.waveformDescription) | V3: \(reg.voice3.formattedFrequency) \(reg.voice3.waveformDescription) | Cutoff: \(String(format: "$%04X", reg.filter.cutoff)) Mode: \(reg.filter.modeDescription)")
            }
            player.stop()
            print("Playback stopped cleanly. Test PASSED!")
            return true
        } catch {
            print("Test FAILED with error: \(error)")
            return false
        }
    }
}
