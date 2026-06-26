/**Definition of class NSScriptObjectSpecifier
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

#ifndef _NSScriptObjectSpecifier_h_GNUSTEP_BASE_INCLUDE
#define _NSScriptObjectSpecifier_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

@class NSAppleEventDescriptor;
@class NSScriptClassDescription;
@class NSScriptWhoseTest;
@class NSString;

typedef NS_ENUM(NSInteger, NSInsertionPosition) {
  NSPositionAfter = 0,
  NSPositionBefore,
  NSPositionBeginning,
  NSPositionEnd,
  NSPositionReplace
};

typedef NS_ENUM(NSInteger, NSRelativePosition) {
  NSRelativeBefore = 0,
  NSRelativeAfter
};

typedef NS_ENUM(NSInteger, NSWhoseSubelementIdentifier) {
  NSIndexSubelement = 0,
  NSEverySubelement,
  NSMiddleSubelement,
  NSRandomSubelement,
  NSNoSubelement
};

#if OS_API_VERSION(MAC_OS_X_VERSION_10_0, GS_API_LATEST)

GS_EXPORT_CLASS
@interface NSScriptObjectSpecifier : NSObject <NSCoding>
{
  @private
  NSScriptObjectSpecifier *_container;
  NSString *_key;
  NSScriptClassDescription *_classDescription;
}

- (instancetype) initWithContainerSpecifier: (NSScriptObjectSpecifier *)container
                                         key: (NSString *)property;

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property;

- (NSScriptObjectSpecifier *) containerSpecifier;
- (void) setContainerSpecifier: (NSScriptObjectSpecifier *)subRef;

- (BOOL) containerIsObjectBeingTested;
- (void) setContainerIsObjectBeingTested: (BOOL)flag;

- (BOOL) containerIsRangeContainerObject;
- (void) setContainerIsRangeContainerObject: (BOOL)flag;

- (NSString *) key;
- (void) setKey: (NSString *)key;

- (NSScriptClassDescription *) keyClassDescription;

- (NSAppleEventDescriptor *) descriptor;

- (id) objectsByEvaluatingSpecifier;

- (NSAppleEventDescriptor *) descriptorAtIndex: (NSInteger)index;

- (NSInteger) evaluationErrorNumber;
- (void) setEvaluationErrorNumber: (NSInteger)error;

- (NSString *) evaluationErrorSpecifier;

@end

// Subclasses

GS_EXPORT_CLASS
@interface NSIndexSpecifier : NSScriptObjectSpecifier
{
  @private
  NSInteger _index;
}

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                            index: (NSInteger)index;

- (NSInteger) index;
- (void) setIndex: (NSInteger)index;

@end

GS_EXPORT_CLASS
@interface NSMiddleSpecifier : NSScriptObjectSpecifier
@end

GS_EXPORT_CLASS
@interface NSNameSpecifier : NSScriptObjectSpecifier
{
  @private
  NSString *_name;
}

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                             name: (NSString *)name;

- (NSString *) name;
- (void) setName: (NSString *)name;

@end

GS_EXPORT_CLASS
@interface NSPositionSpecifier : NSScriptObjectSpecifier
{
  @private
  NSInsertionPosition _insertionPosition;
  id _insertionObject;
}

- (instancetype) initWithPosition: (NSInsertionPosition)position
              objectSpecifier: (NSScriptObjectSpecifier *)specifier;

- (NSInsertionPosition) insertionPosition;
- (void) setInsertionPosition: (NSInsertionPosition)position;

- (NSScriptObjectSpecifier *) objectSpecifier;
- (void) setObjectSpecifier: (NSScriptObjectSpecifier *)objSpec;

- (void) evaluate;
- (id) insertionContainer;
- (NSString *) insertionKey;
- (NSInteger) insertionIndex;

@end

GS_EXPORT_CLASS
@interface NSPropertySpecifier : NSScriptObjectSpecifier
@end

GS_EXPORT_CLASS
@interface NSRandomSpecifier : NSScriptObjectSpecifier
@end

GS_EXPORT_CLASS
@interface NSRangeSpecifier : NSScriptObjectSpecifier
{
  @private
  NSScriptObjectSpecifier *_startSpec;
  NSScriptObjectSpecifier *_endSpec;
}

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                   startSpecifier: (NSScriptObjectSpecifier *)startSpec
                                     endSpecifier: (NSScriptObjectSpecifier *)endSpec;

- (NSScriptObjectSpecifier *) startSpecifier;
- (void) setStartSpecifier: (NSScriptObjectSpecifier *)startSpec;

- (NSScriptObjectSpecifier *) endSpecifier;
- (void) setEndSpecifier: (NSScriptObjectSpecifier *)endSpec;

@end

GS_EXPORT_CLASS
@interface NSRelativeSpecifier : NSScriptObjectSpecifier
{
  @private
  NSRelativePosition _relativePosition;
  NSScriptObjectSpecifier *_baseSpecifier;
}

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                 relativePosition: (NSRelativePosition)relPos
                                   baseSpecifier: (NSScriptObjectSpecifier *)baseSpec;

- (NSRelativePosition) relativePosition;
- (void) setRelativePosition: (NSRelativePosition)relPos;

- (NSScriptObjectSpecifier *) baseSpecifier;
- (void) setBaseSpecifier: (NSScriptObjectSpecifier *)baseSpec;

@end

GS_EXPORT_CLASS
@interface NSUniqueIDSpecifier : NSScriptObjectSpecifier
{
  @private
  id _uniqueID;
}

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                         uniqueID: (id)uniqueID;

- (id) uniqueID;
- (void) setUniqueID: (id)uniqueID;

@end

GS_EXPORT_CLASS
@interface NSWhoseSpecifier : NSScriptObjectSpecifier
{
  @private
  NSScriptWhoseTest *_test;
  NSWhoseSubelementIdentifier _startSubelementIdentifier;
  NSInteger _startSubelementIndex;
  NSWhoseSubelementIdentifier _endSubelementIdentifier;
  NSInteger _endSubelementIndex;
}

- (instancetype) initWithContainerClassDescription: (NSScriptClassDescription *)classDesc
                               containerSpecifier: (NSScriptObjectSpecifier *)container
                                              key: (NSString *)property
                                             test: (NSScriptWhoseTest *)test;

- (NSScriptWhoseTest *) test;
- (void) setTest: (NSScriptWhoseTest *)test;

- (NSWhoseSubelementIdentifier) startSubelementIdentifier;
- (void) setStartSubelementIdentifier: (NSWhoseSubelementIdentifier)subelement;

- (NSInteger) startSubelementIndex;
- (void) setStartSubelementIndex: (NSInteger)index;

- (NSWhoseSubelementIdentifier) endSubelementIdentifier;
- (void) setEndSubelementIdentifier: (NSWhoseSubelementIdentifier)subelement;

- (NSInteger) endSubelementIndex;
- (void) setEndSubelementIndex: (NSInteger)index;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSScriptObjectSpecifier_h_GNUSTEP_BASE_INCLUDE */
