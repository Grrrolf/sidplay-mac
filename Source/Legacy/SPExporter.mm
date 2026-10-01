#import "SPExporter.h"
#import "SPExportController.h"
#import "SPPlayerWindow.h"
#import "PlayerLibSidplay.h"
#import "SongLengthDatabase.h"
#import "SPCollectionUtilities.h"
#import "SPPreferencesController.h"

#include "TargetConditionals.h"
#include "lame.h"

static NSString* exportFileTypeExtensions[NUM_EXPORT_TYPES] =
{
	@"mp3",
	@"m4a",
	@"m4a",
	@"aiff",
	@"prg",
	@"sid"
};

static AudioFileTypeID exportAudioFileIDs[NUM_EXPORT_TYPES] =
{
	kAudioFileMP3Type,
	kAudioFileM4AType,
	kAudioFileM4AType,
	kAudioFileAIFFType,
	0,
	0
};

@implementation SPExporter


// ----------------------------------------------------------------------------
- (id) initWithItem:(SPExportItem*)item withController:(SPExportController*)theController andWindow:(SPPlayerWindow*)window loadNow:(BOOL)loadItem
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		controller = theController;
		ownerWindow = window;
		
		outputFileRef = NULL;
		exportSettings = [controller exportSettings];
		
		samplesRemaining = 0;
		samplesCompleted = 0;
		
		fileName = nil;
		exportProgress = 0.0f;
		fileIcon = nil;
		
		exportItemLoaded = NO;
		exportInProgress = NO;
		[self setExportStopped:NO];
		[self setExportProgressIsIndeterminate:NO];
		
		psid64Task = nil;
		
		player = new PlayerLibSidplay;
		
		exportItem = item;

		title = [item title];
		author = [item author];

		if (loadItem)
		{
			BOOL itemIsValid = [self loadExportItem];
			if (!itemIsValid)
				return nil;
		}
		
		destinationPath = nil;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (BOOL) loadExportItem
// ----------------------------------------------------------------------------
{
	if (exportItemLoaded)
		return NO;
		
	settings = gPreferences.mPlaybackSettings;
	if (settings.mFrequency == 0)
		settings.mFrequency = 44100;
	settings.mStereo = 1;

	NSString* path = [exportItem path];
	int subtune = [exportItem subtune];
	if (subtune <= 0)
		subtune = 1;

	bool success = player->loadTuneByPath([path cStringUsingEncoding:NSUTF8StringEncoding], subtune, &settings);
	if (!success)
		return NO;

	exportSettings.mTimeInSeconds = [[SongLengthDatabase sharedInstance] getSongLengthByPath:path andSubtune:subtune];
	if (exportSettings.mTimeInSeconds == 0)
		exportSettings.mTimeInSeconds = gPreferences.mDefaultPlayTime > 0 ? gPreferences.mDefaultPlayTime : 180;
	if ([exportItem loopCount] > 0)
		exportSettings.mTimeInSeconds *= [exportItem loopCount];

	const char* rel = player->getCurrentReleaseInfo();
	releaseInfo = rel != NULL ? [NSString stringWithCString:rel encoding:NSISOLatin1StringEncoding] : @"";

	const char* t = player->getCurrentTitle();
	if (t != NULL && strlen(t) > 0)
		title = [NSString stringWithCString:t encoding:NSISOLatin1StringEncoding];

	const char* a = player->getCurrentAuthor();
	if (a != NULL && strlen(a) > 0)
		author = [NSString stringWithCString:a encoding:NSISOLatin1StringEncoding];

	exportItemLoaded = YES;

	return YES;
}


// ----------------------------------------------------------------------------
- (void) unloadExportItem
// ----------------------------------------------------------------------------
{
	if (!exportItemLoaded)
		return;
	
	exportItemLoaded = NO;
}	


// ----------------------------------------------------------------------------
- (ExportSettings) exportSettings
// ----------------------------------------------------------------------------
{
	return exportSettings;
}


// ----------------------------------------------------------------------------
- (void) setExportSettings:(ExportSettings)theExportSettings
// ----------------------------------------------------------------------------
{
	exportSettings = theExportSettings;
}


// ----------------------------------------------------------------------------
- (void) determineExportFilePath:(NSString*)directoryPath
// ----------------------------------------------------------------------------
{
	NSString* suggestedFilename = [self suggestedFilename];
	NSString* suggestedFilenameWithoutExtension = [suggestedFilename stringByDeletingPathExtension];
	NSString* suggestedExtension = [self suggestedFileExtension]; 

	NSString* filename = [suggestedFilenameWithoutExtension stringByAppendingPathExtension:suggestedExtension];
	
	NSString* destinationFile = [directoryPath stringByAppendingPathComponent:filename];
	
	int retryCount = 1;
	BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:destinationFile];
	while (exists)
	{
		filename = [suggestedFilenameWithoutExtension stringByAppendingFormat:@" %d", retryCount];
		filename = [filename stringByAppendingPathExtension:suggestedExtension];
		
		destinationFile = [directoryPath stringByAppendingPathComponent:filename];
		
		retryCount++;
		exists = [[NSFileManager defaultManager] fileExistsAtPath:destinationFile];
	}

	[self setDestinationPath:destinationFile];
}


// ----------------------------------------------------------------------------
- (NSString*) suggestedFileExtension
// ----------------------------------------------------------------------------
{
	return exportFileTypeExtensions[exportSettings.mFileType];
}


// ----------------------------------------------------------------------------
- (NSString*) suggestedFilename
// ----------------------------------------------------------------------------
{
	NSString* safeAuthor = [author length] > 0 ? author : @"Unknown";
	NSString* safeTitle = [title length] > 0 ? title : [[destinationPath ?: [exportItem path] lastPathComponent] stringByDeletingPathExtension];
	if ([safeTitle length] == 0) safeTitle = @"Tune";

	NSRange slashRange = [safeAuthor rangeOfString:@"/"];
	NSString* authorWithoutGroup = nil;
	if (slashRange.location == NSNotFound)
		authorWithoutGroup = safeAuthor;
	else
		authorWithoutGroup = [safeAuthor substringToIndex:slashRange.location];

	authorWithoutGroup = [authorWithoutGroup stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([authorWithoutGroup length] == 0)
		authorWithoutGroup = @"Unknown";

	NSString* titleWithoutSlashes = [safeTitle stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	int subtuneNum = [exportItem subtune] > 0 ? [exportItem subtune] : 1;
	return [NSString stringWithFormat:@"%@ - %@ (song %d).%@", authorWithoutGroup, titleWithoutSlashes, subtuneNum, [self suggestedFileExtension]];
}


// ----------------------------------------------------------------------------
- (void) setFileName:(NSString*)name
// ----------------------------------------------------------------------------
{
	fileName = name;
}


// ----------------------------------------------------------------------------
- (NSString*) fileName
// ----------------------------------------------------------------------------
{
	return fileName;
}


// ----------------------------------------------------------------------------
- (void) setDestinationPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	destinationPath = path;
	[self setFileName:[path lastPathComponent]];
}


// ----------------------------------------------------------------------------
- (PlayerLibSidplay*) player
// ----------------------------------------------------------------------------
{
	return player;
}


// ----------------------------------------------------------------------------
- (NSImage*) fileIcon
// ----------------------------------------------------------------------------
{
	return fileIcon;
}


// ----------------------------------------------------------------------------
- (void) setFileIcon:(NSImage*)icon
// ----------------------------------------------------------------------------
{
	fileIcon = icon;
}


// ----------------------------------------------------------------------------
- (BOOL) exportInProgress
// ----------------------------------------------------------------------------
{
	return exportInProgress;
}


// ----------------------------------------------------------------------------
- (BOOL) exportStopped
// ----------------------------------------------------------------------------
{
	return exportStopped;
}


// ----------------------------------------------------------------------------
- (void) setExportStopped:(BOOL)stopped
// ----------------------------------------------------------------------------
{
	exportStopped = stopped;
}


// ----------------------------------------------------------------------------
- (float) exportProgress
// ----------------------------------------------------------------------------
{
	return exportProgress;
}


// ----------------------------------------------------------------------------
- (void) setExportProgress:(float)progress
// ----------------------------------------------------------------------------
{
	exportProgress = progress;
}


// ----------------------------------------------------------------------------
- (BOOL) exportProgressIsIndeterminate
// ----------------------------------------------------------------------------
{
	return exportProgressIsIndeterminate;
}


// ----------------------------------------------------------------------------
- (void) setExportProgressIsIndeterminate:(BOOL)indeterminate
// ----------------------------------------------------------------------------
{
	exportProgressIsIndeterminate = indeterminate;
}


// ----------------------------------------------------------------------------
- (void) startExport
// ----------------------------------------------------------------------------
{
	samplesRemaining = exportSettings.mTimeInSeconds * settings.mFrequency;
	samplesCompleted = 0;
	exportProgress = 0.0f;
	
	[self setExportStopped:NO];
	exportInProgress = YES;
	
	if (exportSettings.mFileType == EXPORT_TYPE_MP3)
		[NSThread detachNewThreadSelector:@selector(exportUsingLameThread:) toTarget:self withObject:nil];
	else if (exportSettings.mFileType == EXPORT_TYPE_PRG)
		[self exportUsingPsid64];
	else
		[NSThread detachNewThreadSelector:@selector(exportUsingExtAudioFileThread:) toTarget:self withObject:nil];
}


// ----------------------------------------------------------------------------
- (void) stopExport
// ----------------------------------------------------------------------------
{
	[self setExportStopped:YES];
	if (!exportInProgress)
		[controller exportFinished:self];
}


// ----------------------------------------------------------------------------
- (void) revealExportFile
// ----------------------------------------------------------------------------
{
	if (destinationPath != nil)
	{
		NSWorkspace* workSpace = [NSWorkspace sharedWorkspace];
		[workSpace selectFile:destinationPath inFileViewerRootedAtPath:@""];
	}
}


// ----------------------------------------------------------------------------
- (void) exportUsingPsid64
// ----------------------------------------------------------------------------
{
	[self setExportProgressIsIndeterminate:YES];
	
	NSString* psid64ExecutablePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"psid64"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:psid64ExecutablePath])
	{
		NSLog(@"psid64 executable not found at %@", psid64ExecutablePath);
		[self setExportProgressIsIndeterminate:NO];
		[self setExportStopped:YES];
		exportInProgress = NO;
		[controller exportFinished:self];
		return;
	}

	NSMutableArray* psid64Arguments = [NSMutableArray arrayWithCapacity:10];

	if (exportSettings.mBlankScreen)
		[psid64Arguments addObject:@"-b"];
		
	if (exportSettings.mIncludeStilComment)
		[psid64Arguments addObject:@"-g"];

	if (exportSettings.mCompressOutputFile)
		[psid64Arguments addObject:@"-c"];

	[psid64Arguments addObject:@"-v"];

	int subtuneNum = [exportItem subtune] > 0 ? [exportItem subtune] : 1;
	[psid64Arguments addObject:@"-i"];
	[psid64Arguments addObject:[NSString stringWithFormat:@"%d", subtuneNum]];

	NSString* dbPath = [[SongLengthDatabase sharedInstance] databasePath];
	if (dbPath != nil && [[NSFileManager defaultManager] fileExistsAtPath:dbPath])
	{
		[psid64Arguments addObject:@"-s"];
		[psid64Arguments addObject:dbPath];
	}

	[psid64Arguments addObject:@"-o"];
	[psid64Arguments addObject:destinationPath];
	[psid64Arguments addObject:[exportItem path]];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(psid64TaskFinished:) name:NSTaskDidTerminateNotification object:nil];	
	psid64Task = [[NSTask alloc] init];
	[psid64Task setLaunchPath:psid64ExecutablePath];
	[psid64Task setCurrentDirectoryPath:[[NSBundle mainBundle] resourcePath]];
	[psid64Task setArguments:psid64Arguments];
	[psid64Task launch];
}


// ----------------------------------------------------------------------------
- (void) psid64TaskFinished:(NSNotification*)aNotification
// ----------------------------------------------------------------------------
{
	NSTask* task = (NSTask*) [aNotification object];
	if (task != psid64Task)
		return;

	psid64Task = nil;
	
	NSNumber* creatorCode = [NSNumber numberWithUnsignedLong:'C=64'];
	NSNumber* typeCode = [NSNumber numberWithUnsignedLong:'C64F'];
	NSDictionary* attributes = [NSDictionary dictionaryWithObjectsAndKeys:creatorCode, NSFileHFSCreatorCode, typeCode, NSFileHFSTypeCode, nil];
	[[NSFileManager defaultManager] setAttributes:attributes ofItemAtPath:destinationPath error:nil];

	NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:destinationPath];
	[icon setScalesWhenResized:NO];
	[icon setSize:NSMakeSize(32, 32)];
	[self setFileIcon:icon];

	exportInProgress = NO;
	[self setExportStopped:YES];
	[controller exportFinished:self];
	[self setExportProgressIsIndeterminate:NO];

	[[NSNotificationCenter defaultCenter] removeObserver:self];
}


// ----------------------------------------------------------------------------
- (void) exportUsingExtAudioFileThread:(id)inObject
// ----------------------------------------------------------------------------
{
    OSStatus err = noErr;

	[NSThread setThreadPriority:[NSThread threadPriority]+.1];
    
    // create the file
    if (outputFileRef == NULL)
	{
		BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:destinationPath];
		if (exists)
			[[NSFileManager defaultManager] removeItemAtPath:destinationPath error:nil];

		// The format in which we render the SID output: 16-bit interleaved stereo PCM
		inputFormat.mChannelsPerFrame = 2;
		inputFormat.mSampleRate = settings.mFrequency;
		inputFormat.mFormatID = kAudioFormatLinearPCM;
#if TARGET_RT_LITTLE_ENDIAN
		inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
#else
		inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked | kAudioFormatFlagIsBigEndian;
#endif
		inputFormat.mBytesPerPacket = sizeof(short) * inputFormat.mChannelsPerFrame;
		inputFormat.mFramesPerPacket = 1;
		inputFormat.mBytesPerFrame = sizeof(short) * inputFormat.mChannelsPerFrame;
		inputFormat.mBitsPerChannel = 16;

		// The format for the output file
		UInt32 size = sizeof(outputFormat);

		outputFormat.mSampleRate = settings.mFrequency;
		outputFormat.mChannelsPerFrame = 2;

		switch (exportSettings.mFileType)
		{
			case EXPORT_TYPE_AAC:
				outputFormat.mFormatID = kAudioFormatMPEG4AAC;
				outputFormat.mFormatFlags = 0;
				err = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &outputFormat);
				break;

			case EXPORT_TYPE_ALAC:
				outputFormat.mFormatID = kAudioFormatAppleLossless;
				outputFormat.mFormatFlags = 0;
				err = AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &size, &outputFormat);
				break;

			case EXPORT_TYPE_AIFF:
			default:
				outputFormat.mFormatID = kAudioFormatLinearPCM;
				outputFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kAudioFormatFlagIsBigEndian | kAudioFormatFlagIsPacked;
				outputFormat.mBytesPerPacket = sizeof(short) * outputFormat.mChannelsPerFrame;
				outputFormat.mFramesPerPacket = 1;
				outputFormat.mBytesPerFrame = sizeof(short) * outputFormat.mChannelsPerFrame;
				outputFormat.mBitsPerChannel = 16;
				break;
		}
		
		NSURL* outputURL = [NSURL fileURLWithPath:destinationPath];
		err = ExtAudioFileCreateWithURL((__bridge CFURLRef)outputURL, exportAudioFileIDs[exportSettings.mFileType], &outputFormat, NULL, kAudioFileFlags_EraseFile, &outputFileRef);		

		NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:destinationPath];
		[icon setScalesWhenResized:NO];
		[icon setSize:NSMakeSize(32, 32)];
		[self performSelectorOnMainThread:@selector(setFileIcon:) withObject:icon waitUntilDone:NO];

		err = ExtAudioFileSetProperty(outputFileRef, kExtAudioFileProperty_ClientDataFormat, sizeof(AudioStreamBasicDescription), &inputFormat);
		
		if (exportSettings.mFileType == EXPORT_TYPE_AAC)
		{
			size = sizeof(AudioConverterRef);
			AudioConverterRef converterRef;
			err = ExtAudioFileGetProperty(outputFileRef, kExtAudioFileProperty_AudioConverter, &size, &converterRef);
			
			UInt32 mode = exportSettings.mUseVBR ? kAudioCodecBitRateFormat_VBR : kAudioCodecBitRateFormat_CBR;
			err	= AudioConverterSetProperty(converterRef, kAudioCodecBitRateFormat, sizeof(mode), &mode);

			UInt32 bitRate = exportSettings.mBitRate * 1000;
			err = AudioConverterSetProperty(converterRef, kAudioConverterEncodeBitRate, sizeof(UInt32), &bitRate);
			
			UInt32 codecQuality = kAudioConverterQuality_Medium;
			int quality = exportSettings.mQuality * 4;
			switch (quality)
			{
				case 0:
					codecQuality = kAudioConverterQuality_Min;
					break;
				case 1:
					codecQuality = kAudioConverterQuality_Low;
					break;
				case 2:
					codecQuality = kAudioConverterQuality_Medium;
					break;
				case 3:
					codecQuality = kAudioConverterQuality_High;
					break;
				case 4:
					codecQuality = kAudioConverterQuality_Max;
					break;
			}

			err = AudioConverterSetProperty(converterRef, kAudioConverterCodecQuality, sizeof(UInt32), &codecQuality);
		}
    }
    
	const int maxSamplesPerSlice = 64 * 1024;
	const int fadeTimeInSamples = exportSettings.mFadeOutTime * settings.mFrequency;

	AudioBufferList outputBufferList;
	UInt32 renderBufferSize = (maxSamplesPerSlice * inputFormat.mBytesPerFrame);
	char* renderBuffer = new char[renderBufferSize];

	outputBufferList.mNumberBuffers = 1;
	outputBufferList.mBuffers[0].mNumberChannels = inputFormat.mChannelsPerFrame;
	outputBufferList.mBuffers[0].mData = renderBuffer;
	outputBufferList.mBuffers[0].mDataByteSize = renderBufferSize;
	
    // loop until stopped from an external event, or finished the entire extraction
	while (!exportStopped)
	{
        if (samplesRemaining == 0)
			break;

		// progress update
		NSNumber* progress = [NSNumber numberWithFloat:(float)samplesCompleted / float(samplesCompleted + samplesRemaining)];
		[self performSelectorOnMainThread:@selector(exportInProgressNotification:) withObject:progress waitUntilDone:NO];
		
		UInt32 numSamplesThisSlice = samplesRemaining;
		if (numSamplesThisSlice > maxSamplesPerSlice)
			numSamplesThisSlice = maxSamplesPerSlice;

		// write it to the file
		if (numSamplesThisSlice > 0)
		{
			UInt32 bytesThisSlice = numSamplesThisSlice * inputFormat.mBytesPerFrame;
			outputBufferList.mBuffers[0].mDataByteSize = bytesThisSlice;
			player->fillBuffer(outputBufferList.mBuffers[0].mData, bytesThisSlice);

			if (exportSettings.mWithFadeOut && (samplesRemaining - numSamplesThisSlice) < fadeTimeInSamples)
			{
				short* sampleBuffer = (short*) renderBuffer;
				
				for(int i = 0; i < numSamplesThisSlice; i++)
				{
					if ((samplesRemaining - i) < fadeTimeInSamples)
					{
						float fadeOutFactor = float(samplesRemaining - i) / float(fadeTimeInSamples);
						sampleBuffer[i * 2]     = (short)(fadeOutFactor * sampleBuffer[i * 2]);
						sampleBuffer[i * 2 + 1] = (short)(fadeOutFactor * sampleBuffer[i * 2 + 1]);
					}
				}
			}

			err = ExtAudioFileWrite(outputFileRef, numSamplesThisSlice, &outputBufferList);
			if (err != noErr)
				break;
		}
		
		samplesRemaining -= numSamplesThisSlice;
		samplesCompleted += numSamplesThisSlice;
    }

	delete[] renderBuffer;
		
    if (outputFileRef != NULL) {
		ExtAudioFileDispose(outputFileRef);
		outputFileRef = NULL;
    }
 	
	[self performSelectorOnMainThread:@selector(exportCompletedNotification:)
                           withObject:(id)[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]
                        waitUntilDone:NO];
}


// ----------------------------------------------------------------------------
- (void) exportUsingLameThread:(id)inObject
// ----------------------------------------------------------------------------
{
	[NSThread setThreadPriority:[NSThread threadPriority]+.1];

    OSStatus err = noErr;

	FILE* outputFileHandle = fopen([destinationPath fileSystemRepresentation], "wb");
	if (outputFileHandle == NULL)
	{
		NSLog(@"Failed to open output file: %@", destinationPath);
		[self performSelectorOnMainThread:@selector(exportCompletedNotification:)
		                       withObject:(id)[NSError errorWithDomain:NSPOSIXErrorDomain code:errno userInfo:nil]
		                    waitUntilDone:NO];
		return;
	}

	NSImage* icon = [[NSWorkspace sharedWorkspace] iconForFile:destinationPath];
	[icon setScalesWhenResized:NO];
	[icon setSize:NSMakeSize(32, 32)];
	[self performSelectorOnMainThread:@selector(setFileIcon:) withObject:icon waitUntilDone:NO];

	lame_global_flags *lameState;
	lameState = lame_init();
	lame_set_num_channels(lameState, 2);
	lame_set_mode(lameState, JOINT_STEREO);
	lame_set_in_samplerate(lameState, settings.mFrequency);
	
	if (exportSettings.mUseVBR)
	{
		lame_set_VBR(lameState, vbr_default);
		lame_set_brate(lameState, exportSettings.mBitRate);		
	}
	else
	{
		lame_set_VBR(lameState, vbr_off);
		lame_set_brate(lameState, exportSettings.mBitRate);		
	}

	int lameQuality = (int) ((1.0f - exportSettings.mQuality) * 9.0f);
	lame_set_quality(lameState, lameQuality);

	id3tag_init(lameState);
	id3tag_add_v2(lameState);
	if ([title length] > 0)
		id3tag_set_title(lameState, [title cStringUsingEncoding:NSISOLatin1StringEncoding]);
	if ([author length] > 0)
		id3tag_set_artist(lameState, [author cStringUsingEncoding:NSISOLatin1StringEncoding]);

	if ([releaseInfo length] >= 4)
	{
		NSString* year = [releaseInfo substringWithRange:NSMakeRange(0, 4)];
		id3tag_set_year(lameState, [year cStringUsingEncoding:NSISOLatin1StringEncoding]);
	}
	
	id3tag_set_comment(lameState, "Exported with SIDPLAY");
	
	int rc = lame_init_params(lameState);

	const int maxSamplesPerSlice = 64 * 1024;
	const int fadeTimeInSamples = exportSettings.mFadeOutTime * settings.mFrequency;

	UInt32 renderBufferSize = (maxSamplesPerSlice * 2 * sizeof(short));
	char* renderBuffer = new char[renderBufferSize];

	int mp3BufferSize = (int) (1.25f * maxSamplesPerSlice * 2 + 7200);
	unsigned char* mp3Buffer = new unsigned char[mp3BufferSize];

	while (!exportStopped)
	{
        if (samplesRemaining == 0)
			break;

		// progress update
		NSNumber* progress = [NSNumber numberWithFloat:(float)samplesCompleted / float(samplesCompleted + samplesRemaining)];
		[self performSelectorOnMainThread:@selector(exportInProgressNotification:) withObject:progress waitUntilDone:NO];
		
		UInt32 numSamplesThisSlice = samplesRemaining;
		if (numSamplesThisSlice > maxSamplesPerSlice)
			numSamplesThisSlice = maxSamplesPerSlice;

		// write it to the file
		if (numSamplesThisSlice > 0)
		{
			UInt32 bytesThisSlice = numSamplesThisSlice * 2 * sizeof(short);
			player->fillBuffer(renderBuffer, bytesThisSlice);

			if (exportSettings.mWithFadeOut && (samplesRemaining - numSamplesThisSlice) < fadeTimeInSamples)
			{
				short* sampleBuffer = (short*) renderBuffer;
				
				for(int i = 0; i < numSamplesThisSlice; i++)
				{
					if ((samplesRemaining - i) < fadeTimeInSamples)
					{
						float fadeOutFactor = float(samplesRemaining - i) / float(fadeTimeInSamples);
						sampleBuffer[i * 2]     = (short)(fadeOutFactor * sampleBuffer[i * 2]);
						sampleBuffer[i * 2 + 1] = (short)(fadeOutFactor * sampleBuffer[i * 2 + 1]);
					}
				}
			}

			rc = lame_encode_buffer_interleaved(lameState, (short int*)renderBuffer, numSamplesThisSlice, mp3Buffer, mp3BufferSize);
			if (rc > 0)
				fwrite(mp3Buffer, 1, rc, outputFileHandle);
		}
		
		samplesRemaining -= numSamplesThisSlice;
		samplesCompleted += numSamplesThisSlice;
    }

	rc = lame_encode_flush(lameState, mp3Buffer, mp3BufferSize);
	if (rc > 0)
		fwrite(mp3Buffer, 1, rc, outputFileHandle);
	lame_close(lameState);

	delete[] renderBuffer;
	delete[] mp3Buffer;
		
    if (outputFileHandle != NULL)
		fclose(outputFileHandle);
 	
	[self performSelectorOnMainThread:@selector(exportCompletedNotification:)
                           withObject:(id)[NSError errorWithDomain:NSOSStatusErrorDomain code:err userInfo:nil]
                        waitUntilDone:NO];
}


// ----------------------------------------------------------------------------
- (void) exportCompletedNotification:(NSError *)error
// ----------------------------------------------------------------------------
{
	//NSLog(@"export stopped with error: %@\n", error);

	exportInProgress = NO;
	[self setExportStopped:YES];
	[controller exportFinished:self];
}


// ----------------------------------------------------------------------------
- (void) exportInProgressNotification:(id)progress
// ----------------------------------------------------------------------------
{
	[self setExportProgress:[progress floatValue]];
}


@end



@implementation SPExportItem

// ----------------------------------------------------------------------------
- (id) initWithPath:(NSString*)filePath andTitle:(NSString*)titleString andAuthor:(NSString*)authorString andSubtune:(int)subtuneIndex andLoopCount:(int)loops
// ----------------------------------------------------------------------------
{
	self = [super init];
	if (self != nil)
	{
		path = filePath;
		title = titleString;
		author = authorString;
		subtune = subtuneIndex;
		loopCount = loops;
		exporter = nil;
	}
	return self;
}


// ----------------------------------------------------------------------------
- (NSString*) path
// ----------------------------------------------------------------------------
{
	return path;
}


// ----------------------------------------------------------------------------
- (void) setPath:(NSString*)filePath
// ----------------------------------------------------------------------------
{
	path = filePath;
}


// ----------------------------------------------------------------------------
- (NSString*) title
// ----------------------------------------------------------------------------
{
	return title;
}


// ----------------------------------------------------------------------------
- (void) setTitle:(NSString*)titleString
// ----------------------------------------------------------------------------
{
	title = titleString;
}


// ----------------------------------------------------------------------------
- (NSString*) author
// ----------------------------------------------------------------------------
{
	return author;
}


// ----------------------------------------------------------------------------
- (void) setAuthor:(NSString*)authorString
// ----------------------------------------------------------------------------
{
	author = authorString;
}


// ----------------------------------------------------------------------------
- (int) subtune
// ----------------------------------------------------------------------------
{
	return subtune;
}


// ----------------------------------------------------------------------------
- (void) setSubtune:(int)subtuneIndex
// ----------------------------------------------------------------------------
{
	subtune = subtuneIndex;
}


// ----------------------------------------------------------------------------
- (int) loopCount
// ----------------------------------------------------------------------------
{
	return loopCount;
}


// ----------------------------------------------------------------------------
- (void) setLoopCount:(int)loops
// ----------------------------------------------------------------------------
{
	loopCount = loops;
}


// ----------------------------------------------------------------------------
- (SPExporter*) exporter
// ----------------------------------------------------------------------------
{
	return exporter;
}


// ----------------------------------------------------------------------------
- (void) setExporter:(SPExporter*)theExporter
// ----------------------------------------------------------------------------
{
	exporter = theExporter;
}


@end
