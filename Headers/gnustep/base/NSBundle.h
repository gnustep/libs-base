/* Interface for NSBundle for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.

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

extern NSString* NSBundleDidLoadNotification;
extern NSString* NSShowNonLocalizedStrings;
extern NSString* NSLoadedClasses;

@interface NSBundle : NSObject
{
    NSString	*_path;
    NSArray*    _bundleClasses;
    Class       _principalClass;
    id          _infoDict;
    unsigned int _retainCount;
    unsigned int _bundleType;
    BOOL	_codeLoaded;
}

+ (NSBundle *) mainBundle;
+ (NSBundle *) bundleForClass: (Class)aClass;
+ (NSBundle *) bundleWithPath: (NSString *)path;
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

#ifndef STRICT_OPENSTEP
- (NSDictionary *) infoDictionary;
#endif

@end

#define NSLocalizedString(key, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:nil]
#define NSLocalizedStringFromTable(key, tbl, comment) \
  [[NSBundle mainBundle] localizedStringForKey:(key) value:@"" table:(tbl)]
#define NSLocalizedStringFromTableInBundle(key, tbl, bundle, comment) \
  [bundle localizedStringForKey:(key) value:@"" table:(tbl)]

#endif	/* __NSBundle_h_GNUSTEP_BASE_INCLUDE */
