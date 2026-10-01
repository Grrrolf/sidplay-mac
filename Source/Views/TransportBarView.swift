//
//  TransportBarView.swift
//  SIDPLAY
//
//  Top control toolbar recreating the classic SIDPLAY look from Screenshot 2:
//  Stop, Pause, Subtune, Play, Tempo Slider, Retro LCD Display, Search, Volume.
//

import SwiftUI

public struct TransportBarView: View {
    @ObservedObject var player: SIDPlayer
    @ObservedObject var library: SIDLibraryManager
    @Binding var showSidebar: Bool
    @Binding var showInspector: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @State private var fastForwardSpeed: Double = 1.0
    @State private var showVolumePopover: Bool = false
    @FocusState private var isSearchFocused: Bool
    
    @MainActor
    public init(
        player: SIDPlayer = .shared,
        library: SIDLibraryManager = .shared,
        showSidebar: Binding<Bool> = .constant(true),
        showInspector: Binding<Bool> = .constant(true)
    ) {
        self.player = player
        self.library = library
        self._showSidebar = showSidebar
        self._showInspector = showInspector
    }
    
    private var isHighContrast: Bool {
        colorSchemeContrast == .increased || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
    
    private var capsuleStrokeColor: Color {
        if isHighContrast {
            return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.85)
        } else {
            return colorScheme == .dark ? Color.white.opacity(0.40) : Color.black.opacity(0.20)
        }
    }
    
    private var capsuleStrokeWidth: CGFloat {
        isHighContrast ? 1.25 : 1.0
    }
    
    private var searchStrokeColor: Color {
        if isSearchFocused {
            return Color.accentColor
        } else if isHighContrast {
            return colorScheme == .dark ? Color.white.opacity(0.85) : Color.black.opacity(0.75)
        } else {
            return library.searchScope == .hvsc ? Color.accentColor.opacity(0.40) : Color.primary.opacity(0.20)
        }
    }
    
    private var volumeIconName: String {
        if player.volume == 0 {
            return "speaker.slash.fill"
        } else if player.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if player.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    
    public var body: some View {
        HStack(spacing: 12) {
            // Invisible balanced spacer matching the search bar width (~135 pt)
            Color.clear
                .frame(width: 135, height: 1)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            
            Spacer(minLength: 0)
            
            // MARK: - Apple Music Unified Player Capsule
            HStack(spacing: 8) {
                // MARK: Left: Transport Controls Cluster
                HStack(spacing: 3) {
                    // Stop Button (Discreet Commodore SID Audio Reset)
                    Button(action: { player.stop() }) {
                        Image(systemName: "stop.fill")
                    }
                    .buttonStyle(AppleMusicGlyphButtonStyle(iconSize: 11, frameSize: 26))
                    .disabled(!player.isTuneLoaded)
                    .focusable(false)
                    .help("Stop Playback & Reset SID")
                    
                    // Shuffle Button (Matches Apple Music far left)
                    Button(action: { library.isShuffleEnabled.toggle() }) {
                        Image(systemName: "shuffle")
                    }
                    .buttonStyle(AppleMusicGlyphButtonStyle(
                        iconSize: 12,
                        frameSize: 26,
                        isActive: library.isShuffleEnabled
                    ))
                    .focusable(false)
                    .help(library.isShuffleEnabled ? "Shuffle: ON (Play in random order)" : "Shuffle: OFF (Sequential)")
                    
                    // Previous Subtune / Tune Button (backward.fill)
                    Button(action: {
                        if !player.previousSubtune() {
                            library.playPreviousInQueue()
                        }
                    }) {
                        Image(systemName: "backward.fill")
                    }
                    .buttonStyle(AppleMusicGlyphButtonStyle(iconSize: 13, frameSize: 28))
                    .disabled(!player.isTuneLoaded)
                    .focusable(false)
                    .help("Previous Subtune / Previous Tune")
                    
                    // Play / Pause Unified Button (Apple Music Centerpiece)
                    Button(action: {
                        _ = player.togglePlayPause()
                    }) {
                        Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(AppleMusicGlyphButtonStyle(
                        iconSize: 18,
                        frameSize: 34,
                        isActive: player.isPlaying
                    ))
                    .disabled(!player.isTuneLoaded)
                    .focusable(false)
                    .keyboardShortcut(.space, modifiers: [])
                    .help(player.isPlaying ? "Pause (Space)" : "Play / Resume (Space)")
                    
                    // Next Subtune / Tune Button (forward.fill)
                    Button(action: {
                        if !player.nextSubtune() {
                            library.playNextInQueue()
                        }
                    }) {
                        Image(systemName: "forward.fill")
                    }
                    .buttonStyle(AppleMusicGlyphButtonStyle(iconSize: 13, frameSize: 28))
                    .disabled(!player.isTuneLoaded)
                    .focusable(false)
                    .help("Next Subtune / Next Tune")
                    
                    // Repeat Button (Matches Apple Music transport right)
                    Button(action: { library.isRepeatEnabled.toggle() }) {
                        Image(systemName: "repeat")
                    }
                    .buttonStyle(AppleMusicGlyphButtonStyle(
                        iconSize: 12,
                        frameSize: 26,
                        isActive: library.isRepeatEnabled
                    ))
                    .focusable(false)
                    .help(library.isRepeatEnabled ? "Repeat: ON" : "Repeat: OFF")
                }
                
                // Fast Forward Slider (♫ ---●--- ♫♫)
                HStack(spacing: 2) {
                    Image(systemName: "music.note")
                        .font(.system(size: 8))
                        .foregroundColor(fastForwardSpeed <= 1.05 ? .secondary : .accentColor)
                        .help("Normal Speed (1.0x)")
                    
                    FixedSizeSlider(
                        value: Binding(
                            get: { fastForwardSpeed },
                            set: { newVal in
                                fastForwardSpeed = newVal
                                player.tempo = Int(round(newVal * 100))
                            }
                        ),
                        in: 1.0...5.0,
                        trackHeight: 3.5,
                        knobSize: 11,
                        activeColor: fastForwardSpeed > 1.05 ? .accentColor : .secondary.opacity(0.4),
                        onEditingChanged: { isEditing in
                            if !isEditing {
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                    fastForwardSpeed = 1.0
                                }
                                player.tempo = 100
                            }
                        }
                    )
                    .frame(width: 52)
                    .disabled(!player.isTuneLoaded)
                    .help(fastForwardSpeed > 1.05 ? String(format: "Fast Forward: %.1fx", fastForwardSpeed) : "Fast Forward Slider")
                    
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 8))
                        .foregroundColor(fastForwardSpeed > 1.05 ? .accentColor : .secondary)
                        .help("Fast Forward (up to 5.0x)")
                }
                
                Spacer(minLength: 6)
                
                // MARK: Center: Track Display or Centered Logo
                RetroLCDDisplayView(player: player)
                    .frame(maxWidth: .infinity)
                
                Spacer(minLength: 6)
                
                // MARK: Right: Speaker Icon with Volume Slider Popover
                HStack(spacing: 3) {
                    // Speaker Icon with Volume Slider Popover (Apple Music Volume)
                    Button(action: {
                        showVolumePopover.toggle()
                    }) {
                        Image(systemName: volumeIconName)
                    }
                    .buttonStyle(AppleMusicGlyphButtonStyle(
                        iconSize: 13,
                        frameSize: 28,
                        isActive: showVolumePopover || player.volume == 0
                    ))
                    .focusable(false)
                    .popover(isPresented: $showVolumePopover, arrowEdge: .bottom) {
                        HStack(spacing: 8) {
                            Button(action: {
                                if player.volume > 0 {
                                    player.volume = 0
                                } else {
                                    player.volume = 0.8
                                }
                            }) {
                                Image(systemName: player.volume == 0 ? "speaker.slash.fill" : "speaker.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(player.volume == 0 ? .accentColor : .secondary)
                            }
                            .buttonStyle(.plain)
                            .focusable(false)
                            .focusEffectDisabled()
                            .help(player.volume == 0 ? "Unmute" : "Mute")
                            
                            FixedSizeSlider(value: $player.volume, in: 0.0...1.0, trackHeight: 4, knobSize: 12)
                                .frame(width: 120)
                                .help("Volume: \(Int(player.volume * 100))%")
                            
                            Image(systemName: "speaker.wave.3.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                            
                            Text("\(Int(player.volume * 100))%")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .frame(width: 32, alignment: .trailing)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }
                    .help("Volume: \(Int(player.volume * 100))% (Click to adjust)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .frame(minWidth: 640, maxWidth: 880)
            .frame(height: 44)
            .background(
                Capsule()
                    .fill(Color(NSColor.controlBackgroundColor).opacity(colorScheme == .dark ? 0.35 : 0.50))
                    .overlay(
                        Capsule()
                            .stroke(capsuleStrokeColor, lineWidth: capsuleStrokeWidth)
                    )
                    .shadow(color: Color.black.opacity(isHighContrast ? 0 : 0.04), radius: 2, x: 0, y: 1)
                    .contentShape(Capsule())
                    .onTapGesture(count: 2) {
                        handleTitleBarDoubleClick()
                    }
            )
            
            Spacer(minLength: 0)
            
            // MARK: - Right: Search Bar outside Capsule
            HStack(spacing: 5) {
                Menu {
                    Button(action: { library.setSearchScope(.folder) }) {
                        Label("Current Folder (\(library.currentFolderName))", systemImage: "folder")
                    }
                    Button(action: { library.setSearchScope(.hvsc) }) {
                        Label("Entire HVSC Archive (61,000+ Tunes)", systemImage: "globe")
                    }
                } label: {
                    Image(systemName: library.searchScope == .hvsc ? "globe" : "magnifyingglass")
                        .font(.system(size: 11, weight: library.searchScope == .hvsc ? .semibold : .regular))
                        .foregroundColor(library.searchScope == .hvsc ? .accentColor : .secondary)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .focusable(false)
                .focusEffectDisabled()
                .frame(width: 14)
                .help("Search Scope: \(library.searchScope.rawValue) (click to switch)")
                
                TextField(
                    library.searchScope == .hvsc ? "Search HVSC..." : "Search Folder...",
                    text: $library.searchText
                )
                .focused($isSearchFocused)
                .textFieldStyle(.plain)
                .font(.system(size: 11))
                .frame(width: 95)
                .onExitCommand {
                    if !library.searchText.isEmpty {
                        library.clearSearch()
                    }
                    isSearchFocused = false
                }
                
                if library.isSearchingHVSC {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 10, height: 10)
                } else if !library.searchText.isEmpty {
                    Button(action: { library.clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color(NSColor.textBackgroundColor).opacity(0.8))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(searchStrokeColor, lineWidth: isSearchFocused ? 1.5 : (isHighContrast ? 1.25 : 1.0))
            )
            .frame(width: 165)
            .background(
                // Global ⌘F shortcut button
                Button(action: {
                    isSearchFocused = true
                }) {
                    EmptyView()
                }
                .keyboardShortcut("f", modifiers: .command)
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
            )
            .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SIDFocusSearchField"))) { _ in
                isSearchFocused = true
            }
            .onChange(of: isSearchFocused) { focused in
                if focused && !library.searchText.isEmpty {
                    DispatchQueue.main.async {
                        NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(
            Color(NSColor.windowBackgroundColor)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    handleTitleBarDoubleClick()
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            if fastForwardSpeed > 1.05 {
                withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                    fastForwardSpeed = 1.0
                }
                player.tempo = 100
            }
        }
    }
    
    private func handleTitleBarDoubleClick() {
        guard let win = NSApp.keyWindow ?? NSApp.mainWindow else { return }
        let action = UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick")
        if action == "Minimize" {
            win.performMiniaturize(nil)
        } else if action == "None" {
            // Off
        } else {
            win.performZoom(nil)
        }
    }
}


// MARK: - Apple Music Style Borderless Transport Button Style
public struct AppleMusicGlyphButtonStyle: ButtonStyle {
    var iconSize: CGFloat = 13
    var frameSize: CGFloat = 28
    var isActive: Bool = false
    
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false
    
    public init(iconSize: CGFloat = 13, frameSize: CGFloat = 28, isActive: Bool = false) {
        self.iconSize = iconSize
        self.frameSize = frameSize
        self.isActive = isActive
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundColor(
                !isEnabled
                    ? Color.secondary.opacity(0.35)
                    : (isActive ? .accentColor : .primary)
            )
            .frame(width: frameSize, height: frameSize)
            .background(
                Circle()
                    .fill(
                        isEnabled && configuration.isPressed
                            ? Color.primary.opacity(0.18)
                            : (isEnabled && isHovered ? Color.primary.opacity(0.10) : Color.clear)
                    )
            )
            .scaleEffect(isEnabled && configuration.isPressed ? 0.90 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .onHover { hovering in
                if isEnabled {
                    isHovered = hovering
                }
            }
            .contentShape(Circle())
            .focusEffectDisabled()
    }
}


// MARK: - Apple Music Fixed-Size Sleek Slider Component
public struct FixedSizeSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double>
    var trackHeight: CGFloat
    var knobSize: CGFloat
    var activeColor: Color
    var inactiveColor: Color?
    var onEditingChanged: ((Bool) -> Void)?
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.isEnabled) private var isEnabled
    @State private var isDragging: Bool = false
    @State private var isHovered: Bool = false
    
    public init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0.0...1.0,
        trackHeight: CGFloat = 4,
        knobSize: CGFloat = 12,
        activeColor: Color = .accentColor,
        inactiveColor: Color? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.range = range
        self.trackHeight = trackHeight
        self.knobSize = knobSize
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.onEditingChanged = onEditingChanged
    }
    
    public init(
        value: Binding<Float>,
        in range: ClosedRange<Float> = 0.0...1.0,
        trackHeight: CGFloat = 4,
        knobSize: CGFloat = 12,
        activeColor: Color = .accentColor,
        inactiveColor: Color? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = Binding<Double>(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Float($0) }
        )
        self.range = Double(range.lowerBound)...Double(range.upperBound)
        self.trackHeight = trackHeight
        self.knobSize = knobSize
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
        self.onEditingChanged = onEditingChanged
    }
    
    private var isHighContrast: Bool {
        colorSchemeContrast == .increased || NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
    }
    
    private var defaultInactiveColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)
    }

    public var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let knobRadius = knobSize / 2
            let travelDistance = max(totalWidth - knobSize, 1)
            let span = max(range.upperBound - range.lowerBound, 0.0001)
            let progress = max(0, min(1, (value - range.lowerBound) / span))
            let knobX = knobRadius + CGFloat(progress) * travelDistance
            let activeWidth = max(0, min(knobX, totalWidth))
            
            ZStack(alignment: .leading) {
                // Inactive Background Track
                Capsule()
                    .fill(inactiveColor ?? defaultInactiveColor)
                    .frame(height: trackHeight)
                    .overlay(
                        isHighContrast ? Capsule().stroke(Color.primary.opacity(0.35), lineWidth: 0.5) : nil
                    )
                
                // Active Foreground Fill
                Capsule()
                    .fill(isEnabled ? activeColor : Color.secondary.opacity(0.3))
                    .frame(width: activeWidth, height: trackHeight)
                
                // Circular Thumb Knob (STRICT FIXED DIMENSIONS - Never changes size on drag)
                Circle()
                    .fill(Color.white)
                    .frame(width: knobSize, height: knobSize)
                    .overlay(
                        Circle()
                            .stroke(
                                isHighContrast
                                    ? (colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.75))
                                    : Color.black.opacity(0.18),
                                lineWidth: isHighContrast ? 1.0 : 0.5
                            )
                    )
                    .shadow(
                        color: Color.black.opacity(isHighContrast ? 0.35 : (isHovered ? 0.22 : 0.15)),
                        radius: isHovered ? 2.5 : 1.5,
                        x: 0,
                        y: 1
                    )
                    .position(x: knobX, y: geometry.size.height / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        guard isEnabled else { return }
                        if !isDragging {
                            isDragging = true
                            onEditingChanged?(true)
                        }
                        let touchX = gesture.location.x
                        let relativeX = max(0, min(touchX - knobRadius, travelDistance))
                        let newProgress = Double(relativeX / travelDistance)
                        let newValue = range.lowerBound + newProgress * span
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { gesture in
                        guard isEnabled else { return }
                        let touchX = gesture.location.x
                        let relativeX = max(0, min(touchX - knobRadius, travelDistance))
                        let newProgress = Double(relativeX / travelDistance)
                        let newValue = range.lowerBound + newProgress * span
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                        isDragging = false
                        onEditingChanged?(false)
                    }
            )
            .onHover { hovering in
                if isEnabled {
                    isHovered = hovering
                }
            }
        }
        .frame(height: max(knobSize + 6, 18))
        .focusable(false)
        .focusEffectDisabled()
    }
}

