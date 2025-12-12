/* Implementation of class NSScriptObjectSpecifier
   Copyright (C) 2024 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
   Date: Dec 2024

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

#import "common.h"
#import "Foundation/NSScriptObjectSpecifier.h"
#import "Foundation/NSAppleEventDescriptor.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSException.h"
#import "Foundation/NSScriptClassDescription.h"
#import "Foundation/NSScriptWhoseTests.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"

/* Suppress warnings for NSAppleEventDescriptor methods that may not be
 * fully declared in the header but are available at runtime */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-method-access"

// NSScriptObjectSpecifier

@implementation NSScriptObjectSpecifier

- (instancetype) init
{
  return [self initWithContainerSpecifier: nil key: nil];
}

- (instancetype) initWithContainerSpecifier: (NSScriptObjectSpecifier *)container
                                         key: (NSString *)property
{
  self = [super init];
  if (self != nil)
    {
      ASSIGN(_container, container);
      ASSIGN(_key, property);
      _classDescription = nil;
    }
  return self;
}

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
{
  self = [self initWithContainerSpecifier: container key: property];
  if (self != nil)
    {
      ASSIGN(_classDescription, classDesc);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_container);
  RELEASE(_key);
  RELEASE(_classDescription);
  [super dealloc];
}

- (NSScriptObjectSpecifier *) containerSpecifier
{
  return _container;
}

- (void) setContainerSpecifier: (NSScriptObjectSpecifier *)subRef
{
  ASSIGN(_container, subRef);
}

- (BOOL) containerIsObjectBeingTested
{
  return NO;
}

- (void) setContainerIsObjectBeingTested: (BOOL)flag
{
  // Stub for subclasses
}

- (BOOL) containerIsRangeContainerObject
{
  return NO;
}

- (void) setContainerIsRangeContainerObject: (BOOL)flag
{
  // Stub for subclasses
}

- (NSString *) key
{
  return _key;
}

- (void) setKey: (NSString *)key
{
  ASSIGN(_key, key);
}

- (NSScriptClassDescription *) keyClassDescription
{
  return _classDescription;
}

- (NSAppleEventDescriptor *) descriptor
{
  [NSException raise: NSInvalidArgumentException
              format: @"NSScriptObjectSpecifier -descriptor is abstract"];
  return nil;
}

- (id) objectsByEvaluatingSpecifier
{
  id container;
  
  if (_container == nil)
    {
      return nil;
    }
  
  container = [_container objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if (_key == nil)
    {
      return container;
    }
  
  return [container valueForKey: _key];
}

- (NSAppleEventDescriptor *) descriptorAtIndex: (NSInteger)index
{
  return nil;
}

- (NSInteger) evaluationErrorNumber
{
  return 0;
}

- (void) setEvaluationErrorNumber: (NSInteger)error
{
  // Stub
}

- (NSString *) evaluationErrorSpecifier
{
  return nil;
}

// NSCoding

- (void) encodeWithCoder: (NSCoder *)coder
{
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _container forKey: @"NSContainer"];
      [coder encodeObject: _key forKey: @"NSKey"];
      [coder encodeObject: _classDescription forKey: @"NSClassDescription"];
    }
  else
    {
      [coder encodeObject: _container];
      [coder encodeObject: _key];
      [coder encodeObject: _classDescription];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super init];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          ASSIGN(_container, [coder decodeObjectForKey: @"NSContainer"]);
          ASSIGN(_key, [coder decodeObjectForKey: @"NSKey"]);
          ASSIGN(_classDescription, [coder decodeObjectForKey: @"NSClassDescription"]);
        }
      else
        {
          ASSIGN(_container, [coder decodeObject]);
          ASSIGN(_key, [coder decodeObject]);
          ASSIGN(_classDescription, [coder decodeObject]);
        }
    }
  return self;
}

@end

// NSIndexSpecifier

@implementation NSIndexSpecifier

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                            index: (NSInteger)index
{
  self = [super initWithContainerClassDescription: classDesc
                              containerSpecifier: container
                                             key: property];
  if (self != nil)
    {
      _index = index;
    }
  return self;
}

- (NSInteger) index
{
  return _index;
}

- (void) setIndex: (NSInteger)index
{
  _index = index;
}

- (id) objectsByEvaluatingSpecifier
{
  id container;
  NSArray *array;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      array = [container valueForKey: [self key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return nil;
    }
  
  if (_index < 0 || _index >= [array count])
    {
      return nil;
    }
  
  return [array objectAtIndex: _index];
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  // Add container descriptor
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  // Add key
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'form'];
    }
  
  // Add index
  [desc setDescriptor: [NSAppleEventDescriptor descriptorWithInt32: (int)_index]
           forKeyword: 'seld'];
  
  return desc;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeInteger: _index forKey: @"NSIndex"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(NSInteger) at: &_index];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          _index = [coder decodeIntegerForKey: @"NSIndex"];
        }
      else
        {
          [coder decodeValueOfObjCType: @encode(NSInteger) at: &_index];
        }
    }
  return self;
}

@end

// NSMiddleSpecifier

@implementation NSMiddleSpecifier

- (id) objectsByEvaluatingSpecifier
{
  id container;
  NSArray *array;
  NSUInteger count;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      array = [container valueForKey: [self key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return nil;
    }
  
  count = [array count];
  if (count == 0)
    {
      return nil;
    }
  
  return [array objectAtIndex: count / 2];
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'form'];
    }
  
  [desc setDescriptor: [NSAppleEventDescriptor descriptorWithTypeCode: 'midd']
           forKeyword: 'seld'];
  
  return desc;
}

@end

// NSNameSpecifier

@implementation NSNameSpecifier

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                             name: (NSString *)name
{
  self = [super initWithContainerClassDescription: classDesc
                              containerSpecifier: container
                                             key: property];
  if (self != nil)
    {
      ASSIGN(_name, name);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_name);
  [super dealloc];
}

- (NSString *) name
{
  return _name;
}

- (void) setName: (NSString *)name
{
  ASSIGN(_name, name);
}

- (id) objectsByEvaluatingSpecifier
{
  id container;
  NSArray *array;
  id object;
  NSEnumerator *enumerator;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      array = [container valueForKey: [self key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return nil;
    }
  
  enumerator = [array objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      id objectName;
      
      objectName = [object valueForKey: @"name"];
      if (objectName != nil && [objectName isEqual: _name])
        {
          return object;
        }
    }
  
  return nil;
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'form'];
    }
  
  if (_name != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: _name]
               forKeyword: 'seld'];
    }
  
  return desc;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _name forKey: @"NSName"];
    }
  else
    {
      [coder encodeObject: _name];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          ASSIGN(_name, [coder decodeObjectForKey: @"NSName"]);
        }
      else
        {
          ASSIGN(_name, [coder decodeObject]);
        }
    }
  return self;
}

@end

// NSPositionSpecifier

@implementation NSPositionSpecifier

- (instancetype) initWithPosition: (NSInsertionPosition)position
              objectSpecifier: (NSScriptObjectSpecifier *)specifier
{
  self = [super init];
  if (self != nil)
    {
      _insertionPosition = position;
      ASSIGN(_insertionObject, specifier);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_insertionObject);
  [super dealloc];
}

- (NSInsertionPosition) insertionPosition
{
  return _insertionPosition;
}

- (void) setInsertionPosition: (NSInsertionPosition)position
{
  _insertionPosition = position;
}

- (NSScriptObjectSpecifier *) objectSpecifier
{
  return _insertionObject;
}

- (void) setObjectSpecifier: (NSScriptObjectSpecifier *)objSpec
{
  ASSIGN(_insertionObject, objSpec);
}

- (void) evaluate
{
  // Stub
}

- (id) insertionContainer
{
  if (_insertionObject != nil)
    {
      return [_insertionObject objectsByEvaluatingSpecifier];
    }
  return nil;
}

- (NSString *) insertionKey
{
  if (_insertionObject != nil)
    {
      return [_insertionObject key];
    }
  return nil;
}

- (NSInteger) insertionIndex
{
  id container;
  NSArray *array;
  NSInteger count;
  
  container = [self insertionContainer];
  if (container == nil)
    {
      return NSNotFound;
    }
  
  if ([_insertionObject key] != nil)
    {
      array = [container valueForKey: [_insertionObject key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return NSNotFound;
    }
  
  count = [array count];
  
  switch (_insertionPosition)
    {
      case NSPositionBeginning:
        return 0;
      case NSPositionEnd:
        return count;
      case NSPositionBefore:
        if ([_insertionObject isKindOfClass: [NSIndexSpecifier class]])
          {
            return [(NSIndexSpecifier *)_insertionObject index];
          }
        return NSNotFound;
      case NSPositionAfter:
        if ([_insertionObject isKindOfClass: [NSIndexSpecifier class]])
          {
            return [(NSIndexSpecifier *)_insertionObject index] + 1;
          }
        return NSNotFound;
      case NSPositionReplace:
        if ([_insertionObject isKindOfClass: [NSIndexSpecifier class]])
          {
            return [(NSIndexSpecifier *)_insertionObject index];
          }
        return NSNotFound;
      default:
        return NSNotFound;
    }
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *objDesc;
  
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (_insertionObject != nil)
    {
      objDesc = [_insertionObject descriptor];
      if (objDesc != nil)
        {
          [desc setDescriptor: objDesc forKeyword: 'kobj'];
        }
    }
  
  [desc setDescriptor: [NSAppleEventDescriptor descriptorWithEnumCode: _insertionPosition]
           forKeyword: 'kpos'];
  
  return desc;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeInteger: _insertionPosition forKey: @"NSInsertionPosition"];
      [coder encodeObject: _insertionObject forKey: @"NSInsertionObject"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(NSInteger) at: &_insertionPosition];
      [coder encodeObject: _insertionObject];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          _insertionPosition = [coder decodeIntegerForKey: @"NSInsertionPosition"];
          ASSIGN(_insertionObject, [coder decodeObjectForKey: @"NSInsertionObject"]);
        }
      else
        {
          [coder decodeValueOfObjCType: @encode(NSInteger) at: &_insertionPosition];
          ASSIGN(_insertionObject, [coder decodeObject]);
        }
    }
  return self;
}

@end

// NSPropertySpecifier

@implementation NSPropertySpecifier

- (id) objectsByEvaluatingSpecifier
{
  id container;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      return [container valueForKey: [self key]];
    }
  
  return container;
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'seld'];
    }
  
  [desc setDescriptor: [NSAppleEventDescriptor descriptorWithTypeCode: 'prop']
           forKeyword: 'form'];
  
  return desc;
}

@end

// NSRandomSpecifier

@implementation NSRandomSpecifier

- (id) objectsByEvaluatingSpecifier
{
  id container;
  NSArray *array;
  NSUInteger count;
  NSUInteger randomIndex;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      array = [container valueForKey: [self key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return nil;
    }
  
  count = [array count];
  if (count == 0)
    {
      return nil;
    }
  
  randomIndex = random() % count;
  return [array objectAtIndex: randomIndex];
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'form'];
    }
  
  [desc setDescriptor: [NSAppleEventDescriptor descriptorWithTypeCode: 'rang']
           forKeyword: 'seld'];
  
  return desc;
}

@end

// NSRangeSpecifier

@implementation NSRangeSpecifier

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                   startSpecifier: (NSScriptObjectSpecifier *)startSpec
                                     endSpecifier: (NSScriptObjectSpecifier *)endSpec
{
  self = [super initWithContainerClassDescription: classDesc
                              containerSpecifier: container
                                             key: property];
  if (self != nil)
    {
      ASSIGN(_startSpec, startSpec);
      ASSIGN(_endSpec, endSpec);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_startSpec);
  RELEASE(_endSpec);
  [super dealloc];
}

- (NSScriptObjectSpecifier *) startSpecifier
{
  return _startSpec;
}

- (void) setStartSpecifier: (NSScriptObjectSpecifier *)startSpec
{
  ASSIGN(_startSpec, startSpec);
}

- (NSScriptObjectSpecifier *) endSpecifier
{
  return _endSpec;
}

- (void) setEndSpecifier: (NSScriptObjectSpecifier *)endSpec
{
  ASSIGN(_endSpec, endSpec);
}

- (id) objectsByEvaluatingSpecifier
{
  id container;
  NSArray *array;
  NSInteger startIndex;
  NSInteger endIndex;
  NSRange range;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      array = [container valueForKey: [self key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return nil;
    }
  
  startIndex = 0;
  endIndex = [array count] - 1;
  
  if ([_startSpec isKindOfClass: [NSIndexSpecifier class]])
    {
      startIndex = [(NSIndexSpecifier *)_startSpec index];
    }
  
  if ([_endSpec isKindOfClass: [NSIndexSpecifier class]])
    {
      endIndex = [(NSIndexSpecifier *)_endSpec index];
    }
  
  if (startIndex < 0 || endIndex >= [array count] || startIndex > endIndex)
    {
      return nil;
    }
  
  range = NSMakeRange(startIndex, endIndex - startIndex + 1);
  return [array subarrayWithRange: range];
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  NSAppleEventDescriptor *rangeDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'form'];
    }
  
  rangeDesc = [NSAppleEventDescriptor listDescriptor];
  if (_startSpec != nil)
    {
      [rangeDesc insertDescriptor: [_startSpec descriptor] atIndex: 0];
    }
  if (_endSpec != nil)
    {
      [rangeDesc insertDescriptor: [_endSpec descriptor] atIndex: 1];
    }
  
  [desc setDescriptor: rangeDesc forKeyword: 'seld'];
  
  return desc;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _startSpec forKey: @"NSStartSpecifier"];
      [coder encodeObject: _endSpec forKey: @"NSEndSpecifier"];
    }
  else
    {
      [coder encodeObject: _startSpec];
      [coder encodeObject: _endSpec];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          ASSIGN(_startSpec, [coder decodeObjectForKey: @"NSStartSpecifier"]);
          ASSIGN(_endSpec, [coder decodeObjectForKey: @"NSEndSpecifier"]);
        }
      else
        {
          ASSIGN(_startSpec, [coder decodeObject]);
          ASSIGN(_endSpec, [coder decodeObject]);
        }
    }
  return self;
}

@end

// NSRelativeSpecifier

@implementation NSRelativeSpecifier

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                 relativePosition: (NSRelativePosition)relPos
                                   baseSpecifier: (NSScriptObjectSpecifier *)baseSpec
{
  self = [super initWithContainerClassDescription: classDesc
                              containerSpecifier: container
                                             key: property];
  if (self != nil)
    {
      _relativePosition = relPos;
      ASSIGN(_baseSpecifier, baseSpec);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_baseSpecifier);
  [super dealloc];
}

- (NSRelativePosition) relativePosition
{
  return _relativePosition;
}

- (void) setRelativePosition: (NSRelativePosition)relPos
{
  _relativePosition = relPos;
}

- (NSScriptObjectSpecifier *) baseSpecifier
{
  return _baseSpecifier;
}

- (void) setBaseSpecifier: (NSScriptObjectSpecifier *)baseSpec
{
  ASSIGN(_baseSpecifier, baseSpec);
}

- (id) objectsByEvaluatingSpecifier
{
  id container;
  NSArray *array;
  id baseObject;
  NSInteger baseIndex;
  NSInteger targetIndex;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      array = [container valueForKey: [self key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return nil;
    }
  
  if (_baseSpecifier == nil)
    {
      return nil;
    }
  
  baseObject = [_baseSpecifier objectsByEvaluatingSpecifier];
  if (baseObject == nil)
    {
      return nil;
    }
  
  baseIndex = [array indexOfObject: baseObject];
  if (baseIndex == NSNotFound)
    {
      return nil;
    }
  
  if (_relativePosition == NSRelativeBefore)
    {
      targetIndex = baseIndex - 1;
    }
  else
    {
      targetIndex = baseIndex + 1;
    }
  
  if (targetIndex < 0 || targetIndex >= [array count])
    {
      return nil;
    }
  
  return [array objectAtIndex: targetIndex];
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  NSAppleEventDescriptor *baseDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'form'];
    }
  
  [desc setDescriptor: [NSAppleEventDescriptor descriptorWithEnumCode: _relativePosition]
           forKeyword: 'rele'];
  
  if (_baseSpecifier != nil)
    {
      baseDesc = [_baseSpecifier descriptor];
      if (baseDesc != nil)
        {
          [desc setDescriptor: baseDesc forKeyword: 'seld'];
        }
    }
  
  return desc;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeInteger: _relativePosition forKey: @"NSRelativePosition"];
      [coder encodeObject: _baseSpecifier forKey: @"NSBaseSpecifier"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(NSInteger) at: &_relativePosition];
      [coder encodeObject: _baseSpecifier];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          _relativePosition = [coder decodeIntegerForKey: @"NSRelativePosition"];
          ASSIGN(_baseSpecifier, [coder decodeObjectForKey: @"NSBaseSpecifier"]);
        }
      else
        {
          [coder decodeValueOfObjCType: @encode(NSInteger) at: &_relativePosition];
          ASSIGN(_baseSpecifier, [coder decodeObject]);
        }
    }
  return self;
}

@end

// NSUniqueIDSpecifier

@implementation NSUniqueIDSpecifier

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                         uniqueID: (id)uniqueID
{
  self = [super initWithContainerClassDescription: classDesc
                              containerSpecifier: container
                                             key: property];
  if (self != nil)
    {
      ASSIGN(_uniqueID, uniqueID);
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_uniqueID);
  [super dealloc];
}

- (id) uniqueID
{
  return _uniqueID;
}

- (void) setUniqueID: (id)uniqueID
{
  ASSIGN(_uniqueID, uniqueID);
}

- (id) objectsByEvaluatingSpecifier
{
  id container;
  NSArray *array;
  id object;
  NSEnumerator *enumerator;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      array = [container valueForKey: [self key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return nil;
    }
  
  enumerator = [array objectEnumerator];
  while ((object = [enumerator nextObject]) != nil)
    {
      id objectID;
      
      if ([object respondsToSelector: @selector(uniqueID)])
        {
          objectID = [object performSelector: @selector(uniqueID)];
        }
      else
        {
          objectID = [object valueForKey: @"uniqueID"];
        }
      
      if (objectID != nil && [objectID isEqual: _uniqueID])
        {
          return object;
        }
    }
  
  return nil;
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'form'];
    }
  
  if (_uniqueID != nil)
    {
      NSAppleEventDescriptor *idDesc;
      
      if ([_uniqueID isKindOfClass: [NSString class]])
        {
          idDesc = [NSAppleEventDescriptor descriptorWithString: _uniqueID];
        }
      else if ([_uniqueID isKindOfClass: [NSNumber class]])
        {
          idDesc = [NSAppleEventDescriptor descriptorWithInt32: [_uniqueID intValue]];
        }
      else
        {
          idDesc = nil;
        }
      
      if (idDesc != nil)
        {
          [desc setDescriptor: idDesc forKeyword: 'seld'];
        }
    }
  
  return desc;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _uniqueID forKey: @"NSUniqueID"];
    }
  else
    {
      [coder encodeObject: _uniqueID];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          ASSIGN(_uniqueID, [coder decodeObjectForKey: @"NSUniqueID"]);
        }
      else
        {
          ASSIGN(_uniqueID, [coder decodeObject]);
        }
    }
  return self;
}

@end

// NSWhoseSpecifier

@implementation NSWhoseSpecifier

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                             test: (NSScriptWhoseTest *)test
{
  self = [super initWithContainerClassDescription: classDesc
                              containerSpecifier: container
                                             key: property];
  if (self != nil)
    {
      ASSIGN(_test, test);
      _startSubelementIdentifier = NSNoSubelement;
      _startSubelementIndex = 0;
      _endSubelementIdentifier = NSNoSubelement;
      _endSubelementIndex = 0;
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_test);
  [super dealloc];
}

- (NSScriptWhoseTest *) test
{
  return _test;
}

- (void) setTest: (NSScriptWhoseTest *)test
{
  ASSIGN(_test, test);
}

- (NSWhoseSubelementIdentifier) startSubelementIdentifier
{
  return _startSubelementIdentifier;
}

- (void) setStartSubelementIdentifier: (NSWhoseSubelementIdentifier)subelement
{
  _startSubelementIdentifier = subelement;
}

- (NSInteger) startSubelementIndex
{
  return _startSubelementIndex;
}

- (void) setStartSubelementIndex: (NSInteger)index
{
  _startSubelementIndex = index;
}

- (NSWhoseSubelementIdentifier) endSubelementIdentifier
{
  return _endSubelementIdentifier;
}

- (void) setEndSubelementIdentifier: (NSWhoseSubelementIdentifier)subelement
{
  _endSubelementIdentifier = subelement;
}

- (NSInteger) endSubelementIndex
{
  return _endSubelementIndex;
}

- (void) setEndSubelementIndex: (NSInteger)index
{
  _endSubelementIndex = index;
}

- (id) objectsByEvaluatingSpecifier
{
  id container;
  NSArray *array;
  NSMutableArray *result;
  id object;
  NSEnumerator *enumerator;
  
  container = [[self containerSpecifier] objectsByEvaluatingSpecifier];
  if (container == nil)
    {
      return nil;
    }
  
  if ([self key] != nil)
    {
      array = [container valueForKey: [self key]];
    }
  else
    {
      array = container;
    }
  
  if (![array isKindOfClass: [NSArray class]])
    {
      return nil;
    }
  
  if (_test == nil)
    {
      return array;
    }
  
  result = [NSMutableArray arrayWithCapacity: [array count]];
  enumerator = [array objectEnumerator];
  
  while ((object = [enumerator nextObject]) != nil)
    {
      if ([_test isTrue])
        {
          [result addObject: object];
        }
    }
  
  return result;
}

- (NSAppleEventDescriptor *) descriptor
{
  NSAppleEventDescriptor *desc;
  NSAppleEventDescriptor *containerDesc;
  
  containerDesc = [[self containerSpecifier] descriptor];
  desc = [NSAppleEventDescriptor recordDescriptor];
  
  if (containerDesc != nil)
    {
      [desc setDescriptor: containerDesc forKeyword: 'from'];
    }
  
  if ([self key] != nil)
    {
      [desc setDescriptor: [NSAppleEventDescriptor descriptorWithString: [self key]]
               forKeyword: 'form'];
    }
  
  [desc setDescriptor: [NSAppleEventDescriptor descriptorWithTypeCode: 'whos']
           forKeyword: 'form'];
  
  return desc;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  [super encodeWithCoder: coder];
  if ([coder allowsKeyedCoding])
    {
      [coder encodeObject: _test forKey: @"NSTest"];
      [coder encodeInteger: _startSubelementIdentifier forKey: @"NSStartSubelementIdentifier"];
      [coder encodeInteger: _startSubelementIndex forKey: @"NSStartSubelementIndex"];
      [coder encodeInteger: _endSubelementIdentifier forKey: @"NSEndSubelementIdentifier"];
      [coder encodeInteger: _endSubelementIndex forKey: @"NSEndSubelementIndex"];
    }
  else
    {
      [coder encodeObject: _test];
      [coder encodeValueOfObjCType: @encode(NSInteger) at: &_startSubelementIdentifier];
      [coder encodeValueOfObjCType: @encode(NSInteger) at: &_startSubelementIndex];
      [coder encodeValueOfObjCType: @encode(NSInteger) at: &_endSubelementIdentifier];
      [coder encodeValueOfObjCType: @encode(NSInteger) at: &_endSubelementIndex];
    }
}

- (instancetype) initWithCoder: (NSCoder *)coder
{
  self = [super initWithCoder: coder];
  if (self != nil)
    {
      if ([coder allowsKeyedCoding])
        {
          ASSIGN(_test, [coder decodeObjectForKey: @"NSTest"]);
          _startSubelementIdentifier = [coder decodeIntegerForKey: @"NSStartSubelementIdentifier"];
          _startSubelementIndex = [coder decodeIntegerForKey: @"NSStartSubelementIndex"];
          _endSubelementIdentifier = [coder decodeIntegerForKey: @"NSEndSubelementIdentifier"];
          _endSubelementIndex = [coder decodeIntegerForKey: @"NSEndSubelementIndex"];
        }
      else
        {
          ASSIGN(_test, [coder decodeObject]);
          [coder decodeValueOfObjCType: @encode(NSInteger) at: &_startSubelementIdentifier];
          [coder decodeValueOfObjCType: @encode(NSInteger) at: &_startSubelementIndex];
          [coder decodeValueOfObjCType: @encode(NSInteger) at: &_endSubelementIdentifier];
          [coder decodeValueOfObjCType: @encode(NSInteger) at: &_endSubelementIndex];
        }
    }
  return self;
}

@end

#pragma clang diagnostic pop
