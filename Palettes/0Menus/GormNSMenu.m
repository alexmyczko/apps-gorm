/* GormNSMenu.m

   Copyright (C) 2002 Free Software Foundation, Inc.

   Author: Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
   Date: 2002
   
   This file is part of GNUstep.
   
   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.
   
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.
   
   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
*/

#import "GormNSMenu.h"

@interface GormNSMenuWindow : NSWindow
{
}
@end

@implementation GormNSMenuWindow
- (BOOL)canBecomeMainWindow
{
  return YES;
}
- (BOOL)canBecomeKeyWindow
{
  return YES;
}
- (void) sendEvent: (NSEvent*)theEvent
{
  NSEventType   type;

  type = [theEvent type];
  if (type == NSLeftMouseDown)
    {
      NSLog(@"here");
      if (_f.is_main == YES)
	{
	  NSLog(@"already main %@", [NSApp mainWindow]);
	}
      [self makeMainWindow];
      [self makeKeyWindow];
    }

  [super sendEvent: theEvent];
}

@end

@implementation GormNSMenu
- (BOOL) performKeyEquivalent: (NSEvent*)theEvent
{
  return NO;
}


- (NSPanel*) _createWindow
{
  NSLog(@"called _cre");
  NSPanel *win = [[GormNSMenuWindow alloc] 
                     initWithContentRect: NSZeroRect
		   styleMask: /*NSTitledWindowMask/*/NSBorderlessWindowMask
                     backing: NSBackingStoreBuffered
                     defer: YES];
  [win setLevel: NSSubmenuWindowLevel];
  //  [win setWorksWhenModal: YES];
  //  [win setBecomesKeyOnlyIfNeeded: YES];

  return win;
}

@end

@implementation NSMenu (GormNSMenu)
+ (id) allocSubstitute
{
  return [GormNSMenu alloc];
}
@end
