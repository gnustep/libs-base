/* Interface for NSBundle class
 *
 * Copyright (C)  1993  The Board of Trustees of  
 * The Leland Stanford Junior University.  All Rights Reserved.
 *
 * Authors: Adam Fedor, Scott Francis and Paul Kunz
 *
 * This file is part of an Objective-C class library for X/Motif
 *
 * NSBundle.h,v 1.9 1993/10/20 00:44:51 pfkeb Exp
 */

#ifndef _NS_Bundle_h_
#define _NS_Bundle_h_

#include <foundation/NSObject.h>

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

#endif	/* _NS_Bundle_h_ */
