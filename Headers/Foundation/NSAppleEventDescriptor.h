/* Definition of class NSAppleEventDescriptor
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Fri Nov  1 00:25:01 EDT 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#ifndef _NSAppleEventDescriptor_h_GNUSTEP_BASE_INCLUDE
#define _NSAppleEventDescriptor_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_0, GS_API_LATEST)

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSData;
@class NSString;
@class NSMutableArray;
@class NSMutableDictionary;

typedef uint32_t AEKeyword;
typedef int32_t DescType;

enum {
  typeBoolean = 'bool',
  typeChar = 'TEXT',
  typeSInt16 = 'shor',
  typeSInt32 = 'long',
  typeUInt32 = 'magn',
  typeSInt64 = 'comp',
  typeIEEE32BitFloatingPoint = 'sing',
  typeIEEE64BitFloatingPoint = 'doub',
  type128BitFloatingPoint = 'ldbl',
  typeDecimalStruct = 'decm',
  typeAEList = 'list',
  typeAERecord = 'reco',
  typeAppleEvent = 'aevt',
  typeEventRecord = 'evrc',
  typeTrue = 'true',
  typeFalse = 'fals',
  typeAlias = 'alis',
  typeEnumerated = 'enum',
  typeType = 'type',
  typeAppParameters = 'appa',
  typeProperty = 'prop',
  typeFSS = 'fss ',
  typeFSRef = 'fsrf',
  typeFileURL = 'furl',
  typeKeyword = 'keyw',
  typeSectionH = 'sect',
  typeWildCard = '****',
  typeApplSignature = 'sign',
  typeQDRectangle = 'qdrt',
  typeFixed = 'fixd',
  typeProcessSerialNumber = 'psn ',
  typeApplicationURL = 'aprl',
  typeNull = 'null'
};

GS_EXPORT_CLASS
@interface NSAppleEventDescriptor : NSObject <NSCopying>
{
  @private
  DescType _descriptorType;
  NSData *_data;
  int _internalType;
  
  NSMutableArray *_listItems;
  NSMutableDictionary *_recordKeywords;
  NSMutableArray *_recordDescriptors;
  
  uint32_t _eventClass;
  uint32_t _eventID;
  int16_t _returnID;
  int32_t _transactionID;
  NSMutableDictionary *_parameters;
  NSMutableDictionary *_attributes;
}

// Creating descriptors
+ (NSAppleEventDescriptor *) descriptorWithBoolean: (BOOL)boolean;
+ (NSAppleEventDescriptor *) descriptorWithDescriptorType: (DescType)descriptorType
                                                     bytes: (const void *)bytes
                                                    length: (NSUInteger)byteCount;
+ (NSAppleEventDescriptor *) descriptorWithDescriptorType: (DescType)descriptorType
                                                      data: (NSData *)data;
+ (NSAppleEventDescriptor *) descriptorWithEnumCode: (uint32_t)enumerator;
+ (NSAppleEventDescriptor *) descriptorWithInt32: (int32_t)signedInt;
+ (NSAppleEventDescriptor *) descriptorWithString: (NSString *)string;
+ (NSAppleEventDescriptor *) descriptorWithTypeCode: (uint32_t)typeCode;
+ (NSAppleEventDescriptor *) nullDescriptor;

// List and record descriptors
+ (NSAppleEventDescriptor *) listDescriptor;
+ (NSAppleEventDescriptor *) recordDescriptor;

// Apple event descriptors
+ (NSAppleEventDescriptor *) appleEventWithEventClass: (uint32_t)eventClass
                                              eventID: (uint32_t)eventID
                                     targetDescriptor: (NSAppleEventDescriptor *)targetDescriptor
                                             returnID: (int16_t)returnID
                                      transactionID: (int32_t)transactionID;

// Accessing descriptor data
- (DescType) descriptorType;
- (NSData *) data;
- (BOOL) booleanValue;
- (int32_t) int32Value;
- (NSString *) stringValue;
- (uint32_t) typeCodeValue;
- (uint32_t) enumCodeValue;

// Working with list descriptors
- (NSInteger) numberOfItems;
- (void) insertDescriptor: (NSAppleEventDescriptor *)descriptor
                  atIndex: (NSInteger)index;
- (NSAppleEventDescriptor *) descriptorAtIndex: (NSInteger)index;
- (void) removeDescriptorAtIndex: (NSInteger)index;

// Working with record descriptors
- (void) setDescriptor: (NSAppleEventDescriptor *)descriptor
            forKeyword: (AEKeyword)keyword;
- (NSAppleEventDescriptor *) descriptorForKeyword: (AEKeyword)keyword;
- (void) removeDescriptorWithKeyword: (AEKeyword)keyword;
- (AEKeyword) keywordForDescriptorAtIndex: (NSInteger)index;

// Working with Apple event descriptors
- (NSAppleEventDescriptor *) paramDescriptorForKeyword: (AEKeyword)keyword;
- (void) setParamDescriptor: (NSAppleEventDescriptor *)descriptor
                 forKeyword: (AEKeyword)keyword;
- (NSAppleEventDescriptor *) attributeDescriptorForKeyword: (AEKeyword)keyword;
- (void) setAttributeDescriptor: (NSAppleEventDescriptor *)descriptor
                     forKeyword: (AEKeyword)keyword;

- (uint32_t) eventClass;
- (uint32_t) eventID;
- (int16_t) returnID;
- (int32_t) transactionID;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSAppleEventDescriptor_h_GNUSTEP_BASE_INCLUDE */

