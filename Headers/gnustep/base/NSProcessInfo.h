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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#ifndef __NSProcessInfo_h_GNUSTEP_BASE_INCLUDE
#define __NSProcessInfo_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

@class NSArray;
@class NSMutableArray;
@class NSDictionary;
@class NSData;
@class NSMutableSet;

#ifndef	STRICT_OPENSTEP
/*
 * Constants returned by -operatingSystem
 * NB. The presence of a constant in this list does *NOT* imply that
 * the named operating system is supported.  Some values are provided
 * for MacOS-X compatibility only.
 */
enum {
  NSWindowsNTOperatingSystem = 1,
  NSWindows95OperatingSystem,
  NSSolarisOperatingSystem,
  NSHPUXOperatingSystem,
  NSMACHOperatingSystem,
  NSSunOSOperatingSystem,
  NSOSF1OperatingSystem,
  NSGNULinuxOperatingSystem = 100,
  NSBSDOperatingSystem
};
#endif


@interface NSProcessInfo: NSObject

+ (NSProcessInfo*) processInfo;

- (NSArray*) arguments;
- (NSDictionary*) environment;
- (NSString*) globallyUniqueString;
- (NSString*) hostName;
#ifndef	STRICT_OPENSTEP
- (unsigned int) operatingSystem;
- (NSString*) operatingSystemName;
- (int) processIdentifier;
#endif
- (NSString*) processName;

- (void) setProcessName: (NSString*)newName;

@end

#ifndef	NO_GNUSTEP

@interface	NSProcessInfo (GNUstep)
- (NSMutableSet*) debugSet;
- (BOOL) setLogFile: (NSString*)path;
+ (void) initializeWithArguments: (char**)argv
                           count: (int)argc
                     environment: (char**)env;
@end

/*
 * This function determines if the specified debug level is present in the
 * set of active debug levels.
 */
GS_EXPORT BOOL GSDebugSet(NSString *level);

#endif

#endif /* __NSProcessInfo_h_GNUSTEP_BASE_INCLUDE */
