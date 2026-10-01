# SIDPLAY for macOS — Key Features & Implementation Highlights

This document provides a comprehensive overview of the modern features, architectural advancements, and technical enhancements implemented in SIDPLAY for macOS.

---

## 1. Modern macOS User Interface (SwiftUI & macOS HIG)

### Apple Music Style Unified Capsule Player
* **Single Capsule Transport Bar:** Unified transport bar design inspired by Apple Music, housing playback controls, live song info, volume popover, and fast-forward controls in an elegant centered capsule.
* **Borderless Transport Glyphs:** Modern borderless SF Symbols for `[Stop]`, `[Previous]`, `[Play/Pause]`, and `[Next]` with proportional optical sizing and active state feedback.
* **Interactive Volume Popover:** Compact speaker button revealing a floating vertical volume slider with real-time level feedback.
* **Fast-Forward Spring Slider:** Center-sprung shuttle slider supporting smooth variable-speed forward playback (up to 8x) that snaps back to 1x upon release.
* **macOS Title Bar Window Maximize:** Native macOS window behavior allowing users to double-click anywhere across the top title bar to zoom/maximize the window without entering full-screen mode.

### 3-Pane Adaptive Split-View Layout
* **HSplitView Geometry:** Fluid three-column layout featuring a collapsible Source Sidebar, central Tune Library Table with breadcrumb path navigation, and a collapsible Inspector Panel.
* **macOS HIG Window Controls:** Dedicated `sidebar.leading` and `sidebar.trailing` toggle buttons integrated into the navigation bar for instant hiding/revealing of side panels.
* **FixedSizeSlider Components:** Custom AppKit-backed SwiftUI slider wrappers that maintain strictly uniform knob geometry, eliminating macOS thumb ballooning and layout clipping during drags.
* **Accessibility & High Contrast Compliance:** High-contrast adaptive borders, backgrounds, and text rendering reacting automatically to macOS "Increase Contrast" accessibility preferences in both Light and Dark appearances.

### Modern Native Preferences Suite
* **Native Tabbed Window:** Fully rewritten native SwiftUI preferences window (`PreferencesView.swift`) replacing legacy nib dialogs with unified tabs: Audio, Emulation, UI, and Database.
* **Zero Layout Jitter:** Fixed-width control columns and alignment grids preventing layout jumps when toggling options or switching tabs.

---

## 2. Emulation Engine & Audio Architecture

### Dual-Engine Emulation Switcher (`libsidplayfp` vs. `libsidplay2`)
* **Dynamic Core Switching:** Seamless real-time switching between modern cycle-accurate `libsidplayfp 3.1.1` (with `reSIDfp 1.2.2`) and classic `libsidplay2` (with `reSID 0.16`).
* **Clean Abstract Interface:** `ISidEngine` abstraction isolating engine-specific implementations from the core playback lifecycle and user interface.
* **Objective-C++ Bridge:** Type-safe, low-overhead bridge layer (`SIDEngineBridge.mm`) connecting Swift UI state to C++ audio core threads.

### Multi-SID Hardware Support (Up to 4 Chips)
* **Per-Chip Model Identification:** Independent identification and chip model selection (6581 vs. 8580) for up to 4 SIDs mapped across Commodore 64 address space:
  * Primary SID: `$D400`
  * Secondary 2SID: `$D420`
  * Tertiary 3SID: `$D500`
  * Quaternary 4SID: `$DE00`
* **Multi-Chip Voice Mixer:** Granular channel mixer displaying up to 12 distinct voices (3 voices × 4 chips) with individual mute toggles, solo buttons, and continuous volume attenuation sliders.
* **Analog DC Bias Preservation:** Specialized audio mixing DSP maintaining analog DC filter bias during voice muting and attenuation, eliminating pops, clicks, and discontinuities during playback.

---

## 3. Filter Curve Modeling & Real-Time Visualizer

### Interactive Dynamic Filter Response Graph
* **Mathematical Transfer Model:** Real-time transfer curve visualizer (`SIDFilterCurveGraphView`) rendering the non-linear analog transconductance response across the 0–12 kHz spectrum.
* **Dynamic Curve Morphing:** Graph paths dynamically stretch, tilt, shift, and reshape in direct response to user slider manipulation.
* **Live Register Telemetry Overlay:** Real-time audio playback tracking displaying:
  * Instantaneous cutoff frequency line (dashed cyan marker).
  * Animated glowing indicator dot directly traversing the morphed curve.
  * Active filter routing badge (Low-Pass `LP`, Band-Pass `BP`, High-Pass `HP`).
  * Instantaneous resonance value (0–15).
  * Calculated cutoff frequency readout (e.g. `3.8 kHz`).

### Comprehensive Filter & Distortion Parameter Suite
* **Filter Steepness:** Configurable gain slope ($\Delta f / \Delta \text{FC}$) spanning 50 to 390 (nominal 120 for 6581, 132 for 8580).
* **Filter Offset:** Baseline cutoff floor adjustment from -800 Hz to +300 Hz.
* **Center Curve:** Mid-band non-linear inflection control ranging from 5% to 95%.
* **Range / Span:** Dynamic filter sweep bandwidth control mapping directly to `ReSIDfpBuilder::filter6581Range`.
* **Vintage 2200 pF Capacitors:** Breadbin hardware toggle emulating early ASSY 326298 motherboards with darker, bass-heavy filter resonance.
* **Collapsible Analog Distortion Controls:**
  * Distortion enable toggle activating non-linear op-amp saturation modeling.
  * Distortion Rate slider (100 to 3200) controlling integrator slew rate.
  * Distortion Headroom slider (192 to 512) adjusting op-amp rail clipping limits.
* **Intelligent Preset Management:** Factory presets for 6581 and 8580 chips, automatic detection and switching to "Custom Tuned" when parameters are modified, and a one-click "Reset to Defaults" button.

---

## 4. Library Management, HVSC & Metadata

### High-Performance HVSC Library & Search
* **Asynchronous Archive Indexer:** Background cataloging engine capable of indexing 50,000+ files from the High Voltage SID Collection (HVSC) without blocking the UI thread.
* **Multi-Criteria Search Scopes:** Instant filtering across the entire library with selectable scopes: `All`, `Title`, `Author`, and `Released`.
* **Auto-Scroll & Playlist Synchronization:** Selected tunes synchronize automatically across the playlist table, with automatic smooth scrolling to the currently playing item.

### Native Smart Playlists & Rule-Based Collections
* **Multi-Criteria Rule Engine:** Dynamic playlist generator evaluating tunes against multiple metadata fields (`Title`, `Author`, `Released`, `File Path`).
* **Rich Comparison Operators:** Granular matching support including `contains`, `does not contain`, `starts with`, `ends with`, and `is` (exact match).
* **Flexible Logic & Limits:** Switchable rule conjunctions (`Match ALL rules [AND]` vs. `Match ANY rule [OR]`) with optional tune count capping (e.g. limit to 50 tunes).
* **Ultra-Fast Library Evaluation:** High-speed query engine executing across 61,000+ HVSC archive tunes in under 2 ms with live real-time match count calculations.
* **Native macOS Menu & Shortcut Integration:** Full macOS menu bar wiring (`File -> New Playlist` `⌘N`, `File -> New Smart Playlist...` `⌥⌘N`, `File -> Edit Smart Playlist`) with dynamic menu item validation.
* **Rich Sidebar & Breadcrumb Controls:** Dedicated gear-badged smart playlists in the sidebar with live tune counters, context menu operations (Edit Rules, Duplicate, Delete), breadcrumb bar quick-action button (`[ 🎚️ Edit Rules ]`), and empty-state guidance.

### Deep SID Tune Information List (STIL & BUG)
* **STIL Metadata Inspector:** Dedicated inspector pane displaying rich historical annotations, composer notes, cover tune credits, and trivia parsed from official HVSC `STIL.txt` and `BUG.txt` databases.
* **Song Length Database Integration:** Instant song length lookups via `Songlengths.md5` and `Songlengths.txt` providing exact duration tracking and retro LCD HUD countdown.

---

## 5. High-Performance Visualizer & Telemetry Architecture

### Hardware-Driven CRT Oscilloscope
* **CADisplayLink Direct V-Sync Synchronization:** Native macOS `CADisplayLink` driving oscilloscope rendering directly at display refresh rate (60 Hz / 120 Hz ProMotion), eliminating AppKit timer coalescing and macOS power-saving throttling.
* **Zero SwiftUI View Invalidation:** Decoupled `NSViewRepresentable` drawing directly via CoreGraphics with zero invalidation overhead on parent SwiftUI container views, tables, or navigation components.
* **Dual-Pass Glowing Cyan Phosphor:** Authentic analog CRT visualization featuring a wide outer cyan glow pass (`RGB(0.2, 0.85, 0.95)` at 35% opacity) and a razor-sharp high-intensity core (`RGB(0.25, 0.95, 1.0)`).
* **Automatic Occlusion & Power Management:** Display link automatically pauses when the inspector or oscilloscope section is collapsed, dropping rendering CPU footprint to 0.0%.

### Isolated Telemetry & Caching Pipeline
* **Dedicated Register Telemetry Pipeline:** Real-time 30 Hz SID hardware register updates ($D400–$D418) isolated inside `SIDRegisterTelemetry`, preventing high-frequency `objectWillChange` invalidation cascades to the 55,000-item table and player controls.
* **Smart Playlist & Library Memoization:** O(1) cached evaluation of library collections and smart playlists with smart invalidation tracking, eliminating redundant 55,000-item scans during UI refresh cycles.
* **Throttled Time Synchronization:** Integer second playback progress deduplication ensuring timeline sliders and retro LCD counters update smoothly without redundant main-thread dispatch.


