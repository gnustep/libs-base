/* Interface for NSInvocation for GNUStep
   Copyright (C) 1994 NeXT Computer, Inc.
   
   This file is part of the GNU Objective C Class Library.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __NSInvocation_h_OBJECTS_INCLUDE
#define __NSInvocation_h_OBJECTS_INCLUDE

#include <objects/stdobjects.h>

@class NSMethodSignature;

@interface NSInvocation : NSObject
{
  id methodSignature;
  arglist_t argFrame;
  retval_t retFrame;
}

+ (NSInvocation*) invocationWithMethodSignature: (NSMethodSignature*)ms;
+ (NSInvocation*) invocationWithMethodSignature: (NSMethodSignature*)ms
   frame: (arglist_t)argFrame;

- (void) getArgument: (void*)argumentLocation atIndex: (int)index;
- (void) getReturnValue: (void*)returnLocation;

- (NSMethodSignature*) methodSignature;
- (SEL) selector;
- (void) setArgument: (void*)argumentLocation atIndex: (int)index;
- (void) setReturnValue: (void*)returnLocation;
- (void) setSelector: (SEL)aSelector;
- (void) setTarget: (id)target;
- (id) target;

- (void) invoke;
- (void) invokeWithTarget: (id)target;

@end

#endif /* __NSInvocation_h_OBJECTS_INCLUDE */
