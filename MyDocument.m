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
#import "NWStitchBlock.h"

@implementation MyDocument

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
		_objects = [[NSMutableArray alloc] init];
		_selection = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void)dealloc {
	[_objects release];
	[_selection release];
	[super dealloc];
}

- (NSString *)windowNibName
{
    // Override returning the nib file name of the document
    // If you need to use a subclass of NSWindowController or if your document supports multiple NSWindowControllers, you should remove this method and override -makeWindowControllers instead.
    return @"MyDocument";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];

    // Add any code here that needs to be executed once the windowController has loaded the document's window.
	[_mainView setDelegate:self];
	
	NSPoint			min = [self minPoint];
	NSPoint			max = [self maxPoint];
	
	NSRect			r;
	r.origin.x = min.x;
	r.origin.y = min.y;
	r.size.width = max.x - min.x;
	r.size.height = max.y - min.y;
		
	/* We set the bounds origin since designs do not always originate
	   from (0, 0). Some are even (<0, <0). */
	[_mainView setBoundsOrigin:r.origin];

	/* We set our frame to be the size of our design. */
	[_mainView setFrame:r];
	
	/* We set the maximum size of the window's content to be no larger
	   than the content itself. We don't want the user dragging the window
	   beyond so that it exposes the Land of Infinite Grey. */
	/* TODO: I might need to disable this when I implement zooming. */
	[[_mainView window] setContentMaxSize:r.size];
	
	/* We zoom the window so that the entire design is visible without 
	   scrolling. If the screen is smaller than the design, the scroll view
	   will help us out. */
	[[_mainView window] performZoom:nil];
}

- (NSData *)dataOfType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to write your document to data of the specified type. If the given outError != NULL, ensure that you set *outError when returning nil.

    // You can also choose to override -fileWrapperOfType:error:, -writeToURL:ofType:error:, or -writeToURL:ofType:forSaveOperation:originalContentsURL:error: instead.

    // For applications targeted for Panther or earlier systems, you should use the deprecated API -dataRepresentationOfType:. In this case you can also choose to override -fileWrapperRepresentationOfType: or -writeToFile:ofType: instead.

    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
	return nil;
}

- (int32_t) readInt32:(unsigned char *)b {
	return (b[3] << 24) | (b[2] << 16) | (b[1] << 8) | b[0];
}

- (int) numColors {
	return _numColors;
}

- (BOOL) readFromURL:(NSURL *)anUrl ofType:(NSString *)aType error:(NSError **) outError {
	char buffer[4];
	//unsigned char b[4];
	unsigned char b[4];
	int ptr, i, *colors;
	int32_t pecstart;
	
	_pesData = [NSData dataWithContentsOfURL:anUrl];

	if (_pesData == nil) {
		return NO;
	}
	
	const unsigned char *pesBytes = [_pesData bytes];
	
	[_pesData getBytes:buffer length:4];

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
	[_pesData getBytes:b range:startRange];
	pecstart = [self readInt32:b];
	
	/* Move to pecstart + 48 */
	ptr = pecstart + 48;
	//printf ("pecstart: %d\n", pecstart);

	/* Fetch the number of colors in our document */
	_numColors = pesBytes[ptr] + 1;
	//printf ("numColors: %d\n", _numColors);
	
	/* We've read ptr, so advance one byte */
	ptr += 1;
	
	/* Allocate a list of colors (integers) */
	colors = malloc (sizeof (int) * _numColors);
	/* Walk our byte array and fetch each color */
	for (i=0; i < _numColors; i+=1) {
		colors[i] = pesBytes[ptr++];
		//printf ("colors[%d] = %d\n", i, colors[i]);
	}
	
	/* Move to stitches */
	ptr = pecstart + 532;
	
	unsigned char val1, val2;
	BOOL stitchBlockDone = FALSE;
	int colorNum = -1, numStitches = 0;
	NSPoint prev = NSZeroPoint, delta = NSZeroPoint, tmpPoint;
	NSBezierPath *tempStitches = [NSBezierPath bezierPath];
	NWStitchBlock *curBlock;
	
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
			curBlock = [[NWStitchBlock alloc] init];

			/* Save the stitches to our block */
			[curBlock setStitches:tempStitches];
			
			/* Set our block's color */
			colorNum += 1;
			[curBlock setColorIndex:colors[colorNum]];
			
			/* Save our block */
			[self addObject:curBlock];
		}

		// color switch, start a new block		
		else if (val1 == 254 && val2 == 176) {
			//printf ("new block\n");
			
			/* Allocate a block */
			curBlock = [[NWStitchBlock alloc] init];

			/* Save the stitches to our block */
			[curBlock setStitches:tempStitches];

			/* Set our block's color */
			colorNum += 1;
			[curBlock setColorIndex:colors[colorNum]];
			//printf ("colorNum a: %d\n", colorNum);
			
			/* Save our block */
			[self addObject:curBlock];
			
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
			numStitches += 1;
			
			prev.x += delta.x;
			prev.y += delta.y;
			if (prev.x > _max.x) {
				_max.x = prev.x;
			} else if (prev.x < _min.x) {
				_min.x = prev.x;
			}
			if (prev.y > _max.y) {
				_max.y = prev.y;
			} else if (prev.y < _min.y) {
				_min.y = prev.y;
			}
		}
	}
	
	return YES;
}

- (NSPrintOperation *)printOperationWithSettings:(NSDictionary *)printSettings error:(NSError **)outError {
	NSPrintInfo* printInfo = [NSPrintInfo sharedPrintInfo];
	[printInfo setHorizontalPagination:NSFitPagination];
	[printInfo setVerticalPagination:NSFitPagination];
	[printInfo setHorizontallyCentered:YES];
	[printInfo setVerticallyCentered:YES];
		
	NSPrintOperation* op = [NSPrintOperation printOperationWithView:_mainView printInfo:printInfo];
	
	return op;
}

- (NSPoint) minPoint {
	return _min;
}
- (NSPoint) maxPoint {
	return _max;
}
/*
 - (BOOL)readFromData:(NSData *)data ofType:(NSString *)typeName error:(NSError **)outError
{
    // Insert code here to read your document from the given data of the specified type.  If the given outError != NULL, ensure that you set *outError when returning NO.

    // You can also choose to override -readFromFileWrapper:ofType:error: or -readFromURL:ofType:error: instead. 
    
    // For applications targeted for Panther or earlier systems, you should use the deprecated API -loadDataRepresentation:ofType. In this case you can also choose to override -readFromFile:ofType: or -loadFileWrapperRepresentation:ofType: instead.
    
    if ( outError != NULL ) {
		*outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:NULL];
	}
    return YES;
}
*/

- (void)addObject:(id) object {
	if (![_objects containsObject:object]) {
		[_objects addObject:object];
	}
}

- (void)removeObject:(id) object {
	[_objects removeObject:object];
}

- (NSArray*) objects {
	return _objects;
}

- (void) setObjects:(NSMutableArray*) arr {
	[arr retain];
	[_objects release];
	_objects = arr;
	//[self deselectAll];
}

- (BOOL) isPES {
	return _isPES;
}
@end
