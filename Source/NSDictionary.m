/* NSDictionary - Dictionary object to store key/value pairs
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

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

#include <foundation/NSDictionary.h>

@implementation NSDictionary 

- copyWithZone:(NSZone *)zone
{
    return [super copyWithZone:zone];
}

+ allocWithZone:(NSZone *)zone
{
    return [super allocWithZone:zone];
}

+ dictionary
{
    return [[[NSDictionary alloc] init] autorelease];
}

+ dictionaryWithObjects:(id *)objects forKeys:(NSString **)keys count:(unsigned)count
{
    [self notImplemented:_cmd];
    return 0;
}

+ dictionaryWithObjects:(NSArray *)objects forKeys:(NSArray *)keys
{
    [self notImplemented:_cmd];
    return 0;
}

- initWithObjects:(id *)objects forKeys:(NSString **)keys count:(unsigned)count
{
    [self notImplemented:_cmd];
    return 0;
}

- initWithDictionary:(NSDictionary *)otherDictionary
{
    [self notImplemented:_cmd];
    return 0;
}

- initWithContentsOfFile:(NSString *)path
{
    [self notImplemented:_cmd];
    return 0;
}

- (unsigned)count
{
    [self notImplemented:_cmd];
    return 0;
}

- objectForKey:(NSString *)aKey
{
    [self notImplemented:_cmd];
    return 0;
}

//- (NSEnumerator *)keyEnumerator
//{
//    [self notImplemented:_cmd];
//}

- (BOOL)isEqualToDictionary:(NSDictionary *)other
{
    [self notImplemented:_cmd];
    return 0;
}

- (NSString *)description
{
    [self notImplemented:_cmd];
    return 0;
}

- (NSString *)descriptionWithIndent:(unsigned)level
{
    [self notImplemented:_cmd];
    return 0;
}

- (NSArray *)allKeys
{
    [self notImplemented:_cmd];
    return 0;
}

- (NSArray *)allValues
{
    [self notImplemented:_cmd];
    return 0;
}

- (NSArray *)allKeysForObject:anObject
{
    [self notImplemented:_cmd];
    return 0;
}

- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
    [self notImplemented:_cmd];
    return 0;
}

//- (NSEnumerator *)objectEnumerator
//{
//    [self notImplemented:_cmd];
//}


@end

@implementation NSMutableDictionary

+ allocWithZone:(NSZone *)zone
{
    [self notImplemented:_cmd];
    return 0;
}

+ dictionaryWithCapacity:(unsigned)numItems
{
    [self notImplemented:_cmd];
    return 0;
}

- initWithCapacity:(unsigned)numItems
{
    [self notImplemented:_cmd];
    return 0;
}


- (void)setObject:anObject forKey:(NSString *)aKey
{
    [self notImplemented:_cmd];
}

- (void)removeObjectForKey:(NSString *)aKey
{
    [self notImplemented:_cmd];
}

- (void)removeAllObjects
{
    [self notImplemented:_cmd];
}

- (void)removeObjectsForKeys:(NSArray *)keyArray
{
    [self notImplemented:_cmd];
}

- (void)addEntriesFromDictionary:(NSDictionary *)otherDictionary
{
    [self notImplemented:_cmd];
}


@end

/*	NSDictionary.h
	Basic dictionary container
  	Copyright 1993, 1994, NeXT, Inc.
	NeXT, March 1993
*/

#include "NSDictionary.h"

@implementation NSDictionary 

- copyWithZone:(NSZone *)zone
{
    return [super copy];
}

- (void)dealloc
{
    [super free];
}

//+ allocWithZone:(NSZone *)zone;
//+ dictionary;
//+ dictionaryWithObjects:(id *)objects forKeys:(NSString **)keys count:(unsigned)count;
//+ dictionaryWithObjects:(NSArray *)objects forKeys:(NSArray *)keys;
//- initWithObjects:(id *)objects forKeys:(NSString **)keys count:(unsigned)count;
//- initWithDictionary:(NSDictionary *)otherDictionary;
//- initWithContentsOfFile:(NSString *)path;

//- (unsigned)count;
//- objectForKey:(NSString *)aKey;
//- (NSEnumerator *)keyEnumerator;
//- (BOOL)isEqualToDictionary:(NSDictionary *)other;
//- (NSString *)description;
//- (NSString *)descriptionWithIndent:(unsigned)level;
//- (NSArray *)allKeys;
//- (NSArray *)allValues;
//- (NSArray *)allKeysForObject:anObject;
//- (BOOL)writeToFile:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
//- (NSEnumerator *)objectEnumerator;

@end

@implementation NSMutableDictionary

//+ allocWithZone:(NSZone *)zone;
//+ dictionaryWithCapacity:(unsigned)numItems;
//- initWithCapacity:(unsigned)numItems;

//- (void)setObject:anObject forKey:(NSString *)aKey;
//- (void)removeObjectForKey:(NSString *)aKey;
//- (void)removeAllObjects;
//- (void)removeObjectsForKeys:(NSArray *)keyArray;
//- (void)addEntriesFromDictionary:(NSDictionary *)otherDictionary;

@end

