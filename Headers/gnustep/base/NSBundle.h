/* Interface for NSBundle for GNUStep
   Copyright (C) 1995, 1997, 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: 1995
   
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

#ifndef __NSBundle_h_GNUSTEP_BASE_INCLUDE
#define __NSBundle_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

@class NSString;
@class NSArray;
@class NSDictionary;
@class NSMutableDictionary;

extern NSString* NSBundleDidLoadNotification;
extern NSString* NSShowNonLocalizedStrings;
extern NSString* NSLoadedClasses;

@interface NSBundle : NSObject
{
  NSString	*_path;
  NSArray	*_bundleClasses;
  Class		_principalClass;
  NSDictionary	*_infoDict;
  NSMutableDictionary	*_localizations;
  unsigned	_bundleType;
  BOOL		_codeLoaded;
  unsigned	_version;
}

+ (NSArray *) allBundles;
+ (NSArray *) allFrameworks;
+ (NSBundle *) mainBundle;
+ (NSBundle *) bundleForClass: (Class)aClass;
+ (NSBundle *) bundleWithPath: (NSString *)path;
+ (NSString *) pathForResource: (NSString *)name
		ofType: (NSString *)ext	
		inDirectory: (NSString *)bundlePath;
+ (NSString *) pathForResource: (NSString *)name
		ofType: (NSString *)ext	
		inDirectory: (NSString *)bundlePath
                withVersion: (int)version;
- initWithPath: (NSString *)path;
- (NSString *) bundlePath;
- (Class) classNamed: (NSString *)className;
- (Class) principalClass;

- (NSArray *) pathsForResourcesOfType: (NSString *)extension
		inDirectory: (NSString *)bundlePath;
- (NSString *) pathForResource: (NSString *)name
		ofType: (NSString *)ext	
		inDirectory: (NSString *)bundlePath;
- (NSString *) pathForResource: (NSString *)name
		ofType: (NSString *)ext;
- (NSString *) localizedStringForKey: (NSString *)key	
		value: (NSString *)value
		table: (NSString *)tableName;
- (NSString *) resourcePath;

- (unsigned) bundleVersion;
- (void) setBundleVersion: (unsigned)version;

#ifndef STRICT_OPENSTEP
- (NSDictionary *) infoDictionary;
- (BOOL) load;
#endif

@end

#ifndef	NO_GNUSTEP
@interface NSBundle (GNUstep)

+ (NSString*) _gnustep_target_cpu;
+ (NSString*) _gnustep_target_dir;
+ (NSString*) _gnustep_target_os;
+ (NSString*) _library_combo;
+ (NSBundle*) gnustepBundle;
+ (NSString *) pathForGNUstepResource: (NSString *)name
			       ofType: (NSString *)ext	
			  inDirectory: (NSString *)bundlePath;

@end
#define GSLocalizedString(key, comment) \
  [[NSBundle gnustepBundle] localizedStringForKey:(key) value:@"" table:nil]
#define GSLocalizedStringFromTable(key, tbl, comment) \
  [[NSBundle gnustepBundle] localizedStringForKey:(key) value:@"" table:(tbl)]

#endif

#define NSLocalizedString(key, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]
#define NSLocalizedStringFromTable(key, tbl, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:(tbl)]
#define NSLocalizedStringFromTableInBundle(key, tbl, bundle, comment) \
  [bundle localizedStringForKey:(key) value:@"" table:(tbl)]

#ifndef	NO_GNUSTEP
#define NSLocalizedStringFromTableInFramework(key, tbl, fpth, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" \
  table: [bundle pathForGNUstepResource:(tbl) ofType: nil inDirectory: (fpth)]
#endif

#endif	/* __NSBundle_h_GNUSTEP_BASE_INCLUDE */


