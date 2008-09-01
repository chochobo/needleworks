//
//  StitchBlock.h
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

#import <Cocoa/Cocoa.h>


@interface StitchBlock : NSObject {
	NSColor *color;
	NSColor* stitchColor;
	CGFloat r, g, b; 
    NSBezierPath *stitches;
	NSUInteger colorIndex;
	NSUInteger numStitches;
}

// properties
@property (copy, nonatomic) NSColor *color;
@property (copy, nonatomic) NSBezierPath *stitches;
@property (nonatomic, assign) NSUInteger colorIndex;
@property (nonatomic, assign) NSUInteger numStitches;

- (void) drawWithSelection:(BOOL) selected;

@end
