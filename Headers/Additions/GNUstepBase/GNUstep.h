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


/*
 *	Check consistency of definitions for system compatibility.
 */
#if	defined(STRICT_OPENSTEP)
#define GS_OPENSTEP_V	010000
#define	NO_GNUSTEP	1
#elif	defined(STRICT_MACOS_X)
#define GS_OPENSTEP_V	100000
#define	NO_GNUSTEP	1
#else
#undef	NO_GNUSTEP
#endif

/*
 * NB. The version values below must be integers ... by convention these are
 * made up of two digits each for major, minor and subminor version numbers
 * (ie each is in the range 00 to 99 though a leading zero in the major
 * number is not permitted).
 * So for a MacOS-X 10.3.9 release the version number would be 100309
 *
 * You may define GS_GNUSTEP_V or GS_OPENSTEP_V to ensure that your
 * program only 'sees' the specified varsion of the API.
 */

/**
 * <p>Macro to check a defined GNUstep version number (GS_GNUSTEP_V) against
 * the supplied arguments.  Returns true if no GNUstep version is specified,
 * or if ADD &lt;= version &lt; REM, where ADD is the version
 * number at which a feature guarded by the macro was introduced and
 * REM is the version number at which it was removed.
 * </p>
 * <p>The version number arguments are six digit integers where the first
 * two digits are the major version number, the second two are the minor
 * version number and the last two are the subminor number (all left padded
 * with a zero where necessary).  However, for convenience you can also
 * use any of several predefined constants ... 
 * <ref type="macro" id="GS_API_NONE">GS_API_NONE</ref>,
 * <ref type="macro" id="GS_API_LATEST">GS_API_LATEST</ref>,
 * <ref type="macro" id="GS_API_OSSPEC">GS_API_OSSPEC</ref>,
 * <ref type="macro" id="GS_API_OPENSTEP">GS_API_OPENSTEP</ref>,
 * <ref type="macro" id="GS_API_MACOSX">GS_API_MACOSX</ref>
 * </p>
 * <p>Also see <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * </p>
 * <p>NB. If you are changing the API (eg adding a new feature) you need
 * to control the visibility io the new header file code using<br />
 * <code>#if GS_API_VERSION(ADD,GS_API_LATEST)</code><br />
 * where <code>ADD</code> is the version number of the next minor
 * release after the most recent one.<br />
 * As a general principle you should <em>not</em> change the API with
 * changing subminor version numbers ... as that tends to confuse
 * people (though Apple has sometimes done it).
 * </p>
 */
#define	GS_API_VERSION(ADD,REM) \
  (!defined(GS_GNUSTEP_V) || (GS_GNUSTEP_V >= ADD && GS_GNUSTEP_V < REM))

/**
 * <p>Macro to check a defined OpenStep/OPENSTEP/MacOS-X version against the
 * supplied arguments.  Returns true if no version is specified, or if
 * ADD &lt;= version &lt; REM, where ADD is the version
 * number at which a feature guarded by the macro was introduced and
 * REM is the version number at which it was removed.
 * </p>
 * <p>The version number arguments are six digit integers where the first
 * two digits are the major version number, the second two are the minor
 * version number and the last two are the subminor number (all left padded
 * with a zero where necessary).  However, for convenience you can also
 * use any of several predefined constants ... 
 * <ref type="macro" id="GS_API_NONE">GS_API_NONE</ref>,
 * <ref type="macro" id="GS_API_LATEST">GS_API_LATEST</ref>,
 * <ref type="macro" id="GS_API_OSSPEC">GS_API_OSSPEC</ref>,
 * <ref type="macro" id="GS_API_OPENSTEP">GS_API_OPENSTEP</ref>,
 * <ref type="macro" id="GS_API_MACOSX">GS_API_MACOSX</ref>
 * </p>
 * <p>Also see <ref type="macro" id="GS_API_VERSION">GS_API_VERSION</ref>
 * </p>
 */
#define	OS_API_VERSION(ADD,REM) \
  (!defined(GS_OPENSTEP_V) || (GS_OPENSTEP_V >= ADD && GS_OPENSTEP_V < REM))

/**
 * A constant which is the lowest possible version number (0) so that
 * when used as the removal version (second argument of the GS_API_VERSION
 * or OS_API_VERSION macro) represents a feature which is not present in
 * any version.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_NONE, GS_API_NONE)<br />
 * denotes  code not present in OpenStep/OPENSTEP/MacOS-X
 */
#define	GS_API_NONE	     0

/**
 * A constant to represent a feature which is still present in the latest
 * version.  This is the highest possible version number.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_MACOSX, GS_API_LATEST)<br />
 * denotes code present from the initial MacOS-X version onwards.
 */
#define	GS_API_LATEST	999999

/**
 * The version number of the initial OpenStep specification.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_OSSPEC, GS_API_LATEST)<br />
 * denotes code present from the OpenStep specification onwards.
 */
#define	GS_API_OSSPEC	 10000

/**
 * The version number of the first OPENSTEP implementation.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_OPENSTEP, GS_API_LATEST)<br />
 * denotes code present from the initial OPENSTEP version onwards.
 */
#define	GS_API_OPENSTEP	 40000

/**
 * The version number of the first MacOS-X implementation.<br />
 * eg.<br />
 * #if <ref type="macro" id="OS_API_VERSION">OS_API_VERSION</ref>
 * (GS_API_MACOSX, GS_API_LATEST)<br />
 * denotes code present from the initial MacOS-X version onwards.
 */
#define	GS_API_MACOSX	100000

#else
#include <Foundation/NSObject.h>
#endif /* GNUSTEP */

#endif /* __GNUSTEP_GNUSTEP_H_INCLUDED_ */
