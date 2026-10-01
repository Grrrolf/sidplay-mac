#import "SPExportController.h"
#import "SPExportOptionsPanel.h"
#import "SPPlayerWindow.h"
#import "SPPreferencesController.h"
#import "SPExportTaskWindow.h"


@implementation SPExportController


static SPExportController* gSharedExportController = nil;

+ (SPExportController*) sharedInstance
{
	return gSharedExportController;
}

- (NSWindow*) targetModalWindow
{
	for (NSWindow* w in [NSApp windows])
	{
		if ([w isVisible] && [[w title] isEqualToString:@"SIDPLAY"])
			return w;
	}

	NSWindow* win = [NSApp keyWindow];
	if (win != nil && [win isVisible] && ![win isKindOfClass:[NSPanel class]] && win != (NSWindow*)exportTaskWindow)
		return win;

	win = [NSApp mainWindow];
	if (win != nil && [win isVisible] && ![win isKindOfClass:[NSPanel class]] && win != (NSWindow*)exportTaskWindow)
		return win;

	for (NSWindow* w in [NSApp windows])
	{
		if ([w isVisible] && ![w isKindOfClass:[NSPanel class]] && w != (NSWindow*)exportTaskWindow)
			return w;
	}

	if (ownerWindow != nil && [ownerWindow isVisible])
		return (NSWindow*)ownerWindow;

	return nil;
}

// ----------------------------------------------------------------------------
- (void) awakeFromNib
// ----------------------------------------------------------------------------
{
	gSharedExportController = self;
	currentExportPanel = nil;
	itemsToExport = nil;
	exportDirectoryPath = nil;
	NSProcessInfo* processInfo = [NSProcessInfo processInfo];
	numberOfConcurrentExportTasks = MIN(8, [processInfo activeProcessorCount]);
	
	exportSettings.Init();
}


// ----------------------------------------------------------------------------
- (void) exportFile:(SPExportItem*)item withType:(ExportFileType)type
// ----------------------------------------------------------------------------
{
	exportSettings.mFileType = type;
	
	itemsToExport = [NSArray arrayWithObject:item];
	SPExporter* exporter = [[SPExporter alloc] initWithItem:item withController:self andWindow:ownerWindow loadNow:YES];
	if (exporter == nil)
		return;
		
	[item setExporter:exporter];
	exportSettings = [exporter exportSettings];
	
	if (type == EXPORT_TYPE_PRG)
		currentExportPanel = exportPrgFilePanel;
	else if ([self isCompressedFileType:type])
		currentExportPanel = exportCompressedFilePanel;
	else
		currentExportPanel = exportFilePanel;
	
	[currentExportPanel setExportController:self];
	
	NSWindow* targetWin = [self targetModalWindow];
	if (targetWin != nil)
		[NSApp beginSheet:(NSWindow*)currentExportPanel modalForWindow:targetWin modalDelegate:self didEndSelector:@selector(didEndExportSheet:returnCode:contextInfo:) contextInfo:NULL];
	else
	{
		[currentExportPanel center];
		[currentExportPanel makeKeyAndOrderFront:self];
	}
}


// ----------------------------------------------------------------------------
- (void) exportFiles:(NSMutableArray*)items withType:(ExportFileType)type
// ----------------------------------------------------------------------------
{
	exportSettings.mFileType = type;

	itemsToExport = [NSArray arrayWithArray:items];
	
	if (type == EXPORT_TYPE_PRG)
		currentExportPanel = exportMultiplePrgFilesPanel;
	else if ([self isCompressedFileType:type])
		currentExportPanel = exportMultipleCompressedFilesPanel;
	else
		currentExportPanel = exportMultipleFilesPanel;

	[currentExportPanel setExportController:self];
	[currentExportPanel updateFileListTextView:items];

	NSWindow* targetWin = [self targetModalWindow];
	if (targetWin != nil)
		[NSApp beginSheet:(NSWindow*)currentExportPanel modalForWindow:targetWin modalDelegate:self didEndSelector:@selector(didEndExportSheet:returnCode:contextInfo:) contextInfo:NULL];
	else
	{
		[currentExportPanel center];
		[currentExportPanel makeKeyAndOrderFront:self];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) cancelExportSheet:(id)sender
// ----------------------------------------------------------------------------
{
	if ([currentExportPanel isSheet])
		[NSApp endSheet:(NSWindow*)currentExportPanel returnCode:NSModalResponseCancel];
	else
		[self didEndExportSheet:(NSWindow*)currentExportPanel returnCode:NSModalResponseCancel contextInfo:NULL];
}


// ----------------------------------------------------------------------------
- (IBAction) confirmExportSheet:(id)sender
// ----------------------------------------------------------------------------
{
	[currentExportPanel timeChanged:nil];
	if ([currentExportPanel isSheet])
		[NSApp endSheet:(NSWindow*)currentExportPanel returnCode:NSModalResponseOK];
	else
		[self didEndExportSheet:(NSWindow*)currentExportPanel returnCode:NSModalResponseOK contextInfo:NULL];
}


// ----------------------------------------------------------------------------
- (void) didEndExportSheet:(NSWindow*)sheet returnCode:(int)returnCode contextInfo:(void*)contextInfo
// ----------------------------------------------------------------------------
{
    [sheet orderOut:self];
	
	exportSettings = [currentExportPanel exportSettings];
	currentExportPanel = nil;

	if (returnCode == NSModalResponseOK)
	{
		if ([itemsToExport count] == 1)
			[self selectDestinationFilename];
		else
			[self selectDestinationDirectory];
	}
}


// ----------------------------------------------------------------------------
- (BOOL) isCompressedFileType:(ExportFileType)type
// ----------------------------------------------------------------------------
{
	switch (type)
	{
		case EXPORT_TYPE_MP3:
		case EXPORT_TYPE_AAC:
			return YES;
			break;
			
		case EXPORT_TYPE_ALAC:
		case EXPORT_TYPE_AIFF:
		default:
			return NO;
			break;
	}
}


// ----------------------------------------------------------------------------
- (int) calculateExpectedFileSizeForSettings:(ExportSettings*)settings
// ----------------------------------------------------------------------------
{
	int fileSize = 0;
	
	switch(settings->mFileType)
	{
		case EXPORT_TYPE_MP3:
			if (settings->mUseVBR)
				fileSize = -1;
			else
				fileSize = settings->mTimeInSeconds * settings->mBitRate * 1000 / 8;
			break;
			
		case EXPORT_TYPE_AAC:
			if (settings->mUseVBR)
				fileSize = -1;
			else
				fileSize = settings->mTimeInSeconds * settings->mBitRate * 1000 / 8;
			break;
			
		case EXPORT_TYPE_ALAC:
			fileSize = -1;
			break;
			
		case EXPORT_TYPE_AIFF:
			fileSize = settings->mTimeInSeconds * gPreferences.mPlaybackSettings.mFrequency * sizeof(short) * 2; 
			break;
			
		default:
			break;
	}
	
	return fileSize;
}


// ----------------------------------------------------------------------------
- (void) selectDestinationFilename
// ----------------------------------------------------------------------------
{
	SPExporter* exporter = [[itemsToExport objectAtIndex:0] exporter];
	NSString* suggestedFilename = [exporter suggestedFilename];
	NSString* suggestedExtension = [exporter suggestedFileExtension]; 

	NSSavePanel* savePanel = [NSSavePanel savePanel];
    [savePanel setNameFieldStringValue:suggestedFilename];
    savePanel.allowedFileTypes = [NSArray arrayWithObject:suggestedExtension];
	[savePanel setCanSelectHiddenExtension:YES];
	
    void (^completionHandler)(NSInteger) = ^(NSInteger result)
    {
        if (result == NSFileHandlingPanelOKButton || result == NSModalResponseOK)
        {
            [exportTaskWindow makeKeyAndOrderFront:self];
            
            SPExporter* exp = [[itemsToExport objectAtIndex:0] exporter];
            [exp setExportSettings:exportSettings];
            [exp setDestinationPath:[savePanel.URL path]];
            [exporterArray addObject:exp];
            [self updateExporterState];
        }
    };

    NSWindow* targetWin = [self targetModalWindow];
    if (targetWin != nil)
        [savePanel beginSheetModalForWindow:targetWin completionHandler:completionHandler];
    else
        [savePanel beginWithCompletionHandler:completionHandler];
}


// ----------------------------------------------------------------------------
- (void) selectDestinationDirectory
// ----------------------------------------------------------------------------
{
	NSOpenPanel* openPanel = [NSOpenPanel openPanel];
	openPanel.allowedFileTypes = [NSArray arrayWithObject:@""];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setTitle:@"Select export destination"];
	[openPanel setPrompt:@"Choose"];

    void (^completionHandler)(NSInteger) = ^(NSInteger result)
    {
        if (result == NSFileHandlingPanelOKButton || result == NSModalResponseOK)
        {
            [exportTaskWindow makeKeyAndOrderFront:self];
            
            NSMutableArray* exportersToAdd = [NSMutableArray arrayWithCapacity:[itemsToExport count]];
            
            for (SPExportItem* item in itemsToExport)
            {
                SPExporter* exp = [[SPExporter alloc] initWithItem:item withController:self andWindow:ownerWindow loadNow:NO];
                if (exp == nil)
                    continue;
                
                [item setExporter:exp];
                [exp setExportSettings:exportSettings];
                
                exportDirectoryPath = [openPanel.URL path];
                
                [exp setFileName:[exp suggestedFilename]];
                [exportersToAdd addObject:exp];
            }
            
            [exporterArray addObjects:exportersToAdd];
            [self updateExporterState];
        }
    };

    NSWindow* targetWin = [self targetModalWindow];
    if (targetWin != nil)
        [openPanel beginSheetModalForWindow:targetWin completionHandler:completionHandler];
    else
        [openPanel beginWithCompletionHandler:completionHandler];
}



// ----------------------------------------------------------------------------
- (void) exportFinished:(SPExporter*)exporter
// ----------------------------------------------------------------------------
{
	[self updateExporterState];
}


// ----------------------------------------------------------------------------
- (void) updateExporterState
// ----------------------------------------------------------------------------
{
	int exportersInProgress = 0;
	
	for (SPExporter* exporter in [exporterArray arrangedObjects])
	{
		if ([exporter exportInProgress])
			exportersInProgress++;
	}

	if (exportersInProgress < numberOfConcurrentExportTasks)
	{
		int exportersToStart = numberOfConcurrentExportTasks - exportersInProgress;
		for (SPExporter* exporter in [exporterArray arrangedObjects])
		{
			if (![exporter exportInProgress] && ![exporter exportStopped])
			{
				if ([exporter loadExportItem])
					[exporter determineExportFilePath:exportDirectoryPath];

				[exporter startExport];
				exportersToStart--;
			}
			
			if (exportersToStart == 0)
				break;
		}
	}

	exportersInProgress = 0;
	
	for (SPExporter* exporter in [exporterArray arrangedObjects])
	{
		if ([exporter exportInProgress])
			exportersInProgress++;
	}
}


// ----------------------------------------------------------------------------
- (void) setOwnerWindow:(SPPlayerWindow*)window
// ----------------------------------------------------------------------------
{
	ownerWindow = window;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(windowWillClose:)
												 name:NSWindowWillCloseNotification
											   object:exportTaskWindow];
}


// ----------------------------------------------------------------------------
- (ExportSettings) exportSettings
// ----------------------------------------------------------------------------
{
	return exportSettings;
}


// ----------------------------------------------------------------------------
- (void) setExportSettings:(ExportSettings)settings
// ----------------------------------------------------------------------------
{
	exportSettings = settings;
}


// ----------------------------------------------------------------------------
- (NSArray*) itemsToExport
// ----------------------------------------------------------------------------
{
	return itemsToExport;
}


// ----------------------------------------------------------------------------
- (void) windowWillClose:(NSNotification *)aNotification
// ----------------------------------------------------------------------------
{
	[[ownerWindow exportTaskWindowMenuItem] setTitle:@"Show Export Tasks"];
}	


// ----------------------------------------------------------------------------
- (NSInteger) activeExportTasksCount
// ----------------------------------------------------------------------------
{
	NSInteger count = 0;
	
	for (SPExporter* exporter in [exporterArray arrangedObjects])
	{
		if (![exporter exportStopped])
			count++;
	}

	return count;
}


// ----------------------------------------------------------------------------
- (IBAction) toggleExportTasksWindow:(id)sender
// ----------------------------------------------------------------------------
{
	if ([exportTaskWindow isVisible])
	{
		[sender setTitle:@"Show Export Tasks"];
		[exportTaskWindow orderOut:sender];
	}
	else
	{
		[sender setTitle:@"Hide Export Tasks"];
		[exportTaskWindow orderFront:sender];
	}
}


// ----------------------------------------------------------------------------
- (IBAction) clearExportTasksButtonClicked:(id)sender
// ----------------------------------------------------------------------------
{
	NSMutableArray* exportersToRemove = [NSMutableArray arrayWithCapacity:10];
	for (SPExporter* exporter in [exporterArray arrangedObjects])
	{
		if ([exporter exportStopped])
			[exportersToRemove addObject:exporter];
	}

	[exporterArray removeObjects:exportersToRemove];

	[self updateExporterState];
}


// ----------------------------------------------------------------------------
- (IBAction) numberOfConcurrentExportTasksChanged:(id)sender
// ----------------------------------------------------------------------------
{
	[exportTasksCount setIntValue:[sender intValue]];
	numberOfConcurrentExportTasks = [sender intValue]; 
	[self updateExporterState];
}

@end
