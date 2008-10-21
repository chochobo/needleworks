//
//  QuickLookView.m
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

#import "QuickLookView.h"
#import "StitchBlock.h"

@implementation QuickLookView

- (void) initWithFrame:(NSRect) frameRect {
	[super initWithFrame:frameRect];
}

- (void) drawRect:(NSRect) rect {
	MyDocument* doc = [self delegate];
	
	// Get our list of stitch blocks
	NSArray*		drawList = [doc stitchBlocks];
	NSEnumerator*	iter;
	StitchBlock*	stitchblock;
		
	// Draw all of the stitches
	iter = [drawList objectEnumerator];
	while(stitchblock = [iter nextObject]) {
		[stitchblock drawWithSelection:FALSE Jumps:FALSE Width:2];
	}	
}

- (void) setFrameSize:(NSSize)newSize {
	
    [super setFrameSize:newSize];
	
    if ([self inLiveResize]) {
		// A change in size has required the view to be invalidated.
        NSRect rects[4];
        int count;
		
        [self getRectsExposedDuringLiveResize:rects count:&count];
		
        while (count-- > 0) {
            [self setNeedsDisplayInRect:rects[count]];
        }
    } else {
        [self setNeedsDisplay:YES];
    }
}

/* We want to draw with (0, 0) at the top left */
- (BOOL) isFlipped {
	return YES;
}

- (BOOL) isOpaque {
	return YES;
}

@synthesize delegate;

@end
