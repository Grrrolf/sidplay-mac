/*
 *  EngineSidplayFP.cpp
 *  SIDPLAY
 *
 *  Modern cycle-exact SID emulation backend based on libsidplayfp and libresidfp.
 */

#include "EngineSidplayFP.h"
#include <cstdio>
#include <cstring>
#include <algorithm>

EngineSidplayFP::EngineSidplayFP() :
    m_sampleRate(48000),
    m_clockSpeed(0),
    m_sidModel(0),
    m_forceSidModel(false),
    m_filterCurve(0.50),
    m_filterType(0),
    m_filterSteepness(120.0),
    m_filterOffset(-375.0),
    m_filterRange(0.50),
    m_filterKinkiness(0.17),
    m_old6581caps(false),
    m_distortionEnabled(true),
    m_distortionRate(1500),
    m_distortionHeadroom(400),
    m_subtuneCount(0),
    m_defaultSubtune(0),
    m_currentSubtune(0)
{
    for (int c = 0; c < 4; c++) {
        for (int v = 0; v < 3; v++) {
            m_voiceVolume[c][v] = 1.0f;
            m_voiceMute[c][v] = false;
        }
    }
    m_builder = std::make_unique<ReSIDfpBuilder>("reSIDfp");
    configure(48000, 0, 0, false);
}

EngineSidplayFP::~EngineSidplayFP()
{
    m_engine.load(nullptr);
    m_tune.reset();
}

bool EngineSidplayFP::configure(int sampleRate, int clockSpeed, int sidModel, bool forceSidModel)
{
    m_sampleRate = (sampleRate > 0) ? sampleRate : 48000;
    m_clockSpeed = clockSpeed;
    m_sidModel = sidModel;
    m_forceSidModel = forceSidModel;

    SidConfig cfg;
    cfg.frequency = m_sampleRate;
    cfg.samplingMethod = SidConfig::INTERPOLATE;

    // Clock speed: 0 = Auto, 1 = PAL, 2 = NTSC
    if (m_clockSpeed == 1) {
        cfg.defaultC64Model = SidConfig::PAL;
        cfg.forceC64Model = true;
    } else if (m_clockSpeed == 2) {
        cfg.defaultC64Model = SidConfig::NTSC;
        cfg.forceC64Model = true;
    } else {
        cfg.defaultC64Model = SidConfig::PAL;
        cfg.forceC64Model = false;
    }

    // SID chip model: 0 = Auto, 1 = MOS6581, 2 = MOS8580
    if (m_sidModel == 1) {
        cfg.defaultSidModel = SidConfig::MOS6581;
        cfg.forceSidModel = true;
    } else if (m_sidModel == 2) {
        cfg.defaultSidModel = SidConfig::MOS8580;
        cfg.forceSidModel = true;
    } else {
        cfg.defaultSidModel = SidConfig::MOS6581;
        cfg.forceSidModel = m_forceSidModel;
    }

    cfg.digiBoost = true;
    cfg.sidEmulation = m_builder.get();

    bool ok = m_engine.config(cfg);
    if (!ok) {
        fprintf(stderr, "[EngineSidplayFP] Config error: %s\n", m_engine.error());
    }

    applyFilterSettings();

    int maxBufSize = m_engine.getBufSize(8000);
    if (maxBufSize < 16384) maxBufSize = 16384;
    mMixBuffer.resize(maxBufSize);

    return ok;
}

void EngineSidplayFP::applyFilterSettings()
{
    if (!m_builder) return;

    double baseCurve = m_filterCurve;
    if (baseCurve < 0.05 || baseCurve > 0.95) baseCurve = 0.50;

    double steepness = m_filterSteepness;
    double offset = m_filterOffset;
    double range = m_filterRange;
    bool oldCaps = m_old6581caps;

    if (m_filterType != 5) { // If not Custom, presets define the nominal base values
        switch (m_filterType) {
            case 1: // 6581R3
                baseCurve = std::clamp(baseCurve * 0.90, 0.05, 0.95);
                break;
            case 2: // Galway
                baseCurve = std::clamp(baseCurve * 1.30, 0.05, 0.95);
                break;
            case 3: // 6581R4
                baseCurve = std::clamp(baseCurve * 1.10, 0.05, 0.95);
                oldCaps = true;
                break;
            case 4: // 8580
                oldCaps = false;
                break;
            default: // 6581 Standard
                break;
        }
    }

    // Offset shifts center frequency (negative offset shifts toward lower/darker frequencies)
    double effectiveCurve = std::clamp(baseCurve + (offset / 3000.0), 0.05, 0.95);
    // Steepness scales the dynamic range / slope of the filter
    double effectiveRange = std::clamp(range * (steepness / 120.0), 0.05, 0.95);

    if (m_filterType == 4) { // 8580
        m_builder->filter8580Curve(effectiveCurve);
        m_builder->enableOld6581caps(false);
    } else {
        m_builder->filter6581Curve(effectiveCurve);
        m_builder->filter6581Range(effectiveRange);
        m_builder->filter8580Curve(effectiveCurve);
        m_builder->enableOld6581caps(oldCaps);
    }

    m_builder->combinedWaveformsStrength(SidConfig::AVERAGE);
    m_builder->dacLeakage(1.0);
    m_builder->offset6581(1.0);
    m_builder->dcbRes(0.0);
}

void EngineSidplayFP::updateSampleRate(int sampleRate)
{
    configure(sampleRate, m_clockSpeed, m_sidModel, m_forceSidModel);
}

void EngineSidplayFP::setFilterCurve(double curve)
{
    m_filterCurve = curve;
    applyFilterSettings();
}

void EngineSidplayFP::setFilterType(int filterType)
{
    m_filterType = filterType;
    applyFilterSettings();
}

void EngineSidplayFP::setFilterSteepness(double steepness)
{
    m_filterSteepness = steepness;
    applyFilterSettings();
}

void EngineSidplayFP::setFilterOffset(double offset)
{
    m_filterOffset = offset;
    applyFilterSettings();
}

void EngineSidplayFP::setFilterRange(double range)
{
    m_filterRange = range;
    applyFilterSettings();
}

void EngineSidplayFP::setFilterKinkiness(double kinkiness)
{
    m_filterKinkiness = kinkiness;
    applyFilterSettings();
}

void EngineSidplayFP::setOld6581Caps(bool enabled)
{
    m_old6581caps = enabled;
    applyFilterSettings();
}

void EngineSidplayFP::setDistortionEnabled(bool enabled)
{
    m_distortionEnabled = enabled;
    applyFilterSettings();
}

void EngineSidplayFP::setDistortionRate(int rate)
{
    m_distortionRate = rate;
    applyFilterSettings();
}

void EngineSidplayFP::setDistortionHeadroom(int headroom)
{
    m_distortionHeadroom = headroom;
    applyFilterSettings();
}

bool EngineSidplayFP::loadTune(const uint8_t* data, size_t size, int subtune)
{
    m_engine.load(nullptr);
    m_tune.reset();

    if (!data || size == 0) return false;

    m_tune = std::make_unique<SidTune>(data, (uint_least32_t)size);
    if (!m_tune->getStatus()) {
        fprintf(stderr, "[EngineSidplayFP] SidTune parse error: %s\n", m_tune->statusString());
        m_tune.reset();
        return false;
    }

    const SidTuneInfo *info = m_tune->getInfo();
    m_subtuneCount = (int)info->songs();
    m_defaultSubtune = (int)info->startSong();
    m_currentSubtune = (subtune >= 1 && subtune <= m_subtuneCount) ? subtune : m_defaultSubtune;

    configure(m_sampleRate, m_clockSpeed, m_sidModel, m_forceSidModel);

    m_tune->selectSong((unsigned int)m_currentSubtune);
    if (!m_engine.load(m_tune.get())) {
        fprintf(stderr, "[EngineSidplayFP] load error: %s\n", m_engine.error());
        m_tune.reset();
        return false;
    }

    m_engine.initMixer(true);

    for (unsigned int c = 0; c < 4; c++) {
        for (unsigned int v = 0; v < 3; v++) {
            updateEngineMixer(c, v);
        }
    }
    return true;
}

bool EngineSidplayFP::selectSubtune(int subtune)
{
    if (!m_tune || subtune < 1 || subtune > m_subtuneCount) return false;
    m_currentSubtune = subtune;
    m_tune->selectSong((unsigned int)m_currentSubtune);
    m_engine.load(m_tune.get());
    m_engine.initMixer(true);

    for (unsigned int c = 0; c < 4; c++) {
        for (unsigned int v = 0; v < 3; v++) {
            updateEngineMixer(c, v);
        }
    }
    return true;
}

int EngineSidplayFP::getSubtuneCount() const { return m_subtuneCount; }
int EngineSidplayFP::getDefaultSubtune() const { return m_defaultSubtune; }
int EngineSidplayFP::getCurrentSubtune() const { return m_currentSubtune; }
int EngineSidplayFP::getPlaybackSeconds() const { return static_cast<int>(m_engine.time()); }

const char* EngineSidplayFP::getTitle() const {
    return (m_tune && m_tune->getInfo()) ? m_tune->getInfo()->infoString(0) : "";
}

const char* EngineSidplayFP::getAuthor() const {
    return (m_tune && m_tune->getInfo()) ? m_tune->getInfo()->infoString(1) : "";
}

const char* EngineSidplayFP::getReleaseInfo() const {
    return (m_tune && m_tune->getInfo()) ? m_tune->getInfo()->infoString(2) : "";
}

const char* EngineSidplayFP::getFormat() const {
    return (m_tune && m_tune->getInfo()) ? m_tune->getInfo()->formatString() : "";
}

uint16_t EngineSidplayFP::getLoadAddress() const {
    return (m_tune && m_tune->getInfo()) ? m_tune->getInfo()->loadAddr() : 0;
}

uint16_t EngineSidplayFP::getInitAddress() const {
    return (m_tune && m_tune->getInfo()) ? m_tune->getInfo()->initAddr() : 0;
}

uint16_t EngineSidplayFP::getPlayAddress() const {
    return (m_tune && m_tune->getInfo()) ? m_tune->getInfo()->playAddr() : 0;
}

const char* EngineSidplayFP::getChipModel(unsigned int chip) const {
    if (!m_tune || !m_tune->getInfo()) return "Unspecified";
    SidTuneInfo::model_t model = m_tune->getInfo()->sidModel(chip);
    if (model == SidTuneInfo::SIDMODEL_6581) return "MOS 6581";
    if (model == SidTuneInfo::SIDMODEL_8580) return "MOS 8580";
    if (model == SidTuneInfo::SIDMODEL_ANY) return "MOS 6581 / 8580";

    if (chip < m_engine.info().numberOfSIDs()) {
        SidTuneInfo::model_t activeModel = m_engine.info().sidModel(chip);
        if (activeModel == SidTuneInfo::SIDMODEL_8580) return "MOS 8580";
        if (activeModel == SidTuneInfo::SIDMODEL_6581) return "MOS 6581";
    }
    return "MOS 6581";
}

unsigned int EngineSidplayFP::getInstalledSIDs() const {
    if (m_tune && m_tune->getInfo()) {
        int chips = m_tune->getInfo()->sidChips();
        if (chips > 0) return (unsigned int)chips;
    }
    unsigned int installed = m_engine.installedSIDs();
    return installed > 0 ? installed : 1;
}

uint16_t EngineSidplayFP::getSidChipBase(unsigned int chip) const {
    if (!m_tune || !m_tune->getInfo()) {
        return (chip == 0) ? 0xD400 : 0;
    }
    uint16_t addr = m_tune->getInfo()->sidChipBase(chip);
    if (addr == 0 && chip == 0) addr = 0xD400;
    return addr;
}

int EngineSidplayFP::renderAudio(short* buffer, int maxShorts) {
    if (!m_tune || !buffer || maxShorts <= 0) return 0;

    constexpr unsigned int STEP_CYCLES = 4000;
    int samples = m_engine.play(STEP_CYCLES);
    if (samples <= 0) return 0;

    if (mMixBuffer.size() < static_cast<size_t>(samples * 2)) {
        mMixBuffer.resize(samples * 2);
    }

    unsigned int mixedShorts = m_engine.mix(mMixBuffer.data(), static_cast<unsigned int>(samples));
    int toCopy = std::min(static_cast<int>(mixedShorts), maxShorts);
    memcpy(buffer, mMixBuffer.data(), toCopy * sizeof(short));
    return toCopy;
}

extern "C" void residfp_set_voice_volume(unsigned int chip, unsigned int voice, float volume);

void EngineSidplayFP::setVoiceVolume(unsigned int chip, unsigned int voice, float volume) {
    if (chip < 4 && voice < 3) {
        m_voiceVolume[chip][voice] = volume;
        updateEngineMixer(chip, voice);
    }
}

void EngineSidplayFP::setVoiceMute(unsigned int chip, unsigned int voice, bool mute) {
    if (chip < 4 && voice < 3) {
        m_voiceMute[chip][voice] = mute;
        updateEngineMixer(chip, voice);
    }
}

void EngineSidplayFP::updateEngineMixer(unsigned int chip, unsigned int voice) {
    bool isMuted = m_voiceMute[chip][voice] || (m_voiceVolume[chip][voice] <= 0.001f);
    float effectiveVol = isMuted ? 0.0f : m_voiceVolume[chip][voice];
    residfp_set_voice_volume(chip, voice, effectiveVol);
}

bool EngineSidplayFP::getSidStatus(unsigned int chip, uint8_t regs[32]) {
    return m_engine.getSidStatus(chip, regs);
}
