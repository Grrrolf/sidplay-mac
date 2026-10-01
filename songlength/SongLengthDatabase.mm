#import "SongLengthDatabase.h"
#include <sidplayfp/SidDatabase.h>
#include <sidplayfp/SidTune.h>

static NSString* SidplaySongLengthDataBaseRelativePathMd5 = @"DOCUMENTS/Songlengths.md5";
static NSString* SidplaySongLengthDataBaseRelativePathTxt = @"DOCUMENTS/Songlengths.txt";

static SongLengthDatabase* sharedInstance = nil;

@interface SongLengthDatabase () {
    SidDatabase* m_db;
}
@end

@implementation SongLengthDatabase

// ----------------------------------------------------------------------------
+ (SongLengthDatabase*) sharedInstance
// ----------------------------------------------------------------------------
{
	return sharedInstance;
}


// ----------------------------------------------------------------------------
+ (void) setSharedInstance:(SongLengthDatabase*)database
// ----------------------------------------------------------------------------
{
	sharedInstance = database;
}


// ----------------------------------------------------------------------------
- (id) initWithRootPath:(NSString*)rootPath
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		databaseAvailable = NO;
		collectionRootPath = rootPath;	
		
		if (rootPath == nil)
			return nil;
			
        m_db = new SidDatabase();
        
		databasePath = [rootPath stringByAppendingPathComponent:SidplaySongLengthDataBaseRelativePathMd5];
        if (![[NSFileManager defaultManager] fileExistsAtPath:databasePath]) {
            databasePath = [rootPath stringByAppendingPathComponent:SidplaySongLengthDataBaseRelativePathTxt];
        }

		bool success = m_db->open([databasePath UTF8String]);

		if (!success) {
            delete m_db;
            m_db = nullptr;
			return nil;
        }
			
		databaseAvailable = YES;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (id) initWithRootUrlString:(NSString*)urlString
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		databaseAvailable = NO;
		collectionRootPath = urlString;	
		
		if (urlString == nil)
			return nil;
		
		databasePath = [urlString stringByAppendingPathComponent:SidplaySongLengthDataBaseRelativePathTxt];
	}
	return self;
}


// ----------------------------------------------------------------------------
- (void) dealloc
// ----------------------------------------------------------------------------
{
    if (m_db) {
        delete m_db;
        m_db = nullptr;
    }
#if !__has_feature(objc_arc)
    [super dealloc];
#endif
}


// ----------------------------------------------------------------------------
- (int) getSongLengthByPath:(NSString*)path andSubtune:(int)subtune
// ----------------------------------------------------------------------------
{
	if (!databaseAvailable || !m_db || path == nil)
		return 0;
	
    SidTune tune([path UTF8String]);
    if (!tune.getStatus())
        return 0;

    tune.selectSong(subtune > 0 ? subtune : 1);
    int_least32_t ms = m_db->lengthMs(tune);
    if (ms > 0) return (int)((ms + 500) / 1000);
    int_least32_t len = m_db->length(tune);
    return len > 0 ? (int)len : 0;
}


// ----------------------------------------------------------------------------
- (int) getSongLengthFromBuffer:(void*)buffer withBufferLength:(int)length andSubtune:(int)subtune
// ----------------------------------------------------------------------------
{
    if (!databaseAvailable || !m_db || buffer == NULL || length <= 0)
        return 0;

    SidTune tune(static_cast<const uint_least8_t*>(buffer), static_cast<uint_least32_t>(length));
    if (!tune.getStatus())
        return 0;

    tune.selectSong(subtune > 0 ? subtune : 1);
    int_least32_t ms = m_db->lengthMs(tune);
    if (ms > 0) return (int)((ms + 500) / 1000);
    int_least32_t len = m_db->length(tune);
    return len > 0 ? (int)len : 0;
}


// ----------------------------------------------------------------------------
- (int) getSongLengthFromSidTune:(SidTuneWrapper*)sidtune andSubtune:(int)subtune
// ----------------------------------------------------------------------------
{
    return 0;
}


// ----------------------------------------------------------------------------
- (NSString*) databasePath
// ----------------------------------------------------------------------------
{
	return databasePath;
}


@end

