/** Declaration of extension methods and functions for standard classes

   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   and:         Adam Fedor <fedor@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   AutogsdocSource: Additions/GSCategories.m

*/

#ifndef	INCLUDED_GS_CATEGORIES_H
#define	INCLUDED_GS_CATEGORIES_H
#include "GNUstepBase/GSVersionMacros.h"

#include <Foundation/Foundation.h>

/* The following ifndef prevents the categories declared in this file being
 * seen in GNUstep code.  This is necessary because those category
 * declarations are also present in the header files for the corresponding
 * classes in GNUstep.  The separate category declarations in this file
 * are only needed for software using the GNUstep Additions library
 * without the main GNUstep base library.
 */
#ifndef GNUSTEP

#include <string.h>

#ifdef NeXT_Foundation_LIBRARY
#include <CoreFoundation/CFString.h>
#endif

#include "GNUstepBase/preface.h"
#include "GNUstepBase/GSObjCRuntime.h"
#include "GNUstepBase/GNUstep.h"

#if	defined(__cplusplus)
extern "C" {
#endif

#if	OS_API_VERSION(GS_API_NONE,GS_API_LATEST)

@class NSMutableSet;


/* ------------------------------------------------------------------------
 * Macros
 */

// Following are also defined in base/Headers/Foundation/NSDebug.h
#ifdef DEBUG
#define NSDebugLLog(level, format, args...) \
    do { if (GSDebugSet(level) == YES) \
        NSLog(format , ## args); } while (0)

#define NSDebugLog(format, args...) \
    do { if (GSDebugSet(@"dflt") == YES) \
        NSLog(format , ## args); } while (0)

#define NSDebugFLLog(level, format, args...) \
    do { if (GSDebugSet(level) == YES) { \
        NSString *fmt = GSDebugFunctionMsg( \
        __PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
        NSLog(fmt , ## args); }} while (0)

#define NSDebugFLog(format, args...) \
    do { if (GSDebugSet(@"dflt") == YES) { \
        NSString *fmt = GSDebugFunctionMsg( \
        __PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
        NSLog(fmt , ## args); }} while (0)

#define NSDebugMLLog(level, format, args...) \
    do { if (GSDebugSet(level) == YES) { \
        NSString *fmt = GSDebugMethodMsg( \
        self, _cmd, __FILE__, __LINE__, format); \
        NSLog(fmt , ## args); }} while (0)

#define NSDebugMLog(format, args...) \
    do { if (GSDebugSet(@"dflt") == YES) { \
        NSString *fmt = GSDebugMethodMsg( \
        self, _cmd, __FILE__, __LINE__, format); \
        NSLog(fmt , ## args); }} while (0)

#else
#define NSDebugLLog(level, format, args...)
#define NSDebugLog(format, args...)
#define NSDebugFLLog(level, format, args...)
#define NSDebugFLog(format, args...)
#define NSDebugMLLog(level, format, args...)
#define NSDebugMLog(format, args...)
#endif /* DEBUG */

#define GSOnceFLog(format, args...) \
  do { static BOOL beenHere = NO; if (beenHere == NO) {\
    NSString *fmt = GSDebugFunctionMsg( \
        __PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
    beenHere = YES; \
    NSLog(fmt , ## args); }} while (0)

#define GSOnceMLog(format, args...) \
  do { static BOOL beenHere = NO; if (beenHere == NO) {\
    NSString *fmt = GSDebugMethodMsg( \
        self, _cmd, __FILE__, __LINE__, format); \
    beenHere = YES; \
    NSLog(fmt , ## args); }} while (0)

#ifdef GSWARN
#define NSWarnLog(format, args...) \
    do { if (GSDebugSet(@"NoWarn") == NO) { \
        NSLog(format , ## args); }} while (0)

#define NSWarnFLog(format, args...) \
    do { if (GSDebugSet(@"NoWarn") == NO) { \
        NSString *fmt = GSDebugFunctionMsg( \
        __PRETTY_FUNCTION__, __FILE__, __LINE__, format); \
        NSLog(fmt , ## args); }} while (0)

#define NSWarnMLog(format, args...) \
    do { if (GSDebugSet(@"NoWarn") == NO) { \
        NSString *fmt = GSDebugMethodMsg( \
        self, _cmd, __FILE__, __LINE__, format); \
        NSLog(fmt , ## args); }} while (0)
#else
#define NSWarnLog(format, args...)
#define NSWarnFLog(format, args...)
#define NSWarnMLog(format, args...)
#endif /* GSWARN */

#define GS_RANGE_CHECK(RANGE, SIZE) \
  if (RANGE.location > SIZE || RANGE.length > (SIZE - RANGE.location)) \
    [NSException raise: NSRangeException \
                format: @"in %s, range { %u, %u } extends beyond size (%u)", \
                  GSNameFromSelector(_cmd), RANGE.location, RANGE.length, SIZE]

/* Taken from base/Headers/Foundation/NSString.h */
typedef enum _NSGNUstepStringEncoding
{
/* NB. Must not have an encoding with value zero - so we can use zero to
   tell that a variable that should contain an encoding has not yet been
   initialised */
  GSUndefinedEncoding = 0,

// GNUstep additions
  NSKOI8RStringEncoding = 50,		// Russian/Cyrillic
  NSISOLatin3StringEncoding = 51,	// ISO-8859-3; South European
  NSISOLatin4StringEncoding = 52,	// ISO-8859-4; North European
  NSISOCyrillicStringEncoding = 22,	// ISO-8859-5
  NSISOArabicStringEncoding = 53,	// ISO-8859-6
  NSISOGreekStringEncoding = 54,	// ISO-8859-7
  NSISOHebrewStringEncoding = 55,	// ISO-8859-8
  NSISOLatin5StringEncoding = 57,	// ISO-8859-9; Turkish
  NSISOLatin6StringEncoding = 58,	// ISO-8859-10; Nordic
  NSISOThaiStringEncoding = 59,		// ISO-8859-11
/* Possible future ISO-8859 additions
					// ISO-8859-12
*/
  NSISOLatin7StringEncoding = 61,	// ISO-8859-13
  NSISOLatin8StringEncoding = 62,	// ISO-8859-14
  NSISOLatin9StringEncoding = 63,	// ISO-8859-15; Replaces ISOLatin1
  NSGB2312StringEncoding = 56,
  NSUTF7StringEncoding = 64,		// RFC 2152
  NSGSM0338StringEncoding,		// GSM (mobile phone) default alphabet
  NSBIG5StringEncoding,			// Traditional chinese
  NSKoreanEUCStringEncoding,
#if MAC_OS_X_VERSION_10_4 >= MAC_OS_X_VERSION_MAX_ALLOWED
    NSUTF16BigEndianStringEncoding = 0x90000100,          /* NSUTF16StringEncoding encoding with explicit endianness specified */
    NSUTF16LittleEndianStringEncoding = 0x94000100,       /* NSUTF16StringEncoding encoding with explicit endianness specified */

    NSUTF32StringEncoding = 0x8c000100,
    NSUTF32BigEndianStringEncoding = 0x98000100,          /* NSUTF32StringEncoding encoding with explicit endianness specified */
    NSUTF32LittleEndianStringEncoding = 0x9c000100,        /* NSUTF32StringEncoding encoding with explicit endianness specified */
#endif

  GSEncodingUnusedLast
} NSGNUstepStringEncoding;


/* Taken from base/Headers/Foundation/NSLock.h */
#define GS_INITIALIZED_LOCK(IDENT,CLASSNAME) \
           (IDENT != nil ? IDENT : [CLASSNAME newLockAt: &IDENT])

/* ------------------------------------------------------------------------
 * Class/Method Extensions
 */

/* 
   GSCategory extensions are implemented in 
   Source/Additions/GSCategory.m
   for both gnustep-base and gnustep-baseadd.
*/


/* 
   GSCompatibility methods are implemented in
   Source/Additions/GSCompatibility.m
   for gnustep-baseadd only.
   The implementations for gnustep-base reside in the
   corresponding source files of -base.
*/


/* ------------------------------------------------------------------------
 * Functions
 */

/* 
   Similar to the GSCompatibility methods,
   these functions are implemented in
   Source/Additions/GSCompatibility.m
   for gnustep-baseadd only.
   The implementations for gnustep-base reside in the
   corresponding source files of -base.
*/
GS_EXPORT NSArray *NSStandardLibraryPaths(void);
GS_EXPORT void NSDecimalFromComponents(NSDecimal *result, 
				       unsigned long long mantissa,
				       short exponent, BOOL negative);

GS_EXPORT BOOL GSDebugSet(NSString *level);

GS_EXPORT NSThread *GSCurrentThread(void);
GS_EXPORT NSMutableDictionary *GSCurrentThreadDictionary(void);

GS_EXPORT NSString *GSDebugMethodMsg(id obj, SEL sel, const char *file, 
				     int line, NSString *fmt);
GS_EXPORT NSString *GSDebugFunctionMsg(const char *func, const char *file,
				       int line, NSString *fmt);

#endif	/* OS_API_VERSION(GS_API_NONE,GS_API_NONE) */

#include	<GNUstepBase/NSTask+GS.h>

#if	defined(__cplusplus)
}
#endif

#endif	/* GNUSTEP */

#endif	/* INCLUDED_GS_CATEGORIES_H */


