/*
 *  SpatialEngine.cpp
 *  SIDPLAY
 *
 *  High-performance C++ DSP engine providing continuous Mid/Side stereo width
 *  scaling and 180 Hz Linkwitz-Riley crossover mono bass anchoring for multi-SID tunes.
 */

#include "SpatialEngine.h"

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

SpatialEngine::SpatialEngine() :
    mSampleRate(48000),
    mTargetWidth(1.0f),
    mCurrentWidth(1.0f),
    mSmoothingAlpha(0.001f),
    mBassAnchorEnabled(true),
    mCrossoverFreq(180.0f)
{
    init(48000);
}

void SpatialEngine::init(int sampleRate)
{
    mSampleRate = (sampleRate > 0) ? sampleRate : 48000;
    
    // Smoothing time constant tau = 20ms (0.02s) to prevent zipper noise
    constexpr float tau = 0.02f;
    mSmoothingAlpha = 1.0f - std::exp(-1.0f / (tau * static_cast<float>(mSampleRate)));

    updateFilterCoefficients();
    reset();
}

void SpatialEngine::reset()
{
    mLPStateL1.reset();
    mLPStateL2.reset();
    mHPStateL1.reset();
    mHPStateL2.reset();

    mLPStateR1.reset();
    mLPStateR2.reset();
    mHPStateR1.reset();
    mHPStateR2.reset();

    mCurrentWidth = mTargetWidth;
}

void SpatialEngine::setStereoWidth(float width)
{
    // Clamp width: 0.0 (Pure Mono) .. 1.0 (Native Stereo) .. 3.0 (+200% Expanded)
    mTargetWidth = std::clamp(width, 0.0f, 3.0f);
}

void SpatialEngine::setBassAnchorEnabled(bool enabled)
{
    if (mBassAnchorEnabled != enabled) {
        mBassAnchorEnabled = enabled;
        reset();
    }
}

void SpatialEngine::setCrossoverFrequency(float freqHz)
{
    float clampedFreq = std::clamp(freqHz, 40.0f, 600.0f);
    if (std::abs(mCrossoverFreq - clampedFreq) > 0.1f) {
        mCrossoverFreq = clampedFreq;
        updateFilterCoefficients();
    }
}

void SpatialEngine::updateFilterCoefficients()
{
    // Bilinear transform pre-warping
    double omegaA = std::tan(M_PI * static_cast<double>(mCrossoverFreq) / static_cast<double>(mSampleRate));
    constexpr double q = 0.70710678118654752440; // 1 / sqrt(2) for 2nd-order Butterworth
    double omegaA2 = omegaA * omegaA;

    // 2nd-order Butterworth Low-Pass section
    double normLP = 1.0 / (1.0 + (omegaA / q) + omegaA2);
    mLPCoeffs.b0 = omegaA2 * normLP;
    mLPCoeffs.b1 = 2.0 * mLPCoeffs.b0;
    mLPCoeffs.b2 = mLPCoeffs.b0;
    mLPCoeffs.a1 = 2.0 * (omegaA2 - 1.0) * normLP;
    mLPCoeffs.a2 = (1.0 - (omegaA / q) + omegaA2) * normLP;

    // 2nd-order Butterworth High-Pass section
    double normHP = 1.0 / (1.0 + (omegaA / q) + omegaA2);
    mHPCoeffs.b0 = 1.0 * normHP;
    mHPCoeffs.b1 = -2.0 * mHPCoeffs.b0;
    mHPCoeffs.b2 = mHPCoeffs.b0;
    mHPCoeffs.a1 = 2.0 * (omegaA2 - 1.0) * normHP;
    mHPCoeffs.a2 = (1.0 - (omegaA / q) + omegaA2) * normHP;
}

void SpatialEngine::process(short* buffer, int numFrames)
{
    if (!buffer || numFrames <= 0) return;

    // Fast bypass path: if at native unity width and bass anchor is off, no DSP required
    if (!mBassAnchorEnabled &&
        std::abs(mCurrentWidth - 1.0f) < 0.0005f &&
        std::abs(mTargetWidth - 1.0f) < 0.0005f)
    {
        return;
    }

    constexpr double SCALE_IN = 1.0 / 32768.0;
    constexpr double SCALE_OUT = 32767.0;

    for (int i = 0; i < numFrames; ++i) {
        // Smooth width parameter
        mCurrentWidth += mSmoothingAlpha * (mTargetWidth - mCurrentWidth);

        double inL = buffer[i * 2] * SCALE_IN;
        double inR = buffer[i * 2 + 1] * SCALE_IN;

        double outL = inL;
        double outR = inR;

        if (mBassAnchorEnabled) {
            // Cascaded 2nd-order Butterworth filters yielding 4th-order Linkwitz-Riley (24 dB/oct)
            double lowL = processBiquad(processBiquad(inL, mLPCoeffs, mLPStateL1), mLPCoeffs, mLPStateL2);
            double lowR = processBiquad(processBiquad(inR, mLPCoeffs, mLPStateR1), mLPCoeffs, mLPStateR2);

            double highL = processBiquad(processBiquad(inL, mHPCoeffs, mHPStateL1), mHPCoeffs, mHPStateL2);
            double highR = processBiquad(processBiquad(inR, mHPCoeffs, mHPStateR1), mHPCoeffs, mHPStateR2);

            // Sub-crossover bass: unconditionally centered in both ears
            double lowMono = (lowL + lowR) * 0.5;

            // High band: Mid/Side width expansion/collapse
            double midHigh = (highL + highR) * 0.5;
            double sideHigh = (highL - highR) * 0.5;
            double wideHighL = midHigh + (mCurrentWidth * sideHigh);
            double wideHighR = midHigh - (mCurrentWidth * sideHigh);

            outL = lowMono + wideHighL;
            outR = lowMono + wideHighR;
        } else {
            // Full-spectrum Mid/Side processing
            double mid = (inL + inR) * 0.5;
            double side = (inL - inR) * 0.5;
            outL = mid + (mCurrentWidth * side);
            outR = mid - (mCurrentWidth * side);
        }

        // Saturation / clipping protection
        outL = std::clamp(outL, -1.0, 1.0);
        outR = std::clamp(outR, -1.0, 1.0);

        buffer[i * 2] = static_cast<short>(std::round(outL * SCALE_OUT));
        buffer[i * 2 + 1] = static_cast<short>(std::round(outR * SCALE_OUT));
    }
}
