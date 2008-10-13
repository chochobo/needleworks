//
//  MyDocument.m
//  Needle Works
//
//  Copyright 2008 Ryan Lovett <ryan@spacecoaster.org>. All rights reserved.
//  
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License
//  as published by the Free Software Foundation; either version 2
//  of the License, or (at your option) any later version.
//  
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//   
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
//  02111-1307, USA.

#import "MyDocument.h"
#import "StitchBlock.h"

@implementation MyDocument

/*
 Designated initializer for new documents: creates the people array
 */
- (id) init {
    self = [super init];
    if (self) {
		stitchBlocks = [[NSMutableArray alloc] init];
		selection = [[NSMutableArray alloc] init];
		docName = [[NSString alloc] initWithString:@""];
		docSize = [[NSString alloc] initWithString:@""];
		docDate = [[NSString alloc] initWithString:@""];
		lineWidth = 2;
		fabricColor = [NSColor whiteColor];
		showJumpStitches = YES;

		colorLists = [[NSMutableArray alloc] init];
		origPrintViewSizePortrait = NSMakeSize(0, 0);
		origPrintViewSizeLandscape = NSMakeSize(0, 0);
		
		// Our application's shared color panel
		NSColorPanel *colorPanel = [NSColorPanel sharedColorPanel];
		
		// The paths to our .clr files in Needle Works.app/Contents/Resources/
		NSArray *colorPaths = [[NSBundle mainBundle] pathsForResourcesOfType:@"clr" inDirectory:nil];
		NSEnumerator *colorPathIter;
		NSColorList *colorList;
		
		NSArray *colorNames;
		NSEnumerator *colorNameIter;
		NSString *path, *pathBasename;
		
		colorPathIter = [colorPaths objectEnumerator];
		while (path = [colorPathIter nextObject]) {
			pathBasename = [path lastPathComponent];
			colorList = [[NSColorList alloc] initWithName:[pathBasename stringByDeletingPathExtension] fromFile:path];
			if (colorList != nil) {
				[colorPanel attachColorList:colorList];
				colorNames = [colorList allKeys];
				colorNameIter = [colorNames objectEnumerator];
				/*while (colorStr = [colorNameIter nextObject]) {
					NSLog(colorStr);
				}*/
				[[self colorLists] addObject:colorList];
			} else {
				NSLog(@"Cannot find %s color list\n", [path lastPathComponent]);
			}
			
		}
		
		//NSLog(@"colorLists count: %d", [[self colorLists] count]);
    }
    return self;
}

- (void)dealloc {
	//NSLog(@"MyDocument::dealloc\n");
	[stitchBlocks release];
	[selection release];
	[docName release];
	[docSize release];
	[docDate release];
	[super dealloc];
}

/*
 windowNibName returns the name of the document's nib file
 */
- (NSString *) windowNibName {
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController {
    [super windowControllerDidLoadNib:aController];
	
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
	[mainView setDelegate:self];
	[printView setDelegate:self];
	[splitView setDelegate:self];
	[legendPrintView setDelegate:self];
		
	NSRect			r;
	r.origin.x = min.x;
	r.origin.y = min.y;
	r.size.width = max.x - min.x;
	r.size.height = max.y - min.y;
	
	/* We set the bounds origin since designs do not always originate
	 from (0, 0). Some are even (<0, <0). */
	[mainView setBoundsOrigin:min];
	
	/* Resize the clip view using the proper DPI */
	CGFloat actualScale = 100.0f / 254;
	NSView *clipView = [mainView superview];
	NSSize clipViewFrameSize = [clipView frame].size;
	NSSize actualSize = NSMakeSize((clipViewFrameSize.width / actualScale), (clipViewFrameSize.height / actualScale));
	[clipView setBoundsSize:actualSize];
	
	[mainView setFrame:r];
		
	/* We set the maximum size of the window's content to be no larger than the content itself. (plus the scrollbar troughs?) We don't want the user dragging the window beyond so that it exposes the Land of Infinite Grey. */
	/* TODO: I might need to disable this when I implement zooming. */
	/* We also scale the max dimensions to the proper DPI since the view will be too. */
	r.size.width = (max.x - min.x)  * actualScale + 16;
	r.size.height = (max.y - min.y) * actualScale + 16;
	[[mainView window] setContentMaxSize:r.size];
		
	/* We zoom the window so that the entire design is visible without 
	 scrolling. If the screen is smaller than the design, the scroll view
	 will help us out. */
	[[mainView window] performZoom:nil];
}

// Since we are a new document and haven't been saved we need to explicitly set our
// window title to something other than "Untitled n"
- (NSString *)displayName {
	return docName;
}

- (int32_t) readInt32:(unsigned char *)b {
	return (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0];
}

- (BOOL) readFromURL:(NSURL *)anUrl ofType:(NSString *)aType error:(NSError **) outError {
	char buffer[4];
	unsigned char b[4];
	int ptr, i, *colors;
	int32_t pecstart;
	
	//NSLog([[anUrl path] lastPathComponent]);
	
	self.docName = [[anUrl path] lastPathComponent];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDictionary *fileAttributes = [fileManager fileAttributesAtPath:[anUrl path] traverseLink:YES];

	self.docSize = [[fileAttributes objectForKey:NSFileSize] stringValue];
	//NSLog([[fileAttributes objectForKey:NSFileSize] stringValue]);

	docDate = [fileModificationDate description];
	//NSLog([fileModificationDate description]);

	//NSLog(@"File size: %qi\n", [fileSize unsignedLongLongValue]);
	
	pesData = [NSData dataWithContentsOfURL:anUrl];
	
	if (pesData == nil) {
		return NO;
	}
	
	const unsigned char *pesBytes = [pesData bytes];
	
	[pesData getBytes:buffer length:4];
	
	if (strncmp ("#PES", buffer, 4)) {
		if ( outError != NULL ) {
			*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
		}
		return NO;
	}
	
	/* The value at 8 is an int representing pecstart */
	NSRange startRange;
	startRange.location = 8;
	startRange.length = 4;
	[pesData getBytes:b range:startRange];
	
	pecstart = [self readInt32:b];
	//NSLog(@"pecstart: %d\n", pecstart);
	
	/* Move to pecstart + 48 */
	ptr = pecstart + 48;
	
	/* Fetch the number of colors in our document */
	numColors = pesBytes[ptr++] + 1;
	//NSLog(@"numColors: %d\n", numColors);
	numColorChanges = 0;
	
	numStitches = 0;
	int numBlockStitches = 0;
	
	/* Allocate a list of colors (integers) */
	colors = malloc (sizeof (int) * numColors);
	/* Walk our byte array and fetch each color */
	for (i=0; i < numColors; i+=1) {
		colors[i] = pesBytes[ptr++];
		//NSLog(@"colors[%d] = %d\n", i, colors[i]);
	}
	
	/* Move to stitches */
	ptr = pecstart + 532;
	
	unsigned char val1, val2;
	BOOL stitchBlockDone = FALSE, jumpStitch;
	int colorNum = -1;
	NSPoint prev = NSZeroPoint, delta = NSZeroPoint, tmpPoint;
	NSBezierPath *tempStitches = [NSBezierPath bezierPath];
	NSBezierPath *tempStitchesAndJumps = [NSBezierPath bezierPath];
	StitchBlock *curBlock;
	
	//NSLog(@"START ptr: %d\n\n", ptr);
	
	while (!stitchBlockDone) {
		jumpStitch = FALSE;
		val1 = pesBytes[ptr++];
		val2 = pesBytes[ptr++];		
		//NSLog(@"vals: (%d, %d)\n", val1, val2);
		
		if (val1 == 255 && val2 == 0) {
			//NSLog(@"last block\n");
			stitchBlockDone = TRUE;
			
			/* Allocate the last block */
			curBlock = [[StitchBlock alloc] init];
			
			/* Save the stitches to our block */
			[curBlock setStitches:tempStitches];
			[curBlock setStitchesAndJumps:tempStitchesAndJumps];
			
			/* Set our block's color */
			colorNum += 1;
			[curBlock setColorIndex:colors[colorNum]];
			//NSLog(@"color: %d\n", colorNum);
			
			/* Save our block */
			[self addStitchBlock:curBlock];
		}
		// color switch, start a new block		
		else if (val1 == 254 && val2 == 176) {
			//NSLog(@"new block\n");
			numColorChanges += 1;
			
			/* Allocate a block */
			curBlock = [[StitchBlock alloc] init];
			
			/* Save the stitches to our block */
			[curBlock setStitches:tempStitches];
			[curBlock setStitchesAndJumps:tempStitchesAndJumps];
			
			/* Set our block's color */
			colorNum += 1;
			[curBlock setColorIndex:colors[colorNum]];
			//NSLog(@"colorNum: %d\n", colorNum);
			
			/* Save our block */
			[self addStitchBlock:curBlock];
			
			/* Start a new stitch */
			tempStitches = [NSBezierPath bezierPath];
			tempStitchesAndJumps = [NSBezierPath bezierPath];
			numStitches = 0;
			
			/* Skip a "useless" byte */
			ptr += 1;
		} else {
			//NSLog(@"continuation\n");
			
			delta = NSZeroPoint;
			
			if ((val1 & 0x80) == 0x80) {
				jumpStitch = TRUE;
				//NSLog(@"jump stitch 1\n");
				delta.x = ((val1 & 0xF) * 256) + val2;
				if (((int)delta.x & 0x800) == 0x800) { //0800
					delta.x = (int)((int)delta.x | 0xFFFFF000);
				}
				val2 = pesBytes[ptr++];
			} else {
				//NSLog(@"normal stitch 1\n");
				delta.x = (int)val1;
				if (delta.x > 63) {
					delta.x -= 128;
				}
			}
			
			if ((val2 & 0x80) == 0x80) {
				jumpStitch = TRUE;
				//NSLog(@"jump stitch 2\n");
				delta.y = ((val2 & 0xF) * 256) + pesBytes[ptr++];
				if (((int)delta.y & 0x800) == 0x800) {
					delta.y = (int)((int)delta.y | 0xFFFFF000);
				}
			} else {
				//NSLog(@"normal stitch 2\n");
				delta.y = (int)val2;
				if (delta.y > 63) {
					delta.y -= 128;
				}
			}
			tmpPoint.x = prev.x + delta.x;
			tmpPoint.y = prev.y + delta.y;
			
			if (numStitches == 0) {
				/* Start here */
				[tempStitches moveToPoint:tmpPoint];
				[tempStitchesAndJumps moveToPoint:tmpPoint];
			} else if (jumpStitch) {
				/* then draw a line to here for the other stitches */
				[tempStitches moveToPoint:tmpPoint];
				[tempStitchesAndJumps lineToPoint:tmpPoint];
			} else {
				/* then draw a line to here for the other stitches */
				[tempStitches lineToPoint:tmpPoint];
				[tempStitchesAndJumps lineToPoint:tmpPoint];
			}
			
			/* Stitches in our block */
			numBlockStitches += 1;
			/* Stitches in our design */
			numStitches += 1;

			prev.x += delta.x;
			prev.y += delta.y;
			if (prev.x > max.x) {
				max.x = prev.x;
			} else if (prev.x < min.x) {
				min.x = prev.x;
			}
			if (prev.y > max.y) {
				max.y = prev.y;
			} else if (prev.y < min.y) {
				min.y = prev.y;
			}
		}
	}
	
	// Determine the physical size of our design
	CGFloat w = max.x - min.x;
	CGFloat h = max.y - min.y;
	designSize = [
		[NSString alloc] initWithFormat:@"%.2f\" x %.2f\" (%.0f mm x %.0f mm)",
				w/254, h/254, w/10, h/10
	];
	
	return YES;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
	
	NSPrintInfo* printInfo = [self printInfo];
	
    NSSize paperSize = [printInfo paperSize];
    NSRect printableRect = [printInfo imageablePageBounds];
	
    // calculate page margins
    CGFloat marginL = printableRect.origin.x;
    CGFloat marginR = paperSize.width - (printableRect.origin.x + printableRect.size.width);
    CGFloat marginB = printableRect.origin.y;
    CGFloat marginT = paperSize.height - (printableRect.origin.y + printableRect.size.height);
	
    // Make sure margins are symetric and positive
    CGFloat marginLR = MAX(0, MAX(marginL, marginR));
    CGFloat marginTB = MAX(0, MAX(marginT, marginB));
    
    // Tell printInfo what the nice new margins are
    [printInfo setLeftMargin:   marginLR];
    [printInfo setRightMargin:  marginLR];
    [printInfo setTopMargin:    marginTB];
    [printInfo setBottomMargin: marginTB];
	
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSFitPagination];
	//[printInfo setHorizontallyCentered:NO];
	//[printInfo setVerticallyCentered:NO];
	
	CGFloat pageWidth  = paperSize.width - marginLR*2;
	CGFloat pageHeight = paperSize.height - marginTB*2;
	//NSLog(@"page size: %f x %f", pageWidth, pageHeight);

	// Expand our split view to occupy the whole page
	[splitView setFrameSize:NSMakeSize(pageWidth, pageHeight)];
	
	CGFloat xdiff = max.x - min.x;
	CGFloat ydiff = max.y - min.y;
	CGFloat factor;
	
	// Set our printed design view's bounds and save it
	NSRect npb;
	if ([printInfo orientation] == NSPortraitOrientation) {
		if (origPrintViewSizePortrait.width == 0 && origPrintViewSizePortrait.height == 0) {
			origPrintViewSizePortrait = [printView bounds].size;
		}		
		npb = NSMakeRect(min.x, min.y,
						 origPrintViewSizePortrait.width, origPrintViewSizePortrait.height);
	} else {
		if (origPrintViewSizeLandscape.width == 0 && origPrintViewSizeLandscape.height == 0) {
			origPrintViewSizeLandscape = [printView bounds].size;
		}
		npb = NSMakeRect(min.x, min.y,
						 origPrintViewSizeLandscape.width, origPrintViewSizeLandscape.height);
	}
	
	// Fetch the print scale preference
	int printScale = [[NSUserDefaults standardUserDefaults] integerForKey:@"printScale"];

	// User wants the printed size scaled to fit
	if (printScale == 1) {
				
		// If the design's aspect ratio is wider than the design's portion of our page,
		// our bounds must be scaled to fit it by width, otherwise by height.
		if ((xdiff/ydiff) >= (pageWidth/pageHeight)) {
			//NSLog(@"Design is wide.");
			factor = xdiff/npb.size.width;
		} else {			
			//NSLog(@"Design is tall.");
			factor = ydiff/npb.size.height;
		}
	}
	// User wants the design printed at actual size
	else {
		factor = 1 + 254/100.0f; // why 3.54?		
	}
	
	npb.size.width *= factor;
	npb.size.height *= factor;

	//NSLog(@"design size: %f x %f", xdiff, ydiff);
	//NSLog(@"old frame: %f x %f (%f, %f)",
	//	  [printView frame].size.width, [printView frame].size.height,
	//	  [printView frame].origin.x, [printView frame].origin.y);
	//NSLog(@"old bounds: %f x %f (%f, %f)",
	//	  [printView bounds].size.width, [printView bounds].size.height,
	//	  [printView bounds].origin.x, [printView bounds].origin.y);

	[printView setBounds:npb];

	//NSLog(@"new bounds: %f x %f (%f, %f)",
	//	  [printView bounds].size.width, [printView bounds].size.height,
	//	  [printView bounds].origin.x, [printView bounds].origin.y);
	
	NSPrintOperation* op = [NSPrintOperation printOperationWithView:splitView printInfo:printInfo];
	
	return op;
}

- (void)addStitchBlock:(id) object {
	if (![stitchBlocks containsObject:object]) {
		[stitchBlocks addObject:object];
	}
}

- (void)removeStitchBlock:(id) object {
	[stitchBlocks removeObject:object];
}

- (NSArray*) stitchBlocks {
	return stitchBlocks;
}

- (void) setStitchBlocks:(NSMutableArray*) arr {
	[arr retain];
	[stitchBlocks release];
	stitchBlocks = arr;
}

- (NSColor*) fabricColor {
	return fabricColor;
}

- (void) setFabricColor:(NSColor*) c {
	[c retain];
	[fabricColor release];
	fabricColor = c;
	[mainView setNeedsDisplay:YES];
}

- (CGFloat) lineWidth {
	return lineWidth;
}

- (void) setLineWidth:(CGFloat) w {
	lineWidth = w;
	[mainView setNeedsDisplay:YES];
	//[[mainView window] performZoom:nil];
}

- (BOOL) showJumpStitches {
	return showJumpStitches;
}

- (void) setShowJumpStitches:(BOOL) show {
	showJumpStitches = !showJumpStitches;
	[mainView setNeedsDisplay:YES];
	//[[mainView window] performZoom:nil];
}

- (NSPoint) max {
	return max;
}

- (NSPoint) min {
	return min;
}

- (NSMutableArray*)colorLists {
	return colorLists;
}

/*
 Accessor methods
*/ 
@synthesize fileName;
@synthesize docName;
@synthesize fileSize;
@synthesize docSize;
@synthesize fileModificationDate;
@synthesize designSize;
@synthesize numStitches;
@synthesize numColors;
@synthesize numColorChanges;
@synthesize isPES;

@end