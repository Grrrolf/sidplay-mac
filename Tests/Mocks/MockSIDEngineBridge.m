//
//  MockSIDEngineBridge.m
//  SIDPLAYTests
//
//  Lightweight mock for SIDEngineBridge allowing fast headless CLI test execution
//  without linking against the full C++ emulation and audio core runtime.
//

#import "SIDEngineBridge.h"

@implementation SIDEngineBridge

@synthesize stereoWidth = _stereoWidth;
@synthesize bassAnchorEnabled = _bassAnchorEnabled;

- (instancetype)init {
    self = [super init];
    if (self) {
        _stereoWidth = 1.0f;
        _bassAnchorEnabled = YES;
    }
    return self;
}

+ (instancetype)sharedBridge {
    static SIDEngineBridge *bridge = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        bridge = [[self alloc] init];
    });
    return bridge;
}

+ (NSInteger)songLengthForPath:(NSString *)path subtune:(NSInteger)subtune {
    return 0;
}

+ (void)initializeSongLengthDatabaseWithRootPath:(NSString *)rootPath {
}

- (BOOL)loadTuneAtPath:(NSString *)path subtune:(NSInteger)subtuneIndex { return YES; }
- (BOOL)play { return YES; }
- (void)pause {}
- (void)stop {}
- (BOOL)togglePlayPause { return YES; }
- (BOOL)selectSubtune:(NSInteger)subtuneIndex { return YES; }
- (BOOL)nextSubtune { return YES; }
- (BOOL)previousSubtune { return YES; }
- (void)setVoice:(NSInteger)voice volume:(float)vol {}
- (float)voiceVolume:(NSInteger)voice { return 1.0f; }
- (void)setVoice:(NSInteger)voice muted:(BOOL)muted {}
- (BOOL)isVoiceMuted:(NSInteger)voice { return NO; }
- (void)setVoice:(NSInteger)voice solo:(BOOL)solo {}
- (BOOL)isVoiceSolo:(NSInteger)voice { return NO; }
- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip volume:(float)vol {}
- (float)voiceVolume:(NSInteger)voice chip:(NSInteger)chip { return 1.0f; }
- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip muted:(BOOL)muted {}
- (BOOL)isVoiceMuted:(NSInteger)voice chip:(NSInteger)chip { return NO; }
- (void)setVoice:(NSInteger)voice chip:(NSInteger)chip solo:(BOOL)solo {}
- (BOOL)isVoiceSolo:(NSInteger)voice chip:(NSInteger)chip { return NO; }
- (void)getRegisterFrame:(uint8_t *)outBuffer length:(NSUInteger)length {}
- (void)getRegisterFrame:(uint8_t *)outBuffer length:(NSUInteger)length chip:(NSInteger)chip {}
- (void)copyAudioSamples:(float *)outBuffer count:(NSInteger)count {}
- (void)copyOscilloscopeSamples:(float *)outBuffer count:(NSInteger)count {}
- (NSString *)chipModelDescriptionForChip:(NSInteger)chip { return @"MOS 6581"; }
- (uint16_t)sidAddressForChip:(NSInteger)chip { return 0xd400; }

@end
