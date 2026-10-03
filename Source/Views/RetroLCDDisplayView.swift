//
//  RetroLCDDisplayView.swift
//  SIDPLAY
//
//  Faithful recreation of the iconic SIDPLAY retro LCD / HUD status display.
//

import SwiftUI

public struct RetroLCDDisplayView: View {
    @ObservedObject var player: SIDPlayer
    @Environment(\.colorScheme) private var colorScheme
    
    @MainActor
    public init(player: SIDPlayer = .shared) {
        self.player = player
    }
    
    private var timeColor: Color {
        guard player.isPlaying else {
            return Color.secondary.opacity(colorScheme == .dark ? 0.8 : 0.6)
        }
        return colorScheme == .dark ? Color(red: 0.35, green: 0.95, blue: 0.85) : Color.primary
    }
    
    private var timeShadowColor: Color {
        guard player.isPlaying && colorScheme == .dark else { return Color.clear }
        return Color(red: 0.35, green: 0.95, blue: 0.85).opacity(0.4)
    }
    
    @State private var showLogoDuringPlayback: Bool = false
    
    public var body: some View {
        Group {
            if let meta = player.metadata, !showLogoDuringPlayback {
                HStack(spacing: 12) {
                    // MARK: - Left: Title, Author, Year
                    VStack(alignment: .leading, spacing: 2) {
                        Text(meta.title)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(meta.title)
                        
                        Text(meta.author)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(meta.author)
                        
                        Text(meta.releaseInfo)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary.opacity(0.8))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                    .layoutPriority(0)
                    
                    Spacer(minLength: 4)
                    
                    // MARK: - Right: Telemetry (Subtune & Digital Clock)
                    HStack(spacing: 6) {
                        if meta.subtuneCount > 1 {
                            HStack(spacing: 2) {
                                Button(action: { _ = player.previousSubtune() }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(2)
                                }
                                .buttonStyle(.plain)
                                .help("Previous Subtune")
                                
                                Button(action: { _ = player.nextSubtune() }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(2)
                                }
                                .buttonStyle(.plain)
                                .help("Next Subtune")
                                
                                Text(String(format: "Song %02d of %02d", player.currentSubtune, meta.subtuneCount))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(.secondary)
                            }
                        } else {
                            Text("Song 01 of 01")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        
                        Text(player.currentTimeString)
                            .font(.system(size: 20, weight: .bold, design: .monospaced))
                            .monospacedDigit()
                            .foregroundColor(timeColor)
                            .shadow(color: timeShadowColor, radius: 4, x: 0, y: 0)
                            .frame(width: 68, alignment: .trailing)
                    }
                    .fixedSize()
                    .layoutPriority(2)
                }
            } else {
                // Classic SIDPLAY Demoscene Animated Logo (Idle State or Playback Toggle)
                SIDDemosceneLogoView()
            }
        }
        .frame(height: 34)
        .contentShape(Rectangle())
        .onTapGesture {
            if player.metadata != nil {
                withAnimation(.easeInOut(duration: 0.18)) {
                    showLogoDuringPlayback.toggle()
                }
            }
        }
        .help(player.metadata != nil ? (showLogoDuringPlayback ? "Click to show track info" : "Click to show demoscene logo") : "Classic SIDPLAY Demoscene Logo")
    }
}
