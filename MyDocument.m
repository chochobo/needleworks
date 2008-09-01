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
    }
    return self;
}

- (void)dealloc {
	[stitchBlocks release];
	[selection release];
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
		
	NSRect			r;
	r.origin.x = min.x;
	r.origin.y = min.y;
	r.size.width = max.x - min.x;
	r.size.height = max.y - min.y;
	
	/* We set the bounds origin since designs do not always originate
	 from (0, 0). Some are even (<0, <0). */
	[mainView setBoundsOrigin:r.origin];
	
	/* We set our frame to be the size of our design. */
	[mainView setFrame:r];
	
	/* We set the maximum size of the window's content to be no larger than the
	 content itself. (plus the scrollbar troughs?) We don't want the user
	 dragging the window beyond so that it exposes the Land of Infinite Grey. */
	/* TODO: I might need to disable this when I implement zooming. */
	r.size.width = max.x - min.x + 16;
	r.size.height = max.y - min.y + 16;
	[[mainView window] setContentMaxSize:r.size];
	
	/* We zoom the window so that the entire design is visible without 
	 scrolling. If the screen is smaller than the design, the scroll view
	 will help us out. */
	[[mainView window] performZoom:nil];
}
/*
 dataOfType:error: method returns an NSData object that is an archive of the
 group name and the array of Person objects.
 This example doesn't do any error checking.
 */
/*- (NSData *) dataOfType:(NSString *)typeName error:(NSError **)outError {
	NSMutableData *data = [NSMutableData data];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
	
	[archiver encodeObject:people forKey:@"people"];
	[archiver encodeObject:groupName forKey:@"groupName"];
	[archiver encodeObject:firstColor forKey:@"firstColor"];
	[archiver finishEncoding];

	return data;
}*/

- (int32_t) readInt32:(unsigned char *)b {
	return (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0];
}

/*
 readFromData:ofType:error: method reads an NSData object that is an archive of the
 group name and the array of Person objects.
 This example doesn't do any error checking.
 */
/*- (BOOL) readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError {
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:data];
		
	self.people = [unarchiver decodeObjectForKey:@"people"];
    self.groupName = [unarchiver decodeObjectForKey:@"groupName"];
	self.firstColor = [unarchiver decodeObjectForKey:@"firstColor"];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDictionary *fileAttributes = [fileManager fileAttributesAtPath:fileName traverseLink:YES];
	self.fileSize = [fileAttributes objectForKey:NSFileSize];

	self.docName = [fileName lastPathComponent];
	[unarchiver finishDecoding];

	return YES;
}*/


- (BOOL) readFromURL:(NSURL *)anUrl ofType:(NSString *)aType error:(NSError **) outError {
	char buffer[4];
	unsigned char b[4];
	int ptr, i, *colors;
	int32_t pecstart;
	
	NSLog([[anUrl path] lastPathComponent]);
	
	[self willChangeValueForKey:@"docName"];
	self.docName = [[anUrl path] lastPathComponent];
	[self didChangeValueForKey:@"docName"];
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSDictionary *fileAttributes = [fileManager fileAttributesAtPath:[anUrl path] traverseLink:YES];

	self.docSize = [[fileAttributes objectForKey:NSFileSize] stringValue];
	NSLog([[fileAttributes objectForKey:NSFileSize] stringValue]);

	docDate = [fileModificationDate description];
	NSLog([fileModificationDate description]);
	
	//fileSize = [NSString stringWithFormat:@"12345 KB"];
	//designSize = [NSString stringWithFormat:@"AxB"];
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
	//printf ("numColors: %d\n", numColors);
	numColorChanges = 0;
	
	numStitches = 0;
	int numBlockStitches = 0;
	
	/* Allocate a list of colors (integers) */
	colors = malloc (sizeof (int) * numColors);
	/* Walk our byte array and fetch each color */
	for (i=0; i < numColors; i+=1) {
		colors[i] = pesBytes[ptr++];
		//printf ("colors[%d] = %d\n", i, colors[i]);
	}
	
	/* Move to stitches */
	ptr = pecstart + 532;
	
	unsigned char val1, val2;
	BOOL stitchBlockDone = FALSE;
	int colorNum = -1;
	NSPoint prev = NSZeroPoint, delta = NSZeroPoint, tmpPoint;
	NSBezierPath *tempStitches = [NSBezierPath bezierPath];
	StitchBlock *curBlock;
	
	//printf ("START ptr: %d\n\n", ptr);
	
	while (!stitchBlockDone) {
		//printf ("ptr: %d\n", ptr);
		//printf ("ptr @val1: %d\n", ptr);
		val1 = pesBytes[ptr++];
		//printf ("ptr @val2: %d\n", ptr);
		val2 = pesBytes[ptr++];
		
		//printf ("vals: (%d, %d)\n", val1, val2);
		
		if (val1 == 255 && val2 == 0) {
			//printf ("last block\n");
			
			stitchBlockDone = TRUE;
			
			/* Allocate the last block */
			curBlock = [[StitchBlock alloc] init];
			
			/* Save the stitches to our block */
			[curBlock setStitches:tempStitches];
			
			/* Set our block's color */
			colorNum += 1;
			[curBlock setColorIndex:colors[colorNum]];
			
			/* Save our block */
			[self addStitchBlock:curBlock];
		}
		
		// color switch, start a new block		
		else if (val1 == 254 && val2 == 176) {
			//printf ("new block\n");
			numColorChanges += 1;
			
			/* Allocate a block */
			curBlock = [[StitchBlock alloc] init];
			
			/* Save the stitches to our block */
			[curBlock setStitches:tempStitches];
			
			/* Set our block's color */
			colorNum += 1;
			[curBlock setColorIndex:colors[colorNum]];
			//printf ("colorNum a: %d\n", colorNum);
			
			/* Save our block */
			[self addStitchBlock:curBlock];
			
			/* Start a new stitch */
			tempStitches = [NSBezierPath bezierPath];
			numStitches = 0;
			
			/* Skip a "useless" byte */
			ptr += 1;
		} else {
			//printf ("continuation\n");
			
			delta = NSZeroPoint;
			
			if ((val1 & 0x80) == 0x80) {
				//printf ("jump 1\n");
				// Jump stitch		
				delta.x = ((val1 & 0xF) * 256) + val2;
				if (((int)delta.x & 0x800) == 0x800) { //0800
					//printf ("deltaXa: %.0f\n", delta.x);
					delta.x = (int)((int)delta.x | 0xFFFFF000);
				}
				val2 = pesBytes[ptr++];
				//printf ("deltaXb: %.0f\n", delta.x);
			} else {
				//printf ("normal 1\n");
				// Normal stitch
				delta.x = (int)val1;
				if (delta.x > 63) {
					delta.x -= 128;
				}
				//printf ("deltaX: %.0f\n", delta.x);
			}
			
			if ((val2 & 0x80) == 0x80) {
				//printf ("jump 2\n");
				// Jump stitch
				delta.y = ((val2 & 0xF) * 256) + pesBytes[ptr++];
				if (((int)delta.y & 0x800) == 0x800) {
					//printf ("deltaYa: %.0f\n", delta.y);
					delta.y = (int)((int)delta.y | 0xFFFFF000);
				}
				//printf ("deltaYb: %.0f\n", delta.y);
			} else {
				//printf ("normal 2\n");
				
				// Normal stitch
				delta.y = (int)val2;
				if (delta.y > 63) {
					delta.y -= 128;
				}
				//printf ("deltaY: %.0f\n", delta.y);
			}
			//printf ("prev (%.0f, %.0f)\tdelta (%.0f, %.0f)\n", prev.x, prev.y, delta.x, delta.y);
			tmpPoint.x = prev.x + delta.x;
			tmpPoint.y = prev.y + delta.y;
			//printf ("point (%.0f, %.0f)\n", tmpPoint.x, tmpPoint.y);
			
			if (numStitches == 0) {
				/* Start here */
				[tempStitches moveToPoint:tmpPoint];
			} else {
				/* then draw a line to here for the other stitches */
				[tempStitches lineToPoint:tmpPoint];
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
	
	NSRect			r;
	r.origin.x = min.x;
	r.origin.y = min.y;
	r.size.width = max.x - min.x;
	r.size.height = max.y - min.y;
	NSLog(@"%f x %f\n", r.size.width, r.size.height);
	designSize = [
		[NSString alloc] initWithFormat:@"%.2f\" x %.2f\" (%.0f mm x %.0f mm)",
				  r.size.width/254, r.size.height/254,
				  r.size.width/10, r.size.height/10
	];
	
	return YES;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
	NSPrintInfo* printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSFitPagination];
	[printInfo setHorizontallyCentered:YES];
	[printInfo setVerticallyCentered:YES];
	
	NSPrintOperation* op = [NSPrintOperation printOperationWithView:mainView printInfo:printInfo];
	
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

- (NSUInteger) countOfStitcheBlocks {
	return [stitchBlocks count];
}

/*
 Accessor methods
*/ 
@synthesize fileName;
@synthesize docName;
@synthesize fileSize;
@synthesize docSize;
@synthesize fileModificationDate;
@synthesize firstColor;
@synthesize designSize;
@synthesize numStitches;
@synthesize numColors;
@synthesize numColorChanges;
@synthesize isPES;
@end