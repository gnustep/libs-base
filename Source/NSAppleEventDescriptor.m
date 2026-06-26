/* Implementation of class NSAppleEventDescriptor
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

#import "Foundation/NSAppleEventDescriptor.h"
#import "Foundation/NSData.h"
#import "Foundation/NSString.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSValue.h"
#import "common.h"

typedef enum {
  NSAppleEventDescriptorTypeSimple,
  NSAppleEventDescriptorTypeList,
  NSAppleEventDescriptorTypeRecord,
  NSAppleEventDescriptorTypeAppleEvent
} NSAppleEventDescriptorInternalType;

@implementation NSAppleEventDescriptor

// Creating descriptors

+ (NSAppleEventDescriptor *) descriptorWithBoolean: (BOOL)boolean
{
  unsigned char boolVal = boolean ? 1 : 0;
  return [self descriptorWithDescriptorType: typeBoolean
                                      bytes: &boolVal
                                     length: sizeof(boolVal)];
}

+ (NSAppleEventDescriptor *) descriptorWithDescriptorType: (DescType)descriptorType
                                                     bytes: (const void *)bytes
                                                    length: (NSUInteger)byteCount
{
  NSData *data;
  
  data = [NSData dataWithBytes: bytes length: byteCount];
  return [self descriptorWithDescriptorType: descriptorType data: data];
}

+ (NSAppleEventDescriptor *) descriptorWithDescriptorType: (DescType)descriptorType
                                                      data: (NSData *)data
{
  NSAppleEventDescriptor *descriptor;
  
  descriptor = [[self alloc] init];
  descriptor->_descriptorType = descriptorType;
  descriptor->_data = RETAIN(data);
  descriptor->_internalType = NSAppleEventDescriptorTypeSimple;
  return AUTORELEASE(descriptor);
}

+ (NSAppleEventDescriptor *) descriptorWithEnumCode: (uint32_t)enumerator
{
  uint32_t code = enumerator;
  return [self descriptorWithDescriptorType: typeEnumerated
                                      bytes: &code
                                     length: sizeof(code)];
}

+ (NSAppleEventDescriptor *) descriptorWithInt32: (int32_t)signedInt
{
  int32_t value = signedInt;
  return [self descriptorWithDescriptorType: typeSInt32
                                      bytes: &value
                                     length: sizeof(value)];
}

+ (NSAppleEventDescriptor *) descriptorWithString: (NSString *)string
{
  NSData *data;
  
  data = [string dataUsingEncoding: NSUTF8StringEncoding];
  return [self descriptorWithDescriptorType: typeChar data: data];
}

+ (NSAppleEventDescriptor *) descriptorWithTypeCode: (uint32_t)typeCode
{
  uint32_t code = typeCode;
  return [self descriptorWithDescriptorType: typeType
                                      bytes: &code
                                     length: sizeof(code)];
}

+ (NSAppleEventDescriptor *) nullDescriptor
{
  return [self descriptorWithDescriptorType: typeNull bytes: NULL length: 0];
}

// List and record descriptors

+ (NSAppleEventDescriptor *) listDescriptor
{
  NSAppleEventDescriptor *descriptor;
  
  descriptor = [[self alloc] init];
  descriptor->_descriptorType = typeAEList;
  descriptor->_internalType = NSAppleEventDescriptorTypeList;
  descriptor->_listItems = [[NSMutableArray alloc] init];
  return AUTORELEASE(descriptor);
}

+ (NSAppleEventDescriptor *) recordDescriptor
{
  NSAppleEventDescriptor *descriptor;
  
  descriptor = [[self alloc] init];
  descriptor->_descriptorType = typeAERecord;
  descriptor->_internalType = NSAppleEventDescriptorTypeRecord;
  descriptor->_recordKeywords = [[NSMutableDictionary alloc] init];
  descriptor->_recordDescriptors = [[NSMutableArray alloc] init];
  return AUTORELEASE(descriptor);
}

// Apple event descriptors

+ (NSAppleEventDescriptor *) appleEventWithEventClass: (uint32_t)eventClass
                                              eventID: (uint32_t)eventID
                                     targetDescriptor: (NSAppleEventDescriptor *)targetDescriptor
                                             returnID: (int16_t)returnID
                                      transactionID: (int32_t)transactionID
{
  NSAppleEventDescriptor *descriptor;
  
  descriptor = [[self alloc] init];
  descriptor->_descriptorType = typeAppleEvent;
  descriptor->_internalType = NSAppleEventDescriptorTypeAppleEvent;
  descriptor->_eventClass = eventClass;
  descriptor->_eventID = eventID;
  descriptor->_returnID = returnID;
  descriptor->_transactionID = transactionID;
  descriptor->_parameters = [[NSMutableDictionary alloc] init];
  descriptor->_attributes = [[NSMutableDictionary alloc] init];
  
  if (targetDescriptor != nil)
    {
      [descriptor setAttributeDescriptor: targetDescriptor forKeyword: 'targ'];
    }
  
  return AUTORELEASE(descriptor);
}

// Initialization and deallocation

- (id) init
{
  if ((self = [super init]))
    {
      _internalType = NSAppleEventDescriptorTypeSimple;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_data);
  RELEASE(_listItems);
  RELEASE(_recordKeywords);
  RELEASE(_recordDescriptors);
  RELEASE(_parameters);
  RELEASE(_attributes);
  [super dealloc];
}

- (id) copyWithZone: (NSZone *)zone
{
  NSAppleEventDescriptor *copy;
  
  copy = [[NSAppleEventDescriptor allocWithZone: zone] init];
  copy->_descriptorType = _descriptorType;
  copy->_internalType = _internalType;
  copy->_data = [_data copyWithZone: zone];
  copy->_listItems = [_listItems mutableCopyWithZone: zone];
  copy->_recordKeywords = [_recordKeywords mutableCopyWithZone: zone];
  copy->_recordDescriptors = [_recordDescriptors mutableCopyWithZone: zone];
  copy->_eventClass = _eventClass;
  copy->_eventID = _eventID;
  copy->_returnID = _returnID;
  copy->_transactionID = _transactionID;
  copy->_parameters = [_parameters mutableCopyWithZone: zone];
  copy->_attributes = [_attributes mutableCopyWithZone: zone];
  
  return copy;
}

// Accessing descriptor data

- (DescType) descriptorType
{
  return _descriptorType;
}

- (NSData *) data
{
  return _data;
}

- (BOOL) booleanValue
{
  const unsigned char *bytes;
  
  if (_descriptorType == typeTrue)
    {
      return YES;
    }
  if (_descriptorType == typeFalse)
    {
      return NO;
    }
  if (_descriptorType == typeBoolean && [_data length] >= 1)
    {
      bytes = [_data bytes];
      return bytes[0] != 0;
    }
  return NO;
}

- (int32_t) int32Value
{
  const int32_t *value;
  
  if (_descriptorType == typeSInt32 && [_data length] >= sizeof(int32_t))
    {
      value = [_data bytes];
      return *value;
    }
  return 0;
}

- (NSString *) stringValue
{
  if (_descriptorType == typeChar)
    {
      return [[[NSString alloc] initWithData: _data
                                    encoding: NSUTF8StringEncoding] autorelease];
    }
  return nil;
}

- (uint32_t) typeCodeValue
{
  const uint32_t *value;
  
  if (_descriptorType == typeType && [_data length] >= sizeof(uint32_t))
    {
      value = [_data bytes];
      return *value;
    }
  return 0;
}

- (uint32_t) enumCodeValue
{
  const uint32_t *value;
  
  if (_descriptorType == typeEnumerated && [_data length] >= sizeof(uint32_t))
    {
      value = [_data bytes];
      return *value;
    }
  return 0;
}

// Working with list descriptors

- (NSInteger) numberOfItems
{
  if (_internalType == NSAppleEventDescriptorTypeList)
    {
      return [_listItems count];
    }
  if (_internalType == NSAppleEventDescriptorTypeRecord)
    {
      return [_recordDescriptors count];
    }
  return 0;
}

- (void) insertDescriptor: (NSAppleEventDescriptor *)descriptor
                  atIndex: (NSInteger)index
{
  if (_internalType == NSAppleEventDescriptorTypeList)
    {
      if (descriptor != nil)
        {
          [_listItems insertObject: descriptor atIndex: index];
        }
    }
}

- (NSAppleEventDescriptor *) descriptorAtIndex: (NSInteger)index
{
  if (_internalType == NSAppleEventDescriptorTypeList)
    {
      if (index >= 0 && index < [_listItems count])
        {
          return [_listItems objectAtIndex: index];
        }
    }
  else if (_internalType == NSAppleEventDescriptorTypeRecord)
    {
      if (index >= 0 && index < [_recordDescriptors count])
        {
          return [_recordDescriptors objectAtIndex: index];
        }
    }
  return nil;
}

- (void) removeDescriptorAtIndex: (NSInteger)index
{
  if (_internalType == NSAppleEventDescriptorTypeList)
    {
      if (index >= 0 && index < [_listItems count])
        {
          [_listItems removeObjectAtIndex: index];
        }
    }
}

// Working with record descriptors

- (void) setDescriptor: (NSAppleEventDescriptor *)descriptor
            forKeyword: (AEKeyword)keyword
{
  NSNumber *keywordNum;
  NSNumber *indexNum;
  
  if (_internalType != NSAppleEventDescriptorTypeRecord)
    {
      return;
    }
  
  if (descriptor == nil)
    {
      [self removeDescriptorWithKeyword: keyword];
      return;
    }
  
  keywordNum = [NSNumber numberWithUnsignedInt: keyword];
  indexNum = [_recordKeywords objectForKey: keywordNum];
  
  if (indexNum != nil)
    {
      [_recordDescriptors replaceObjectAtIndex: [indexNum integerValue]
                                    withObject: descriptor];
    }
  else
    {
      [_recordDescriptors addObject: descriptor];
      [_recordKeywords setObject: [NSNumber numberWithInteger: [_recordDescriptors count] - 1]
                          forKey: keywordNum];
    }
}

- (NSAppleEventDescriptor *) descriptorForKeyword: (AEKeyword)keyword
{
  NSNumber *keywordNum;
  NSNumber *index;
  
  if (_internalType != NSAppleEventDescriptorTypeRecord)
    {
      return nil;
    }
  
  keywordNum = [NSNumber numberWithUnsignedInt: keyword];
  index = [_recordKeywords objectForKey: keywordNum];
  
  if (index != nil)
    {
      return [_recordDescriptors objectAtIndex: [index integerValue]];
    }
  return nil;
}

- (void) removeDescriptorWithKeyword: (AEKeyword)keyword
{
  NSNumber *keywordNum;
  NSNumber *index;
  
  if (_internalType != NSAppleEventDescriptorTypeRecord)
    {
      return;
    }
  
  keywordNum = [NSNumber numberWithUnsignedInt: keyword];
  index = [_recordKeywords objectForKey: keywordNum];
  
  if (index != nil)
    {
      [_recordDescriptors removeObjectAtIndex: [index integerValue]];
      [_recordKeywords removeObjectForKey: keywordNum];
    }
}

- (AEKeyword) keywordForDescriptorAtIndex: (NSInteger)index
{
  NSEnumerator *keyEnum;
  NSNumber *keywordNum;
  NSNumber *idx;
  
  if (_internalType != NSAppleEventDescriptorTypeRecord)
    {
      return 0;
    }
  
  keyEnum = [_recordKeywords keyEnumerator];
  while ((keywordNum = [keyEnum nextObject]) != nil)
    {
      idx = [_recordKeywords objectForKey: keywordNum];
      if ([idx integerValue] == index)
        {
          return [keywordNum unsignedIntValue];
        }
    }
  return 0;
}

// Working with Apple event descriptors

- (NSAppleEventDescriptor *) paramDescriptorForKeyword: (AEKeyword)keyword
{
  NSNumber *keywordNum;
  
  if (_internalType != NSAppleEventDescriptorTypeAppleEvent)
    {
      return nil;
    }
  
  keywordNum = [NSNumber numberWithUnsignedInt: keyword];
  return [_parameters objectForKey: keywordNum];
}

- (void) setParamDescriptor: (NSAppleEventDescriptor *)descriptor
                 forKeyword: (AEKeyword)keyword
{
  NSNumber *keywordNum;
  
  if (_internalType != NSAppleEventDescriptorTypeAppleEvent)
    {
      return;
    }
  
  keywordNum = [NSNumber numberWithUnsignedInt: keyword];
  if (descriptor != nil)
    {
      [_parameters setObject: descriptor forKey: keywordNum];
    }
  else
    {
      [_parameters removeObjectForKey: keywordNum];
    }
}

- (NSAppleEventDescriptor *) attributeDescriptorForKeyword: (AEKeyword)keyword
{
  NSNumber *keywordNum;
  
  if (_internalType != NSAppleEventDescriptorTypeAppleEvent)
    {
      return nil;
    }
  
  keywordNum = [NSNumber numberWithUnsignedInt: keyword];
  return [_attributes objectForKey: keywordNum];
}

- (void) setAttributeDescriptor: (NSAppleEventDescriptor *)descriptor
                     forKeyword: (AEKeyword)keyword
{
  NSNumber *keywordNum;
  
  if (_internalType != NSAppleEventDescriptorTypeAppleEvent)
    {
      return;
    }
  
  keywordNum = [NSNumber numberWithUnsignedInt: keyword];
  if (descriptor != nil)
    {
      [_attributes setObject: descriptor forKey: keywordNum];
    }
  else
    {
      [_attributes removeObjectForKey: keywordNum];
    }
}

- (uint32_t) eventClass
{
  if (_internalType == NSAppleEventDescriptorTypeAppleEvent)
    {
      return _eventClass;
    }
  return 0;
}

- (uint32_t) eventID
{
  if (_internalType == NSAppleEventDescriptorTypeAppleEvent)
    {
      return _eventID;
    }
  return 0;
}

- (int16_t) returnID
{
  if (_internalType == NSAppleEventDescriptorTypeAppleEvent)
    {
      return _returnID;
    }
  return 0;
}

- (int32_t) transactionID
{
  if (_internalType == NSAppleEventDescriptorTypeAppleEvent)
    {
      return _transactionID;
    }
  return 0;
}

@end
