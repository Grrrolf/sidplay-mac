# SIDPLAY for macOS

**Version 4.4 — Modern Commodore 64 Music Player & SID Synthesizer**

SIDPLAY is the premier Commodore 64 audio player and SID chip emulator for macOS, engineered to play classic game, demo, and scene tunes from the golden era of 8-bit computing with authentic cycle-exact accuracy.

---

## Highlights in Version 4.4

* **Apple Silicon & 64-Bit Architecture:** Fully native on Apple Silicon (M1/M2/M3/M4/M5) and Intel Macs with low-latency CoreAudio output.
* **Modernized SwiftUI Interface:** Unified Apple Music-style transport capsule, retro dot-matrix LCD display, and collapsible 3-pane layout (Collections Sidebar, Song Table, and Info Inspector).
* **Restored Demoscene Logo Effect:** Faithful real-time recreation of the classic SIDPLAY demoscene logo from `logo.qtz`: smooth 60 FPS horizontal sine-wave raster wobbler and a 16-point glowing Lissajous sine-bob particle trail.
* **Dual Emulation Engines:**
  * **libsidplayfp 3.1.1 + reSIDfp 1.2.2:** Cycle-exact emulation with precise MOS 6581/8580 filter curve modeling and distortion simulation.
  * **libsidplay2 + reSID:** Classic, lightweight legacy engine.
* **Multi-SID Support:** Automatic detection and playback for 2SID, 3SID, and 4SID tunes ($D420, $D440, $D500, $DE00, etc.) with up to 12-voice mixing and stereo separation.
* **Live Register Telemetry & CRT Oscilloscope:** 60 FPS hardware-driven CRT visualizer, real-time voice frequencies, pulse-width modulation, ADSR envelopes, filter cutoff/resonance telemetry, and per-voice mute/solo controls.
* **HVSC & STIL Integration:** Deep integration with High Voltage SID Collection (HVSC) song lengths, STIL artist comments, and full archive search.
* **Audio & PRG Export:** Export songs or subtunes to MP3, AAC, Apple Lossless, AIFF, or C64 executable PRG (powered by PSID64).
* **Spotlight Search:** Built-in Spotlight metadata importer (`SIDMusic.mdimporter`) indexing tune titles, composers, and copyright information across macOS Finder.

For a comprehensive technical breakdown of all architectural enhancements, see [FEATURES.md](FEATURES.md).

---

## Building from Source

### Prerequisites
* macOS 14.0 (Sonoma) or later
* Xcode 15 or later (with Command Line Tools installed)

### Build with Xcode GUI
1. Open `SIDPLAY.xcodeproj` in Xcode.
2. Select the **SIDPLAY** scheme.
3. Press `Cmd + B` to build, or `Cmd + R` to run.

### Build via Command Line
```bash
# Build Release application to ./build/Release/SIDPLAY.app
xcodebuild -project SIDPLAY.xcodeproj -scheme SIDPLAY -configuration Release build SYMROOT="$(pwd)/build" CODE_SIGNING_ALLOWED=NO
```

### Running Automated Tests
SIDPLAY includes a comprehensive regression and unit test suite verifying tune parsing, multi-SID detection, STIL normalization, queue algorithms, and UI geometry:
```bash
./scripts/run_tests.sh
```

---

## Credits & Acknowledgments

* **Original Author:** Andreas Varga (Application v1.0–v4.3 © Andreas Varga)
* **Modernization 2026:** Rolf Greven (Version 4.4 modernization) with AI engineering assistance from Google DeepMind / Google Gemini
* **Emulation Cores:**
  * Dag Lem (*reSID* MOS 6581/8580 sound chip emulator)
  * Michael Schwendt (*libsidplay2* C64 environment and CPU emulation)
  * Leandro Nini (*libsidplayfp* 3.1.1 and *reSIDfp* 1.2.2 cycle-exact engine)
* **High Voltage SID Collection (HVSC):**
  * The HVSC Crew, administrators, and contributors for maintaining the definitive archive of Commodore 64 music.
* **PSID64:** Roland Hermans (C64 PRG executable wrapper)
* **LAME Project:** The LAME development team (MP3 encoding)

---

## License

SIDPLAY is free software distributed under the terms of the **GNU General Public License (GPL) version 2** or later. See the `LICENSE` file for details.
