//
//  MyDocument.h
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

@interface MyDocument : NSDocument
{
	NSData*			_pesData;
	NSMutableArray* _objects;
	NSMutableArray* _selection;
	NSPoint			_min, _max;
	
	BOOL			_isPES;
	
	int				_numColors;
	
	IBOutlet id		_mainView;
}
- (int32_t) readInt32:(unsigned char *)bytes;
- (int) numColors;

/* drawing maintenance */
- (void)		addObject:(id) object;
- (void)		removeObject:(id) object;
- (NSArray*)	objects;

- (void)		setObjects:(NSMutableArray*) arr;
- (BOOL)		isPES;
- (NSPoint)		minPoint;
- (NSPoint)		maxPoint;

@end
