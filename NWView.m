//
//  NWView.h
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

#import "NWView.h"
#import "NWStitchBlock.h"
#import "MyDocument.h"

@implementation NWView

- (void) drawRect:(NSRect) rect {
	MyDocument* doc = [self delegate];

	/* Draw the background */
	[[NSColor whiteColor] set];
	NSRectFill (rect);
	
	/* Draw a red box around our view for debugging *
	NSColor* red = [NSColor redColor];
	[red setStroke];
	NSBezierPath* outline = [NSBezierPath bezierPathWithRect:r];
	[outline setLineWidth:3];
	[[NSBezierPath bezierPathWithRect:r] stroke];*/

	/* shrink code - just for playing
	float factor = 0.5f;
	 NSView* clipView = [self superview];
	NSSize clipViewFrameSize = [clipView frame].size;
	[clipView setBoundsSize:NSMakeSize((clipViewFrameSize.width/factor), (clipViewFrameSize.height/factor))];
	 */
	
	/* Get our list of stitch blocks */
	NSArray*		drawList = [doc objects];
	NSEnumerator*	iter = [drawList objectEnumerator];
	NWStitchBlock*	stitchblock;
	 
	/* Draw all of the blocks */
	while(stitchblock = [iter nextObject]) {
		[stitchblock drawWithSelection:FALSE];
	}	
}

/* http://developer.apple.com/documentation/Cocoa/Conceptual/CocoaViewsGuide/Optimizing/chapter_8_section_7.html */
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

- (void) setDelegate:(id) aDelegate {
	_delegate = aDelegate;
}

- (id) delegate {
	return _delegate;
}
@end
