/** Additional functions for GNUStep
   Copyright (C) 2005-2006 Free Software Foundation, Inc.

   Written by:  Sheldon Gill
   Date:    2005
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
 
   AutogsdocSource:	Additions/GSFunctions.m
   */ 

#ifndef __GSFunctions_h_GNUSTEP_BASE_INCLUDE
#define __GSFunctions_h_GNUSTEP_BASE_INCLUDE

#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSObjCRuntime.h"
#include "GNUstepBase/GNUstep.h"

#if	defined(__cplusplus)
extern "C" {
#endif

@class	NSArray;
@class	NSString;


/**
 * Returns the system error message for the given error number
 */
GS_EXPORT NSString *GSErrorString(long errorNumber);

/**
 * <p>Returns the error message for the last system error.</p>
 * On *nix, this is equivalent to strerror(errno).
 * On MS-Windows this is the message for GetLastError().
 */
static inline NSString *GSLastError(void)
{
#if defined(__MINGW32__)
    return GSErrorString(GetLastError());
#else
    return GSErrorString(errno);
#endif
}

/**
 * <p>Returns the error message for the last sockets library
 * error.</p>
 * On *nix, this is equivalent to strerror(errno).
 * On MS-Windows this is the message for WSAGetLastError().
 */
static inline NSString *GSLastSocketError(void)
{
#if defined(__MINGW32__)
    return GSErrorString(WSAGetLastError());
#else
    return GSErrorString(errno);
#endif
}

/**
 * <p>Prints a message to fptr using the format string provided and any
 * additional arguments.  The format string is interpreted as by
 * the NSString formatted initialisers, and understands the '%@' syntax
 * for printing an object.
 * </p>
 * <p>The data is written to the file pointer in the default CString
 * encoding if possible, as a UTF8 string otherwise.
 * </p>
 * <p>This function is recommended for printing general log messages.
 * For debug messages use NSDebugLog() and friends.  For error logging
 * use NSLog(), and for warnings you might consider NSWarnLog().
 * </p>
 */
GS_EXPORT BOOL GSPrintf (FILE *fptr, NSString *format, ...);

/**
 * Try to locate file/directory (aName).(anExtension) in paths.
 * Will return the first found or nil if nothing is found.
 */
GS_EXPORT NSString *GSFindNamedFile(NSArray *paths, NSString *aName,
  NSString *anExtension);

#if	defined(__cplusplus)
}
#endif

#endif /* __NSPathUtilities_h_GNUSTEP_BASE_INCLUDE */
