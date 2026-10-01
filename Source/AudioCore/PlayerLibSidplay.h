#ifndef _PlayerLibSidplay_H
#define _PlayerLibSidplay_H

#include <cstdint>
#include <vector>
#include <memory>
#include <string>
#include <mutex>

#include "ISidEngine.h"
#include "EngineSidplayFP.h"
#include <sidplayfp/SidDatabase.h>

#include "AudioDriver.h"

enum SPFilterType
{
	SID_FILTER_6581_Resid = 0,
	SID_FILTER_6581R3,
	SID_FILTER_6581_Galway,
	SID_FILTER_6581R4,
	SID_FILTER_8580,
	SID_FILTER_CUSTOM
};

struct PlaybackSettings
{
	int				mFrequency;
	int				mBits;
	int				mStereo;

	int				mOversampling;
	int				mSidModel;
	bool			mForceSidModel;
	int				mClockSpeed;
	int				mOptimization;
	
	float			mFilterKinkiness;
	float			mFilterBaseLevel;
	float			mFilterOffset;
	float			mFilterSteepness;
	float			mFilterRolloff;
	SPFilterType	mFilterType;
	double			mFilterCurve;
	
	int				mEnableFilterDistortion;
	int				mDistortionRate;
	int				mDistortionHeadroom;	
};

typedef int sid_fc_t[2];
struct sid_filter_t
{
	sid_fc_t       cutoff[0x800];
	uint16_t       points;
	int            distortion_enable, rate, headroom, opmin, opmax;
};

// Legacy compatibility for SidRegisterFrame
namespace SIDPLAY2_NAMESPACE
{
    const int SID_REGISTER_COUNT = 32;
    struct SidRegisterFrame
    {
        uint8_t mRegisters[SID_REGISTER_COUNT];
        uint32_t mTimeStamp;
        SidRegisterFrame() : mTimeStamp(0) { for (int i = 0; i < SID_REGISTER_COUNT; i++) mRegisters[i] = 0; }
    };
}

typedef std::vector<SIDPLAY2_NAMESPACE::SidRegisterFrame> SidRegisterLog;

const int TUNE_BUFFER_SIZE = 65536 + 2 + 0x7c;

class PlayerLibSidplay
{
public:
	PlayerLibSidplay();
	virtual ~PlayerLibSidplay();

	void setAudioDriver(AudioDriver* audioDriver);

	// Engine Core Selection & Status
	void setEngineBackend(SIDEngineType type);
	SIDEngineType getEngineBackend() const { return mEngineType; }
	bool isLegacyEngineAvailable() const { return mLegacyEngine != nullptr; }
	const char* getEngineName() const;

	void initEmuEngine(PlaybackSettings *settings);
	void updateSampleRate(int newSampleRate);
	
	bool playTuneByPath(const char *filename, int subtune, PlaybackSettings *settings);
	bool playTuneFromBuffer(char *buffer, int length, int subtune, PlaybackSettings *settings);

	bool loadTuneByPath(const char *filename, int subtune, PlaybackSettings *settings);
	bool loadTuneFromBuffer(char *buffer, int length, int subtune, PlaybackSettings *settings);

	bool startPrevSubtune();
	bool startNextSubtune();
	bool startSubtune(int which);
	bool initCurrentSubtune();

	void fillBuffer(void* buffer, int len);

	inline int getTempo() const { return mCurrentTempo; }
	void setTempo(int tempo);

	void setVoiceVolume(int voice, float volume);
	void setVoiceVolume(unsigned int chip, unsigned int voice, float volume);
	void setVoiceMute(unsigned int chip, unsigned int voice, bool mute);
	
	void setFilterType(SPFilterType type);
	inline SPFilterType getFilterType() const { return mPlaybackSettings.mFilterType; }

	void setFilterCurve(double curve);
	inline double getFilterCurve() const { return mPlaybackSettings.mFilterCurve; }

	void setFilterSteepness(float steepness);
	inline float getFilterSteepness() const { return mPlaybackSettings.mFilterSteepness; }

	void setFilterOffset(float offset);
	inline float getFilterOffset() const { return mPlaybackSettings.mFilterOffset; }

	void setFilterRange(double range);
	inline double getFilterRange() const { return mFilterRange; }

	void setFilterKinkiness(float kinkiness);
	inline float getFilterKinkiness() const { return mPlaybackSettings.mFilterKinkiness; }

	void setOld6581Caps(bool enabled);
	inline bool getOld6581Caps() const { return mOld6581Caps; }

	void setDistortionEnabled(bool enabled);
	inline bool getDistortionEnabled() const { return mPlaybackSettings.mEnableFilterDistortion != 0; }

	void setDistortionRate(int rate);
	inline int getDistortionRate() const { return mPlaybackSettings.mDistortionRate; }

	void setDistortionHeadroom(int headroom);
	inline int getDistortionHeadroom() const { return mPlaybackSettings.mDistortionHeadroom; }

	void setSidModel(int model, bool force);
	inline int getSidModel() const { return mPlaybackSettings.mSidModel; }
	inline bool getForceSidModel() const { return mPlaybackSettings.mForceSidModel; }

	void setClockSpeed(int clockSpeed);
	inline int getClockSpeed() const { return mPlaybackSettings.mClockSpeed; }
	
	sid_filter_t* getFilterSettings() { return &mFilterSettings; }
	void setFilterSettings(sid_filter_t* filterSettings);
	static void setFilterSettingsFromPlaybackSettings(sid_filter_t& filterSettings, PlaybackSettings* settings);

	inline bool isTuneLoaded() const { return mTuneLength > 0 && mCurrentEngine != nullptr; }
	
	int getPlaybackSeconds() const;
	inline int getCurrentSubtune() const { return mCurrentSubtune; }
	inline int getSubtuneCount() const { return mSubtuneCount; }
	inline int getDefaultSubtune() const { return mDefaultSubtune; }
	inline int hasTuneInformationStrings() const { return 1; }
	
	const char* getCurrentTitle() const;
	const char* getCurrentAuthor() const;
	const char* getCurrentReleaseInfo() const;
	unsigned short getCurrentLoadAddress() const;
	unsigned short getCurrentInitAddress() const;
	unsigned short getCurrentPlayAddress() const;
	const char* getCurrentFormat() const;
	int getCurrentFileSize() const;
	char* getTuneBuffer(int& outTuneLength);

	const char* getCurrentChipModel(unsigned int chip = 0) const;
	const char* getCompositeChipModel() const;
	double getCurrentCpuClockRate() const;
	
	SIDPLAY2_NAMESPACE::SidRegisterFrame getCurrentSidRegisters() const;
	bool getSidStatus(unsigned int sidNum, uint8_t regs[32]) const;
	
	unsigned int getInstalledSIDs() const;
	uint16_t getSidChipBase(unsigned int i) const;
	int getSongLengthSeconds() const;
	bool loadSongLengthDatabase(const char* path);

	inline void enableRegisterLogging(bool inEnable) { mLoggingEnabled = inEnable; if (inEnable) mRegisterLog.clear(); }
	inline const SidRegisterLog& getRegisterLog() const { return mRegisterLog; }
	
	static const char* sChipModel6581;
	static const char* sChipModel8580;
	static const char* sChipModelUnknown;
	static const char* sChipModelUnspecified;

private:
	void loadLegacyDylib();
	bool initSIDTune(PlaybackSettings *settings);
	void applyFilterSettings();

	std::unique_ptr<EngineSidplayFP> mFpEngine;
	std::unique_ptr<ISidEngine> mLegacyEngine;
	ISidEngine* mCurrentEngine;
	SIDEngineType mEngineType;

	void* mLegacyDylibHandle;
	CreateLegacySidEngineFunc mCreateLegacyEngine;
	DestroyLegacySidEngineFunc mDestroyLegacyEngine;

	SidDatabase m_database;
	bool m_databaseLoaded;

	PlaybackSettings mPlaybackSettings;
	sid_filter_t mFilterSettings;
	double mFilterRange;
	bool mOld6581Caps;
	AudioDriver* mAudioDriver;

	char mTuneBuffer[TUNE_BUFFER_SIZE];
	int mTuneLength;

	int mCurrentSubtune;
	int mSubtuneCount;
	int mDefaultSubtune;
	int mCurrentTempo;
	float mSpeedFactor;
	double mSamplePhase;

	float mVoiceVolumes[4][3];
	bool mVoiceMutes[4][3];

	std::vector<short> mMixBuffer;
	std::vector<short> mAudioFifo;
	mutable std::recursive_mutex mAudioMutex;

	bool mLoggingEnabled;
	SidRegisterLog mRegisterLog;
};

#endif