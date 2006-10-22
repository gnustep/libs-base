/* GNUstep.h - macros to make easier to port gnustep apps to macos-x
   Copyright (C) 2001 Free Software Foundation, Inc.

   Written by: Nicola Pero <n.pero@mi.flashnet.it>
   Date: March, October 2001
   
   This file is part of GNUstep.

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
   Boston, MA 02110-1301, USA.
*/

#ifndef __GNUSTEP_GNUSTEP_H_INCLUDED_
#define __GNUSTEP_GNUSTEP_H_INCLUDED_

#ifndef GNUSTEP

#define AUTORELEASE(object)      [object autorelease]
#define TEST_AUTORELEASE(object) ({ if (object) [object autorelease]; })

#define RELEASE(object)          [object release]
#define TEST_RELEASE(object)     ({ if (object) [object release]; })

#define RETAIN(object)           [object retain]
#define TEST_RETAIN(object)      ({ if (object) [object retain]; })

#define ASSIGN(object,value)     ({\
     id __value = (id)(value); \
     id __object = (id)(object); \
     if (__value != __object) \
       { \
         if (__value != nil) \
           { \
             [__value retain]; \
           } \
         object = __value; \
         if (__object != nil) \
           { \
             [__object release]; \
           } \
       } \
   })

#define ASSIGNCOPY(object,value) ASSIGN(object, [[value copy] autorelease]);

#define DESTROY(object)          ({ \
     if (object) \
       { \
         id __o = object; \
         object = nil; \
         [__o release]; \
       } \
   })

#define CREATE_AUTORELEASE_POOL(X) \
NSAutoreleasePool *(X) = [NSAutoreleasePool new]

#define NSLocalizedString(key, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]

#define _(X) NSLocalizedString (X, nil)
#define __(X) X

#define NSLocalizedStaticString(X, Y) X

#endif /* defined GNUSTEP */

#ifdef GNUSTEP_WITH_DLL

#if BUILD_libgnustep_base_DLL
#
# if defined(__MINGW32__)
  /* On Mingw, the compiler will export all symbols automatically, so
   * __declspec(dllexport) is not needed.
   */
#  define GS_EXPORT  extern
#  define GS_DECLARE
# else
#  define GS_EXPORT  __declspec(dllexport)
#  define GS_DECLARE __declspec(dllexport)
# endif
#else
#  define GS_EXPORT  extern __declspec(dllimport)
#  define GS_DECLARE __declspec(dllimport)
#endif

#else /* GNUSTEP_WITH[OUT]_DLL */

#  define GS_EXPORT extern
#  define GS_DECLARE

#endif

/*
 * GNUstep attributes - Private, Deprecated
 */
#if (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 1))
#define GS_DEPRECATED __attribute__ ((deprecated))
#else
#define GS_DEPRECATED
#endif

#if (__GNUC__ > 3 || (__GNUC__ == 3 && __GNUC_MINOR__ >= 3))
#define GS_PRIVATE __attribute__ ((visibility("internal")))
#else
#define GS_PRIVATE
#endif

#include <GNUstepBase/GSVersionMacros.h>

#endif /* __GNUSTEP_GNUSTEP_H_INCLUDED_ */
