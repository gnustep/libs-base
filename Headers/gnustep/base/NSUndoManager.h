/* Interface for <NSUndoManager> for GNUStep
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

#ifndef __NSUndoManager_h_OBJECTS_INCLUDE
#define __NSUndoManager_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>
#include <Foundation/NSString.h>

@class NSArray;
@class NSMutableArray;
@class NSInvocation;

/* Public notification */
GS_EXPORT NSString *NSUndoManagerCheckpointNotification;
GS_EXPORT NSString *NSUndoManagerDidOpenUndoGroupNotification;
GS_EXPORT NSString *NSUndoManagerDidRedoChangeNotification;
GS_EXPORT NSString *NSUndoManagerDidUndoChangeNotification;
GS_EXPORT NSString *NSUndoManagerWillCloseUndoGroupNotification;
GS_EXPORT NSString *NSUndoManagerWillRedoChangeNotification;
GS_EXPORT NSString *NSUndoManagerWillUndoChangeNotification;

@interface NSUndoManager: NSObject
{
@private
    NSMutableArray	*_redoStack;
    NSMutableArray	*_undoStack;
    NSString		*_actionName;
    id			_group;
    id			_nextTarget;
    NSArray		*_modes;
    BOOL		_isRedoing;
    BOOL		_isUndoing;
    BOOL		_groupsByEvent;
    BOOL		_registeredUndo;
    unsigned		_disableCount;
    unsigned		_levelsOfUndo;
}

- (void) beginUndoGrouping;
- (BOOL) canRedo;
- (BOOL) canUndo;
- (void) disableUndoRegistration;
- (void) enableUndoRegistration;
- (void) endUndoGrouping;
- (void) forwardInvocation: (NSInvocation*)anInvocation;
- (int) groupingLevel;
- (BOOL) groupsByEvent;
- (BOOL) isRedoing;
- (BOOL) isUndoing;
- (BOOL) isUndoRegistrationEnabled;
- (unsigned int) levelsOfUndo;
- (id) prepareWithInvocationTarget: (id)target;
- (void) redo;
- (NSString*) redoActionName;
- (NSString*) redoMenuItemTitle;
- (NSString*) redoMenuTitleForUndoActionName: (NSString*)name;
- (void) registerUndoWithTarget: (id)target
		       selector: (SEL)aSelector
			 object: (id)anObject;
- (void) removeAllActions;
- (void) removeAllActionsWithTarget: (id)target;
- (NSArray*) runLoopModes;
- (void) setActionName: (NSString*)name;
- (void) setGroupsByEvent: (BOOL)flag;
- (void) setLevelsOfUndo: (unsigned)num;
- (void) setRunLoopModes: (NSArray*)newModes;
- (void) undo;
- (NSString*) undoActionName;
- (NSString*) undoMenuItemTitle;
- (NSString*) undoMenuTitleForUndoActionName: (NSString*)name;
- (void) undoNestedGroup;

@end

#endif /* __NSUndoManager_h_OBJECTS_INCLUDE */
