#import "SPPlayerWindow.h"
#import <objc/message.h>
#import "SPStatusDisplayView.h"
#import "SPPreferencesController.h"
#import "SPBrowserDataSource.h"
#import "SPExportController.h"
#import "SongLengthDatabase.h"
#import "SPCollectionUtilities.h"
#import "SPVisualizerView.h"
#import "SPApplicationStorageController.h"
#import "SPSourceListDataSource.h"
#import "SPGradientBox.h"
#import "SIDEngineBridge.h"

//#import "AudioQueueDriver.h"
#import "AudioCoreDriver.h"
//#import "AudioSoundManager.h"


NSString* SPTuneChangedNotification = @"SPTuneChangedNotification";
NSString* SPPlayerInitializedNotification = @"SPPlayerInitializedNotification";

NSString* SPUrlRequestUserAgentString = nil;

@implementation SPPlayerWindow

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	[[SPPreferencesController sharedInstance] load];
	
	prefsWindowController = nil;
	
	player = new PlayerLibSidplay;
	audioDriver = new AudioCoreDriver;
	player->setAudioDriver(audioDriver);
	
	audioDriver->initialize(player);
	audioDriver->setVolume(gPreferences.mPlaybackVolume);
	gPreferences.mPlaybackSettings.mFrequency = audioDriver->getSampleRate();
	
	sid_filter_t filterSettings;
	PlayerLibSidplay::setFilterSettingsFromPlaybackSettings(filterSettings, &gPreferences.mPlaybackSettings);
	player->setFilterSettings(&filterSettings);
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPPlayerInitializedNotification object:self];
	
	[volumeSlider setFloatValue:gPreferences.mPlaybackVolume * 100.0f];
	volumeIsMuted = NO;
	fadeOutInProgress = NO;
	fadeOutVolume = 1.0f;
	
	currentTunePath = nil;
	currentTuneLengthInSeconds = 0;
	
	urlDownloadData = nil;
	urlDownloadConnection = nil;
	
	lastBufferUnderrunCheckReset = nil;
	
	[exportController setOwnerWindow:self];
	
	[self populateVisualizerMenu];
	
	visualizerView = nil;
    /*
	visualizerView = [[SPVisualizerView alloc] init];
	[visualizerView setFrame:[self frame]];
	[visualizerView setEraseColor:[NSColor colorWithDeviceRed:0.0f green:0.0f blue:0.0f alpha:1.0f]];
	NSString* visualizerPath = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],@"/DefaultVisualizer.qtz"];
	[visualizerView loadCompositionFromFile:visualizerPath];
	[visualizerView setAutostartsRendering:YES];
	[visualizerView setAutoresizesSubviews:YES];
	[visualizerView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
	*/
     
	NSDictionary* infoDictionary = [[NSBundle mainBundle] infoDictionary];
	NSString* appNameString = [infoDictionary objectForKey:@"CFBundleName"];
	NSString* appVersionString = [infoDictionary objectForKey:@"CFBundleVersion"];
	NSString* osVersionString = [[NSProcessInfo processInfo] operatingSystemVersionString];
	SPUrlRequestUserAgentString = [NSString stringWithFormat:@"%@/%@ (Mac OS X, %@)", appNameString, appVersionString, osVersionString];
    
    
    NSString* key = [NSString stringWithFormat:@"NSSplitView Subview Frames %@", splitView.autosaveName];
    NSArray* subviewFrames = [[NSUserDefaults standardUserDefaults] valueForKey:key];
    
    if (subviewFrames.count > 0)
    {
        // the last frame is skipped because I have one less divider than I have frames
        for (NSInteger i=0; i < (subviewFrames.count - 1); i++ )
        {
            // this is the saved frame data - it's an NSString
            NSString* frameString = subviewFrames[i];
            NSArray* components = [frameString componentsSeparatedByString:@", "];
            
            // only one component from the string is needed to set the position
            CGFloat position;
            
            if (splitView.vertical)
                position = [components[2] floatValue];
            else
                position = [components[3] floatValue];
            
            [splitView setPosition:position ofDividerAtIndex:i];
        }
    }
}


// ----------------------------------------------------------------------------
- (void) playTuneAtPath:(NSString*)path
// ----------------------------------------------------------------------------
{
	[self playTuneAtPath:path subtune:0];
}


// ----------------------------------------------------------------------------
- (void) playTuneAtPath:(NSString*)path subtune:(int)subtuneIndex
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL openSel = NSSelectorFromString(@"openFileWithPath:");
		if ([modernController respondsToSelector:openSel]) {
			((void (*)(id, SEL, NSString*))objc_msgSend)(modernController, openSel, path);
			return;
		}
	}

	if (player == NULL)
		return;

	if (audioDriver != NULL)
		gPreferences.mPlaybackSettings.mFrequency = audioDriver->getSampleRate();
	
	bool success = player->playTuneByPath([path cStringUsingEncoding:NSUTF8StringEncoding], subtuneIndex, &gPreferences.mPlaybackSettings);
	if (success)
	{
		if (fadeOutInProgress)
			[self stopFadeOut];

		currentTunePath = path;
		
		[self updateTuneInfo];
		[self setPlayPauseButtonToPause:YES];
	}
}


// ----------------------------------------------------------------------------
- (void) playTuneAtURL:(NSString*)urlString
// ----------------------------------------------------------------------------
{
	[self playTuneAtURL:urlString subtune:0];
}


// ----------------------------------------------------------------------------
- (void) playTuneAtURL:(NSString*)urlString subtune:(int)subtuneIndex
// ----------------------------------------------------------------------------
{
	static const NSUInteger kMaxDownloadTuneSize = 10 * 1024 * 1024; // 10 MB maximum
	NSURL* url = [NSURL URLWithString:urlString];
	if (!url || (![[url scheme] isEqualToString:@"http"] && ![[url scheme] isEqualToString:@"https"]))
	{
		NSAlert* alert = [NSAlert alertWithMessageText:@"Invalid URL"
										 defaultButton:@"OK"
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:@"Only HTTP and HTTPS URLs are supported."];
		[alert runModal];
		return;
	}

	while (urlDownloadConnection != nil)
		[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1f]];

	urlDownloadSubtuneIndex = subtuneIndex;
	
	NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:60.0];
	[request setValue:SPUrlRequestUserAgentString forHTTPHeaderField:@"User-Agent"];
	urlDownloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (urlDownloadConnection != nil)
		urlDownloadData = [NSMutableData data];
}

// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response
// ----------------------------------------------------------------------------
{
	long long expected = [response expectedContentLength];
	if (expected != NSURLResponseUnknownLength && expected > (long long)(10 * 1024 * 1024))
	{
		[connection cancel];
		urlDownloadConnection = nil;
		urlDownloadData = nil;
		NSAlert* alert = [NSAlert alertWithMessageText:@"File Too Large"
										 defaultButton:@"OK"
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:@"The file exceeds the 10 MB limit for SID tunes."];
		[alert runModal];
		return;
	}
	[urlDownloadData setLength:0];
}


// ----------------------------------------------------------------------------
- (void) connection:(NSURLConnection*)connection didReceiveData:(NSData*)data
// ----------------------------------------------------------------------------
{
	if ([urlDownloadData length] + [data length] > (10 * 1024 * 1024))
	{
		[connection cancel];
		urlDownloadConnection = nil;
		urlDownloadData = nil;
		NSAlert* alert = [NSAlert alertWithMessageText:@"Download Limit Exceeded"
										 defaultButton:@"OK"
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:@"The download was terminated because it exceeded the 10 MB limit."];
		[alert runModal];
		return;
	}
	[urlDownloadData appendData:data];
}


// ----------------------------------------------------------------------------
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
// ----------------------------------------------------------------------------
{
	bool success = player->playTuneFromBuffer((char*) [urlDownloadData bytes], [urlDownloadData length], urlDownloadSubtuneIndex, &gPreferences.mPlaybackSettings);
	if (success)
	{
		currentTunePath = nil;
		[self setFadeVolume:1.0f];
		[self setPlayPauseButtonToPause:YES];
		[self updateTuneInfo];
	}
	else
	{
		NSAlert* alert = [NSAlert alertWithMessageText:@"Invalid URL"
										 defaultButton:@"OK"
									   alternateButton:nil
										   otherButton:nil
							 informativeTextWithFormat:@"The URL did not contain a valid SID file."];
		
		[alert runModal];
	}
	
	urlDownloadData = nil;
	urlDownloadConnection = nil;
}


// ----------------------------------------------------------------------------
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
// ----------------------------------------------------------------------------
{
	NSAlert* alert = [NSAlert alertWithMessageText:@"Download failed"
									 defaultButton:@"OK"
								   alternateButton:nil
									   otherButton:nil
						 informativeTextWithFormat:@"The connection to the server failed, please check the URL or try again later."];
	
	[alert runModal];
}


// ----------------------------------------------------------------------------
- (void) setPlayPauseButtonToPause:(BOOL)pause
// ----------------------------------------------------------------------------
{
	if (pause)
	{
		[playPauseButton setImage:[NSImage imageNamed:@"hud_pause"]];
		//[playPauseButton setAlternateImage:[NSImage imageNamed:@"pause_pressed"]];
	}
	else
	{
		[playPauseButton setImage:[NSImage imageNamed:@"hud_play"]];
		//[playPauseButton setAlternateImage:[NSImage imageNamed:@"play_pressed"]];
	}
}


// ----------------------------------------------------------------------------
- (void) switchToSubtune:(NSInteger)subtune
// ----------------------------------------------------------------------------
{
	if (fadeOutInProgress)
		[self stopFadeOut];
	player->startSubtune(subtune);
	[self updateTuneInfo];
}


// ----------------------------------------------------------------------------
- (void) keyDown:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSString* characters = [event charactersIgnoringModifiers];
	unichar character = [characters characterAtIndex:0];

	switch(character)
	{
		case ' ':
			[self clickPlayPauseButton:self];
			break;
		default:
			[super keyDown:event];
	}
}


// ----------------------------------------------------------------------------
- (void) keyUp:(NSEvent*)event
// ----------------------------------------------------------------------------
{
	NSString* characters = [event charactersIgnoringModifiers];
	unichar character = [characters characterAtIndex:0];

	switch(character)
	{
		case ' ':
			break;
		default:
			[super keyUp:event];
	}
}


// ----------------------------------------------------------------------------
- (void) updateTimer
// ----------------------------------------------------------------------------
{
	NSInteger seconds = player != NULL ? (NSInteger)player->getPlaybackSeconds() : 0;
	[statusDisplay setPlaybackSeconds:seconds];
	[browserDataSource updateCurrentSong:seconds];
	
	if (player != NULL && [[NSRunLoop currentRunLoop] currentMode] != NSEventTrackingRunLoopMode)
	{
		int defaultTempo = 50;
		if (player->getTempo() != defaultTempo)
		{
			player->setTempo(defaultTempo);
			[tempoSlider setIntegerValue:defaultTempo];
		}
	}
	
	static int updatesWithNoBufferUnderrun = 0;
	
	if (audioDriver != NULL)
	{
		if (audioDriver->getBufferUnderrunDetected())
		{
			updatesWithNoBufferUnderrun = 0;
			audioDriver->stopPlayback();
			audioDriver->setBufferUnderrunDetected(false);
			[self setPlayPauseButtonToPause:NO];
			
			NSAlert* alert = [NSAlert alertWithMessageText:@"Your Mac is too slow to play at the current emulation accuracy"
											 defaultButton:@"OK"
										   alternateButton:nil
											   otherButton:nil
								 informativeTextWithFormat:@"Please lower the emulation accuracy or turn off filter distortion in the playback preferences"];
			
			[alert runModal];
		}
		else
		{
			updatesWithNoBufferUnderrun++;
			if (updatesWithNoBufferUnderrun >= 100)
			{
				audioDriver->setBufferUnderrunDetected(false);
				updatesWithNoBufferUnderrun = 0;
			}
		}
	}
}


// ----------------------------------------------------------------------------
- (void) updateFastTimer
// ----------------------------------------------------------------------------
{
	if (fadeOutInProgress)
	{
		fadeOutVolume -= 0.006f;
		if (fadeOutVolume < 0.0f)
			fadeOutVolume = 0.0f;
			
		[self setFadeVolume:fadeOutVolume];
	}
	
	BOOL isOptionPressed = [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask ? YES : NO;
	if (isOptionPressed)
	{
		[addPlaylistButton setHidden:YES];
		[addSmartPlaylistButton setHidden:NO];
	}
	else
	{
		[addPlaylistButton setHidden:NO];
		[addSmartPlaylistButton setHidden:YES];
	}

	if (player != NULL)
	{
		SIDPLAY2_NAMESPACE::SidRegisterFrame registerFrame = player->getCurrentSidRegisters();
		unsigned char* registers = registerFrame.mRegisters;
		

		
		if (visualizerView != nil && [visualizerView superview] != nil)
		{
			VisualizerState state;
			
			int voiceRamOffset[3] = {0, 7, 14};
			
			for (int i = 0; i < 3; i++)
			{
				int ramoffset = voiceRamOffset[i];
				
				state.voice[i].Gatebit = registers[ ramoffset + 4 ] & 1;
				state.voice[i].Frequency = registers[ ramoffset ] + ( registers[ ramoffset + 1 ] << 8 );
				state.voice[i].Pulsewidth = ( registers[ ramoffset + 2 ] + ( registers[ ramoffset + 3 ] << 8 ) ) & 0x0FFF;
				state.voice[i].Waveform = registers[ ramoffset + 4 ] & 0xfe;
				state.voice[i].Attack = registers[ ramoffset + 5 ] >> 4;
				state.voice[i].Decay = registers[ ramoffset + 5 ] & 0x0f;
				state.voice[i].Sustain = registers[ ramoffset + 6 ] >> 4;
				state.voice[i].Release = registers[ ramoffset + 6 ] & 0x0f;
			}
			
			state.FilterCutoff = ( registers[ 0x15 ] + ( registers[ 0x16 ] << 8 ) ) >> 5;
			state.FilterResonance = registers[ 0x17 ] >> 4;
			state.FilterVoices = registers[ 0x17 ] & 0x07;
			state.FilterMode = registers[ 0x18 ] >> 4;
			state.Volume = registers[ 0x18 ] & 0x0f;
			
			[visualizerView update:&state];
		}
	}
}


// ----------------------------------------------------------------------------
- (void) updateSlowTimer
// ----------------------------------------------------------------------------
{
	//[sourceListDataSource checkForRemoteUpdateRevisionChange];
}


// ----------------------------------------------------------------------------
- (void) updateTuneInfo
// ----------------------------------------------------------------------------
{
	if (player == NULL)
		return;

	NSString* title = @"No information available";
	NSString* author = @"";
	NSString* releaseInfo = @"";

	if (player->hasTuneInformationStrings())
	{
		title = [NSString stringWithCString:player->getCurrentTitle() encoding:NSISOLatin1StringEncoding];
		author = [NSString stringWithCString:player->getCurrentAuthor() encoding:NSISOLatin1StringEncoding];
		releaseInfo = [NSString stringWithCString:player->getCurrentReleaseInfo() encoding:NSISOLatin1StringEncoding];
	}
	
	int currentSubtune = player->getCurrentSubtune();
	int subtuneCount = player->getSubtuneCount();

	int tuneLength = 0;
	char* tuneBuffer = player->getTuneBuffer(tuneLength);
	currentTuneLengthInSeconds = tuneBuffer == NULL ? 0 : [[SongLengthDatabase sharedInstance] getSongLengthFromBuffer:tuneBuffer withBufferLength:tuneLength andSubtune:currentSubtune];

	[statusDisplay setTitle:title andAuthor:author andReleaseInfo:releaseInfo andSubtune:currentSubtune ofSubtunes:subtuneCount withSonglength:currentTuneLengthInSeconds];
	
	[[SPPreferencesController sharedInstance] initializeFilterSettingsFromChipModelOfPlayer:player];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:SPTuneChangedNotification object:self];
	
	// update dock tile menu
	NSMenuItem* titleItem = [dockTileMenu itemWithTag:2];
	NSMenuItem* authorItem = [dockTileMenu itemWithTag:3];
	[titleItem setTitle:[NSString stringWithFormat:@"   %@ (%d/%d)", title, currentSubtune, subtuneCount]];
	[authorItem setTitle:[NSString stringWithFormat:@"   %@", author]];
	
	NSArray* menuItems = [[subtuneSelectionMenu itemArray] copy];
	for (NSMenuItem* menuItem in menuItems)
		[subtuneSelectionMenu removeItem:menuItem];
	
	for (int i = 1; i < (subtuneCount + 1); i++)
	{
		NSString* subtuneString = [NSString stringWithFormat:@"%d", i];
		NSString* keyEquivalent = nil;
		if (i < 10)
			keyEquivalent = subtuneString;
		else if (i == 10)
			keyEquivalent = @"0";
		else
			keyEquivalent = @"";
		
		NSMenuItem* item = [subtuneSelectionMenu addItemWithTitle:subtuneString action:@selector(selectSubtune:) keyEquivalent:keyEquivalent];
		[item setTarget:self];
		[item setTag:i];
	}
	
}


// ----------------------------------------------------------------------------
- (AudioDriver*) audioDriver
// ----------------------------------------------------------------------------
{
	return audioDriver;
}


// ----------------------------------------------------------------------------
- (PlayerLibSidplay*) player;
// ----------------------------------------------------------------------------
{
	return player;
}


// ----------------------------------------------------------------------------
- (SPBrowserDataSource*) browserDataSource
// ----------------------------------------------------------------------------
{
	return browserDataSource;
}


// ----------------------------------------------------------------------------
- (SPExportController*) exportController
// ----------------------------------------------------------------------------
{
	return exportController;
}


// ----------------------------------------------------------------------------
- (NSInteger) currentTuneLengthInSeconds
// ----------------------------------------------------------------------------
{
	return currentTuneLengthInSeconds;
}


// ----------------------------------------------------------------------------
- (void) addTopSubView:(NSView*)subView withHeight:(float)height
// ----------------------------------------------------------------------------
{
	NSRect browserFrame = [browserScrollView frame];
	browserFrame.size.height = [rightView frame].size.height - [boxView frame].size.height;
	NSRect subViewFrame;
	NSRect newBrowserFrame;
	NSDivideRect(browserFrame, &subViewFrame, &newBrowserFrame, height, NSMaxYEdge);

	[subView setFrame:subViewFrame];
	[browserScrollView setFrame:newBrowserFrame];
	if ([subView window] != self)
		[rightView addSubview:subView];
	[subView setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void) removeTopSubView
// ----------------------------------------------------------------------------
{
	NSRect browserFrame = [browserScrollView frame];
	browserFrame.size.height = [rightView frame].size.height - [boxView frame].size.height;
	[browserScrollView setFrame:browserFrame];
}


// ----------------------------------------------------------------------------
- (void) addRightSubView:(NSView*)subView withWidth:(float)width
// ----------------------------------------------------------------------------
{
	NSRect splitViewFrame = [splitView frame];
	NSRect subViewFrame;
	NSRect newSplitViewFrame;
	NSDivideRect(splitViewFrame, &subViewFrame, &newSplitViewFrame, width, NSMaxXEdge);

	[subView setFrame:subViewFrame];
	[splitView setFrame:newSplitViewFrame];
	if ([subView window] != self)
		[[self contentView] addSubview:subView];
	[subView setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (void) removeRightSubView
// ----------------------------------------------------------------------------
{
	[splitView setFrame:[[self contentView] frame]];
}


// ----------------------------------------------------------------------------
- (void) addAlternateBoxView:(NSView*)subView
// ----------------------------------------------------------------------------
{
	NSRect boxFrame = [boxView frame];

	[subView setFrame:boxFrame];
	[rightView addSubview:subView];
	[subView setNeedsDisplay:YES];
}


// ----------------------------------------------------------------------------
- (float) fadeVolume
// ----------------------------------------------------------------------------
{
	return fadeOutVolume;
}


// ----------------------------------------------------------------------------
- (void) setFadeVolume:(float)volume
// ----------------------------------------------------------------------------
{
	if (volumeIsMuted)
		return;
		
	float fadeVolume = gPreferences.mPlaybackVolume * volume;
	audioDriver->setVolume(fadeVolume);
}


// ----------------------------------------------------------------------------
- (void) startFadeOut
// ----------------------------------------------------------------------------
{
	if (!fadeOutInProgress)
	{
		fadeOutVolume = 1.0f;
		fadeOutInProgress = YES;
	}
}


// ----------------------------------------------------------------------------
- (void) stopFadeOut
// ----------------------------------------------------------------------------
{
	if (fadeOutInProgress)
		fadeOutInProgress = NO;
		
	fadeOutVolume = 1.0f;
	[self setFadeVolume:fadeOutVolume];
}


// ----------------------------------------------------------------------------
- (NSMenuItem*) exportTaskWindowMenuItem;
// ----------------------------------------------------------------------------
{
	return exportTaskWindowMenuItem;
}


// ----------------------------------------------------------------------------
- (SPStatusDisplayView*) statusDisplay
// ----------------------------------------------------------------------------
{
	return statusDisplay;
}


// ----------------------------------------------------------------------------
- (void) setStatusDisplay:(SPStatusDisplayView*)view
// ----------------------------------------------------------------------------
{
	statusDisplay = view;
	[self updateTuneInfo];
}


#pragma mark -
#pragma mark UI action methods


// ----------------------------------------------------------------------------
- (IBAction) clickPlayPauseButton:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL toggleSel = NSSelectorFromString(@"togglePlayPause");
		if ([modernController respondsToSelector:toggleSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, toggleSel);
			return;
		}
	}

	if (!player->isTuneLoaded())
	{
		BOOL foundPlayableItem = [browserDataSource playSelectedItem];
		if (foundPlayableItem)
			[self setPlayPauseButtonToPause:YES];
		return;
	}

	if (audioDriver && audioDriver->getIsPlaying())
	{
		audioDriver->stopPlayback();
		[self setPlayPauseButtonToPause:NO];
	}
	else if (audioDriver)
	{
		audioDriver->startPlayback();
		[self setPlayPauseButtonToPause:YES];
	}
	
	[[SPPreferencesController sharedInstance] save];
}


// ----------------------------------------------------------------------------
- (IBAction) clickStopButton:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL stopSel = NSSelectorFromString(@"stopPlayback");
		if ([modernController respondsToSelector:stopSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, stopSel);
			return;
		}
	}

	if (audioDriver == NULL)
		return;
		
	audioDriver->stopPlayback();
	[self setPlayPauseButtonToPause:NO];

	player->initCurrentSubtune();

	[[SPPreferencesController sharedInstance] save];
}


// ----------------------------------------------------------------------------
- (IBAction) clickFastForwardButton:(id)sender
// ----------------------------------------------------------------------------
{
	BOOL isOptionPressed = [[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask ? YES : NO;
	int tempo = isOptionPressed ? 88 : 75;
	player->setTempo(tempo);
	[tempoSlider setIntegerValue:tempo];
}


// ----------------------------------------------------------------------------
- (IBAction) moveTempoSlider:(id)sender
// ----------------------------------------------------------------------------
{
	player->setTempo([sender integerValue]);
}


// ----------------------------------------------------------------------------
- (IBAction) moveVolumeSlider:(id)sender
// ----------------------------------------------------------------------------
{
	gPreferences.mPlaybackVolume = [sender floatValue] / 100.0f;
	if (audioDriver) audioDriver->setVolume(gPreferences.mPlaybackVolume);
	[SIDEngineBridge sharedBridge].volume = gPreferences.mPlaybackVolume;
	volumeIsMuted = NO;
}


// ----------------------------------------------------------------------------
- (IBAction) increaseVolume:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL volSel = NSSelectorFromString(@"increaseVolume");
		if ([modernController respondsToSelector:volSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, volSel);
			return;
		}
	}

	gPreferences.mPlaybackVolume += 0.05f;
	if (gPreferences.mPlaybackVolume > 1.0f)
		gPreferences.mPlaybackVolume = 1.0f;
	if (audioDriver) audioDriver->setVolume(gPreferences.mPlaybackVolume);
	[SIDEngineBridge sharedBridge].volume = gPreferences.mPlaybackVolume;
	[volumeSlider setFloatValue:gPreferences.mPlaybackVolume * 100.0f];
	volumeIsMuted = NO;
}


// ----------------------------------------------------------------------------
- (IBAction) decreaseVolume:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL volSel = NSSelectorFromString(@"decreaseVolume");
		if ([modernController respondsToSelector:volSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, volSel);
			return;
		}
	}

	gPreferences.mPlaybackVolume -= 0.05f;
	if (gPreferences.mPlaybackVolume < 0.0f)
		gPreferences.mPlaybackVolume = 0.0f;
	if (audioDriver) audioDriver->setVolume(gPreferences.mPlaybackVolume);
	[SIDEngineBridge sharedBridge].volume = gPreferences.mPlaybackVolume;
	[volumeSlider setFloatValue:gPreferences.mPlaybackVolume * 100.0f];
}


// ----------------------------------------------------------------------------
- (IBAction) muteVolume:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL muteSel = NSSelectorFromString(@"toggleMute");
		if ([modernController respondsToSelector:muteSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, muteSel);
			return;
		}
	}

	if (volumeIsMuted)
	{
		volumeIsMuted = NO;
		if (audioDriver) audioDriver->setVolume(gPreferences.mPlaybackVolume);
		[SIDEngineBridge sharedBridge].volume = gPreferences.mPlaybackVolume;
		[volumeSlider setFloatValue:gPreferences.mPlaybackVolume * 100.0f];
	}
	else
	{
		volumeIsMuted = YES;
		if (audioDriver) audioDriver->setVolume(0.0f);
		[SIDEngineBridge sharedBridge].volume = 0.0f;
		[volumeSlider setFloatValue:0.0f];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) nextSubtune:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL nextSubSel = NSSelectorFromString(@"nextSubtune");
		if ([modernController respondsToSelector:nextSubSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, nextSubSel);
			return;
		}
	}

	if (fadeOutInProgress)
		[self stopFadeOut];
	player->startNextSubtune();
	[self updateTuneInfo];
}

// ----------------------------------------------------------------------------
- (IBAction) previousSubtune:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL prevSubSel = NSSelectorFromString(@"previousSubtune");
		if ([modernController respondsToSelector:prevSubSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, prevSubSel);
			return;
		}
	}

	if (fadeOutInProgress)
		[self stopFadeOut];
	player->startPrevSubtune();
	[self updateTuneInfo];
}


// ----------------------------------------------------------------------------
- (IBAction) selectSubtune:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL selSubSel = NSSelectorFromString(@"selectSubtuneWithTag:");
		if ([modernController respondsToSelector:selSubSel]) {
			((void (*)(id, SEL, NSInteger))objc_msgSend)(modernController, selSubSel, [sender tag]);
			return;
		}
	}

	[self switchToSubtune:[sender tag]];
}




// ----------------------------------------------------------------------------
- (IBAction) openFile:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		NSOpenPanel* openPanel = [NSOpenPanel openPanel];
		openPanel.allowedFileTypes = [NSArray arrayWithObjects:@"sid", @"prg", @"mid", @"mus", @"str", nil];
		openPanel.allowsMultipleSelection = YES;
		openPanel.canChooseDirectories = YES;
		openPanel.canChooseFiles = YES;

		NSWindow* targetWin = nil;
		SEL winSel = NSSelectorFromString(@"currentMainWindow");
		if ([modernController respondsToSelector:winSel]) {
			targetWin = ((NSWindow* (*)(id, SEL))objc_msgSend)(modernController, winSel);
		}

		void (^handler)(NSModalResponse) = ^(NSModalResponse result) {
			if (result == NSModalResponseOK) {
				SEL openSel = NSSelectorFromString(@"openFileWithPath:");
				if ([modernController respondsToSelector:openSel]) {
					for (NSURL* url in openPanel.URLs) {
						((void (*)(id, SEL, NSString*))objc_msgSend)(modernController, openSel, [url path]);
					}
				}
			}
		};

		if (targetWin != nil && [targetWin isVisible]) {
			[openPanel beginSheetModalForWindow:targetWin completionHandler:handler];
		} else {
			[openPanel beginWithCompletionHandler:handler];
		}
		return;
	}

	if (![self isVisible])
		return;

	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = [NSArray arrayWithObject:@"sid"];
	
    [openPanel beginSheetModalForWindow:self completionHandler:^(NSInteger result)
     {
         if (result == NSFileHandlingPanelOKButton)
         {
             NSArray* urlsToOpen = openPanel.URLs;
             NSString* file = [[urlsToOpen objectAtIndex:0] path];
             
             [self playTuneAtPath:file];
         }
     }
     ];
    
}


// ----------------------------------------------------------------------------
- (IBAction) openUrl:(id)sender
// ----------------------------------------------------------------------------
{
	if (![self isVisible])
		return;
		
	[NSApp beginSheet:openUrlSheetPanel modalForWindow:self modalDelegate:self didEndSelector:@selector(didEndOpenUrlSheet:returnCode:contextInfo:) contextInfo:nil];
}


// ----------------------------------------------------------------------------
- (void) didEndOpenUrlSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
// ----------------------------------------------------------------------------
{
    [sheet orderOut:self];
}


// ----------------------------------------------------------------------------
- (IBAction) dismissOpenUrlSheet:(id)sender
// ----------------------------------------------------------------------------
{
	if ([[sender title] isEqualToString:@"OK"])
	{
		NSString* urlString = [openUrlTextField stringValue];

		[self playTuneAtURL:urlString];
	}

	[NSApp endSheet:openUrlSheetPanel];
}


// ----------------------------------------------------------------------------
- (IBAction) openSidplayHomepage:(id)sender
// ----------------------------------------------------------------------------
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/Grrrolf/sidplay-mac"]];
}


// ----------------------------------------------------------------------------
- (IBAction) openHvscHomepage:(id)sender
// ----------------------------------------------------------------------------
{
	[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://www.hvsc.c64.org/"]];
}


// ----------------------------------------------------------------------------
- (IBAction) moveFocusToSearchField:(id)sender
// ----------------------------------------------------------------------------
{
	[self makeFirstResponder:[browserDataSource toolbarSearchField]];
}


// ----------------------------------------------------------------------------
- (IBAction) showAboutWindow:(id)sender
// ----------------------------------------------------------------------------
{
	Class aboutClass = NSClassFromString(@"SIDAboutWindowController");
	if (aboutClass)
	{
		id shared = [aboutClass performSelector:NSSelectorFromString(@"shared")];
		if (shared && [shared respondsToSelector:NSSelectorFromString(@"showWindow")])
		{
			[shared performSelector:NSSelectorFromString(@"showWindow")];
			return;
		}
	}
	[NSApp orderFrontStandardAboutPanel:sender];
}


// ----------------------------------------------------------------------------
- (IBAction) showPreferencesWindow:(id)sender
// ----------------------------------------------------------------------------
{
	Class prefClass = NSClassFromString(@"SIDPreferencesWindowController");
	if (prefClass)
	{
		id shared = [prefClass performSelector:NSSelectorFromString(@"shared")];
		if (shared && [shared respondsToSelector:NSSelectorFromString(@"showWindow")])
		{
			[shared performSelector:NSSelectorFromString(@"showWindow")];
			return;
		}
	}

	NSWindow* syncProgressDialog = [sourceListDataSource syncProgressDialog];
	if (syncProgressDialog != nil && [syncProgressDialog isVisible])
		return;

	if (prefsWindowController == nil)
	{
		prefsWindowController = [[SPPreferencesWindowController alloc] init];
		[prefsWindowController setOwnerWindow:self];
		[prefsWindowController setSourceListDataSource:sourceListDataSource];
	}
	
	[prefsWindowController showWindow:sender];
}


// ----------------------------------------------------------------------------
- (IBAction) playRandomTuneFromCollection:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL randSel = NSSelectorFromString(@"playRandomTune");
		if ([modernController respondsToSelector:randSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, randSel);
			return;
		}
	}

	NSString* path = [[SPCollectionUtilities sharedInstance] pathOfRandomCollectionItemInPath:nil];
	if (path != nil)
	{
		//NSLog(@"random tune: %@\n", path);
		[self playTuneAtPath:path];
		[browserDataSource browseToFile:path andSetAsCurrentItem:YES];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) toggleVisualizerView:(id)sender
// ----------------------------------------------------------------------------
{
	if (visualizerView == nil)
		return;
		
	if ([visualizerView superview] != nil)
	{
		//NSView* contentView = [self contentView];
		//[contentView addSubview:splitView];
		[visualizerView removeFromSuperview];
	}
	else
	{
		NSRect frame = [splitView frame];
		[visualizerView setFrame:frame];
		NSView* contentView = [self contentView];
		[contentView addSubview:visualizerView];
		//[splitView removeFromSuperview];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) selectVisualizer:(id)sender
// ----------------------------------------------------------------------------
{
	if (visualizerView == nil)
		return;
		
	NSInteger index = [sender tag];
	NSArray* menuItems = [[sender menu] itemArray];
	for (NSMenuItem* menuItem in menuItems)
		[menuItem setState:NSOffState];
		
	[sender setState:NSOnState];

	NSString* visualizerPath = [visualizerCompositionPaths objectAtIndex:index];
	[visualizerView loadCompositionFromFile:visualizerPath];
}


// ----------------------------------------------------------------------------
- (void) populateVisualizerMenu
// ----------------------------------------------------------------------------
{
	NSString* defaultVisualizerPath = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] resourcePath],@"/DefaultVisualizer.qtz"];
	visualizerCompositionPaths = [NSMutableArray arrayWithCapacity:3];
	[visualizerCompositionPaths addObject:defaultVisualizerPath];

	NSInteger index = 1;
	NSArray* visualizerFiles = [[NSFileManager defaultManager] directoryContentsAtPath:[SPApplicationStorageController visualizerPath]];
	for (NSString* visualizerFile in visualizerFiles)
	{
		if ([visualizerFile characterAtIndex:0] == '.')
			continue;

		if (![[visualizerFile pathExtension] isEqualToString:@"qtz"])
			continue;

		NSString* visualizerCompositionPath = [[SPApplicationStorageController visualizerPath] stringByAppendingPathComponent:visualizerFile];
		[visualizerCompositionPaths addObject:visualizerCompositionPath];
		
		NSString* name = [visualizerFile stringByDeletingPathExtension];
		NSMenuItem* menuItem = [[NSMenuItem alloc] initWithTitle:name action:@selector(selectVisualizer:) keyEquivalent:@""];
		[menuItem setTarget:self];
		[menuItem setTag:index];
		[visualizerMenu addItem:menuItem];
		
		index++;
	}
}

#pragma mark -
#pragma mark application delegate methods


// ----------------------------------------------------------------------------
- (BOOL) application:(NSApplication*)theApplication openFile:(NSString*)filename
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL openSel = NSSelectorFromString(@"openFileWithPath:");
		if ([modernController respondsToSelector:openSel]) {
			((void (*)(id, SEL, NSString*))objc_msgSend)(modernController, openSel, filename);
			return YES;
		}
	}

	[self playTuneAtPath:filename];
	return YES;
}


// ----------------------------------------------------------------------------
- (void) applicationDidFinishLaunching:(NSNotification*)notification
// ----------------------------------------------------------------------------
{
	// Present the modern SwiftUI interface
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL showSel = NSSelectorFromString(@"showMainWindow");
		if ([modernController respondsToSelector:showSel]) {
			if (audioDriver != NULL) {
				if (player != NULL) {
					player->setAudioDriver(NULL);
					delete player;
					player = NULL;
				}
				delete audioDriver;
				audioDriver = NULL;
			}
			[self orderOut:self];
			((void (*)(id, SEL))objc_msgSend)(modernController, showSel);
			return;
		}
	}

	NSTimer* slowTimer = [NSTimer scheduledTimerWithTimeInterval:10.0f target:self selector:@selector(updateSlowTimer) userInfo:nil repeats:YES];
	NSTimer* normalTimer = [NSTimer scheduledTimerWithTimeInterval:0.05f target:self selector:@selector(updateTimer) userInfo:nil repeats:YES];
	NSTimer* fastTimer = [NSTimer scheduledTimerWithTimeInterval:1.0f/60.0f target:self selector:@selector(updateFastTimer) userInfo:nil repeats:YES];

	[[NSRunLoop currentRunLoop] addTimer:slowTimer forMode:NSEventTrackingRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:normalTimer forMode:NSEventTrackingRunLoopMode];
	[[NSRunLoop currentRunLoop] addTimer:fastTimer forMode:NSEventTrackingRunLoopMode];

	NSWindow* syncProgressDialog = [sourceListDataSource syncProgressDialog];
	if (syncProgressDialog != nil && ![syncProgressDialog isVisible])
		[self makeKeyAndOrderFront:self];
}


// ----------------------------------------------------------------------------
- (void) applicationDidResignActive:(NSNotification*)notification
// ----------------------------------------------------------------------------
{

}


// ----------------------------------------------------------------------------
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)application
// ----------------------------------------------------------------------------
{
	return NO;
}


// ----------------------------------------------------------------------------
- (BOOL) applicationShouldHandleReopen:(NSApplication*)sender hasVisibleWindows:(BOOL)flag
// ----------------------------------------------------------------------------
{
	if (!flag) {
		Class modernController = NSClassFromString(@"SPSwiftModernAppController");
		if (modernController) {
			SEL showSel = NSSelectorFromString(@"showMainWindow");
			if ([modernController respondsToSelector:showSel]) {
				((void (*)(id, SEL))objc_msgSend)(modernController, showSel);
				return YES;
			}
		}
	}
	return YES;
}


// ----------------------------------------------------------------------------
- (NSApplicationTerminateReply) applicationShouldTerminate:(NSApplication*)sender
// ----------------------------------------------------------------------------
{
	if ([exportController activeExportTasksCount] > 0)
	{
		NSAlert* alert = [NSAlert alertWithMessageText:@"You have active export tasks, do you really want to quit SIDPLAY?"
										 defaultButton:@"Don't Quit"
									   alternateButton:@"Quit"
										   otherButton:nil
							 informativeTextWithFormat:@"If you decide to quit, the files that are currently being exported will be incomplete or damaged."];

		NSInteger result = [alert runModal];
		
		if (result == NSAlertDefaultReturn)
			return NSTerminateCancel;
	}

    [statusDisplay prepareForQuit];
    
	return NSTerminateNow;
}


// ----------------------------------------------------------------------------
- (void) applicationWillTerminate:(NSNotification*)aNotification
// ----------------------------------------------------------------------------
{
	//NSLog(@"Shutting down");
	[[SPPreferencesController sharedInstance] save];
}


// ----------------------------------------------------------------------------
- (NSMenu*) applicationDockMenu:(NSApplication*)sender
// ----------------------------------------------------------------------------
{
	return dockTileMenu;
}


#pragma mark -
#pragma mark split view delegate methods

// ----------------------------------------------------------------------------
- (NSRect )splitView:(NSSplitView *)theSplitView additionalEffectiveRectOfDividerAtIndex:(NSInteger)dividerIndex
// ----------------------------------------------------------------------------
{
	if (dividerIndex == 0)
	{
		NSRect leftViewFrame = [leftView frame];
		const int bottom_bar_height = 23;
		NSRect gripRect = NSMakeRect(NSWidth(leftViewFrame) - 17, NSHeight(leftViewFrame) - bottom_bar_height, 17, bottom_bar_height);
		
		return gripRect;
	}
	
	return NSZeroRect;
}


// ----------------------------------------------------------------------------
- (BOOL) splitView:(NSSplitView*)splitView canCollapseSubview:(NSView*) subview
// ----------------------------------------------------------------------------
{
    return NO;
}


// ----------------------------------------------------------------------------
- (CGFloat) splitView:(NSSplitView*)sender constrainSplitPosition:(CGFloat) proposedPosition ofSubviewAt:(NSInteger) offset
// ----------------------------------------------------------------------------
{
	if (offset == 0)
	{
		float position = fminf(proposedPosition, 400.0f);
		position = fmaxf(position, 100.0f);

		return position;
	}
	
    /*
	if (offset == 1)
	{
		float idealPosition = [sender frame].size.width - 400.0f;
		return idealPosition;
		//return fminf(idealPosition, proposedPosition);
	}

	if (offset == 2)
	{
		return 400.0f;
		//return fminf(idealPosition, proposedPosition);
	}
	*/
    
	return proposedPosition;
}


// ----------------------------------------------------------------------------
- (NSRect) splitView:(NSSplitView *)sender effectiveRect:(NSRect)proposedEffectiveRect forDrawnRect:(NSRect)drawnRect ofDividerAtIndex:(NSInteger)dividerIndex
// ----------------------------------------------------------------------------
{
	return NSInsetRect(proposedEffectiveRect, -2.0f, 0.0f);
}



// ----------------------------------------------------------------------------
- (BOOL) splitView:(NSSplitView *)splitView shouldAdjustSizeOfSubview:(NSView *)subview
// ----------------------------------------------------------------------------
{
    return NO;
}


// ----------------------------------------------------------------------------
- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
// ----------------------------------------------------------------------------
{
	return nil;
}

// ----------------------------------------------------------------------------
- (BOOL) validateMenuItem:(NSMenuItem*)item
// ----------------------------------------------------------------------------
{
	SEL action = [item action];
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");

	if (action == @selector(clickPlayPauseButton:))
	{
		if (modernController) {
			SEL isPlayingSel = NSSelectorFromString(@"isPlaying");
			if ([modernController respondsToSelector:isPlayingSel]) {
				BOOL isPlaying = ((BOOL (*)(id, SEL))objc_msgSend)(modernController, isPlayingSel);
				[item setTitle:isPlaying ? @"Pause" : @"Play"];
			}
		}
		return YES;
	}
	if (action == @selector(clickStopButton:))
	{
		return YES;
	}
	if (action == @selector(playRandomTuneFromCollection:))
	{
		return YES;
	}
	if (action == @selector(nextSubtune:) || action == @selector(previousSubtune:))
	{
		return YES;
	}
	if (action == @selector(selectSubtune:))
	{
		if (modernController) {
			SEL countSel = NSSelectorFromString(@"subtuneCount");
			SEL currentSel = NSSelectorFromString(@"currentSubtune");
			if ([modernController respondsToSelector:countSel]) {
				NSInteger count = ((NSInteger (*)(id, SEL))objc_msgSend)(modernController, countSel);
				if ([item tag] > count)
					return NO;
				
				if ([modernController respondsToSelector:currentSel]) {
					NSInteger cur = ((NSInteger (*)(id, SEL))objc_msgSend)(modernController, currentSel);
					[item setState:([item tag] == cur) ? NSControlStateValueOn : NSControlStateValueOff];
				}
				return YES;
			}
		}
		return YES;
	}
	if (action == @selector(navigateBackFromMenu:))
	{
		if (modernController) {
			SEL canBackSel = NSSelectorFromString(@"canNavigateBack");
			if ([modernController respondsToSelector:canBackSel]) {
				return ((BOOL (*)(id, SEL))objc_msgSend)(modernController, canBackSel);
			}
		}
		return YES;
	}
	if (action == @selector(navigateForwardFromMenu:))
	{
		if (modernController) {
			SEL canFwdSel = NSSelectorFromString(@"canNavigateForward");
			if ([modernController respondsToSelector:canFwdSel]) {
				return ((BOOL (*)(id, SEL))objc_msgSend)(modernController, canFwdSel);
			}
		}
		return YES;
	}
	if (action == @selector(showCurrentItem:) || action == @selector(revealSelectedItemInFinder:) || action == @selector(revealSelectedItemInBrowser:) || action == @selector(switchToFavoritesPlaylist:) || action == @selector(syncCurrentCollection:))
	{
		return YES;
	}
	if (action == @selector(increaseVolume:) || action == @selector(decreaseVolume:) || action == @selector(muteVolume:))
	{
		return YES;
	}

	return YES;
}

// ----------------------------------------------------------------------------
- (IBAction) navigateBackFromMenu:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL backSel = NSSelectorFromString(@"navigateBack");
		if ([modernController respondsToSelector:backSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, backSel);
		}
	}
}

// ----------------------------------------------------------------------------
- (IBAction) navigateForwardFromMenu:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL fwdSel = NSSelectorFromString(@"navigateForward");
		if ([modernController respondsToSelector:fwdSel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, fwdSel);
		}
	}
}

// ----------------------------------------------------------------------------
- (IBAction) showCurrentItem:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL sel = NSSelectorFromString(@"showCurrentSong");
		if ([modernController respondsToSelector:sel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, sel);
		}
	}
}

// ----------------------------------------------------------------------------
- (IBAction) revealSelectedItemInFinder:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL sel = NSSelectorFromString(@"revealSelectedItemInFinder");
		if ([modernController respondsToSelector:sel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, sel);
		}
	}
}

// ----------------------------------------------------------------------------
- (IBAction) revealSelectedItemInBrowser:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL sel = NSSelectorFromString(@"revealSelectedItemInBrowser");
		if ([modernController respondsToSelector:sel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, sel);
		}
	}
}

// ----------------------------------------------------------------------------
- (IBAction) switchToFavoritesPlaylist:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL sel = NSSelectorFromString(@"switchToFavorites");
		if ([modernController respondsToSelector:sel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, sel);
		}
	}
}

// ----------------------------------------------------------------------------
- (IBAction) syncCurrentCollection:(id)sender
// ----------------------------------------------------------------------------
{
	Class modernController = NSClassFromString(@"SPSwiftModernAppController");
	if (modernController) {
		SEL sel = NSSelectorFromString(@"syncCurrentCollection");
		if ([modernController respondsToSelector:sel]) {
			((void (*)(id, SEL))objc_msgSend)(modernController, sel);
		}
	}
}

@end


@implementation SPWindowDelegate


// ----------------------------------------------------------------------------
- (BOOL) windowShouldZoom:(NSWindow*)window toFrame:(NSRect)proposedFrame
// ----------------------------------------------------------------------------
{
	return YES;
}


// ----------------------------------------------------------------------------
- (NSSize) windowWillResize:(NSWindow*)window toSize:(NSSize)proposedFrameSize
// ----------------------------------------------------------------------------
{
	return proposedFrameSize;
}


@end

