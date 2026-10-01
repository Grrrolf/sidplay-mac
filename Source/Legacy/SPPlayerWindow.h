#import <Cocoa/Cocoa.h>
#import "PlayerLibSidplay.h"
#import "SPExporter.h"


// Forward declares
class AudioDriver;
@class SPStatusDisplayView;
@class SPPreferencesWindowController;
@class SPBrowserDataSource;
@class SPSourceListDataSource;
@class SPExportController;
@class SPGradientBox;
@class SPVisualizerView;


extern NSString* SPTuneChangedNotification;
extern NSString* SPPlayerInitializedNotification;

extern NSString* SPUrlRequestUserAgentString;


@interface SPPlayerWindow : NSWindow <NSSplitViewDelegate>
{
    IBOutlet id leftView;
    IBOutlet id rightView;
	IBOutlet NSSplitView* splitView;
	IBOutlet id infoView;
	IBOutlet SPBrowserDataSource* browserDataSource;
	IBOutlet NSScrollView* browserScrollView;
	IBOutlet SPSourceListDataSource* sourceListDataSource;
	IBOutlet SPGradientBox* boxView;
	
	IBOutlet NSButton* playPauseButton;
	IBOutlet NSSlider* volumeSlider;
	IBOutlet NSSlider* tempoSlider;
	IBOutlet SPStatusDisplayView* statusDisplay;
	
	IBOutlet NSPanel* openUrlSheetPanel;
	IBOutlet NSTextField* openUrlTextField;
	
	IBOutlet NSButton* addPlaylistButton;
	IBOutlet NSButton* addSmartPlaylistButton;
	
	IBOutlet NSMenu* dockTileMenu;
	
	IBOutlet SPExportController* exportController;
	
	IBOutlet NSMenuItem* exportTaskWindowMenuItem;
	
	PlayerLibSidplay* player;
	AudioDriver* audioDriver;
	NSString* currentTunePath;
	NSInteger currentTuneLengthInSeconds;
	CGFloat currentVolume;
	BOOL volumeIsMuted;
	BOOL fadeOutInProgress;
	float fadeOutVolume;
	
	NSDate* lastBufferUnderrunCheckReset;
	
	NSMutableData* urlDownloadData;
	NSURLConnection* urlDownloadConnection;
	NSInteger urlDownloadSubtuneIndex;
	
	SPPreferencesWindowController* prefsWindowController;
	
	SPVisualizerView* visualizerView;
	NSMutableArray* visualizerCompositionPaths;
	IBOutlet NSMenu* visualizerMenu;
	
	IBOutlet NSMenu* subtuneSelectionMenu;
}

- (void) playTuneAtPath:(NSString*)path;
- (void) playTuneAtPath:(NSString*)path subtune:(int)subtuneIndex;
- (void) playTuneAtURL:(NSString*)urlString;
- (void) playTuneAtURL:(NSString*)urlString subtune:(int)subtuneIndex;

- (void) setPlayPauseButtonToPause:(BOOL)pause;
- (void) switchToSubtune:(NSInteger)subtune;
- (void) updateTimer;
- (void) updateFastTimer;
- (void) updateSlowTimer;
- (void) updateTuneInfo;
- (float) fadeVolume;
- (void) setFadeVolume:(float)volume;
- (void) startFadeOut;
- (void) stopFadeOut;

- (AudioDriver*) audioDriver;
- (PlayerLibSidplay*) player;

- (void) addTopSubView:(NSView*)subView withHeight:(float)height;
- (void) removeTopSubView;

- (void) addRightSubView:(NSView*)subView withWidth:(float)width;
- (void) removeRightSubView;

- (void) addAlternateBoxView:(NSView*)subView;

- (SPBrowserDataSource*) browserDataSource;
- (SPExportController*) exportController;
- (NSInteger) currentTuneLengthInSeconds;

- (NSMenuItem*) exportTaskWindowMenuItem;

- (SPStatusDisplayView*) statusDisplay;
- (void) setStatusDisplay:(SPStatusDisplayView*)view;

- (void) populateVisualizerMenu;

- (IBAction) clickPlayPauseButton:(id)sender;
- (IBAction) clickStopButton:(id)sender;
- (IBAction) clickFastForwardButton:(id)sender;
- (IBAction) moveTempoSlider:(id)sender;
- (IBAction) moveVolumeSlider:(id)sender;
- (IBAction) increaseVolume:(id)sender;
- (IBAction) decreaseVolume:(id)sender;
- (IBAction) muteVolume:(id)sender;
- (IBAction) nextSubtune:(id)sender;
- (IBAction) previousSubtune:(id)sender;
- (IBAction) selectSubtune:(id)sender;

- (IBAction) moveFocusToSearchField:(id)sender;

- (IBAction) openFile:(id)sender;
- (IBAction) openUrl:(id)sender;
- (IBAction) dismissOpenUrlSheet:(id)sender;

- (IBAction) openSidplayHomepage:(id)sender;
- (IBAction) openHvscHomepage:(id)sender;

- (IBAction) showAboutWindow:(id)sender;
- (IBAction) showPreferencesWindow:(id)sender;
- (IBAction) playRandomTuneFromCollection:(id)sender;

- (IBAction) toggleVisualizerView:(id)sender;
- (IBAction) selectVisualizer:(id)sender;

- (IBAction) navigateBackFromMenu:(id)sender;
- (IBAction) navigateForwardFromMenu:(id)sender;
- (IBAction) showCurrentItem:(id)sender;
- (IBAction) revealSelectedItemInFinder:(id)sender;
- (IBAction) revealSelectedItemInBrowser:(id)sender;
- (IBAction) switchToFavoritesPlaylist:(id)sender;
- (IBAction) syncCurrentCollection:(id)sender;

@end


@interface SPWindowDelegate : NSObject
{
	IBOutlet SPPlayerWindow* mainPlayerWindow;
}

- (BOOL) windowShouldZoom:(NSWindow *)window toFrame:(NSRect)proposedFrame;

@end