/* 
   GormOutlineView.h

   The outline class.
   
   Copyright (C) 2001 Free Software Foundation, Inc.

   Author:  Gregory John Casamento <greg_casamento@yahoo.com>
   Date: July 2002
   
   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/ 

#ifndef _GNUstep_H_GormOutlineView
#define _GNUstep_H_GormOutlineView

#include <AppKit/NSOutlineView.h>
#include <Foundation/NSMapTable.h>

@class NSTableColumn;
@class NSMenuItem;

typedef enum {None, Outlets, Actions} GSAttributeType;

@interface GormOutlineView : NSOutlineView
{
  float _attributeOffset;
  BOOL _isEditing;
  id _itemBeingEdited;
  NSTableColumn *_actionColumn;
  NSTableColumn *_outletColumn;
  GSAttributeType _edittype;
  NSMenuItem *_menuItem;
}

// Instance methods
- (float)attributeOffset;
- (void)setAttributeOffset: (float)offset;
- (id) itemBeingEdited;
- (void) setItemBeingEdited: (id)item;
- (BOOL) isEditing;
- (void) setIsEditing: (BOOL)flag;
- (NSTableColumn *)actionColumn;
- (void) setActionColumn: (NSTableColumn *)ac;
- (NSTableColumn *)outletColumn;
- (void) setOutletColumn: (NSTableColumn *)oc;
- (NSMenuItem *)menuItem;
- (void) setMenuItem: (NSMenuItem *)item;
- (void) addAttributeToClass;
@end /* interface of GormOutlineView */

// informal protocol to define necessary methods on
// GormOutlineView's data source to make information
// about the class which was selected...
@interface NSObject (GormOutlineViewDataSource)
- (NSArray *) outlineView: (GormOutlineView *)ov
           actionsForItem: (id)item;
- (NSArray *) outlineView: (GormOutlineView *)ov
           outletsForItem: (id)item;
@end
#endif /* _GNUstep_H_GormOutlineView */
