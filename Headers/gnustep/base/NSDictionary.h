/*	NSDictionary.h
	Basic dictionary container
  	Copyright 1993, 1994, NeXT, Inc.
	NeXT, March 1993
*/

#ifndef _NSDictionary_INCLUDE_
#define _NSDictionary_INCLUDE_

#include <objects/Dictionary.h>
#include <objects/ObjectRetaining.h>
#include <foundation/NSObject.h>

@class NSArray;

@interface NSDictionary : Dictionary <NSCopying>

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

@interface NSMutableDictionary: NSDictionary

//+ allocWithZone:(NSZone *)zone;
//+ dictionaryWithCapacity:(unsigned)numItems;
//- initWithCapacity:(unsigned)numItems;

//- (void)setObject:anObject forKey:(NSString *)aKey;
//- (void)removeObjectForKey:(NSString *)aKey;
//- (void)removeAllObjects;
//- (void)removeObjectsForKeys:(NSArray *)keyArray;
//- (void)addEntriesFromDictionary:(NSDictionary *)otherDictionary;

@end

#endif
