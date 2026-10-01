//
//  SIDRegisters.swift
//  SIDPLAY
//
//  Decodes and formats real-time SID hardware registers ($D400 - $D418).
//

import Foundation

public struct SIDVoiceRegisters: Sendable, Equatable {
    public let frequency: UInt16
    public let pulseWidth: UInt16
    public let controlRegister: UInt8
    public let attack: UInt8
    public let decay: UInt8
    public let sustain: UInt8
    public let release: UInt8
    
    // Decoded control flags
    public var isGateOn: Bool { (controlRegister & 0x01) != 0 }
    public var isSyncOn: Bool { (controlRegister & 0x02) != 0 }
    public var isRingModOn: Bool { (controlRegister & 0x04) != 0 }
    public var isTestOn: Bool { (controlRegister & 0x08) != 0 }
    public var isTriangleWave: Bool { (controlRegister & 0x10) != 0 }
    public var isSawtoothWave: Bool { (controlRegister & 0x20) != 0 }
    public var isPulseWave: Bool { (controlRegister & 0x40) != 0 }
    public var isNoiseWave: Bool { (controlRegister & 0x80) != 0 }
    
    public var waveformDescription: String {
        var forms: [String] = []
        if isNoiseWave { forms.append("Noise") }
        if isPulseWave { forms.append("Pulse") }
        if isSawtoothWave { forms.append("Saw") }
        if isTriangleWave { forms.append("Tri") }
        return forms.isEmpty ? "None" : forms.joined(separator: "+")
    }
    
    /// Estimated frequency in Hz assuming PAL clock rate (~985248 Hz)
    /// F_out = (Fn * F_clk) / 16777216
    public var frequencyInHz: Double {
        Double(frequency) * 985248.4 / 16777216.0
    }
    
    public var formattedFrequency: String {
        String(format: "$%04X (%.1f Hz)", frequency, frequencyInHz)
    }
    
    public var formattedPulseWidth: String {
        String(format: "$%03X (%.1f%%)", pulseWidth, (Double(pulseWidth) / 4095.0) * 100.0)
    }
    
    public var formattedADSR: String {
        String(format: "A:%X D:%X S:%X R:%X", attack, decay, sustain, release)
    }
}

public struct SIDFilterRegisters: Sendable, Equatable {
    public let cutoff: UInt16
    public let resonance: UInt8
    public let filterVoice1: Bool
    public let filterVoice2: Bool
    public let filterVoice3: Bool
    public let filterExternal: Bool
    public let lowPass: Bool
    public let bandPass: Bool
    public let highPass: Bool
    public let voice3Off: Bool
    public let volume: UInt8
    
    public var modeDescription: String {
        var modes: [String] = []
        if lowPass { modes.append("LP") }
        if bandPass { modes.append("BP") }
        if highPass { modes.append("HP") }
        return modes.isEmpty ? "Off" : modes.joined(separator: "+")
    }
    
    public var routedVoicesDescription: String {
        var routed: [String] = []
        if filterVoice1 { routed.append("V1") }
        if filterVoice2 { routed.append("V2") }
        if filterVoice3 { routed.append("V3") }
        if filterExternal { routed.append("Ext") }
        return routed.isEmpty ? "None" : routed.joined(separator: ", ")
    }
}

public struct SIDRegisters: Sendable, Equatable {
    public let rawBytes: [UInt8]
    public let voice1: SIDVoiceRegisters
    public let voice2: SIDVoiceRegisters
    public let voice3: SIDVoiceRegisters
    public let filter: SIDFilterRegisters
    
    public init(bytes: [UInt8]) {
        var buf = [UInt8](repeating: 0, count: 25)
        for i in 0..<min(bytes.count, 25) {
            buf[i] = bytes[i]
        }
        self.rawBytes = buf
        
        // Voice 1: $D400 - $D406
        self.voice1 = SIDVoiceRegisters(
            frequency: UInt16(buf[0]) | (UInt16(buf[1]) << 8),
            pulseWidth: (UInt16(buf[2]) | (UInt16(buf[3] & 0x0F) << 8)),
            controlRegister: buf[4],
            attack: (buf[5] >> 4) & 0x0F,
            decay: buf[5] & 0x0F,
            sustain: (buf[6] >> 4) & 0x0F,
            release: buf[6] & 0x0F
        )
        
        // Voice 2: $D407 - $D40D
        self.voice2 = SIDVoiceRegisters(
            frequency: UInt16(buf[7]) | (UInt16(buf[8]) << 8),
            pulseWidth: (UInt16(buf[9]) | (UInt16(buf[10] & 0x0F) << 8)),
            controlRegister: buf[11],
            attack: (buf[12] >> 4) & 0x0F,
            decay: buf[12] & 0x0F,
            sustain: (buf[13] >> 4) & 0x0F,
            release: buf[13] & 0x0F
        )
        
        // Voice 3: $D40E - $D414
        self.voice3 = SIDVoiceRegisters(
            frequency: UInt16(buf[14]) | (UInt16(buf[15]) << 8),
            pulseWidth: (UInt16(buf[16]) | (UInt16(buf[17] & 0x0F) << 8)),
            controlRegister: buf[18],
            attack: (buf[19] >> 4) & 0x0F,
            decay: buf[19] & 0x0F,
            sustain: (buf[20] >> 4) & 0x0F,
            release: buf[20] & 0x0F
        )
        
        // Filter: $D415 - $D418
        let cutoff = UInt16(buf[21] & 0x07) | (UInt16(buf[22]) << 3)
        let resFilt = buf[23]
        let modeVol = buf[24]
        
        self.filter = SIDFilterRegisters(
            cutoff: cutoff,
            resonance: (resFilt >> 4) & 0x0F,
            filterVoice1: (resFilt & 0x01) != 0,
            filterVoice2: (resFilt & 0x02) != 0,
            filterVoice3: (resFilt & 0x04) != 0,
            filterExternal: (resFilt & 0x08) != 0,
            lowPass: (modeVol & 0x10) != 0,
            bandPass: (modeVol & 0x20) != 0,
            highPass: (modeVol & 0x40) != 0,
            voice3Off: (modeVol & 0x80) != 0,
            volume: modeVol & 0x0F
        )
    }
    
    public static var empty: SIDRegisters {
        SIDRegisters(bytes: [UInt8](repeating: 0, count: 25))
    }
}
