/*
 *  PlayerLibSidplay.cpp
 *  SIDPLAY
 *
 *  Dual-core SID emulation backend supporting instant A/B switching between
 *  libsidplayfp (Cycle-Exact Modern Core) and libsidplay2 (Legacy 2008 Core).
 */

#include "PlayerLibSidplay.h"
#include <cstdio>
#include <cstring>
#include <algorithm>
#include <dlfcn.h>
#include <mach-o/dyld.h>
#include <unistd.h>

const char* PlayerLibSidplay::sChipModel6581 = "MOS 6581";
const char* PlayerLibSidplay::sChipModel8580 = "MOS 8580";
const char* PlayerLibSidplay::sChipModelUnknown = "Unknown";
const char* PlayerLibSidplay::sChipModelUnspecified = "Unspecified";

// ----------------------------------------------------------------------------
PlayerLibSidplay::PlayerLibSidplay() :
	mCurrentEngine(nullptr),
	mEngineType(SID_ENGINE_CYCLE_EXACT),
	mLegacyDylibHandle(nullptr),
	mCreateLegacyEngine(nullptr),
	mDestroyLegacyEngine(nullptr),
	m_databaseLoaded(false),
	mAudioDriver(nullptr),
	mTuneLength(0),
	mCurrentSubtune(0),
	mSubtuneCount(0),
	mDefaultSubtune(0),
	mCurrentTempo(100),
	mSpeedFactor(1.0f),
	mSamplePhase(0.0),
	mLoggingEnabled(false)
{
	// Initialize voice volume & mute state table
	for (int c = 0; c < 4; c++) {
		for (int v = 0; v < 3; v++) {
			mVoiceVolumes[c][v] = 1.0f;
			mVoiceMutes[c][v] = false;
		}
	}

	// 1. Initialize modern cycle-exact core
	mFpEngine = std::make_unique<EngineSidplayFP>();
	mCurrentEngine = mFpEngine.get();

	// 2. Discover and load legacy dylib
	loadLegacyDylib();

	// 3. Default playback settings
	mPlaybackSettings.mFrequency = 48000;
	mPlaybackSettings.mBits = 16;
	mPlaybackSettings.mStereo = 1;
	mPlaybackSettings.mOversampling = 1;
	mPlaybackSettings.mSidModel = 0; // Auto
	mPlaybackSettings.mForceSidModel = false;
	mPlaybackSettings.mClockSpeed = 0; // PAL
	mPlaybackSettings.mOptimization = 0;
	mPlaybackSettings.mFilterType = SID_FILTER_6581_Resid;
	mPlaybackSettings.mFilterCurve = 0.50;
	mPlaybackSettings.mFilterKinkiness = 0.17f;
	mPlaybackSettings.mFilterBaseLevel = 210.0f;
	mPlaybackSettings.mFilterOffset = -375.0f;
	mPlaybackSettings.mFilterSteepness = 120.0f;
	mPlaybackSettings.mFilterRolloff = 5.5f;
	mPlaybackSettings.mEnableFilterDistortion = 1;
	mPlaybackSettings.mDistortionRate = 1500;
	mPlaybackSettings.mDistortionHeadroom = 400;
	mFilterRange = 0.50;
	mOld6581Caps = false;

	initEmuEngine(&mPlaybackSettings);
}

// ----------------------------------------------------------------------------
PlayerLibSidplay::~PlayerLibSidplay()
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mCurrentEngine = nullptr;
	mFpEngine.reset();

	if (mLegacyEngine && mDestroyLegacyEngine) {
		mDestroyLegacyEngine(mLegacyEngine.release());
	}

	if (mLegacyDylibHandle) {
		dlclose(mLegacyDylibHandle);
		mLegacyDylibHandle = nullptr;
	}
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::loadLegacyDylib()
{
	std::vector<std::string> searchPaths;

	// 1. Check relative to executable within app bundle (Contents/Frameworks)
	char execPath[1024];
	uint32_t size = sizeof(execPath);
	if (_NSGetExecutablePath(execPath, &size) == 0) {
		std::string basePath(execPath);
		size_t lastSlash = basePath.rfind('/');
		if (lastSlash != std::string::npos) {
			std::string execDir = basePath.substr(0, lastSlash);
			searchPaths.push_back(execDir + "/../Frameworks/liblegacy_sidplay2.dylib");
		}
	}

	// 2. Runpath search path
	searchPaths.push_back("@rpath/liblegacy_sidplay2.dylib");

	// 3. Project workspace paths
	searchPaths.push_back("libs/liblegacy_sidplay2.dylib");

	for (const auto& path : searchPaths) {
		void* handle = dlopen(path.c_str(), RTLD_NOW | RTLD_LOCAL);
		if (handle) {
			mCreateLegacyEngine = (CreateLegacySidEngineFunc)dlsym(handle, "createLegacySidEngine");
			mDestroyLegacyEngine = (DestroyLegacySidEngineFunc)dlsym(handle, "destroyLegacySidEngine");

			if (mCreateLegacyEngine && mDestroyLegacyEngine) {
				mLegacyDylibHandle = handle;
				mLegacyEngine.reset(mCreateLegacyEngine());
				fprintf(stderr, "[PlayerLibSidplay] Loaded legacy engine from: %s\n", path.c_str());
				return;
			} else {
				dlclose(handle);
			}
		}
	}

	fprintf(stderr, "[PlayerLibSidplay] Legacy engine dylib not found; legacy core will be unavailable.\n");
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setEngineBackend(SIDEngineType type)
{
	if (type == SID_ENGINE_LEGACY && !mLegacyEngine) {
		fprintf(stderr, "[PlayerLibSidplay] Cannot switch to legacy engine: library not available.\n");
		return;
	}

	if (type == mEngineType && mCurrentEngine != nullptr) {
		return;
	}

	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);

	int resumeSubtune = mCurrentSubtune;
	mEngineType = type;
	mCurrentEngine = (type == SID_ENGINE_LEGACY) ? mLegacyEngine.get() : mFpEngine.get();

	// Configure new engine with current settings
	mCurrentEngine->configure(mPlaybackSettings.mFrequency,
	                          mPlaybackSettings.mClockSpeed,
	                          mPlaybackSettings.mSidModel,
	                          mPlaybackSettings.mForceSidModel);

	applyFilterSettings();

	// Reload tune at current subtune if a tune was active
	if (mTuneLength > 0) {
		mCurrentEngine->loadTune((const uint8_t*)mTuneBuffer, (size_t)mTuneLength, resumeSubtune);
	}

	// Restore voice volume and muting on the new engine
	for (unsigned int chip = 0; chip < 4; chip++) {
		for (unsigned int voice = 0; voice < 3; voice++) {
			mCurrentEngine->setVoiceVolume(chip, voice, mVoiceVolumes[chip][voice]);
			mCurrentEngine->setVoiceMute(chip, voice, mVoiceMutes[chip][voice]);
		}
	}

	// Clear leftover FIFO samples to ensure clean transition
	mAudioFifo.clear();
	mSamplePhase = 0.0;

	fprintf(stderr, "[PlayerLibSidplay] Active engine core switched to: %s\n", mCurrentEngine->getEngineName());
}

// ----------------------------------------------------------------------------
const char* PlayerLibSidplay::getEngineName() const
{
	return mCurrentEngine ? mCurrentEngine->getEngineName() : "None";
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setAudioDriver(AudioDriver* audioDriver)
{
	mAudioDriver = audioDriver;
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::initEmuEngine(PlaybackSettings *settings)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	if (settings) {
		mPlaybackSettings = *settings;
	}

	if (mCurrentEngine) {
		mCurrentEngine->configure(mPlaybackSettings.mFrequency,
		                          mPlaybackSettings.mClockSpeed,
		                          mPlaybackSettings.mSidModel,
		                          mPlaybackSettings.mForceSidModel);
	}

	mSpatialEngine.init(mPlaybackSettings.mFrequency);

	applyFilterSettings();

	if (mMixBuffer.size() < 16384) {
		mMixBuffer.resize(16384);
	}
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::applyFilterSettings()
{
	if (!mCurrentEngine) return;
	mCurrentEngine->setFilterCurve(mPlaybackSettings.mFilterCurve);
	mCurrentEngine->setFilterType((int)mPlaybackSettings.mFilterType);
	mCurrentEngine->setFilterSteepness(mPlaybackSettings.mFilterSteepness);
	mCurrentEngine->setFilterOffset(mPlaybackSettings.mFilterOffset);
	mCurrentEngine->setFilterRange(mFilterRange);
	mCurrentEngine->setFilterKinkiness(mPlaybackSettings.mFilterKinkiness);
	mCurrentEngine->setOld6581Caps(mOld6581Caps);
	mCurrentEngine->setDistortionEnabled(mPlaybackSettings.mEnableFilterDistortion != 0);
	mCurrentEngine->setDistortionRate(mPlaybackSettings.mDistortionRate);
	mCurrentEngine->setDistortionHeadroom(mPlaybackSettings.mDistortionHeadroom);
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::updateSampleRate(int newSampleRate)
{
	mPlaybackSettings.mFrequency = newSampleRate;
	mSpatialEngine.init(newSampleRate);
	if (mCurrentEngine) {
		mCurrentEngine->updateSampleRate(newSampleRate);
	}
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::loadTuneByPath(const char *filename, int subtune, PlaybackSettings *settings)
{
	if (!filename) return false;

	FILE *fp = fopen(filename, "rb");
	if (!fp) return false;
	mTuneLength = (int)fread(mTuneBuffer, 1, TUNE_BUFFER_SIZE, fp);
	fclose(fp);

	if (mTuneLength <= 0) return false;

	mCurrentSubtune = subtune;
	return initSIDTune(settings);
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::loadTuneFromBuffer(char *buffer, int length, int subtune, PlaybackSettings *settings)
{
	if (!buffer || length <= 0 || length > TUNE_BUFFER_SIZE) return false;

	memcpy(mTuneBuffer, buffer, length);
	mTuneLength = length;
	mCurrentSubtune = subtune;
	return initSIDTune(settings);
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::playTuneByPath(const char *filename, int subtune, PlaybackSettings *settings)
{
	if (mAudioDriver) mAudioDriver->stopPlayback();
	bool success = loadTuneByPath(filename, subtune, settings);
	if (success && mAudioDriver) mAudioDriver->startPlayback();
	return success;
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::playTuneFromBuffer(char *buffer, int length, int subtune, PlaybackSettings *settings)
{
	if (mAudioDriver) mAudioDriver->stopPlayback();
	bool success = loadTuneFromBuffer(buffer, length, subtune, settings);
	if (success && mAudioDriver) mAudioDriver->startPlayback();
	return success;
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::initSIDTune(PlaybackSettings *settings)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);

	initEmuEngine(settings);
	mAudioFifo.clear();

	if (!mCurrentEngine) return false;

	bool loaded = mCurrentEngine->loadTune((const uint8_t*)mTuneBuffer, (size_t)mTuneLength, mCurrentSubtune);
	if (!loaded) {
		fprintf(stderr, "[PlayerLibSidplay] Failed to load tune into active engine (%s)\n", mCurrentEngine->getEngineName());
		return false;
	}

	mSubtuneCount = mCurrentEngine->getSubtuneCount();
	mDefaultSubtune = mCurrentEngine->getDefaultSubtune();
	mCurrentSubtune = mCurrentEngine->getCurrentSubtune();

	// Also load into secondary engine in background so A/B switching is instant
	if (mEngineType == SID_ENGINE_CYCLE_EXACT && mLegacyEngine) {
		mLegacyEngine->loadTune((const uint8_t*)mTuneBuffer, (size_t)mTuneLength, mCurrentSubtune);
	} else if (mEngineType == SID_ENGINE_LEGACY && mFpEngine) {
		mFpEngine->loadTune((const uint8_t*)mTuneBuffer, (size_t)mTuneLength, mCurrentSubtune);
	}

	// Restore voice mute/volume states
	for (unsigned int chip = 0; chip < 4; chip++) {
		for (unsigned int voice = 0; voice < 3; voice++) {
			mCurrentEngine->setVoiceVolume(chip, voice, mVoiceVolumes[chip][voice]);
			mCurrentEngine->setVoiceMute(chip, voice, mVoiceMutes[chip][voice]);
		}
	}

	return true;
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::initCurrentSubtune()
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	if (!mCurrentEngine || mTuneLength <= 0) return false;

	mAudioFifo.clear();
	mSamplePhase = 0.0;
	bool ok = mCurrentEngine->selectSubtune(mCurrentSubtune);

	if (mEngineType == SID_ENGINE_CYCLE_EXACT && mLegacyEngine) {
		mLegacyEngine->selectSubtune(mCurrentSubtune);
	} else if (mEngineType == SID_ENGINE_LEGACY && mFpEngine) {
		mFpEngine->selectSubtune(mCurrentSubtune);
	}

	return ok;
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::startSubtune(int which)
{
	if (which < 1 || which > mSubtuneCount) return false;
	mCurrentSubtune = which;
	return initCurrentSubtune();
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::startNextSubtune()
{
	if (mCurrentSubtune < mSubtuneCount) {
		return startSubtune(mCurrentSubtune + 1);
	}
	return false;
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::startPrevSubtune()
{
	if (mCurrentSubtune > 1) {
		return startSubtune(mCurrentSubtune - 1);
	}
	return false;
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::fillBuffer(void* buffer, int len)
{
	if (!buffer || len <= 0) return;

	int requestedShorts = len / sizeof(short);
	short* outPtr = static_cast<short*>(buffer);

	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);

	if (!mCurrentEngine || mTuneLength <= 0) {
		memset(buffer, 0, len);
		return;
	}

	int numFrames = requestedShorts / 2;

	if (std::abs(mSpeedFactor - 1.0f) < 0.001f) {
		// 1.0x Normal Speed: direct bit-perfect playback
		while (mAudioFifo.size() < static_cast<size_t>(requestedShorts)) {
			int produced = mCurrentEngine->renderAudio(mMixBuffer.data(), (int)mMixBuffer.size());
			if (produced <= 0) {
				break;
			}
			mAudioFifo.insert(mAudioFifo.end(), mMixBuffer.begin(), mMixBuffer.begin() + produced);
		}

		size_t toCopy = std::min(static_cast<size_t>(requestedShorts), mAudioFifo.size());
		if (toCopy > 0) {
			memcpy(outPtr, mAudioFifo.data(), toCopy * sizeof(short));
			mAudioFifo.erase(mAudioFifo.begin(), mAudioFifo.begin() + toCopy);
		}

		if (toCopy < static_cast<size_t>(requestedShorts)) {
			memset(outPtr + toCopy, 0, (requestedShorts - toCopy) * sizeof(short));
		}
		mSamplePhase = 0.0;
	} else {
		// Variable Playback Speed (Tempo / Fast-Forward / Slow-Mo)
		size_t neededFifoShorts = static_cast<size_t>(std::ceil(numFrames * mSpeedFactor) * 2) + 8;
		while (mAudioFifo.size() < neededFifoShorts) {
			int produced = mCurrentEngine->renderAudio(mMixBuffer.data(), (int)mMixBuffer.size());
			if (produced <= 0) {
				break;
			}
			mAudioFifo.insert(mAudioFifo.end(), mMixBuffer.begin(), mMixBuffer.begin() + produced);
		}

		double phase = mSamplePhase;
		double step = static_cast<double>(mSpeedFactor);

		for (int f = 0; f < numFrames; ++f) {
			size_t baseIdx = static_cast<size_t>(phase) * 2;
			if (baseIdx + 3 < mAudioFifo.size()) {
				double frac = phase - static_cast<size_t>(phase);
				short l0 = mAudioFifo[baseIdx];
				short l1 = mAudioFifo[baseIdx + 2];
				short l = static_cast<short>(l0 + frac * (l1 - l0));

				short r0 = mAudioFifo[baseIdx + 1];
				short r1 = mAudioFifo[baseIdx + 3];
				short r = static_cast<short>(r0 + frac * (r1 - r0));

				outPtr[f * 2] = l;
				outPtr[f * 2 + 1] = r;
			} else if (baseIdx + 1 < mAudioFifo.size()) {
				outPtr[f * 2] = mAudioFifo[baseIdx];
				outPtr[f * 2 + 1] = mAudioFifo[baseIdx + 1];
			} else {
				outPtr[f * 2] = 0;
				outPtr[f * 2 + 1] = 0;
			}
			phase += step;
		}

		size_t framesConsumed = static_cast<size_t>(phase);
		size_t shortsToErase = std::min(framesConsumed * 2, mAudioFifo.size());
		mAudioFifo.erase(mAudioFifo.begin(), mAudioFifo.begin() + shortsToErase);
		mSamplePhase = phase - framesConsumed;
	}

	mSpatialEngine.process(outPtr, requestedShorts / 2);
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setStereoWidth(float width)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mSpatialEngine.setStereoWidth(width);
}

// ----------------------------------------------------------------------------
float PlayerLibSidplay::getStereoWidth() const
{
	return mSpatialEngine.getStereoWidth();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setBassAnchorEnabled(bool enabled)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mSpatialEngine.setBassAnchorEnabled(enabled);
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::getBassAnchorEnabled() const
{
	return mSpatialEngine.isBassAnchorEnabled();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setTempo(int tempo)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	if (tempo < 25) tempo = 25;
	if (tempo > 800) tempo = 800;
	mCurrentTempo = tempo;
	mSpeedFactor = static_cast<float>(tempo) / 100.0f;
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setVoiceVolume(int voice, float volume)
{
	setVoiceVolume(0, (unsigned int)voice, volume);
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setVoiceVolume(unsigned int chip, unsigned int voice, float volume)
{
	if (chip < 4 && voice < 3) {
		mVoiceVolumes[chip][voice] = volume;
		if (mCurrentEngine) {
			mCurrentEngine->setVoiceVolume(chip, voice, volume);
		}
	}
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setVoiceMute(unsigned int chip, unsigned int voice, bool mute)
{
	if (chip < 4 && voice < 3) {
		mVoiceMutes[chip][voice] = mute;
		std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
		if (mCurrentEngine) {
			mCurrentEngine->setVoiceMute(chip, voice, mute);
		}
	}
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterType(SPFilterType type)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mFilterType = type;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterCurve(double curve)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mFilterCurve = curve;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterSteepness(float steepness)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mFilterSteepness = steepness;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterOffset(float offset)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mFilterOffset = offset;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterRange(double range)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mFilterRange = range;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterKinkiness(float kinkiness)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mFilterKinkiness = kinkiness;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setOld6581Caps(bool enabled)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mOld6581Caps = enabled;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setDistortionEnabled(bool enabled)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mEnableFilterDistortion = enabled ? 1 : 0;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setDistortionRate(int rate)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mDistortionRate = rate;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setDistortionHeadroom(int headroom)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mDistortionHeadroom = headroom;
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setSidModel(int model, bool force)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mSidModel = model;
	mPlaybackSettings.mForceSidModel = force;
	initEmuEngine(&mPlaybackSettings);
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setClockSpeed(int clockSpeed)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	mPlaybackSettings.mClockSpeed = clockSpeed;
	initEmuEngine(&mPlaybackSettings);
}

// ----------------------------------------------------------------------------
int PlayerLibSidplay::getPlaybackSeconds() const
{
	return mCurrentEngine ? mCurrentEngine->getPlaybackSeconds() : 0;
}

// ----------------------------------------------------------------------------
const char* PlayerLibSidplay::getCurrentTitle() const
{
	return mCurrentEngine ? mCurrentEngine->getTitle() : "";
}

// ----------------------------------------------------------------------------
const char* PlayerLibSidplay::getCurrentAuthor() const
{
	return mCurrentEngine ? mCurrentEngine->getAuthor() : "";
}

// ----------------------------------------------------------------------------
const char* PlayerLibSidplay::getCurrentReleaseInfo() const
{
	return mCurrentEngine ? mCurrentEngine->getReleaseInfo() : "";
}

// ----------------------------------------------------------------------------
unsigned short PlayerLibSidplay::getCurrentLoadAddress() const
{
	return mCurrentEngine ? mCurrentEngine->getLoadAddress() : 0;
}

// ----------------------------------------------------------------------------
unsigned short PlayerLibSidplay::getCurrentInitAddress() const
{
	return mCurrentEngine ? mCurrentEngine->getInitAddress() : 0;
}

// ----------------------------------------------------------------------------
unsigned short PlayerLibSidplay::getCurrentPlayAddress() const
{
	return mCurrentEngine ? mCurrentEngine->getPlayAddress() : 0;
}

// ----------------------------------------------------------------------------
const char* PlayerLibSidplay::getCurrentFormat() const
{
	return mCurrentEngine ? mCurrentEngine->getFormat() : "";
}

// ----------------------------------------------------------------------------
int PlayerLibSidplay::getCurrentFileSize() const
{
	return mTuneLength;
}

// ----------------------------------------------------------------------------
char* PlayerLibSidplay::getTuneBuffer(int& outTuneLength)
{
	outTuneLength = mTuneLength;
	return mTuneBuffer;
}

// ----------------------------------------------------------------------------
const char* PlayerLibSidplay::getCurrentChipModel(unsigned int chip) const
{
	return mCurrentEngine ? mCurrentEngine->getChipModel(chip) : sChipModelUnspecified;
}

// ----------------------------------------------------------------------------
const char* PlayerLibSidplay::getCompositeChipModel() const
{
	if (!mCurrentEngine || mTuneLength == 0) return sChipModelUnspecified;
	unsigned int count = getInstalledSIDs();
	if (count <= 1) {
		return getCurrentChipModel(0);
	}

	bool has6581 = false;
	bool has8580 = false;
	for (unsigned int i = 0; i < count; i++) {
		const char* m = getCurrentChipModel(i);
		if (strcmp(m, sChipModel6581) == 0) has6581 = true;
		else if (strcmp(m, sChipModel8580) == 0) has8580 = true;
		else if (strstr(m, "6581") && strstr(m, "8580")) {
			has6581 = true;
			has8580 = true;
		}
	}

	if (has6581 && has8580) {
		return "MOS 6581 + MOS 8580";
	} else if (has8580) {
		return sChipModel8580;
	} else {
		return sChipModel6581;
	}
}

// ----------------------------------------------------------------------------
double PlayerLibSidplay::getCurrentCpuClockRate() const
{
	if (mPlaybackSettings.mClockSpeed == 2) return 1022727.14; // NTSC
	return 985248.4; // PAL
}

// ----------------------------------------------------------------------------
SIDPLAY2_NAMESPACE::SidRegisterFrame PlayerLibSidplay::getCurrentSidRegisters() const
{
	SIDPLAY2_NAMESPACE::SidRegisterFrame frame;
	getSidStatus(0, frame.mRegisters);
	frame.mTimeStamp = static_cast<uint32_t>(getPlaybackSeconds() * 1000);
	return frame;
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::getSidStatus(unsigned int sidNum, uint8_t regs[32]) const
{
	if (!mCurrentEngine || !regs) return false;
	return mCurrentEngine->getSidStatus(sidNum, regs);
}

// ----------------------------------------------------------------------------
unsigned int PlayerLibSidplay::getInstalledSIDs() const
{
	return mCurrentEngine ? mCurrentEngine->getInstalledSIDs() : 1;
}

// ----------------------------------------------------------------------------
uint16_t PlayerLibSidplay::getSidChipBase(unsigned int i) const
{
	return mCurrentEngine ? mCurrentEngine->getSidChipBase(i) : ((i == 0) ? 0xD400 : 0);
}

// ----------------------------------------------------------------------------
bool PlayerLibSidplay::loadSongLengthDatabase(const char* path)
{
	if (!path) return false;
	m_databaseLoaded = m_database.open(path);
	return m_databaseLoaded;
}

// ----------------------------------------------------------------------------
int PlayerLibSidplay::getSongLengthSeconds() const
{
	if (!m_databaseLoaded || !mFpEngine) return 0;
	const SidTune* tune = mFpEngine->getSidTune();
	if (!tune) return 0;

	SidTune* mutableTune = const_cast<SidTune*>(tune);
	int_least32_t ms = const_cast<SidDatabase&>(m_database).lengthMs(*mutableTune);
	if (ms > 0) {
		return static_cast<int>((ms + 500) / 1000);
	}
	int_least32_t len = const_cast<SidDatabase&>(m_database).length(*mutableTune);
	return (len > 0) ? static_cast<int>(len) : 0;
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterSettings(sid_filter_t* filterSettings)
{
	std::lock_guard<std::recursive_mutex> lock(mAudioMutex);
	if (filterSettings) {
		mFilterSettings = *filterSettings;
	}
	applyFilterSettings();
}

// ----------------------------------------------------------------------------
void PlayerLibSidplay::setFilterSettingsFromPlaybackSettings(sid_filter_t& filterSettings, PlaybackSettings* settings)
{
	if (!settings) return;
	filterSettings.distortion_enable = settings->mEnableFilterDistortion;
	filterSettings.rate = settings->mDistortionRate;
	filterSettings.headroom = settings->mDistortionHeadroom;
	filterSettings.points = 0x800;
}
