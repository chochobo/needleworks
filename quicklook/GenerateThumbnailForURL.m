//
//  GenerateThumbnailForURL.m
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

#include <CoreFoundation/CoreFoundation.h>
#include <CoreServices/CoreServices.h>
#include <QuickLook/QuickLook.h>
#include <Cocoa/Cocoa.h>
#include "MyDocument.h"
#include "QuickLookView.h"

/* -----------------------------------------------------------------------------
    Generate a thumbnail for file

   This function's job is to create thumbnail for designated file as fast as possible
   ----------------------------------------------------------------------------- */

OSStatus GenerateThumbnailForURL(void *thisInterface, QLThumbnailRequestRef thumbnail, CFURLRef url, CFStringRef contentTypeUTI, CFDictionaryRef options, CGSize maxSize)
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	// Create and read our document
	MyDocument* document = [[MyDocument alloc] init];
	
	if (![document readFromURL:(NSURL*)url ofType:(NSString*)contentTypeUTI error:nil]) {
		[document release];
		[pool release];
		return noErr;
	}
	
	NSSize canvasSize = [document canvasSize];
	
	CGContextRef cgContext = QLThumbnailRequestCreateContext(thumbnail, *(CGSize *)&canvasSize, false, NULL);

	if(cgContext) {
		
        NSGraphicsContext* context = [NSGraphicsContext graphicsContextWithGraphicsPort:(void *)cgContext
																				flipped:YES];
        if(context) {
			[NSGraphicsContext setCurrentContext: context];
			[context setImageInterpolation: NSImageInterpolationHigh];
			
			/* Draw a red box *
			 NSRect f = NSMakeRect(0, 0, canvasSize.width, canvasSize.height);
			 NSBezierPath *path = [NSBezierPath bezierPathWithRect:f];
			 NSColor* red = [NSColor redColor];
			 [red setStroke];
			 [path setLineWidth:10];
			 [path stroke];
			 /**/
			NSRect renderRect = NSMakeRect(0.0, 0.0, canvasSize.width, canvasSize.height);
			QuickLookView *qlView = [[QuickLookView alloc] initWithFrame:renderRect];
			[qlView setDelegate:document];
			[qlView setBoundsOrigin:[document min]];
			[qlView displayRectIgnoringOpacity:[qlView bounds] inContext:context];
			
			[NSGraphicsContext restoreGraphicsState];
		}
		
		QLThumbnailRequestFlushContext(thumbnail, cgContext);
		
        CFRelease(cgContext);
		
    }
	
    [pool release];
	
    return noErr;
}

void CancelThumbnailGeneration(void* thisInterface, QLThumbnailRequestRef thumbnail)
{
    // implement only if supported
}
