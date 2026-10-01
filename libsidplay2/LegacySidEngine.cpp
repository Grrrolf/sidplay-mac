/*
 *  LegacySidEngine.cpp
 *  SIDPLAY
 *
 *  Implementation of ISidEngine wrapping the classic 2008 libsidplay2 + reSID engine.
 *  Compiled into liblegacy_sidplay2.dylib with symbol isolation.
 */

#include "Source/AudioCore/ISidEngine.h"
#include "include/sidplay/sidplay2.h"
#include "include/sidplay/builders/resid.h"

#include <memory>
#include <cstring>
#include <string>
#include <algorithm>

// Mixer globals referenced by resid/filter.cc
double mixer_value1 = 1.0;
double mixer_value2 = 1.0;
double mixer_value3 = 1.0;

class LegacySidEngine : public ISidEngine {
public:
    LegacySidEngine() :
        m_sampleRate(48000),
        m_clockSpeed(0),
        m_sidModel(0),
        m_forceSidModel(false),
        m_subtuneCount(0),
        m_defaultSubtune(0),
        m_currentSubtune(0),
        m_title(""),
        m_author(""),
        m_releaseInfo(""),
        m_format(""),
        m_loadAddress(0),
        m_initAddress(0),
        m_playAddress(0),
        m_sidChipBase1(0xD400),
        m_sidChipBase2(0)
    {
        for (int c = 0; c < 4; c++) {
            for (int v = 0; v < 3; v++) {
                m_voiceVolume[c][v] = 1.0f;
                m_voiceMute[c][v] = false;
            }
        }
        m_builder = std::make_unique<ReSIDBuilder>("resid");
        if (m_builder->devices(true) == 0) {
            m_builder->create(2);
        }
        m_builder->filter(true);
        m_builder->sampling(m_sampleRate);
    }

    ~LegacySidEngine() override {
        m_engine.load(nullptr);
        m_tune.reset();
        m_builder.reset();
    }

    const char* getEngineName() const override {
        return "Legacy 2008 (libsidplay2 + reSID)";
    }

    SIDEngineType getEngineType() const override {
        return SID_ENGINE_LEGACY;
    }

    bool configure(int sampleRate, int clockSpeed, int sidModel, bool forceSidModel) override {
        m_sampleRate = (sampleRate > 0) ? sampleRate : 48000;
        m_clockSpeed = clockSpeed;
        m_sidModel = sidModel;
        m_forceSidModel = forceSidModel;

        if (m_builder) {
            m_builder->sampling(m_sampleRate);
        }

        sid2_config_t cfg = m_engine.config();
        cfg.frequency = m_sampleRate;
        cfg.playback = sid2_stereo;
        cfg.precision = 16;
        cfg.sidEmulation = m_builder.get();
        cfg.optimisation = SID2_DEFAULT_OPTIMISATION;

        if (m_clockSpeed == 1) {
            cfg.clockSpeed = SID2_CLOCK_PAL;
            cfg.clockDefault = SID2_CLOCK_PAL;
            cfg.clockForced = true;
        } else if (m_clockSpeed == 2) {
            cfg.clockSpeed = SID2_CLOCK_NTSC;
            cfg.clockDefault = SID2_CLOCK_NTSC;
            cfg.clockForced = true;
        } else {
            cfg.clockSpeed = SID2_CLOCK_CORRECT;
            cfg.clockDefault = SID2_CLOCK_PAL;
            cfg.clockForced = false;
        }

        if (m_sidModel == 1) {
            cfg.sidDefault = SID2_MOS6581;
            cfg.sidModel = SID2_MOS6581;
        } else if (m_sidModel == 2) {
            cfg.sidDefault = SID2_MOS8580;
            cfg.sidModel = SID2_MOS8580;
        } else {
            cfg.sidDefault = SID2_MOS6581;
            cfg.sidModel = m_forceSidModel ? cfg.sidDefault : SID2_MODEL_CORRECT;
        }

        return (m_engine.config(cfg) == 0);
    }

    void updateSampleRate(int sampleRate) override {
        configure(sampleRate, m_clockSpeed, m_sidModel, m_forceSidModel);
    }

    void setFilterCurve(double /*curve*/) override {
        // Legacy reSID uses static distortion/cutoff tables
    }

    void setFilterType(int /*filterType*/) override {
        // Handled via sidModel in legacy engine
    }

    bool loadTune(const uint8_t* data, size_t size, int subtune) override {
        m_engine.load(nullptr);
        m_tune.reset();

        if (!data || size == 0) return false;

        m_tune = std::make_unique<SidTune>(data, (uint_least32_t)size);
        SidTuneInfo info;
        m_tune->getInfo(info);
        if (!m_tune->getStatus()) {
            fprintf(stderr, "[LegacySidEngine] SidTune parse error (status=%d): %s\n",
                    (int)m_tune->getStatus(), info.statusString ? info.statusString : "Unknown");
            m_tune.reset();
            return false;
        }

        m_subtuneCount = info.songs;
        m_defaultSubtune = info.startSong;
        m_currentSubtune = (subtune >= 1 && subtune <= m_subtuneCount) ? subtune : m_defaultSubtune;

        m_title = info.infoString[0] ? info.infoString[0] : "";
        m_author = info.infoString[1] ? info.infoString[1] : "";
        m_releaseInfo = info.infoString[2] ? info.infoString[2] : "";
        m_format = info.formatString ? info.formatString : "SID";
        m_loadAddress = info.loadAddr;
        m_initAddress = info.initAddr;
        m_playAddress = info.playAddr;
        m_sidChipBase1 = info.sidChipBase1 ? info.sidChipBase1 : 0xD400;
        m_sidChipBase2 = info.sidChipBase2;

        configure(m_sampleRate, m_clockSpeed, m_sidModel, m_forceSidModel);

        m_tune->selectSong(m_currentSubtune);
        int loadRet = m_engine.load(m_tune.get());
        bool ok = (loadRet == 0);
        if (!ok) {
            fprintf(stderr, "[LegacySidEngine] m_engine.load error %d: %s\n", loadRet, m_engine.error());
        } else {
            updateLegacyMixer(0, 0);
            updateLegacyMixer(0, 1);
            updateLegacyMixer(0, 2);
        }
        return ok;
    }

    bool selectSubtune(int subtune) override {
        if (!m_tune || subtune < 1 || subtune > m_subtuneCount) return false;
        m_currentSubtune = subtune;
        m_tune->selectSong(m_currentSubtune);
        bool ok = (m_engine.load(m_tune.get()) == 0);
        if (ok) {
            updateLegacyMixer(0, 0);
            updateLegacyMixer(0, 1);
            updateLegacyMixer(0, 2);
        }
        return ok;
    }

    int getSubtuneCount() const override { return m_subtuneCount; }
    int getDefaultSubtune() const override { return m_defaultSubtune; }
    int getCurrentSubtune() const override { return m_currentSubtune; }
    int getPlaybackSeconds() const override { return (int)(m_engine.time() / 10); }

    const char* getTitle() const override { return m_title.c_str(); }
    const char* getAuthor() const override { return m_author.c_str(); }
    const char* getReleaseInfo() const override { return m_releaseInfo.c_str(); }
    const char* getFormat() const override { return m_format.c_str(); }
    uint16_t getLoadAddress() const override { return m_loadAddress; }
    uint16_t getInitAddress() const override { return m_initAddress; }
    uint16_t getPlayAddress() const override { return m_playAddress; }

    const char* getChipModel(unsigned int chip) const override {
        if (m_sidModel == 1) return "MOS 6581";
        if (m_sidModel == 2) return "MOS 8580";
        if (m_tune) {
            SidTuneInfo info;
            const_cast<SidTune*>(m_tune.get())->getInfo(info);
            if (info.sidModel == SID2_MOS8580) return "MOS 8580";
        }
        return "MOS 6581";
    }

    unsigned int getInstalledSIDs() const override {
        return (m_sidChipBase2 != 0) ? 2 : 1;
    }

    uint16_t getSidChipBase(unsigned int chip) const override {
        if (chip == 0) return m_sidChipBase1 ? m_sidChipBase1 : 0xD400;
        if (chip == 1) return m_sidChipBase2;
        return 0;
    }

    int renderAudio(short* buffer, int maxShorts) override {
        if (!m_tune || !buffer || maxShorts <= 0) return 0;
        uint_least32_t bytesToRender = maxShorts * sizeof(short);
        uint_least32_t bytesGenerated = m_engine.play(buffer, bytesToRender);
        return (int)(bytesGenerated / sizeof(short));
    }

    void updateLegacyMixer(unsigned int chip, unsigned int voice) {
        if (chip == 0 && voice < 3) {
            bool isMuted = m_voiceMute[0][voice] || (m_voiceVolume[0][voice] <= 0.001f);
            float effective = isMuted ? 0.0f : m_voiceVolume[0][voice];
            if (voice == 0) mixer_value1 = effective;
            else if (voice == 1) mixer_value2 = effective;
            else if (voice == 2) mixer_value3 = effective;
        }
    }

    void setVoiceVolume(unsigned int chip, unsigned int voice, float volume) override {
        if (chip < 4 && voice < 3) {
            m_voiceVolume[chip][voice] = volume;
            updateLegacyMixer(chip, voice);
        }
    }

    void setVoiceMute(unsigned int chip, unsigned int voice, bool mute) override {
        if (chip < 4 && voice < 3) {
            m_voiceMute[chip][voice] = mute;
            updateLegacyMixer(chip, voice);
        }
    }

    bool getSidStatus(unsigned int chip, uint8_t regs[32]) override {
        if (!regs) return false;
        if (chip == 0) {
            const auto& frame = m_engine.getCurrentRegisterFrame();
            memcpy(regs, frame.mRegisters, 32);
            return true;
        }
        memset(regs, 0, 32);
        return false;
    }

private:
    float m_voiceVolume[4][3];
    bool m_voiceMute[4][3];

    sidplay2 m_engine;
    std::unique_ptr<ReSIDBuilder> m_builder;
    std::unique_ptr<SidTune> m_tune;

    int m_sampleRate;
    int m_clockSpeed;
    int m_sidModel;
    bool m_forceSidModel;

    int m_subtuneCount;
    int m_defaultSubtune;
    int m_currentSubtune;

    std::string m_title;
    std::string m_author;
    std::string m_releaseInfo;
    std::string m_format;
    uint16_t m_loadAddress;
    uint16_t m_initAddress;
    uint16_t m_playAddress;
    uint16_t m_sidChipBase1;
    uint16_t m_sidChipBase2;
};

// MARK: - Exported Factory Functions
extern "C" __attribute__((visibility("default"))) ISidEngine* createLegacySidEngine() {
    return new LegacySidEngine();
}

extern "C" __attribute__((visibility("default"))) void destroyLegacySidEngine(ISidEngine* engine) {
    delete engine;
}
