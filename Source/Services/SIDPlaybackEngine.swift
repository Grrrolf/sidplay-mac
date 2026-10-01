//
//  SIDPlaybackEngine.swift
//  SIDPLAY
//
//  Pure Swift protocol establishing the architectural seam between
//  audio emulation engine and user interface.
//

import Foundation

/// Primary protocol defining the SID audio engine contract.
/// Any future engine implementation (e.g. libsidplayfp, reSID 1.0, or U64 streaming)
/// will conform to this protocol without modifying any UI code.
public protocol SIDPlaybackEngine: AnyObject {
    // State
    var isPlaying: Bool { get }
    var isTuneLoaded: Bool { get }
    var currentSubtune: Int { get }
    var subtuneCount: Int { get }
    var defaultSubtune: Int { get }
    var playbackSeconds: Int { get }
    var volume: Float { get set }
    var tempo: Int { get set }
    
    // Metadata
    var metadata: SIDTuneMetadata? { get }
    
    // Playback Actions
    func loadTune(at path: String, subtune: Int) throws
    func play() -> Bool
    func pause()
    func stop()
    func togglePlayPause() -> Bool
    
    func selectSubtune(_ index: Int) -> Bool
    func nextSubtune() -> Bool
    func previousSubtune() -> Bool
    
    // Voice Mixer
    func setVoice(_ voice: Int, volume: Float)
    func setVoice(_ voice: Int, muted: Bool)
    func isVoiceMuted(_ voice: Int) -> Bool
    func setVoice(_ voice: Int, solo: Bool)
    func isVoiceSolo(_ voice: Int) -> Bool
    
    // Hardware Registers & Audio Waveforms
    func readRegisters() -> SIDRegisters
    func copyAudioSamples(into buffer: inout [Float])
}
