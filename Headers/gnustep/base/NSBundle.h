/* Interface for NSBundle for GNUStep
   Copyright (C) 1994 NeXT Computer, Inc.
   
   This file is part of the GNU Objective C Class Library.

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

#ifndef __NSBundle_h_OBJECTS_INCLUDE
#define __NSBundle_h_OBJECTS_INCLUDE

#include <Foundation/NSObject.h>

@class NSString;
@class NSArray;

@interface NSBundle : NSObject
{
    NSString	*_path;
    Class	_principalClass;
    BOOL	_codeLoaded;
    int		_bundleVersion;
}

+ (NSBundle *)mainBundle;
+ (NSBundle *)bundleForClass:aClass;
+ (NSBundle *)bundleWithPath:(NSString *)path;
- initWithPath:(NSString *)path;
- (NSString *)bundlePath;
- classNamed:(NSString *)className;
- principalClass;

+ (NSString *)pathForResource:(NSString *)name
		ofType:(NSString *)ext	
		inDirectory:(NSString *)bundlePath
		withVersion:(int)version;

- (NSString *)pathForResource:(NSString *)name
		ofType:(NSString *)ext;

+ (void)stripAfterLoading:(BOOL)flag;

- (NSString *)localizedStringForKey:(NSString *)key	
		value:(NSString *)value
		table:(NSString *)tableName;

- (unsigned)bundleVersion;
- (void)setBundleVersion:(unsigned)version;

+ (void)setSystemLanguages:(NSArray *)languages;

@end

#endif	/* __NSBundle_h_OBJECTS_INCLUDE */
