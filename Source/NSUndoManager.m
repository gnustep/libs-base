/** Implementatikon for <NSUndoManager> for GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   
   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#include "config.h"
#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSInvocation.h>
#include <Foundation/NSException.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSUndoManager.h>

/* Public notifications */
NSString *NSUndoManagerCheckpointNotification =
	@"NSUndoManagerCheckpointNotification";
NSString *NSUndoManagerDidOpenUndoGroupNotification =
	@"NSUndoManagerDidOpenUndoGroupNotification";
NSString *NSUndoManagerDidRedoChangeNotification =
	@"NSUndoManagerDidRedoChangeNotification";
NSString *NSUndoManagerDidUndoChangeNotification =
	@"NSUndoManagerDidUndoChangeNotification";
NSString *NSUndoManagerWillCloseUndoGroupNotification =
	@"NSUndoManagerWillCloseUndoGroupNotification";
NSString *NSUndoManagerWillRedoChangeNotification =
	@"NSUndoManagerWillRedoChangeNotification";
NSString *NSUndoManagerWillUndoChangeNotification =
	@"NSUndoManagerWillUndoChangeNotification";


/*
 *	Private class for grouping undo/redo actions.
 */
@interface	PrivateUndoGroup : NSObject
{
    PrivateUndoGroup	*parent;
    NSMutableArray	*actions;
}
- (NSMutableArray*) actions;
- (void) addInvocation: (NSInvocation*)inv;
- (id) initWithParent: (PrivateUndoGroup*)parent;
- (void) orphan;
- (PrivateUndoGroup*) parent;
- (void) perform;
- (BOOL) removeActionsForTarget: (id)target;
@end

@implementation	PrivateUndoGroup

- (NSMutableArray*) actions
{
  return actions;
}

- (void) addInvocation: (NSInvocation*)inv
{
  if (actions == nil)
    {
      actions = [[NSMutableArray alloc] initWithCapacity: 2];
    }
  [actions addObject: inv];
}

- (void) dealloc
{
  RELEASE(actions);
  RELEASE(parent);
  [super dealloc];
}

- (id) initWithParent: (PrivateUndoGroup*)p
{
  self = [super init];
  if (self)
    {
      parent = RETAIN(p);
      actions = nil;
    }
  return self;
}

- (void) orphan
{
  DESTROY(parent);
}

- (PrivateUndoGroup*) parent
{
  return parent;
}

- (void) perform
{
  if (actions != nil)
    {
      unsigned	i = [actions count];

      while (i-- > 0)
	{
	  [[actions objectAtIndex: i] invoke];
	}
    }
}

- (BOOL) removeActionsForTarget: (id)target
{
  if (actions != nil)
    {
      unsigned	i = [actions count];

      while (i-- > 0)
	{
	  NSInvocation	*inv = [actions objectAtIndex: i];

	  if ([inv target] == target)
	    {
	      [actions removeObjectAtIndex: i];
	    }
	}
      if ([actions count] > 0)
	{
	  return YES;
	}
    }
  return NO;
}

@end



/*
 *	Private catagory for the method used to handle default grouping
 */
@interface NSUndoManager (Private)
- (void) _loop: (id)arg;
@end

@implementation NSUndoManager (Private)
- (void) _loop: (id)arg
{
  if (_groupsByEvent)
    {
      if (_group != nil)
	{
	  [self endUndoGrouping];
	}
      [self beginUndoGrouping];
    }
}
@end



/*
 *	The main part for the NSUndoManager implementation.
 */
@implementation NSUndoManager

- (void) beginUndoGrouping
{
  PrivateUndoGroup	*parent;

  if (_isUndoing == NO)
    {
      [[NSNotificationCenter defaultCenter]
	  postNotificationName: NSUndoManagerCheckpointNotification
			object: self];
    }
  parent = (PrivateUndoGroup*)_group;
  _group = [[PrivateUndoGroup alloc] initWithParent: parent];
  if (_group == nil)
    {
      _group = parent;
      [NSException raise: NSInternalInconsistencyException
		  format: @"beginUndoGrouping failed to greate group"];
    }
  else
    {
      RELEASE(parent);

      [[NSNotificationCenter defaultCenter]
	  postNotificationName: NSUndoManagerDidOpenUndoGroupNotification
			object: self];
    }
}

- (BOOL) canRedo
{
  [[NSNotificationCenter defaultCenter]
      postNotificationName: NSUndoManagerCheckpointNotification
		    object: self];
  if ([_redoStack count] > 0)
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

- (BOOL) canUndo
{
  if ([_undoStack count] > 0)
    {
      return YES;
    }
  if (_group != nil && [[_group actions] count] > 0)
    {
      return YES;
    }
  return NO;
}

- (void) dealloc
{
  [[NSRunLoop currentRunLoop] cancelPerformSelector: @selector(_loop:)
					     target: self
					   argument: nil];
  RELEASE(_redoStack);
  RELEASE(_undoStack);
  RELEASE(_actionName);
  RELEASE(_group);
  RELEASE(_modes);
  [super dealloc];
}

- (void) disableUndoRegistration
{
  _disableCount++;
}

- (void) enableUndoRegistration
{
  if (_disableCount > 0)
    {
      _disableCount--;
      _registeredUndo = NO;	/* No operations since registration enabled. */
    }
  else
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"enableUndoRegistration without disable"];
    }
}

- (void) endUndoGrouping
{
  PrivateUndoGroup	*g;
  PrivateUndoGroup	*p;

  if (_group == nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"endUndoGrouping without beginUndoGrouping"];
    }
  [[NSNotificationCenter defaultCenter]
      postNotificationName: NSUndoManagerCheckpointNotification
		    object: self];
  g = (PrivateUndoGroup*)_group;
  p = RETAIN([g parent]);
  _group = p;
  [g orphan];
  [[NSNotificationCenter defaultCenter]
      postNotificationName: NSUndoManagerWillCloseUndoGroupNotification
		    object: self];
  if (p == nil)
    {
      if (_isUndoing)
	{
	  if (_levelsOfUndo > 0 && [_redoStack count] == _levelsOfUndo)
	    {
	      [_redoStack removeObjectAtIndex: 0];
	    }
	  [_redoStack addObject: g];
	}
      else
	{
	  if (_levelsOfUndo > 0 && [_undoStack count] == _levelsOfUndo)
	    {
	      [_undoStack removeObjectAtIndex: 0];
	    }
	  [_undoStack addObject: g];
	}
    }
  else if ([g actions] != nil)
    {
      NSArray	*a = [g actions];
      unsigned	i;

      for (i = 0; i < [a count]; i++)
	{
	  [p addInvocation: [a objectAtIndex: i]];
	}
    }
  RELEASE(g);
}

- (void) forwardInvocation: (NSInvocation*)anInvocation
{
  if (_disableCount == 0)
    {
      if (_nextTarget == nil)
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"forwardInvocation without perparation"];
	}
      if (_group == nil)
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"forwardInvocation without beginUndoGrouping"];
	}
      [anInvocation setTarget: _nextTarget];
      _nextTarget = nil;
      [_group addInvocation: anInvocation];
      if (_isUndoing == NO)
	{
	  [_redoStack removeAllObjects];
	}
      _registeredUndo = YES;
    }
}

- (int) groupingLevel
{
  PrivateUndoGroup	*g = (PrivateUndoGroup*)_group;
  int			level = 0;

  while (g != nil)
    {
      level++;
      g = [g parent];
    }
  return level;
}

- (BOOL) groupsByEvent
{
  return _groupsByEvent;
}

- (id) init
{
  self = [super init];
  if (self)
    {
      _actionName = @"";
      _redoStack = [[NSMutableArray alloc] initWithCapacity: 16];
      _undoStack = [[NSMutableArray alloc] initWithCapacity: 16];
      [self setRunLoopModes:
	[NSArray arrayWithObjects: NSDefaultRunLoopMode, nil]];
    }
  return self;
}

- (BOOL) isRedoing
{
  return _isRedoing;
}

- (BOOL) isUndoing
{
  return _isUndoing;
}

- (BOOL) isUndoRegistrationEnabled
{
  if (_disableCount == 0)
    {
      return YES;
    }
  else
    {
      return NO;
    }
}

- (unsigned int) levelsOfUndo
{
  return _levelsOfUndo;
}

- (id) prepareWithInvocationTarget: (id)target
{
  _nextTarget = target;
  return self;
}

- (void) redo
{
  if (_isUndoing || _isRedoing)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"redo while undoing or redoing"];
    }
  [[NSNotificationCenter defaultCenter]
      postNotificationName: NSUndoManagerCheckpointNotification
		    object: self];
  if ([_redoStack count] > 0)
    {
      PrivateUndoGroup	*oldGroup;
      PrivateUndoGroup	*groupToRedo;

      [[NSNotificationCenter defaultCenter]
	  postNotificationName: NSUndoManagerWillRedoChangeNotification
		    object: self];
      groupToRedo = [_redoStack objectAtIndex: [_redoStack count] - 1];
      IF_NO_GC([groupToRedo retain]);
      [_redoStack removeObjectAtIndex: [_redoStack count] - 1];
      oldGroup = _group;
      _group = nil;
      _isRedoing = YES;
      [self beginUndoGrouping];
      [groupToRedo perform];
      RELEASE(groupToRedo);
      [self endUndoGrouping];
      _isRedoing = NO;
      _group = oldGroup;
      [[NSNotificationCenter defaultCenter]
	  postNotificationName: NSUndoManagerDidRedoChangeNotification
			object: self];
    }
}

- (NSString*) redoActionName
{
  if ([self canRedo] == NO)
    {
      return nil;
    }
  return _actionName;
}

- (NSString*) redoMenuItemTitle
{
  return [self redoMenuTitleForUndoActionName: [self redoActionName]];
}

- (NSString*) redoMenuTitleForUndoActionName: (NSString*)name
{
  if (name)
    {
      if ([name isEqual: @""])
	{
	  return @"Redo";
	}
      else
	{
	  return [NSString stringWithFormat: @"Redo %@", name];
	}
    }
  return name;
}

- (void) registerUndoWithTarget: (id)target
		       selector: (SEL)aSelector
			 object: (id)anObject
{
  if (_disableCount == 0)
    {
      NSMethodSignature	*sig;
      NSInvocation	*inv;
      PrivateUndoGroup	*g;

      if (_group == nil)
	{
	  [NSException raise: NSInternalInconsistencyException
		      format: @"registerUndo without beginUndoGrouping"];
	}
      g = _group;
      sig = [target methodSignatureForSelector: aSelector];
      inv = [NSInvocation invocationWithMethodSignature: sig];
      [inv setTarget: target];
      [inv setSelector: aSelector];
      [inv setArgument: &anObject atIndex: 2];
      [g addInvocation: inv];
      if (_isUndoing == NO)
	{
	  [_redoStack removeAllObjects];
	}
      _registeredUndo = YES;
    }
}

- (void) removeAllActions
{
  [_redoStack removeAllObjects];
  [_undoStack removeAllObjects];
  _isRedoing = NO;
  _isUndoing = NO;
  _disableCount = 0;
}

- (void) removeAllActionsWithTarget: (id)target
{
  unsigned 	i;

  i = [_redoStack count];
  while (i-- > 0)
    {
      PrivateUndoGroup	*g;

      g = [_redoStack objectAtIndex: i];
      if ([g removeActionsForTarget: target] == NO)
	{
	  [_redoStack removeObjectAtIndex: i];
	}
    }
  i = [_undoStack count];
  while (i-- > 0)
    {
      PrivateUndoGroup	*g;

      g = [_undoStack objectAtIndex: i];
      if ([g removeActionsForTarget: target] == NO)
	{
	  [_undoStack removeObjectAtIndex: i];
	}
    }
}

- (NSArray*) runLoopModes
{
  return _modes;
}

- (void) setActionName: (NSString*)name
{
  if (name != nil && _actionName != name)
    {
      ASSIGNCOPY(_actionName, name);
    }
}

- (void) setGroupsByEvent: (BOOL)flag
{
  if (_groupsByEvent != flag)
    {
      _groupsByEvent = flag;
    }
}

- (void) setLevelsOfUndo: (unsigned)num
{
  _levelsOfUndo = num;
  if (num > 0)
    {
      while ([_undoStack count] > num)
	{
	  [_undoStack removeObjectAtIndex: 0];
	}
      while ([_redoStack count] > num)
	{
	  [_redoStack removeObjectAtIndex: 0];
	}
    }
}

- (void) setRunLoopModes: (NSArray*)newModes
{
  if (_modes != newModes)
    {
      ASSIGN(_modes, newModes);
      [[NSRunLoop currentRunLoop] cancelPerformSelector: @selector(_loop:)
						 target: self
					       argument: nil];
      [[NSRunLoop currentRunLoop] performSelector: @selector(_loop:)
					   target: self
					 argument: nil
					    order: 0
					    modes: _modes];
    }
}

- (void) undo
{
  if ([self groupingLevel] == 1)
    {
      [self endUndoGrouping];
    }
  if (_group != nil)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"undo with nested groups"];
    }
  [self undoNestedGroup];
}

- (NSString*) undoActionName
{
  if ([self canUndo] == NO)
    {
      return nil;
    }
  return _actionName;
}

- (NSString*) undoMenuItemTitle
{
  return [self undoMenuTitleForUndoActionName: [self undoActionName]];
}

- (NSString*) undoMenuTitleForUndoActionName: (NSString*)name
{
  if (name)
    {
      if ([name isEqual: @""])
	{
	  return @"Undo";
	}
      else
	{
	  return [NSString stringWithFormat: @"Undo %@", name];
	}
    }
  return name;
}

- (void) undoNestedGroup
{
  PrivateUndoGroup	*oldGroup;
  PrivateUndoGroup	*groupToUndo;

  [[NSNotificationCenter defaultCenter]
      postNotificationName: NSUndoManagerCheckpointNotification
		    object: self];
#if 0
/*
 *	The documentation says we should raise an exception - but I can't
 *	make sense of it - raising an exception seems to break everything.
 *	It would make more sense to raise an exception if NO undo operations
 *	had been registered.
 */
  if (_registeredUndo)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"undoNestedGroup with registered undo ops"];
    }
#endif
  if (_isUndoing || _isRedoing)
    {
      [NSException raise: NSInternalInconsistencyException
		  format: @"undoNestedGroup while undoing or redoing"];
      }
  if (_group != nil && [_undoStack count] == 0)
    {
      return;
    }
  [[NSNotificationCenter defaultCenter]
      postNotificationName: NSUndoManagerWillUndoChangeNotification
		    object: self];
  oldGroup = _group;
  _group = nil;
  _isUndoing = YES;
  if (oldGroup)
    {
      groupToUndo = oldGroup;
      oldGroup = RETAIN([oldGroup parent]);
      [groupToUndo orphan];
      [_redoStack addObject: groupToUndo];
    }
  else
    {
      groupToUndo = [_undoStack objectAtIndex: [_undoStack count] - 1];
      IF_NO_GC([groupToUndo retain]);
      [_undoStack removeObjectAtIndex: [_undoStack count] - 1];
    }
  [self beginUndoGrouping];
  [groupToUndo perform];
  RELEASE(groupToUndo);
  [self endUndoGrouping];
  _isUndoing = NO;
  _group = oldGroup;
  [[NSNotificationCenter defaultCenter]
      postNotificationName: NSUndoManagerDidUndoChangeNotification
		    object: self];
}

@end

