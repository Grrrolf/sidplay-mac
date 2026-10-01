/*
 *  EngineSidplayFP.h
 *  SIDPLAY
 *
 *  Implementation of ISidEngine wrapping the modern cycle-exact
 *  libsidplayfp 3.1.1 + reSIDfp 1.2.2 emulation core.
 */

#ifndef _ENGINESIDPLAYFP_H
#define _ENGINESIDPLAYFP_H

#include "ISidEngine.h"
#include <sidplayfp/sidplayfp.h>
#include <sidplayfp/SidTune.h>
#include <sidplayfp/SidTuneInfo.h>
#include <sidplayfp/SidConfig.h>
#include <sidplayfp/SidInfo.h>
#include <sidplayfp/builders/residfp.h>
#include <memory>
#include <vector>
#include <string>

class EngineSidplayFP : public ISidEngine {
public:
    EngineSidplayFP();
    ~EngineSidplayFP() override;

    const char* getEngineName() const override { return "Cycle-Exact (libsidplayfp 3.1.1 + reSIDfp 1.2.2)"; }
    SIDEngineType getEngineType() const override { return SID_ENGINE_CYCLE_EXACT; }

    bool configure(int sampleRate, int clockSpeed, int sidModel, bool forceSidModel) override;
    void updateSampleRate(int sampleRate) override;
    void setFilterCurve(double curve) override;
    void setFilterType(int filterType) override;
    void setFilterSteepness(double steepness) override;
    void setFilterOffset(double offset) override;
    void setFilterRange(double range) override;
    void setFilterKinkiness(double kinkiness) override;
    void setOld6581Caps(bool enabled) override;
    void setDistortionEnabled(bool enabled) override;
    void setDistortionRate(int rate) override;
    void setDistortionHeadroom(int headroom) override;

    bool loadTune(const uint8_t* data, size_t size, int subtune) override;
    bool selectSubtune(int subtune) override;

    int getSubtuneCount() const override;
    int getDefaultSubtune() const override;
    int getCurrentSubtune() const override;
    int getPlaybackSeconds() const override;

    const char* getTitle() const override;
    const char* getAuthor() const override;
    const char* getReleaseInfo() const override;
    const char* getFormat() const override;
    uint16_t getLoadAddress() const override;
    uint16_t getInitAddress() const override;
    uint16_t getPlayAddress() const override;
    const char* getChipModel(unsigned int chip) const override;
    unsigned int getInstalledSIDs() const override;
    uint16_t getSidChipBase(unsigned int chip) const override;

    int renderAudio(short* buffer, int maxShorts) override;

    void setVoiceVolume(unsigned int chip, unsigned int voice, float volume) override;
    void setVoiceMute(unsigned int chip, unsigned int voice, bool mute) override;

    bool getSidStatus(unsigned int chip, uint8_t regs[32]) override;

    // Access to underlying SidTune for song length database queries
    const SidTune* getSidTune() const { return m_tune.get(); }

private:
    void applyFilterSettings();

    sidplayfp m_engine;
    std::unique_ptr<ReSIDfpBuilder> m_builder;
    std::unique_ptr<SidTune> m_tune;

    int m_sampleRate;
    int m_clockSpeed;
    int m_sidModel;
    bool m_forceSidModel;
    double m_filterCurve;
    int m_filterType;
    double m_filterSteepness;
    double m_filterOffset;
    double m_filterRange;
    double m_filterKinkiness;
    bool m_old6581caps;
    bool m_distortionEnabled;
    int m_distortionRate;
    int m_distortionHeadroom;

    int m_subtuneCount;
    int m_defaultSubtune;
    int m_currentSubtune;

    std::vector<short> mMixBuffer;

    void updateEngineMixer(unsigned int chip, unsigned int voice);
    float m_voiceVolume[4][3];
    bool m_voiceMute[4][3];
};

#endif // _ENGINESIDPLAYFP_H
