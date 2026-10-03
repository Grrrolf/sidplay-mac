/*
 *  SpatialEngine.h
 *  SIDPLAY
 *
 *  High-performance C++ DSP engine providing continuous Mid/Side stereo width
 *  scaling and 180 Hz Linkwitz-Riley crossover mono bass anchoring for multi-SID tunes.
 */

#ifndef _SPATIAL_ENGINE_H
#define _SPATIAL_ENGINE_H

#include <cstdint>
#include <cmath>
#include <algorithm>

class SpatialEngine {
public:
    SpatialEngine();
    ~SpatialEngine() = default;

    /// Initialize DSP sample rate and compute filter coefficients
    void init(int sampleRate);

    /// Reset internal filter delay lines and smoothing state
    void reset();

    /// Stereo Width: 0.0 (Pure Mono) .. 1.0 (Native Stereo) .. 3.0 (+200% Expanded)
    void setStereoWidth(float width);
    float getStereoWidth() const { return mTargetWidth; }

    /// Mono Bass Anchor: Unconditionally sums frequencies below crossover to mono
    void setBassAnchorEnabled(bool enabled);
    bool isBassAnchorEnabled() const { return mBassAnchorEnabled; }

    /// Crossover frequency in Hz (default: 180.0 Hz)
    void setCrossoverFrequency(float freqHz);
    float getCrossoverFrequency() const { return mCrossoverFreq; }

    /// Process interleaved 16-bit stereo PCM samples in-place.
    /// buffer: array of interleaved shorts [L0, R0, L1, R1, ...]
    /// numFrames: number of stereo sample pairs (total shorts / 2)
    void process(short* buffer, int numFrames);

private:
    struct BiquadState {
        double d1 = 0.0;
        double d2 = 0.0;
        void reset() { d1 = 0.0; d2 = 0.0; }
    };

    struct BiquadCoeffs {
        double b0 = 1.0;
        double b1 = 0.0;
        double b2 = 0.0;
        double a1 = 0.0;
        double a2 = 0.0;
    };

    static inline double processBiquad(double in, const BiquadCoeffs& c, BiquadState& s) {
        double out = c.b0 * in + s.d1;
        s.d1 = c.b1 * in - c.a1 * out + s.d2;
        s.d2 = c.b2 * in - c.a2 * out;
        return out;
    }

    void updateFilterCoefficients();

    int mSampleRate;
    float mTargetWidth;
    float mCurrentWidth;
    float mSmoothingAlpha;
    bool mBassAnchorEnabled;
    float mCrossoverFreq;

    // 4th-Order Linkwitz-Riley (two cascaded 2nd-order Butterworth stages per band)
    BiquadCoeffs mLPCoeffs;
    BiquadCoeffs mHPCoeffs;

    // Filter states for Left channel (LP stage 1 & 2, HP stage 1 & 2)
    BiquadState mLPStateL1;
    BiquadState mLPStateL2;
    BiquadState mHPStateL1;
    BiquadState mHPStateL2;

    // Filter states for Right channel (LP stage 1 & 2, HP stage 1 & 2)
    BiquadState mLPStateR1;
    BiquadState mLPStateR2;
    BiquadState mHPStateR1;
    BiquadState mHPStateR2;
};

#endif // _SPATIAL_ENGINE_H
