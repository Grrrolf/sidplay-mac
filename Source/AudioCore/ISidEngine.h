/*
 *  ISidEngine.h
 *  SIDPLAY
 *
 *  Abstract C++ interface defining the contract for SID emulation engines
 *  (libsidplayfp cycle-exact core and legacy libsidplay2 core).
 */

#ifndef _ISIDENGINE_H
#define _ISIDENGINE_H

#include <cstdint>
#include <cstddef>

enum SIDEngineType {
    SID_ENGINE_CYCLE_EXACT = 0, // libsidplayfp 3.1.1 + reSIDfp 1.2.2 (Cycle-Exact Modern)
    SID_ENGINE_LEGACY = 1        // libsidplay2 + reSID (Legacy 2008)
};

class ISidEngine {
public:
    virtual ~ISidEngine() = default;

    virtual const char* getEngineName() const = 0;
    virtual SIDEngineType getEngineType() const = 0;

    // Configuration
    virtual bool configure(int sampleRate, int clockSpeed, int sidModel, bool forceSidModel) = 0;
    virtual void updateSampleRate(int sampleRate) = 0;
    virtual void setFilterCurve(double curve) = 0;
    virtual void setFilterType(int filterType) = 0;
    virtual void setFilterSteepness(double /*steepness*/) {}
    virtual void setFilterOffset(double /*offset*/) {}
    virtual void setFilterRange(double /*range*/) {}
    virtual void setFilterKinkiness(double /*kinkiness*/) {}
    virtual void setOld6581Caps(bool /*enabled*/) {}
    virtual void setDistortionEnabled(bool /*enabled*/) {}
    virtual void setDistortionRate(int /*rate*/) {}
    virtual void setDistortionHeadroom(int /*headroom*/) {}

    // Tune Loading & Selection
    virtual bool loadTune(const uint8_t* data, size_t size, int subtune) = 0;
    virtual bool selectSubtune(int subtune) = 0;

    // Metadata Accessors
    virtual int getSubtuneCount() const = 0;
    virtual int getDefaultSubtune() const = 0;
    virtual int getCurrentSubtune() const = 0;
    virtual int getPlaybackSeconds() const = 0;

    virtual const char* getTitle() const = 0;
    virtual const char* getAuthor() const = 0;
    virtual const char* getReleaseInfo() const = 0;
    virtual const char* getFormat() const = 0;
    virtual uint16_t getLoadAddress() const = 0;
    virtual uint16_t getInitAddress() const = 0;
    virtual uint16_t getPlayAddress() const = 0;
    virtual const char* getChipModel(unsigned int chip) const = 0;
    virtual unsigned int getInstalledSIDs() const = 0;
    virtual uint16_t getSidChipBase(unsigned int chip) const = 0;

    // Audio Output: writes interleaved 16-bit stereo PCM shorts.
    // Returns the number of shorts produced (up to maxShorts).
    virtual int renderAudio(short* buffer, int maxShorts) = 0;

    // Voice Volume & Muting
    virtual void setVoiceVolume(unsigned int chip, unsigned int voice, float volume) = 0;
    virtual void setVoiceMute(unsigned int chip, unsigned int voice, bool mute) = 0;

    // Hardware Register Inspection
    virtual bool getSidStatus(unsigned int chip, uint8_t regs[32]) = 0;
};

// C-exported factory function signatures for dynamically loaded legacy engine
typedef ISidEngine* (*CreateLegacySidEngineFunc)();
typedef void (*DestroyLegacySidEngineFunc)(ISidEngine*);

#endif // _ISIDENGINE_H
