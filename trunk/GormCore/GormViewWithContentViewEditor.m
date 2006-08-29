/* GormViewWithContentViewEditor.m
 *
 * Copyright (C) 2002 Free Software Foundation, Inc.
 *
 * Author:	Pierre-Yves Rivaille <pyrivail@ens-lyon.fr>
 * Date:	2002
 * 
 * This file is part of GNUstep.
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
 */

#include <AppKit/AppKit.h>
#include "GormPrivate.h"
#include "GormViewWithContentViewEditor.h"
#include "GormPlacementInfo.h"
#include "GormSplitViewEditor.h"
#include "GormViewKnobs.h"

@interface GormViewEditor (Private)
- (NSRect) _displayMovingFrameWithHint: (NSRect) frame
		      andPlacementInfo: (GormPlacementInfo *)gpi;
@end



@implementation GormViewWithContentViewEditor

- (id) initWithObject: (id) anObject
  	   inDocument: (id<IBDocuments>)aDocument
{
  _displaySelection = YES;
  //GuideLine
  [[NSNotificationCenter defaultCenter] addObserver:self 
					selector:@selector(guideline:)
					name: GormToggleGuidelineNotification
					object:nil];
  _followGuideLine = YES;
  self = [super initWithObject: anObject
		inDocument: aDocument];
  return self;
}

-(void) guideline:(NSNotification *)notification
{
  if ( _followGuideLine )
    _followGuideLine = NO;
  else 
    _followGuideLine = YES;
}

- (void) handleMouseOnKnob: (IBKnobPosition) knob
		    ofView: (GormViewEditor *) view
		 withEvent: (NSEvent *) theEvent
{
  NSPoint	mouseDownPoint = [[view superview]
				   convertPoint: [theEvent locationInWindow]
				   fromView: nil];
  NSDate	*future = [NSDate distantFuture];
  BOOL		acceptsMouseMoved;
  unsigned	eventMask;
  NSEvent	*e;
  NSEventType	eType;
  NSRect	r = [view frame];
  NSPoint	maxMouse;
  NSPoint	minMouse;
  NSRect	firstRect = [view frame];
  NSRect	lastRect = [view frame];
  NSPoint	lastPoint = mouseDownPoint;
  NSPoint	point = mouseDownPoint;
  NSView        *superview;
  GormPlacementInfo *gpi;

  eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask
    | NSMouseMovedMask | NSPeriodicMask;
  
  // Save window state info.
  acceptsMouseMoved = [[self window] acceptsMouseMovedEvents];
  [[self window] setAcceptsMouseMovedEvents: YES];

  superview = [view superview];
  [superview lockFocus];

  _displaySelection = NO;

  /*
   * Get size limits for resizing or moving and calculate maximum
   * and minimum mouse positions that won't cause us to exceed
   * those limits.
   */
  {
    NSSize	max = [view maximumSizeFromKnobPosition: knob];
    NSSize	min = [view minimumSizeFromKnobPosition: knob];
	  
    r = [superview frame];
      
    minMouse = NSMakePoint(NSMinX(r), NSMinY(r));
    maxMouse = NSMakePoint(NSMaxX(r), NSMaxY(r));
    r = [view frame];
    switch (knob)
      {
      case IBBottomLeftKnobPosition:
	maxMouse.x = NSMaxX(r) - min.width;
	minMouse.x = NSMaxX(r) - max.width;
	maxMouse.y = NSMaxY(r) - min.height;
	minMouse.y = NSMaxY(r) - max.height;
	break;
	      
      case IBMiddleLeftKnobPosition:
	maxMouse.x = NSMaxX(r) - min.width;
	minMouse.x = NSMaxX(r) - max.width;
	break;
	      
      case IBTopLeftKnobPosition:
	maxMouse.x = NSMaxX(r) - min.width;
	minMouse.x = NSMaxX(r) - max.width;
	maxMouse.y = NSMinY(r) + max.height;
	minMouse.y = NSMinY(r) + min.height;
	break;
	      
      case IBTopMiddleKnobPosition:
	maxMouse.y = NSMinY(r) + max.height;
	minMouse.y = NSMinY(r) + min.height;
	break;
	      
      case IBTopRightKnobPosition:
	maxMouse.x = NSMinX(r) + max.width;
	minMouse.x = NSMinX(r) + min.width;
	maxMouse.y = NSMinY(r) + max.height;
	minMouse.y = NSMinY(r) + min.height;
	break;
	      
      case IBMiddleRightKnobPosition:
	maxMouse.x = NSMinX(r) + max.width;
	minMouse.x = NSMinX(r) + min.width;
	break;
	      
      case IBBottomRightKnobPosition:
	maxMouse.x = NSMinX(r) + max.width;
	minMouse.x = NSMinX(r) + min.width;
	maxMouse.y = NSMaxY(r) - min.height;
	minMouse.y = NSMaxY(r) - max.height;
	break;
	      
      case IBBottomMiddleKnobPosition:
	maxMouse.y = NSMaxY(r) - min.height;
	minMouse.y = NSMaxY(r) - max.height;
	break;

      case IBNoneKnobPosition:
	break;	/* NOT REACHED */
      }
  }



  /* Set the arrows cursor in case it might be something else */
  [[NSCursor arrowCursor] push];

  /*
   * Track mouse movements until left mouse up.
   * While we keep track of all mouse movements, we only act on a
   * movement when a periodic event arives (every 20th of a second)
   * in order to avoid excessive amounts of drawing.
   */
  [NSEvent startPeriodicEventsAfterDelay: 0.1 withPeriod: 0.05];
  e = [NSApp nextEventMatchingMask: eventMask
	     untilDate: future
	     inMode: NSEventTrackingRunLoopMode
	     dequeue: YES];
  eType = [e type];

  if ([view respondsToSelector: @selector(initializeResizingInFrame:withKnob:)])
    {
      gpi = [(id)view initializeResizingInFrame: superview
		  withKnob: knob];
    }
  else
    {
      gpi = nil;
    }

  while (eType != NSLeftMouseUp)
    {
      if (eType != NSPeriodic)
	{
	  point = [superview convertPoint: [e locationInWindow]
			     fromView: nil];
	  /*
	  if (edit_view != self)
	    point = _constrainPointToBounds(point, [edit_view bounds]);
	  */
	}
      else if (NSEqualPoints(point, lastPoint) == NO)
	{
	  [[self window] disableFlushWindow];

	  {
	    float	xDiff;
	    float	yDiff;

	    if (point.x < minMouse.x)
	      point.x = minMouse.x;
	    if (point.y < minMouse.y)
	      point.y = minMouse.y;
	    if (point.x > maxMouse.x)
	      point.x = maxMouse.x;
	    if (point.y > maxMouse.y)
	      point.y = maxMouse.y;

	    xDiff = point.x - lastPoint.x;
	    yDiff = point.y - lastPoint.y;
	    lastPoint = point;

	    {
	      r = GormExtBoundsForRect(r/*constrainRect*/);
	      r.origin.x--;
	      r.origin.y--;
	      r.size.width += 2;
	      r.size.height += 2;
	      //	      [superview displayRect: r];
	      r = lastRect;
	      switch (knob)
		{
		case IBBottomLeftKnobPosition:
		  r.origin.x += xDiff;
		  r.origin.y += yDiff;
		  r.size.width -= xDiff;
		  r.size.height -= yDiff;
		  break;
			    
		case IBMiddleLeftKnobPosition:
		  r.origin.x += xDiff;
		  r.size.width -= xDiff;
		  break;

		case IBTopLeftKnobPosition:
		  r.origin.x += xDiff;
		  r.size.width -= xDiff;
		  r.size.height += yDiff;
		  break;
			    
		case IBTopMiddleKnobPosition:
		  r.size.height += yDiff;
		  break;

		case IBTopRightKnobPosition:
		  r.size.width += xDiff;
		  r.size.height += yDiff;
		  break;

		case IBMiddleRightKnobPosition:
		  r.size.width += xDiff;
		  break;

		case IBBottomRightKnobPosition:
		  r.origin.y += yDiff;
		  r.size.width += xDiff;
		  r.size.height -= yDiff;
		  break;

		case IBBottomMiddleKnobPosition:
		  r.origin.y += yDiff;
		  r.size.height -= yDiff;
		  break;

		case IBNoneKnobPosition:
		  break;	/* NOT REACHED */
		}

	      lastRect = r;

	      if ([view respondsToSelector: 
			  @selector(updateResizingWithFrame:andEvent:andPlacementInfo:)])
		{
		  [view updateResizingWithFrame: r
			andEvent: theEvent
			andPlacementInfo: gpi];
		}

	    }
	    /*
	     * Flush any drawing performed for this event.
	     */
	    [[self window] enableFlushWindow];
	    [[self window] flushWindow];
	  }
	}

      e = [NSApp nextEventMatchingMask: eventMask
		 untilDate: future
		 inMode: NSEventTrackingRunLoopMode
		 dequeue: YES];
      eType = [e type];
    }
  
  [NSEvent stopPeriodicEvents];
  [NSCursor pop];
  /* Typically after a view has been dragged in a window, NSWindow
	 sends a spurious moustEntered event. Sending the mouseUp
	 event back to the NSWindow resets the NSWindow's idea of the
	 last mouse point so it doesn't think that the mouse has
	 entered the view (since it was always there, it's just that
	 the view moved).  */
  [[self window] postEvent: e atStart: NO];

  {
    NSRect	redrawRect;

    /*
     * This was a subview resize, so we must clean up by removing
     * the highlighted knob and the wireframe around the view.
     */

    [view updateResizingWithFrame: r
	  andEvent: theEvent
	  andPlacementInfo: gpi];
    
    [view validateFrame: r
	  withEvent: theEvent
	  andPlacementInfo: gpi];

    r = GormExtBoundsForRect(lastRect);
    r.origin.x--;
    r.origin.y--;
    r.size.width += 2;
    r.size.height += 2;
    /*
     * If this was a simple resize, we must redraw the union of
     * the original frame, and the final frame, and the area
     * where we were drawing the wireframe and handles.
     */
    redrawRect = NSUnionRect(r, redrawRect);
    redrawRect = NSUnionRect(firstRect, redrawRect);
  }

  
  if (NSEqualPoints(point, mouseDownPoint) == NO)
    {
      /*
       * A subview was moved or resized, so we must mark the
       * doucment as edited.
	   */
      [document touch];
    }

  [superview unlockFocus];
  _displaySelection = YES;
  
  [self setNeedsDisplay: YES];
  /*
   * Restore state to what it was on entry.
   */
  [[self window] setAcceptsMouseMovedEvents: acceptsMouseMoved];

}

- (void) handleMouseOnView: (GormViewEditor *) view
		 withEvent: (NSEvent *) theEvent
{
  NSPoint	mouseDownPoint = [[view superview]
				   convertPoint: [theEvent locationInWindow]
				   fromView: nil];
  NSDate	*future = [NSDate distantFuture];
  NSView	*subview;
  BOOL		acceptsMouseMoved;
  BOOL		dragStarted = NO;
  unsigned	eventMask;
  NSEvent	*e;
  NSEventType	eType;
  NSRect	r;
  NSPoint	maxMouse;
  NSPoint	minMouse;
  NSPoint	lastPoint = mouseDownPoint;
  NSPoint	point = mouseDownPoint;
  NSView        *superview;
  NSEnumerator		*enumerator;
  NSRect        oldMovingFrame;
  NSRect        suggestedFrame;
  GormPlacementInfo *gpi = nil;
  BOOL shouldUpdateSelection = YES;
  BOOL mouseDidMove = NO;

  eventMask = NSLeftMouseUpMask | NSLeftMouseDraggedMask
    | NSMouseMovedMask | NSPeriodicMask;
  
  // Save window state info.
  acceptsMouseMoved = [[self window] acceptsMouseMovedEvents];
  [[self window] setAcceptsMouseMovedEvents: YES];

  if (view == nil)
    {
      return;
    }

  if ([theEvent modifierFlags] & NSShiftKeyMask)
    {
      if ([selection containsObject: view])
	{
	  NSMutableArray *newSelection = [selection mutableCopy];
	  [newSelection removeObjectIdenticalTo: view];
	  [self selectObjects: newSelection];
	  RELEASE(newSelection);
	  return;
	}
      else
	{
	  NSArray *newSelection;
	  newSelection = [selection arrayByAddingObject: view];
	  [self selectObjects: newSelection];
	}
      shouldUpdateSelection = NO;
    }
  else
    {
      if ([selection containsObject: view])
	{
	  if ([selection count] == 1)
	    shouldUpdateSelection = NO;
	}
      else
	{
	  shouldUpdateSelection = NO;
	  [self selectObjects: [NSArray arrayWithObject: view]];
	}
    }

  superview = [view superview];
  [superview lockFocus];
  
  {
    NSRect	vf = [view frame];
    NSRect	sf = [superview bounds];
    NSPoint	tr = NSMakePoint(NSMaxX(vf), NSMaxY(vf));
    NSPoint	bl = NSMakePoint(NSMinX(vf), NSMinY(vf));
    
    enumerator = [selection objectEnumerator];
    while ((subview = [enumerator nextObject]) != nil)
      {
	if (subview != view)
	  {
	    float	tmp;
	    
	    vf = [subview frame];
	    tmp = NSMaxX(vf);
	    if (tmp > tr.x)
	      tr.x = tmp;
	    tmp = NSMaxY(vf);
	    if (tmp > tr.y)
	      tr.y = tmp;
	    tmp = NSMinX(vf);
	    if (tmp < bl.x)
	      bl.x = tmp;
	    tmp = NSMinY(vf);
	    if (tmp < bl.y)
	      bl.y = tmp;
	  }
      }
    minMouse.x = point.x - bl.x;
    minMouse.y = point.y - bl.y;
    maxMouse.x = NSMaxX(sf) - tr.x + point.x;
    maxMouse.y = NSMaxY(sf) - tr.y + point.y;
  }

  if ([selection count] == 1)
    {
      oldMovingFrame = [[selection objectAtIndex: 0] frame];
      gpi = [[selection objectAtIndex: 0] initializeResizingInFrame: 
					     [self superview]
					   withKnob: IBNoneKnobPosition];
      suggestedFrame = oldMovingFrame;
    }
  
  // Set the arrows cursor in case it might be something else
  [[NSCursor arrowCursor] push];

  
  // Track mouse movements until left mouse up.
  // While we keep track of all mouse movements, we only act on a
  // movement when a periodic event arives (every 20th of a second)
  // in order to avoid excessive amounts of drawing.
  [NSEvent startPeriodicEventsAfterDelay: 0.1 withPeriod: 0.05];
  e = [NSApp nextEventMatchingMask: eventMask
	     untilDate: future
	     inMode: NSEventTrackingRunLoopMode
	     dequeue: YES];

  eType = [e type];

  {

    while ((eType != NSLeftMouseUp) && !mouseDidMove)
      {
	if (eType != NSPeriodic)
	  {
	    point = [superview convertPoint: [e locationInWindow]
			       fromView: nil];
	    if (NSEqualPoints(mouseDownPoint, point) == NO)
	      mouseDidMove = YES;
	  }
	e = [NSApp nextEventMatchingMask: eventMask
		   untilDate: future
		   inMode: NSEventTrackingRunLoopMode
		   dequeue: YES];
	eType = [e type];
      }
  }

  while (eType != NSLeftMouseUp)
    {
      if (eType != NSPeriodic)
	{
	  point = [superview convertPoint: [e locationInWindow]
			     fromView: nil];
	}
      else if (NSEqualPoints(point, lastPoint) == NO)
	{
	  [[self window] disableFlushWindow];

	  {
	    float	xDiff;
	    float	yDiff;

	    if (point.x < minMouse.x)
	      point.x = minMouse.x;
	    if (point.y < minMouse.y)
	      point.y = minMouse.y;
	    if (point.x > maxMouse.x)
	      point.x = maxMouse.x;
	    if (point.y > maxMouse.y)
	      point.y = maxMouse.y;

	    xDiff = point.x - lastPoint.x;
	    yDiff = point.y - lastPoint.y;
	    lastPoint = point;

	    if (dragStarted == NO)
	      {
		// Remove selection knobs before moving selection.
		dragStarted = YES;
		_displaySelection = NO;
		[self setNeedsDisplay: YES];
	      }

  	    if ([selection count] == 1)
  	      {
		id obj = [selection objectAtIndex: 0];
		if([obj isKindOfClass: [NSView class]])
		  {
		    [[selection objectAtIndex: 0] 
		      setFrameOrigin:
			NSMakePoint(NSMaxX([self bounds]),
				    NSMaxY([self bounds]))];
		    [superview display];
		    
		    r = oldMovingFrame;
		    r.origin.x += xDiff;
		    r.origin.y += yDiff;
		    r.origin.x = (int) r.origin.x;
		    r.origin.y = (int) r.origin.y;
		    r.size.width = (int) r.size.width;
		    r.size.height = (int) r.size.height;
		    oldMovingFrame = r;
		    
		    //case guideLine
		    if ( _followGuideLine )
		      {
			suggestedFrame = [obj _displayMovingFrameWithHint: r
					      andPlacementInfo: gpi];
		      }
		    else 
		      {
			suggestedFrame = NSMakeRect (NSMinX(r), 
						     NSMinY(r),
						     NSMaxX(r) - NSMinX(r),
						     NSMaxY(r) - NSMinY(r));
		      }
		    
		    [obj setFrame: suggestedFrame];
		    [obj setNeedsDisplay: YES];
		    
		  }
	      }
	    else
	      {
		enumerator = [selection objectEnumerator];		
		while ((subview = [enumerator nextObject]) != nil)
		  {
		    NSRect	oldFrame = [subview frame];
		    
		    r = oldFrame;
		    r.origin.x += xDiff;
		    r.origin.y += yDiff;
		    r.origin.x = (int) r.origin.x;
		    r.origin.y = (int) r.origin.y;
		    r.size.width = (int) r.size.width;
		    r.size.height = (int) r.size.height;
		    [subview setFrame: r];
		    [superview setNeedsDisplayInRect: oldFrame];
		    [subview setNeedsDisplay: YES];
		  }
	      }
	    
	    /*
	     * Flush any drawing performed for this event.
	     */
	    [[self window] displayIfNeeded];
	    [[self window] enableFlushWindow];
	    [[self window] flushWindow];
	  }
	}
      e = [NSApp nextEventMatchingMask: eventMask
		 untilDate: future
		 inMode: NSEventTrackingRunLoopMode
		 dequeue: YES];
      eType = [e type];
    }

  _displaySelection = YES;

  if ([selection count] == 1)
    [[selection objectAtIndex: 0] setFrame: suggestedFrame];

  if (mouseDidMove == NO && shouldUpdateSelection == YES)
    {
      [self selectObjects: [NSArray arrayWithObject: view]];
    }

  [self setNeedsDisplay: YES];
  [NSEvent stopPeriodicEvents];
  [NSCursor pop];
  /* Typically after a view has been dragged in a window, NSWindow
     sends a spurious mouseEntered event. Sending the mouseUp
     event back to the NSWindow resets the NSWindow's idea of the
     last mouse point so it doesn't think that the mouse has
     entered the view (since it was always there, it's just that
     the view moved).  */
  [[self window] postEvent: e atStart: NO];
  
  
  if (NSEqualPoints(point, mouseDownPoint) == NO)
    {
      // A subview was moved or resized, so we must mark the doucment as edited.
      [document touch];
    }

  [superview unlockFocus];

  // Restore window state to what it was when entering the method.
  [[self window] setAcceptsMouseMovedEvents: acceptsMouseMoved];
 
}

- (void) moveSelectionByX: (float)x 
		     andY: (float)y
{
  int i;
  int count = [selection count];

  for (i = 0; i < count; i++)
    {
      id v = [selection objectAtIndex: i];
      NSRect f = [v frame];
      
      f.origin.x += x;
      f.origin.y += y;

      [v setFrameOrigin: f.origin];
    }
}

- (void) resizeSelectionByX: (float)x 
		       andY: (float)y
{
  int i;
  int count = [selection count];

  for (i = 0; i < count; i++)
    {
      id v = [selection objectAtIndex: i];
      NSRect f = [v frame];
      
      f.size.width += x;
      f.size.height += y;

      [v setFrameSize: f.size];
    }
}

- (void) keyDown: (NSEvent *)theEvent
{
  NSString *characters = [theEvent characters];
  unichar character = 0;
  float moveBy = 1.0;

  if ([characters length] > 0)
    {
      character = [characters characterAtIndex: 0];
    }

  if (([theEvent modifierFlags] & NSShiftKeyMask) == NSShiftKeyMask)
    {
      if (([theEvent modifierFlags] & NSAlternateKeyMask) == NSAlternateKeyMask)
	{
	  moveBy = 10.0;
	}
      
      if ([selection count] == 1)
	{
	  switch (character)
	    {
	    case NSUpArrowFunctionKey:
	      [self resizeSelectionByX: 0 andY: 1*moveBy];
	      [self setNeedsDisplay: YES];
	      return;
	    case NSDownArrowFunctionKey:
	      [self resizeSelectionByX: 0 andY: -1*moveBy];
	      [self setNeedsDisplay: YES];
	      return;
	    case NSLeftArrowFunctionKey:
	      [self resizeSelectionByX: -1*moveBy andY: 0];
	      [self setNeedsDisplay: YES];
	      return;
	    case NSRightArrowFunctionKey:
	      [self resizeSelectionByX: 1*moveBy andY: 0];
	      [self setNeedsDisplay: YES];
	      return;
	    }
	}
    }
  else
    {
      if (([theEvent modifierFlags] & NSAlternateKeyMask) == NSAlternateKeyMask)
	{
	  moveBy = 10.0;
	}
      
      if ([selection count] > 0)
	{
	  switch (character)
	    {
	    case NSUpArrowFunctionKey:
	      [self moveSelectionByX: 0 andY: 1*moveBy];
	      [self setNeedsDisplay: YES];
	      return;
	    case NSDownArrowFunctionKey:
	      [self moveSelectionByX: 0 andY: -1*moveBy];
	      [self setNeedsDisplay: YES];
	      return;
	    case NSLeftArrowFunctionKey:
	      [self moveSelectionByX: -1*moveBy andY: 0];
	      [self setNeedsDisplay: YES];
	      return;
	    case NSRightArrowFunctionKey:
	      [self moveSelectionByX: 1*moveBy andY: 0];
	      [self setNeedsDisplay: YES];
	      return;
	    }
	}
    }
  [super keyDown: theEvent];

}

- (BOOL) acceptsTypeFromArray: (NSArray*)types
{
  if ([super acceptsTypeFromArray: types])
    {
      return YES;
    }
  else
    {
      return [types containsObject: IBViewPboardType];
    }
}

- (void) postDrawForView: (GormViewEditor *) viewEditor
{
  if (_displaySelection == NO)
    {
      return;
    }
  if (((id)openedSubeditor == (id)viewEditor) 
      && (openedSubeditor != nil)
      && ![openedSubeditor isKindOfClass: [GormInternalViewEditor class]])
    {
      GormDrawOpenKnobsForRect([viewEditor bounds]);
      GormShowFastKnobFills();
    }
  else if ([selection containsObject: viewEditor])
    {
      GormDrawKnobsForRect([viewEditor bounds]);
      GormShowFastKnobFills();
    }
}

- (void) postDraw: (NSRect) rect
{
  [super postDraw: rect];

  if (openedSubeditor 
      && ![openedSubeditor isKindOfClass: [GormInternalViewEditor class]])
    {
      GormDrawOpenKnobsForRect(
			       [self convertRect: [openedSubeditor bounds]
				     fromView: openedSubeditor]);
      GormShowFastKnobFills();
    }
  else if (_displaySelection)
    {
      int i;
      int count = [selection count];

      for ( i = 0; i < count ; i++ )
	{
	  GormDrawKnobsForRect([self convertRect:
				       [[selection objectAtIndex: i] bounds]
				     fromView: [selection objectAtIndex: i]]);
	  GormShowFastKnobFills();
	}
    }

}





#undef MAX
#undef MIN

#define MAX(A,B) ((A)>(B)?(A):(B))
#define MIN(A,B) ((A)<(B)?(A):(B))

int _sortViews(id view1, id view2, void *context)
{
  BOOL isVertical = *((BOOL *)context);
  int order = NSOrderedSame;
  NSRect rect1 = [[view1 editedObject] frame];
  NSRect rect2 = [[view2 editedObject] frame];

  if(!isVertical)
    {
      float y1 = rect1.origin.y;
      float y2 = rect2.origin.y;

      if(y1 == y2) 
	order = NSOrderedSame;
      else
	order = (y1 > y2)?NSOrderedAscending:NSOrderedDescending;
    }
  else
    {
      float x1 = rect1.origin.x;
      float x2 = rect2.origin.x;

      if(x1 == x2) 
	order = NSOrderedSame;
      else
	order = (x1 < x2)?NSOrderedAscending:NSOrderedDescending;
    }

  return order;
}

- (NSArray *) _sortByPosition: (NSArray *)subviews
		   isVertical: (BOOL)isVertical
{
  NSMutableArray *array = [subviews mutableCopy];
  NSArray *result = [array sortedArrayUsingFunction: _sortViews
			   context: &isVertical];
  return result;
}

- (BOOL) _shouldBeVertical: (NSArray *)subviews
{
  BOOL vertical = NO;
  NSEnumerator *enumerator = [subviews objectEnumerator];
  GormViewEditor *editor = nil;
  NSRect prevRect = NSZeroRect;
  NSRect currRect = NSZeroRect;
  int count = 0;

  // iterate over the list of views...
  while((editor = [enumerator nextObject]) != nil)
    {
      NSView *subview = [editor editedObject];
      currRect = [subview frame];

      if(!NSEqualRects(prevRect,NSZeroRect))
	{
	  float 
	    x1 = prevRect.origin.x, // pull these for convenience.
	    x2 = currRect.origin.x,
	    y1 = prevRect.origin.y,
	    y2 = currRect.origin.y,
	    h1 = prevRect.size.height,
	    w1 = prevRect.size.width;

	  if((x1 < x2 || x1 > x2) && ((y2 >= y1 && y2 <= (y1 + h1)) || 
				      (y2 <= y1 && y2 >= (y1 - h1))))
	    { 
	      count++;
	    }

	  if((y1 < y2 || y1 > y2) && ((x2 >= x1 && x2 <= (x1 + w1)) ||
				      (x2 <= x1 && x2 >= (x1 - w1))))
	    {
	      count--;
	    }
	}
      
      prevRect = currRect;
    }

  NSDebugLog(@"The vote is %d",count);

  if(count >= 0)
    vertical = YES;
  else
    vertical = NO;

  // return the result...
  return vertical;
}

- (void) groupSelectionInSplitView
{
  NSEnumerator *enumerator = nil;
  GormViewEditor *subview = nil;
  NSSplitView *splitView = nil;
  NSRect rect = NSZeroRect;
  GormViewEditor *editor = nil;
  NSView *superview = nil;
  NSArray *sortedviews = nil;
  BOOL vertical = NO;

  if ([selection count] < 2)
    {
      return;
    }
  
  enumerator = [selection objectEnumerator];
  
  while ((subview = [enumerator nextObject]) != nil)
    {
      superview = [subview superview];
      rect = NSUnionRect(rect, [subview frame]);
      [subview deactivate];
    }

  splitView = [[NSSplitView alloc] initWithFrame: rect];

  
  [document attachObject: splitView 
	    toParent: _editedObject];

  [superview addSubview: splitView];

  // positionally determine orientation
  vertical = [self _shouldBeVertical: selection];
  sortedviews = [self _sortByPosition: selection isVertical: vertical];
  [splitView setVertical: vertical];

  enumerator = [sortedviews objectEnumerator];
  
  editor = (GormViewEditor *)[document editorForObject: splitView
				       inEditor: self
				       create: YES];

  while ((subview = [enumerator nextObject]) != nil)
    {
      id eO = [subview editedObject];
      [splitView addSubview: [subview editedObject]];
      [document attachObject: [subview editedObject]
		toParent: splitView];
      [subview close];
      [document editorForObject: eO
	  inEditor: editor
	  create: YES];
    }
  
  [self selectObjects: [NSArray arrayWithObject: editor]];
}

- (void) groupSelectionInBox
{
  NSEnumerator *enumerator = nil;
  GormViewEditor *subview = nil;
  NSBox *box = nil;
  NSRect rect = NSZeroRect;
  GormViewEditor *editor = nil;
  NSView *superview = nil;

  if ([selection count] < 1)
    {
      return;
    }
  
  enumerator = [selection objectEnumerator];
  
  while ((subview = [enumerator nextObject]) != nil)
    {
      superview = [subview superview];
      rect = NSUnionRect(rect, [subview frame]);
      [subview deactivate];
    }

  box = [[NSBox alloc] initWithFrame: NSZeroRect];
  [box setFrameFromContentFrame: rect];
  
  [document attachObject: box
	    toParent: _editedObject];

  [superview addSubview: box];


  enumerator = [selection objectEnumerator];

  while ((subview = [enumerator nextObject]) != nil)
    {
      NSPoint frameOrigin;
      [box addSubview: [subview editedObject]];
      frameOrigin = [[subview editedObject] frame].origin;
      frameOrigin.x -= rect.origin.x;
      frameOrigin.y -= rect.origin.y;
      [[subview editedObject] setFrameOrigin: frameOrigin];
      [document attachObject: [subview editedObject]
		toParent: box];
      [subview close];
    }

  editor = (GormViewEditor *)[document editorForObject: box
				       inEditor: self
				       create: YES];
  
  [self selectObjects: [NSArray arrayWithObject: editor]];
}

- (void) groupSelectionInScrollView
{
  NSEnumerator *enumerator = nil;
  GormViewEditor *subview = nil;
  NSView *view = nil;
  NSScrollView *scrollView = nil;
  NSRect rect = NSZeroRect;
  GormViewEditor *editor = nil;
  NSView *superview = nil;

  if ([selection count] < 1)
    {
      return;
    }
  
  // if there is more than one view we must join them together.
  if([selection count] > 1)
    {
      // deactivate the editor for each subview.
      enumerator = [selection objectEnumerator];
      while ((subview = [enumerator nextObject]) != nil)
	{
	  superview = [subview superview];
	  rect = NSUnionRect(rect, [subview frame]);
	  [subview deactivate];
	}

      // create the containing view.
      view = [[NSView alloc] initWithFrame: 
			       NSMakeRect(0, 0, rect.size.width, rect.size.height)];
      // create scroll view now.
      scrollView = [[NSScrollView alloc] initWithFrame: rect];
      [scrollView setHasHorizontalScroller: YES];
      [scrollView setHasVerticalScroller: YES];
      [scrollView setBorderType: NSBezelBorder];

      // attach the scroll view...
      [document attachObject: scrollView
		toParent: _editedObject];
      [superview addSubview: scrollView];
      [scrollView setDocumentView: view];

      // add the views.
      enumerator = [selection objectEnumerator];
      while ((subview = [enumerator nextObject]) != nil)
	{
	  NSPoint frameOrigin;
	  [view addSubview: [subview editedObject]];
	  frameOrigin = [[subview editedObject] frame].origin;
	  frameOrigin.x -= rect.origin.x;
	  frameOrigin.y -= rect.origin.y;
	  [[subview editedObject] setFrameOrigin: frameOrigin];
	  [document attachObject: [subview editedObject]
		    toParent: scrollView];
	  [subview close];
	}
    }
  else if([selection count] == 1)
    {
      NSPoint frameOrigin;
      id v = nil;

      // since we have one view, it will be used as the document view.
      subview = [selection objectAtIndex: 0];
      superview = [subview superview];
      rect = NSUnionRect(rect, [subview frame]);
      [subview deactivate];

      // create scroll view now.
      scrollView = [[NSScrollView alloc] initWithFrame: rect];
      [scrollView setHasHorizontalScroller: YES];
      [scrollView setHasVerticalScroller: YES];
      [scrollView setBorderType: NSBezelBorder];

      // attach the scroll view...
      [document attachObject: scrollView
		toParent: _editedObject];
      [superview addSubview: scrollView];

      // add the view
      v = [subview editedObject];
      [scrollView setDocumentView: v];

      // set the origin..
      frameOrigin = [v frame].origin;
      frameOrigin.x -= rect.origin.x;
      frameOrigin.y -= rect.origin.y;
      [v setFrameOrigin: frameOrigin];
      [subview close];
    }
  
  editor = (GormViewEditor *)[document editorForObject: scrollView
				       inEditor: self
				       create: YES];
  
  [self selectObjects: [NSArray arrayWithObject: editor]];
}

@class GormBoxEditor;
@class GormSplitViewEditor;
@class GormScrollViewEditor;

- (void) ungroup
{
  NSView *toUngroup;

  if ([selection count] != 1)
    return;
  
  NSDebugLog(@"ungroup called");

  toUngroup = [selection objectAtIndex: 0];

  NSDebugLog(@"toUngroup = %@",[toUngroup description]);

  if ([toUngroup isKindOfClass: [GormBoxEditor class]]
      || [toUngroup isKindOfClass: [GormSplitViewEditor class]]
      || [toUngroup isKindOfClass: [GormScrollViewEditor class]]
      )
    {
      id contentView = toUngroup;

      NSMutableArray *newSelection = [NSMutableArray array];
      NSArray *views;
      int i;
      views = [contentView destroyAndListSubviews];
      for (i = 0; i < [views count]; i++)
	{
	  id v = [views objectAtIndex: i];
	  [_editedObject addSubview: v];
	  [newSelection addObject:
			  [document editorForObject: v
				    inEditor: self
				    create: YES]];
	}
      [self selectObjects: newSelection];
      
    }

}

- (void) _addViewToDocument: (NSView *)view
{
  NSEnumerator *en = nil;
  NSView *sub = nil;
  NSView *par = [view superview];

  if([sub isKindOfClass: [GormViewEditor class]])
    return;

  if([par isKindOfClass: [GormViewEditor class]])
    {
      par = [(GormViewEditor *)par editedObject];
    }

  [document attachObject: view toParent: par];
  en = [[view subviews] objectEnumerator];
  while((sub = [en nextObject]) != nil)
    {
      [self _addViewToDocument: sub];
    }
}

- (void) pasteInView: (NSView *)view
{
  NSPasteboard	 *pb = [NSPasteboard generalPasteboard];
  NSMutableArray *array = [NSMutableArray array];
  NSArray	 *views;
  NSEnumerator	 *enumerator;
  NSView         *sub;

  /*
   * Ask the document to get the copied views from the pasteboard and add
   * them to it's collection of known objects.
   */
  views = [document pasteType: IBViewPboardType
	       fromPasteboard: pb
		       parent: _editedObject];
  /*
   * Now make all the views subviews of ourself.
   */
  enumerator = [views objectEnumerator];
  while ((sub = [enumerator nextObject]) != nil)
    {
      if ([sub isKindOfClass: [NSView class]] == YES)
	{
	  //
	  // Correct the frame if it is outside of the containing view.
	  // this prevents issues where the subview is placed outside the
	  // viewable region of the superview.
	  //
	  if(NSContainsRect([view frame], [sub frame]) == NO)
	    {
	      NSRect newFrame = [sub frame];
	      newFrame.origin.x = 0;
	      newFrame.origin.y = 0;
	      [sub setFrame: newFrame];
	    }

	  [view addSubview: sub];
	  [self _addViewToDocument: sub];
	  [array addObject:
		   [document editorForObject: sub 
			     inEditor: self 
			     create: YES]];
	}
    }

  [self selectObjects: array];
}

@end