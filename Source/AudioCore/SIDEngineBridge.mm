//
//  SIDEngineBridge.mm
//  SIDPLAY
//
//  Objective-C++ implementation bridging Swift to PlayerLibSidplay & AudioCoreDriver.
//

#import "SIDEngineBridge.h"
#import "PlayerLibSidplay.h"
#import "AudioCoreDriver.h"
#import "songlength/SongLengthDatabase.h"

static constexpr int MAX_SID_CHIPS = 4;

@interface SIDEngineBridge () {
    PlayerLibSidplay *_player;
    AudioCoreDriver *_audioDriver;
    PlaybackSettings _settings;
    
    NSString *_currentPath;
    float _voiceVolumes[MAX_SID_CHIPS][3];
    BOOL _voiceMuted[MAX_SID_CHIPS][3];
    BOOL _voiceSolo[MAX_SID_CHIPS][3];
}
@end

static SIDEngineBridge *sSharedBridge = nil;

@implementation SIDEngineBridge

+ (instancetype)sharedBridge {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (!sSharedBridge) {
            sSharedBridge = [[SIDEngineBridge alloc] init];
        }
    });
    return sSharedBridge;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        if (!sSharedBridge) {
            sSharedBridge = self;
        }
        _player = new PlayerLibSidplay();
        _audioDriver = new AudioCoreDriver();
        
        _player->setAudioDriver(_audioDriver);
        _audioDriver->initialize(_player);
        
        // Setup default playback settings
        int sampleRate = _audioDriver->getSampleRate();
        if (sampleRate <= 0) {
            sampleRate = 44100;
        }
        
        _settings.mFrequency = sampleRate;
        _settings.mBits = 16;
        _settings.mStereo = 1;
        _settings.mOversampling = 1;
        _settings.mSidModel = 0; // Auto
        _settings.mForceSidModel = false;
        _settings.mClockSpeed = 0; // PAL
        _settings.mOptimization = 0;
        
        _settings.mFilterType = SID_FILTER_6581_Resid;
        _settings.mFilterCurve = 0.50;
        _settings.mFilterKinkiness = 0.17f;
        _settings.mFilterBaseLevel = 210.0f;
        _settings.mFilterOffset = -375.0f;
        _settings.mFilterSteepness = 120.0f;
        _settings.mFilterRolloff = 5.5f;
        _settings.mEnableFilterDistortion = 1;
        _settings.mDistortionRate = 1500;
        _settings.mDistortionHeadroom = 400;
        
        _player->initEmuEngine(&_settings);
        
        for (int c = 0; c < MAX_SID_CHIPS; c++) {
            for (int i = 0; i < 3; i++) {
                _voiceVolumes[c][i] = 1.0f;
                _voiceMuted[c][i] = NO;
                _voiceSolo[c][i] = NO;
            }
        }
        
        _audioDriver->setVolume(1.0f);
    }
    return self;
}

- (void)dealloc {
    if (_audioDriver) {
        _audioDriver->stopPlayback();
        delete _audioDriver;
        _audioDriver = nullptr;
    }
    if (_player) {
        delete _player;
        _player = nullptr;
    }
}

// MARK: - Playback Control

- (BOOL)loadTuneAtPath:(NSString *)path subtune:(NSInteger)subtuneIndex {
    if (!path || path.length == 0) {
        return NO;
    }
    
    BOOL wasPlaying = self.isPlaying;
    if (wasPlaying) {
        [self stop];
    }
    
    _settings.mFrequency = _audioDriver->getSampleRate();
    if (_settings.mFrequency <= 0) {
        _settings.mFrequency = 44100;
    }
    
    const char *cPath = [path fileSystemRepresentation];
    bool loaded = _player->loadTuneByPath(cPath, (int)subtuneIndex, &_settings);
    if (!loaded) {
        return NO;
    }
    
    _currentPath = [path copy];
    
    // Apply voice mixer levels
    [self updateVoiceMixer];
    
    if (wasPlaying) {
        [self play];
    }
    
    return YES;
}

- (BOOL)play {
    if (!_player) {
        NSLog(@"[SIDEngineBridge] play failed: _player is NULL");
        return NO;
    }
    if (!_player->isTuneLoaded()) {
        NSLog(@"[SIDEngineBridge] play failed: tune is not loaded");
        return NO;
    }
    
    if (_audioDriver->getIsPlaying()) {
        NSLog(@"[SIDEngineBridge] already playing");
        return YES;
    }
    
    BOOL started = _audioDriver->startPlayback();
    NSLog(@"[SIDEngineBridge] _audioDriver->startPlayback() returned %d", started);
    return started;
}

- (void)pause {
    if (_audioDriver && _audioDriver->getIsPlaying()) {
        _audioDriver->stopPlayback();
    }
}

- (void)stop {
    if (_audioDriver) {
        _audioDriver->stopPlayback();
    }
    if (_player) {
        _player->initCurrentSubtune();
    }
}

- (BOOL)togglePlayPause {
    if (self.isPlaying) {
        [self pause];
        return NO;
    } else {
        return [self play];
    }
}

// MARK: - Subtune Controls

- (BOOL)selectSubtune:(NSInteger)subtuneIndex {
    if (!_player || !_player->isTuneLoaded()) {
        return NO;
    }
    
    BOOL success = _player->startSubtune((int)subtuneIndex);
    if (success) {
        [self updateVoiceMixer];
    }
    return success;
}

- (BOOL)nextSubtune {
    if (!_player || !_player->isTuneLoaded()) {
        return NO;
    }
    BOOL success = _player->startNextSubtune();
    if (success) {
        [self updateVoiceMixer];
    }
    return success;
}

- (BOOL)previousSubtune {
    if (!_player || !_player->isTuneLoaded()) {
        return NO;
    }
    BOOL success = _player->startPrevSubtune();
    if (success) {
        [self updateVoiceMixer];
    }
    return success;
}

// MARK: - Properties

- (BOOL)isPlaying {
    return _audioDriver ? _audioDriver->getIsPlaying() : NO;
}

- (BOOL)isTuneLoaded {
    return _player ? _player->isTuneLoaded() : NO;
}

- (NSInteger)currentSubtune {
    return _player ? _player->getCurrentSubtune() : 0;
}

- (NSInteger)subtuneCount {
    return _player ? _player->getSubtuneCount() : 0;
}

- (NSInteger)defaultSubtune {
    return _player ? _player->getDefaultSubtune() : 0;
}

- (NSInteger)playbackSeconds {
    return _player ? _player->getPlaybackSeconds() : 0;
}

- (float)volume {
    return _audioDriver ? _audioDriver->getVolume() : 1.0f;
}

- (void)setVolume:(float)volume {
    if (_audioDriver) {
        _audioDriver->setVolume(volume);
    }
}

- (NSInteger)tempo {
    return _player ? _player->getTempo() : 100;
}

- (void)setTempo:(NSInteger)tempo {
    if (_player) {
        _player->setTempo((int)tempo);
    }
}

- (nullable NSString *)currentTunePath {
    return _currentPath;
}

// MARK: - Emulation Configuration

- (SIDEngineBackend)engineBackend {
    return _player ? (SIDEngineBackend)_player->getEngineBackend() : SIDEngineBackendCycleExact;
}

- (void)setEngineBackend:(SIDEngineBackend)backend {
    if (_player) {
        _player->setEngineBackend((SIDEngineType)backend);
        [self updateVoiceMixer];
    }
}

- (BOOL)isLegacyEngineAvailable {
    return _player ? _player->isLegacyEngineAvailable() : NO;
}

- (NSString *)engineName {
    return _player ? [NSString stringWithUTF8String:_player->getEngineName()] : @"None";
}

- (SIDChipModel)sidModel {
    return (SIDChipModel)_settings.mSidModel;
}

- (void)setSidModel:(SIDChipModel)model {
    _settings.mSidModel = (int)model;
    _settings.mForceSidModel = (model != SIDChipModelAuto);
    if (_player) {
        _player->setSidModel(_settings.mSidModel, _settings.mForceSidModel);
    }
}

- (BOOL)forceSidModel {
    return _settings.mForceSidModel;
}

- (void)setForceSidModel:(BOOL)force {
    _settings.mForceSidModel = force;
    if (_player) {
        _player->setSidModel(_settings.mSidModel, _settings.mForceSidModel);
    }
}

- (SIDClockSpeed)clockSpeed {
    return (SIDClockSpeed)_settings.mClockSpeed;
}

- (void)setClockSpeed:(SIDClockSpeed)clockSpeed {
    _settings.mClockSpeed = (int)clockSpeed;
    if (_player) {
        _player->setClockSpeed(_settings.mClockSpeed);
    }
}

- (SIDFilterType)filterType {
    return (SIDFilterType)_settings.mFilterType;
}

- (void)setFilterType:(SIDFilterType)filterType {
    _settings.mFilterType = (SPFilterType)filterType;
    if (_player) {
        _player->setFilterType((SPFilterType)filterType);
    }
}

- (double)filterCurve {
    return _settings.mFilterCurve;
}

- (void)setFilterCurve:(double)curve {
    _settings.mFilterCurve = curve;
    if (_player) {
        _player->setFilterCurve(curve);
    }
}

- (double)filterSteepness {
    return _settings.mFilterSteepness;
}

- (void)setFilterSteepness:(double)steepness {
    _settings.mFilterSteepness = (float)steepness;
    if (_player) {
        _player->setFilterSteepness((float)steepness);
    }
}

- (double)filterOffset {
    return _settings.mFilterOffset;
}

- (void)setFilterOffset:(double)offset {
    _settings.mFilterOffset = (float)offset;
    if (_player) {
        _player->setFilterOffset((float)offset);
    }
}

- (double)filterRange {
    return _player ? _player->getFilterRange() : 0.50;
}

- (void)setFilterRange:(double)range {
    if (_player) {
        _player->setFilterRange(range);
    }
}

- (double)filterKinkiness {
    return _settings.mFilterKinkiness;
}

- (void)setFilterKinkiness:(double)kinkiness {
    _settings.mFilterKinkiness = (float)kinkiness;
    if (_player) {
        _player->setFilterKinkiness((float)kinkiness);
    }
}

- (BOOL)old6581Caps {
    return _player ? _player->getOld6581Caps() : NO;
}

- (void)setOld6581Caps:(BOOL)old6581Caps {
    if (_player) {
        _player->setOld6581Caps(old6581Caps);
    }
}

- (BOOL)distortionEnabled {
    return _settings.mEnableFilterDistortion != 0;
}

- (void)setDistortionEnabled:(BOOL)distortionEnabled {
    _settings.mEnableFilterDistortion = distortionEnabled ? 1 : 0;
    if (_player) {
        _player->setDistortionEnabled(distortionEnabled);
    }
}

- (NSInteger)distortionRate {
    return _settings.mDistortionRate;
}

- (void)setDistortionRate:(NSInteger)rate {
    _settings.mDistortionRate = (int)rate;
    if (_player) {
        _player->setDistortionRate((int)rate);
    }
}

- (NSInteger)distortionHeadroom {
    return _settings.mDistortionHeadroom;
}

- (void)setDistortionHeadroom:(NSInteger)headroom {
    _settings.mDistortionHeadroom = (int)headroom;
    if (_player) {
        _player->setDistortionHeadroom((int)headroom);
    }
}

- (NSInteger)optimization {
    return _settings.mOptimization;
}

- (void)setOptimization:(NSInteger)optimization {
    _settings.mOptimization = (int)optimization;
    if (_player) {
        _player->initEmuEngine(&_settings);
    }
}

// MARK: - Metadata

- (NSString *)title {
    if (_player && _player->isTuneLoaded() && _player->getCurrentTitle()) {
        return [NSString stringWithCString:_player->getCurrentTitle() encoding:NSISOLatin1StringEncoding] ?: @"";
    }
    return @"";
}

- (NSString *)author {
    if (_player && _player->isTuneLoaded() && _player->getCurrentAuthor()) {
        return [NSString stringWithCString:_player->getCurrentAuthor() encoding:NSISOLatin1StringEncoding] ?: @"";
    }
    return @"";
}

- (NSString *)releaseInfo {
    if (_player && _player->isTuneLoaded() && _player->getCurrentReleaseInfo()) {
        return [NSString stringWithCString:_player->getCurrentReleaseInfo() encoding:NSISOLatin1StringEncoding] ?: @"";
    }
    return @"";
}

- (NSString *)format {
    if (_player && _player->isTuneLoaded() && _player->getCurrentFormat()) {
        return [NSString stringWithUTF8String:_player->getCurrentFormat()] ?: @"";
    }
    return @"";
}

- (NSString *)chipModelDescription {
    if (_player && _player->isTuneLoaded()) {
        const char *m = _player->getCompositeChipModel();
        if (m) {
            return [NSString stringWithUTF8String:m] ?: @"";
        }
    }
    return @"";
}

- (NSString *)chipModelDescriptionForChip:(NSInteger)chip {
    if (_player && _player->isTuneLoaded()) {
        const char *m = _player->getCurrentChipModel((unsigned int)chip);
        if (m) {
            return [NSString stringWithUTF8String:m] ?: @"";
        }
    }
    return @"";
}

- (uint16_t)sidAddressForChip:(NSInteger)chip {
    if (_player && _player->isTuneLoaded()) {
        return _player->getSidChipBase((unsigned int)chip);
    }
    return (chip == 0) ? 0xD400 : 0;
}

- (NSArray<NSDictionary<NSString *, id> *> *)installedChipsInfo {
    if (!_player || !_player->isTuneLoaded()) {
        return @[];
    }
    NSInteger count = (NSInteger)_player->getInstalledSIDs();
    if (count <= 0) count = 1;
    NSMutableArray *chips = [NSMutableArray arrayWithCapacity:count];
    for (NSInteger i = 0; i < count; i++) {
        uint16_t addr = _player->getSidChipBase((unsigned int)i);
        const char *m = _player->getCurrentChipModel((unsigned int)i);
        NSString *modelStr = m ? ([NSString stringWithUTF8String:m] ?: @"MOS 6581") : @"MOS 6581";
        [chips addObject:@{
            @"index": @(i),
            @"address": @(addr),
            @"model": modelStr
        }];
    }
    return chips;
}

- (uint16_t)loadAddress {
    return _player ? _player->getCurrentLoadAddress() : 0;
}

- (uint16_t)initAddress {
    return _player ? _player->getCurrentInitAddress() : 0;
}

- (uint16_t)playAddress {
    return _player ? _player->getCurrentPlayAddress() : 0;
}

- (NSInteger)fileSize {
    return _player ? _player->getCurrentFileSize() : 0;
}

- (NSInteger)sidChipCount {
    return _player ? (NSInteger)_player->getInstalledSIDs() : 1;
}

- (uint16_t)secondSidAddress {
    return _player ? _player->getSidChipBase(1) : 0;
}

- (uint16_t)thirdSidAddress {
    return _player ? _player->getSidChipBase(2) : 0;
}

- (uint16_t)fourthSidAddress {
    return _player ? _player->getSidChipBase(3) : 0;
}

- (NSInteger)songLengthSeconds {
    if (!_player) return 0;
    int len = _player->getSongLengthSeconds();
    if (len > 0) return len;
    
    if (_currentPath && _currentPath.length > 0) {
        SongLengthDatabase *db = [SongLengthDatabase sharedInstance];
        if (db) {
            return [db getSongLengthByPath:_currentPath andSubtune:(int)_player->getCurrentSubtune()];
        }
    }
    return 0;
}

// MARK: - Voice Mixing & Muting

- (void)updateVoiceMixer {
    if (!_player) return;
    
    BOOL anySolo = NO;
    for (int c = 0; c < MAX_SID_CHIPS; c++) {
        for (int v = 0; v < 3; v++) {
            if (_voiceSolo[c][v]) {
                anySolo = YES;
                break;
            }
        }
        if (anySolo) break;
    }
    
    for (int c = 0; c < MAX_SID_CHIPS; c++) {
        for (int v = 0; v < 3; v++) {
            BOOL mute = _voiceMuted[c][v] || (anySolo && !_voiceSolo[c][v]);
            _player->setVoiceMute((unsigned int)c, (unsigned int)v, mute);
            _player->setVoiceVolume((unsigned int)c, (unsigned int)v, _voiceVolumes[c][v]);
        }
    }
}

- (void)setVoice:(NSInteger)voice volume:(float)vol {
    [self setVoice:voice chip:0 volume:vol];
}

- (float)voiceVolume:(NSInteger)voice {
    return [self voiceVolume:voice chip:0];
}

- (void)setVoice:(NSInteger)voice muted:(BOOL)muted {
    [self setVoice:voice chip:0 muted:muted];
}

- (BOOL)isVoiceMuted:(NSInteger)voice {
    return [self isVoiceMuted:voice chip:0];
}

- (void)setVoice:(NSInteger)voice solo:(BOOL)solo {
    [self setVoice:voice chip:0 solo:solo];
}

- (BOOL)isVoiceSolo:(NSInteger)voice {
    return [self isVoiceSolo:voice chip:0];
}

- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip volume:(float)vol {
    if (chip < 0 || chip >= MAX_SID_CHIPS || voice < 0 || voice > 2) return;
    _voiceVolumes[chip][voice] = vol;
    [self updateVoiceMixer];
}

- (float)voiceVolume:(NSInteger)voice chip:(NSInteger)chip {
    if (chip < 0 || chip >= MAX_SID_CHIPS || voice < 0 || voice > 2) return 1.0f;
    return _voiceVolumes[chip][voice];
}

- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip muted:(BOOL)muted {
    if (chip < 0 || chip >= MAX_SID_CHIPS || voice < 0 || voice > 2) return;
    _voiceMuted[chip][voice] = muted;
    [self updateVoiceMixer];
}

- (BOOL)isVoiceMuted:(NSInteger)voice chip:(NSInteger)chip {
    if (chip < 0 || chip >= MAX_SID_CHIPS || voice < 0 || voice > 2) return NO;
    return _voiceMuted[chip][voice];
}

- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip solo:(BOOL)solo {
    if (chip < 0 || chip >= MAX_SID_CHIPS || voice < 0 || voice > 2) return;
    _voiceSolo[chip][voice] = solo;
    [self updateVoiceMixer];
}

- (BOOL)isVoiceSolo:(NSInteger)voice chip:(NSInteger)chip {
    if (chip < 0 || chip >= MAX_SID_CHIPS || voice < 0 || voice > 2) return NO;
    return _voiceSolo[chip][voice];
}

// MARK: - Real-Time Register & Audio Inspection

- (void)getRegisterFrame:(uint8_t *)outBuffer length:(NSUInteger)length {
    [self getRegisterFrame:outBuffer length:length chip:0];
}

- (void)getRegisterFrame:(uint8_t *)outBuffer length:(NSUInteger)length chip:(NSInteger)chip {
    if (!outBuffer || length == 0) return;
    memset(outBuffer, 0, length);
    if (!_player) return;
    
    uint8_t regs[32] = {0};
    _player->getSidStatus((unsigned int)chip, regs);
    NSUInteger count = MIN(length, (NSUInteger)32);
    memcpy(outBuffer, regs, count);
}

- (void)copyAudioSamples:(float *)outBuffer count:(NSInteger)count {
    if (!outBuffer || count <= 0 || !_audioDriver) return;
    
    short *sampleBuffer = _audioDriver->getSampleBuffer();
    if (!sampleBuffer) {
        memset(outBuffer, 0, count * sizeof(float));
        return;
    }
    
    // Internal buffer has 512 samples
    int samplesToCopy = (int)MIN((NSInteger)512, count);
    float scale = 1.0f / 32768.0f;
    for (int i = 0; i < samplesToCopy; i++) {
        outBuffer[i] = (float)sampleBuffer[i] * scale;
    }
    for (int i = samplesToCopy; i < count; i++) {
        outBuffer[i] = 0.0f;
    }
}

- (void)copyOscilloscopeSamples:(float *)outBuffer count:(NSInteger)count {
    if (!outBuffer || count <= 0) return;
    if (!_audioDriver || !_audioDriver->getIsPlaying()) {
        memset(outBuffer, 0, count * sizeof(float));
        return;
    }
    
    short *sampleBuffer = _audioDriver->getSampleBuffer();
    if (!sampleBuffer) {
        memset(outBuffer, 0, count * sizeof(float));
        return;
    }
    
    int totalFrames = _audioDriver->getNumSamplesInBuffer();
    if (totalFrames <= 0) totalFrames = 512;
    
    float scale = 1.0f / 32768.0f;
    float sum = 0.0f;
    for (NSInteger i = 0; i < count; i++) {
        int frame = (int)((i * totalFrames) / count);
        if (frame >= totalFrames) frame = totalFrames - 1;
        
        float left = (float)sampleBuffer[frame * 2] * scale;
        float right = (float)sampleBuffer[frame * 2 + 1] * scale;
        // On stereo/multi-SID tunes where channels are panned, preserve peak deflection
        float monoSum = (left + right) * 0.5f;
        float dominant = (fabsf(left) > fabsf(right)) ? left : right;
        float sampleVal = (fabsf(monoSum) >= fabsf(dominant) * 0.6f) ? monoSum : dominant;
        outBuffer[i] = sampleVal;
        sum += sampleVal;
    }
    
    // Remove DC offset (common in 6581/8580 analog circuit emulation) to center waveform
    float dcOffset = sum / (float)count;
    for (NSInteger i = 0; i < count; i++) {
        outBuffer[i] -= dcOffset;
    }
}

+ (NSInteger)songLengthForPath:(NSString *)path subtune:(NSInteger)subtune {
    if (!path || path.length == 0) return 0;
    SongLengthDatabase *db = [SongLengthDatabase sharedInstance];
    if (db) {
        return [db getSongLengthByPath:path andSubtune:(int)subtune];
    }
    return 0;
}

+ (void)initializeSongLengthDatabaseWithRootPath:(NSString *)rootPath {
    if (!rootPath || rootPath.length == 0) return;
    SongLengthDatabase *db = [[SongLengthDatabase alloc] initWithRootPath:rootPath];
    [SongLengthDatabase setSharedInstance:db];
    
    NSString *md5Path = [rootPath stringByAppendingPathComponent:@"DOCUMENTS/Songlengths.md5"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:md5Path]) {
        md5Path = [rootPath stringByAppendingPathComponent:@"DOCUMENTS/Songlengths.txt"];
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:md5Path]) {
        SIDEngineBridge *bridge = [SIDEngineBridge sharedBridge];
        if (bridge && bridge->_player) {
            bridge->_player->loadSongLengthDatabase([md5Path UTF8String]);
        }
    }
}

@end
