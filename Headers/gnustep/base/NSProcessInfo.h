/* Interface for NSProcessInfo for GNUStep
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.

   Written by:  Georg Tuparev, EMBL & Academia Naturalis, 
                Heidelberg, Germany
                Tuparev@EMBL-Heidelberg.de
   Last update: 08-aug-1995
	 
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __NSProcessInfo_h_GNUSTEP_BASE_INCLUDE
#define __NSProcessInfo_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>

@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSData;
@class NSMutableSet;

@interface NSProcessInfo: NSObject

/* Getting an NSProcessInfo Object */
+ (NSProcessInfo *)processInfo;

/* Returning Process Information */
- (NSArray *)arguments;
- (NSDictionary *)environment;
- (NSString *)hostName;
- (NSString *)processName;
- (NSString *)globallyUniqueString;

/* Specifying a Process Name */
- (void)setProcessName:(NSString *)newName;

@end

#ifndef	NO_GNUSTEP

@interface	NSProcessInfo (GNUstep)
/* This method returns a set of debug levels set using the
 * --GNU-Debug=... command line option. */
- (NSMutableSet*) debugSet;
@end

/*
 * This function determines if the specified debug level is present in the
 * set of active debug levels.
 */
extern BOOL GSDebugSet(NSString *level);

#endif

#endif /* __NSProcessInfo_h_GNUSTEP_BASE_INCLUDE */
