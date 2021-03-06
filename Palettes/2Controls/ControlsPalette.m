/** 
   main.m

   Copyright (C) 2004 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: 2004
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

#include <InterfaceBuilder/IBPalette.h>
#include <InterfaceBuilder/IBViewResourceDragging.h>
#include <AppKit/NSWindow.h>
#include <AppKit/NSPopUpButton.h>
#include <AppKit/NSPasteboard.h>
#include <AppKit/NSImage.h>
#include <AppKit/NSSound.h>
#include "GormNSPopUpButton.h"

@interface ControlsPalette: IBPalette <IBViewResourceDraggingDelegates>
@end


@implementation ControlsPalette 
- (id) init
{
  if((self = [super init]) != nil)
    {
      // Make ourselves a delegate, so that when the sound/image is dragged in, 
      // this code is called...
      [NSView registerViewResourceDraggingDelegate: self];
    }

  return self;
}

- (void) dealloc
{
  [NSView unregisterViewResourceDraggingDelegate: self];
  [super dealloc];
}

- (void) finishInstantiate
{
  NSView	*contents;
  id		v;

  contents = [originalWindow contentView];
  [contents setFrame: NSMakeRect(0, 0, 272, 192)];
  v = [[GormNSPopUpButton alloc] initWithFrame: NSMakeRect(118, 139, 87, 22)];
  [v addItemWithTitle: @"Item 1"];
  [v addItemWithTitle: @"Item 2"];
  [v addItemWithTitle: @"Item 3"];
  [contents addSubview: v];
  RELEASE(v);
}

/**
 * Ask if the view accepts the object.
 */
- (BOOL) acceptsViewResourceFromPasteboard: (NSPasteboard *)pb
                                 forObject: (id)obj
                                   atPoint: (NSPoint)p
{
  NSArray *types = [pb types];
  return (([obj respondsToSelector: @selector(setSound:)] || 
	   [obj respondsToSelector: @selector(setImage:)]) &&
	  ([types containsObject: GormImagePboardType] ||
	   [types containsObject: GormSoundPboardType]));
}

/**
 * Perform the action of depositing the object.
 */
- (void) depositViewResourceFromPasteboard: (NSPasteboard *)pb
                                  onObject: (id)obj
                                   atPoint: (NSPoint)p
{
  NSArray *types = [pb types];
  if ([types containsObject: GormImagePboardType] == YES)
    {
      NSString *name = [pb stringForType: GormImagePboardType];
      if([(id)obj respondsToSelector: @selector(setImage:)])
	{
	  NSImage *image = [NSImage imageNamed: name];
	  [(id)obj setImage: AUTORELEASE([image copy])];
	}
    }
  else   if ([types containsObject: GormSoundPboardType] == YES)
    {
      NSString *name;
      name = [pb stringForType: GormSoundPboardType];
      if([(id)obj respondsToSelector: @selector(setSound:)])
	{
	  NSSound *sound = [NSSound soundNamed: name];
	  [(id)obj setSound: AUTORELEASE([sound copy])];
	}
    }
}

/**
 * Should we draw the connection frame when the resource is
 * dragged in?
 */
- (BOOL) shouldDrawConnectionFrame
{
  return NO;
}

/**
 * Types of resources accepted by this view.
 */
- (NSArray *)viewResourcePasteboardTypes
{
  return [NSArray arrayWithObjects: GormImagePboardType, GormSoundPboardType, nil];
}
@end
