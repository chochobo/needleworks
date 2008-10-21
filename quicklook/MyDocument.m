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
#import "QuickLookView.h"

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

- (int32_t) readInt32:(unsigned char *)b {
	return (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0];
}

/*- (void) drawInContext:(NSGraphicsContext*)context {
	/*QuickLookView *qlView = [[QuickLookView alloc] init];
	[qlView setDelegate:self];

	CGFloat xdiff = max.x - min.x;
	CGFloat ydiff = max.y - min.y;
	CGFloat factor;
	
	// Set our view's bounds
	NSRect npb;
	NSSize origSize = [qlView bounds].size;

	//npb = NSMakeRect(min.x, min.y, origSize.width, origSize.height);
	npb = NSMakeRect(0.0, 0.0, origSize.width, origSize.height);
	if (xdiff > ydiff) {
		//NSLog(@"Design is wide.");
		factor = xdiff/npb.size.width;
	} else {			
		//NSLog(@"Design is tall.");
		factor = ydiff/npb.size.height;
	}
	npb.size.width *= factor;
	npb.size.height *= factor;
	
	NSArray*		drawList = [self stitchBlocks];
	NSEnumerator*	iter;
	StitchBlock*	stitchblock;
	
    NSColor *color = [NSColor blueColor];
	NSBezierPath*	path = [NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, 100, 100)];
	[color setStroke];
	[path setLineCapStyle:NSRoundLineCapStyle];
	[path setLineJoinStyle:NSRoundLineJoinStyle];
	[path stroke];
	
	return;
	//[qlView setBounds:npb];
	//[qlView setBoundsOrigin:min];
	//[qlView drawRect:npb]; //NSMakeRect(0, 0, [self canvasSize].width, [self canvasSize].height)];
	CGFloat factor = 100.0f/254;
	
	iter = [drawList objectEnumerator];
	while(stitchblock = [iter nextObject]) {
		//[context saveGraphicsState];
		// Move into our QuickLook frame.
		// FIXME: How can we just adjust the frame?

		// Move the origin to the top-left of the design
		[stitchblock moveX:(0-min.x) Y:(0-min.y)];
		// Rotate the design around 0.0 ; its now in the bottom-left quadrant
		[stitchblock rotate:180];
		// Flip it across the y axis
		[stitchblock scaleXBy:-1.0 yBy:1.0];
		// Move it above the x axis
		[stitchblock moveX:0 Y:(max.y-min.y)];
		//[stitchblock scale:factor];
		// Draw the stitches
		[stitchblock drawWithSelection:FALSE Jumps:FALSE Width:2];
		//[context restoreGraphicsState];
	}
}*/

- (BOOL) readFromURL:(NSURL *)anUrl ofType:(NSString *)aType error:(NSError **) outError {
	char buffer[4];
	unsigned char b[4];
	int ptr, i, *colors;
	int32_t pecstart;

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

- (NSPoint) max {
	return max;
}

- (NSPoint) min {
	return min;
}

- (NSSize)canvasSize {
	return NSMakeSize(max.x - min.x, max.y - min.y);
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