/* Interface for NSMethodSignature for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

   Written by:  Mike Kienenberger
   Date: Jun 1998
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
   */ 

#ifndef __NSProtocolChecker_h_GNUSTEP_BASE_INCLUDE
#define __NSProtocolChecker_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>

@class Protocol;

@interface NSProtocolChecker : NSObject
{
  Protocol *myProtocol;
  NSObject *myTarget;
}

// Creating a checker

+ (id) protocolCheckerWithTarget: (NSObject *)anObject
			protocol: (Protocol *)aProtocol;
- (id) initWithTarget: (NSObject *)anObject protocol: (Protocol *)aProtocol;

// Reimplemented NSObject methods
 
- (void)forwardInvocation: (NSInvocation *)anInvocation;
- (struct objc_method_description *) methodDescriptionForSelector: (SEL)aSelector;
   
// Getting information
- (Protocol *) protocol;
- (NSObject *) target;

@end

#endif
