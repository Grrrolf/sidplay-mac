//
//  SIDDemosceneLogoView.swift
//  SIDPLAY
//
//  Complete and faithful recreation of the iconic SIDPLAY demoscene effect
//  from Resources/logo.qtz and Resources/sidplay_logo.png.
//
//  Features:
//  1. Layer 1 (Background): 16-particle Lissajous sine-bob snake trail (Iterator_1) with glowing halos.
//  2. Layer 2 (Foreground): Horizontal sine-wave raster wobbler on the dot-matrix logo (techtech GLSL kernel).
//

import SwiftUI
import AppKit

public struct SIDDemosceneLogoView: View {
    @Environment(\.colorScheme) private var colorScheme
    
    private let logoImage: NSImage? = {
        if let url = Bundle.main.url(forResource: "sidplay_logo", withExtension: "png"),
           let img = NSImage(contentsOfFile: url.path) {
            img.isTemplate = true
            return img
        }
        if let img = NSImage(named: "sidplay_logo") {
            img.isTemplate = true
            return img
        }
        let devPath = "Resources/sidplay_logo.png"
        if FileManager.default.fileExists(atPath: devPath),
           let img = NSImage(contentsOfFile: devPath) {
            img.isTemplate = true
            return img
        }
        return nil
    }()
    
    private var logoColor: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.90)
        } else {
            return Color(white: 0.12, opacity: 0.85)
        }
    }
    
    private var particleColor: Color {
        if colorScheme == .dark {
            return Color(red: 0.35, green: 0.95, blue: 0.85) // Retro phosphor cyan
        } else {
            return Color(red: 0.15, green: 0.45, blue: 0.75) // C64 blue
        }
    }
    
    public init() {}
    
    public var body: some View {
        if let logo = logoImage {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSinceReferenceDate
                    
                    // Larger, more prominent retro font scaling
                    let targetH: CGFloat = 26.0
                    let targetW: CGFloat = 195.0
                    let centerX = size.width / 2.0
                    let centerY = size.height / 2.0
                    
                    // =========================================================================
                    // MARK: - Layer 1: 16-Point Lissajous Particle Sine-Bob Trail (Iterator_1)
                    // =========================================================================
                    let particlePulse = 0.75 + 0.25 * sin(2.0 * .pi * t / 4.0)
                    
                    for i in 0..<16 {
                        let iDouble = Double(i)
                        
                        // Dual LFO phase offsets from logo.qtz Math_1 & Math_2:
                        let phase1 = (2.0 * .pi * t / 2.0) + (iDouble * 5.0 * .pi / 180.0)
                        let phase3 = (2.0 * .pi * t / 1.8) + (iDouble * 10.0 * .pi / 180.0)
                        let normX = 0.38 * sin(phase1) + 0.24 * sin(phase3)
                        
                        let phase2 = (2.0 * .pi * t / 1.6) + (iDouble * 5.0 * .pi / 180.0)
                        let phase4 = (2.0 * .pi * t / 1.4) + (iDouble * 10.0 * .pi / 180.0)
                        let normY = 0.07 * sin(phase2) + 0.05 * sin(phase4)
                        
                        let px = centerX + CGFloat(normX) * (targetW * 0.96)
                        let py = centerY + CGFloat(normY) * (targetH * 1.5)
                        
                        // Tail fade: Head is solid, trailing bobs gradually fade
                        let tailAlpha = (1.0 - (iDouble / 18.0)) * 0.75 * particlePulse
                        
                        // Visibly enlarged sprite bob radii (head is 5.5pt, trailing down to 3.2pt)
                        let dotRadius: CGFloat = (i == 0 ? 5.5 : (i < 4 ? 4.8 : (i < 8 ? 4.0 : 3.2)))
                        let dotRect = CGRect(x: px - dotRadius, y: py - dotRadius, width: dotRadius * 2, height: dotRadius * 2)
                        
                        // 1. Soft glowing outer halo
                        let haloRect = dotRect.insetBy(dx: -2.0, dy: -2.0)
                        context.fill(
                            Path(ellipseIn: haloRect),
                            with: .color(particleColor.opacity(tailAlpha * 0.35))
                        )
                        
                        // 2. Solid vibrant core
                        context.fill(
                            Path(ellipseIn: dotRect),
                            with: .color(particleColor.opacity(tailAlpha))
                        )
                        
                        // 3. Specular highlight center for head and lead bobs
                        if i < 4 {
                            let highlightRect = dotRect.insetBy(dx: 1.5, dy: 1.5)
                            context.fill(
                                Path(ellipseIn: highlightRect),
                                with: .color(Color.white.opacity(tailAlpha * 0.90))
                            )
                        }
                    }
                    
                    // =========================================================================
                    // MARK: - Layer 2: Wobbling Dot-Matrix Logo (techtech GLSL kernel)
                    // =========================================================================
                    let resolved = context.resolve(Image(nsImage: logo).renderingMode(.template))
                    
                    // Wave formulas reverse-engineered from logo.qtz:
                    let phase = (t.truncatingRemainder(dividingBy: 2.0) / 2.0) * 2.0 * .pi
                    let amp = (3.4 + 1.4 * sin(2.0 * .pi * t / 16.0)) // Smooth, authentic wave width proportional to 195pt
                    let scale = 0.08 + 0.03 * sin(2.0 * .pi * t / 32.0) // Gentle single-wave curve across height
                    
                    let slices = 26
                    let sliceH = targetH / CGFloat(slices)
                    let startY = centerY - targetH / 2.0
                    
                    for s in 0..<slices {
                        let y = startY + CGFloat(s) * sliceH
                        let yNorm = CGFloat(s) / CGFloat(slices) * 40.0
                        let offset = amp * sin(yNorm * scale + phase)
                        
                        var sliceContext = context
                        sliceContext.clip(to: Path(CGRect(x: 0, y: y, width: size.width, height: sliceH + 0.4)))
                        sliceContext.draw(
                            resolved,
                            in: CGRect(x: centerX - targetW / 2.0 + offset, y: startY, width: targetW, height: targetH)
                        )
                    }
                }
                .foregroundColor(logoColor)
                .frame(width: 250, height: 34)
            }
        } else {
            Text("SIDPLAY")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(logoColor)
        }
    }
}
