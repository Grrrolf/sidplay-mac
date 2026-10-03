//
//  SIDEngineBridge.h
//  SIDPLAY
//
//  Clean Objective-C interface for PlayerLibSidplay & AudioCoreDriver,
//  providing modern Swift interop.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Filter emulation model types matching SPFilterType
typedef NS_ENUM(NSInteger, SIDFilterType) {
    SIDFilterType6581Resid  NS_SWIFT_NAME(filter6581Resid)  = 0,
    SIDFilterType6581R3     NS_SWIFT_NAME(filter6581R3)     = 1,
    SIDFilterType6581Galway NS_SWIFT_NAME(filter6581Galway) = 2,
    SIDFilterType6581R4     NS_SWIFT_NAME(filter6581R4)     = 3,
    SIDFilterType8580       NS_SWIFT_NAME(filter8580)       = 4,
    SIDFilterTypeCustom     NS_SWIFT_NAME(filterCustom)     = 5
};

/// SID Chip Model preference
typedef NS_ENUM(NSInteger, SIDChipModel) {
    SIDChipModelAuto NS_SWIFT_NAME(auto)    = 0,
    SIDChipModel6581 NS_SWIFT_NAME(mos6581) = 1,
    SIDChipModel8580 NS_SWIFT_NAME(mos8580) = 2
};

/// Clock Speed preference
typedef NS_ENUM(NSInteger, SIDClockSpeed) {
    SIDClockSpeedAuto NS_SWIFT_NAME(auto) = 0,
    SIDClockSpeedPAL  NS_SWIFT_NAME(pal)  = 1,
    SIDClockSpeedNTSC NS_SWIFT_NAME(ntsc) = 2
};

/// Emulation core backend preference
typedef NS_ENUM(NSInteger, SIDEngineBackend) {
    SIDEngineBackendCycleExact NS_SWIFT_NAME(cycleExact) = 0,
    SIDEngineBackendLegacy     NS_SWIFT_NAME(legacy)     = 1
};

@interface SIDEngineBridge : NSObject

+ (instancetype)sharedBridge;

// MARK: - State Properties
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) BOOL isTuneLoaded;
@property (nonatomic, readonly) NSInteger currentSubtune;
@property (nonatomic, readonly) NSInteger subtuneCount;
@property (nonatomic, readonly) NSInteger defaultSubtune;
@property (nonatomic, readonly) NSInteger playbackSeconds;

// MARK: - Playback Settings
@property (nonatomic, assign) SIDEngineBackend engineBackend;
@property (nonatomic, readonly) BOOL isLegacyEngineAvailable;
@property (nonatomic, readonly, copy) NSString *engineName;
@property (nonatomic, assign) float volume;
@property (nonatomic, assign) NSInteger tempo;
@property (nonatomic, assign) SIDChipModel sidModel;
@property (nonatomic, assign) BOOL forceSidModel;
@property (nonatomic, assign) SIDClockSpeed clockSpeed;
@property (nonatomic, assign) SIDFilterType filterType;
@property (nonatomic, assign) double filterCurve;
@property (nonatomic, assign) double filterSteepness;
@property (nonatomic, assign) double filterOffset;
@property (nonatomic, assign) double filterRange;
@property (nonatomic, assign) double filterKinkiness;
@property (nonatomic, assign) BOOL old6581Caps;
@property (nonatomic, assign) BOOL distortionEnabled;
@property (nonatomic, assign) NSInteger distortionRate;
@property (nonatomic, assign) NSInteger distortionHeadroom;
@property (nonatomic, assign) NSInteger optimization;

// MARK: - Spatial Audio Settings
@property (nonatomic, assign) float stereoWidth;
@property (nonatomic, assign) BOOL bassAnchorEnabled;

// MARK: - Current Tune Metadata
@property (nonatomic, readonly, copy) NSString *title;
@property (nonatomic, readonly, copy) NSString *author;
@property (nonatomic, readonly, copy) NSString *releaseInfo;
@property (nonatomic, readonly, copy) NSString *format;
@property (nonatomic, readonly, copy) NSString *chipModelDescription;
@property (nonatomic, readonly) uint16_t loadAddress;
@property (nonatomic, readonly) uint16_t initAddress;
@property (nonatomic, readonly) uint16_t playAddress;
@property (nonatomic, readonly) NSInteger fileSize;
@property (nonatomic, readonly) NSInteger songLengthSeconds;
@property (nonatomic, readonly, nullable, copy) NSString *currentTunePath;
@property (nonatomic, readonly) NSInteger sidChipCount;
@property (nonatomic, readonly) uint16_t secondSidAddress;
@property (nonatomic, readonly) uint16_t thirdSidAddress;
@property (nonatomic, readonly) uint16_t fourthSidAddress;

- (NSString *)chipModelDescriptionForChip:(NSInteger)chip;
- (uint16_t)sidAddressForChip:(NSInteger)chip;
@property (nonatomic, readonly, copy) NSArray<NSDictionary<NSString *, id> *> *installedChipsInfo;

// MARK: - Playback Control
- (BOOL)loadTuneAtPath:(NSString *)path subtune:(NSInteger)subtuneIndex;
- (BOOL)play;
- (void)pause;
- (void)stop;
- (BOOL)togglePlayPause;

- (BOOL)selectSubtune:(NSInteger)subtuneIndex;
- (BOOL)nextSubtune;
- (BOOL)previousSubtune;

// MARK: - Voice Mixing & Muting
- (void)setVoice:(NSInteger)voice volume:(float)vol;
- (float)voiceVolume:(NSInteger)voice;
- (void)setVoice:(NSInteger)voice muted:(BOOL)muted;
- (BOOL)isVoiceMuted:(NSInteger)voice;
- (void)setVoice:(NSInteger)voice solo:(BOOL)solo;
- (BOOL)isVoiceSolo:(NSInteger)voice;

- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip volume:(float)vol;
- (float)voiceVolume:(NSInteger)voice chip:(NSInteger)chip;
- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip muted:(BOOL)muted;
- (BOOL)isVoiceMuted:(NSInteger)voice chip:(NSInteger)chip;
- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip solo:(BOOL)solo;
- (BOOL)isVoiceSolo:(NSInteger)voice chip:(NSInteger)chip;

// MARK: - Real-Time Register & Visualizer Inspection
/// Fills a 25-byte buffer with current SID registers ($D400 - $D418) for primary SID
- (void)getRegisterFrame:(uint8_t *)outBuffer length:(NSUInteger)length;

/// Fills output with current SID registers for the specified chip index (0, 1, or 2)
- (void)getRegisterFrame:(uint8_t *)outBuffer length:(NSUInteger)length chip:(NSInteger)chip;

/// Fills output with recent linear PCM audio samples from the driver (-1.0 .. 1.0)
- (void)copyAudioSamples:(float *)outBuffer count:(NSInteger)count;

/// Fills output with downmixed and smoothed audio samples for high-framerate oscilloscope visualization (-1.0 .. 1.0)
- (void)copyOscilloscopeSamples:(float *)outBuffer count:(NSInteger)count;

/// Songlength database query
+ (NSInteger)songLengthForPath:(NSString *)path subtune:(NSInteger)subtune;

/// Songlength database setup
+ (void)initializeSongLengthDatabaseWithRootPath:(NSString *)rootPath;

@end

NS_ASSUME_NONNULL_END
