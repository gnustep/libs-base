/* GSCompatibility - Extra definitions for compiling on MacOSX

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>

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

#ifndef GSCompatibility_H_INCLUDE
#define GSCompatibility_H_INCLUDE

#ifdef NeXT_Foundation_LIBRARY
#include <string.h>
#include <Foundation/Foundation.h>
#include <CoreFoundation/CFString.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/GSObjCRuntime.h>
#include <gnustep/base/GNUstep.h>

@class NSMutableSet;

/* ------------------------------------------------------------------------
 * Macros
 */

// Following are also defined in gnustep-base/Headers/gnustep/base/NSObject.h
#define IF_NO_GC(x)	\
    x

// Following are also defined in gnustep-base/Headers/gnustep/base/NSDebug.h
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
                  sel_get_name(_cmd), RANGE.location, RANGE.length, SIZE]

/* Taken from gnustep-base/Headers/gnustep/base/NSString.h */
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
  NSBIG5StringEncoding			// Traditional chinese
} NSGNUstepStringEncoding;

/* ------------------------------------------------------------------------
 * Variables
 */
GS_EXPORT NSRecursiveLock *gnustep_global_lock;

/* ------------------------------------------------------------------------
 * Class/Method Extensions
 */

@interface NSObject(GSCompatibility)
+ (id) notImplemented:(SEL)selector;
- (BOOL) isInstance;
@end

@interface NSArray (GSCompatibility)
- (id) initWithArray: (NSArray*)array copyItems: (BOOL)shouldCopy;
@end

@interface NSDistantObject (GSCompatibility)
+ (void) setDebug: (int)val;
@end

@interface NSFileHandle(GSCompatibility)
+ (id) fileHandleAsServerAtAddress: (NSString*)address
                           service: (NSString*)service
                          protocol: (NSString*)protocol;
- (NSString*) socketAddress;
@end

// Used only in EOFault.m, -[EOFault forward::], for Object compatibility
@interface NSInvocation(GSCompatibility)
- (retval_t) returnFrame:(arglist_t)args;
- (id) initWithArgframe:(arglist_t)args selector:(SEL)selector;
@end

@interface NSString(GSCompatibility)
- (BOOL) boolValue;
@end

GS_EXPORT BOOL GSDebugSet(NSString *level);
@interface NSProcessInfo(GSCompatibility)
- (NSMutableSet *) debugSet;
@end

/* ------------------------------------------------------------------------
 * Functions
 */

GS_EXPORT NSArray *NSStandardLibraryPaths();
GS_EXPORT NSString *GetEncodingName(NSStringEncoding availableEncodingValue);

GS_EXPORT NSMutableDictionary *GSCurrentThreadDictionary();

GS_EXPORT NSString *GSDebugMethodMsg(id obj, SEL sel, const char *file, int line, NSString *fmt);
GS_EXPORT NSString *GSDebugFunctionMsg(const char *func, const char *file, int line, NSString *fmt);

#endif /* NexT_FOUNDATION_LIB */

#endif

