/* Implementation for NSValueTransformer for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written Dr. H. Nikolaus Schaller
   Created on Mon Mar 21 2005.
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
   */ 

#import "Foundation/Foundation.h"

@implementation NSValueTransformer

NSString * const NSNegateBooleanTransformerName
  = @"NSNegateBooleanTransformerName";
NSString * const NSIsNilTransformerName
  = @"NSIsNilTransformerName";
NSString * const NSIsNotNilTransformerName
  = @"NSIsNotNilTransformerName"; 
NSString * const NSUnarchiveFromDataTransformerName
  = @"NSUnarchiveFromDataTransformerName";

// non-abstract methods

static NSMutableDictionary *names;

+ (void) setValueTransformer: (NSValueTransformer *)transformer
		     forName: (NSString *)name
{
  if (names == nil)
    {
      [self valueTransformerNames];	// allocate if needed
    }
  [names setObject: transformer forKey: name];
}

+ (NSValueTransformer *) valueTransformerForName: (NSString *)name
{
  return [names objectForKey: name];
}

+ (NSArray *) valueTransformerNames;
{
  if (names == nil)
    {
      names = [[NSMutableDictionary alloc] init];
    }
  return [names allKeys];
}

// abstract methods (must be implemented in subclasses)

+ (BOOL) allowsReverseTransformation
{
  [self subclassResponsibility: _cmd];
  return NO;
}

+ (Class) transformedValueClass
{
  return [self subclassResponsibility: _cmd];
}

- (id) reverseTransformedValue: (id)value
{
  return [self subclassResponsibility: _cmd];
}

- (id) transformedValue: (id)value
{
  return [self subclassResponsibility: _cmd];
}

@end

// builtin transformers

@implementation NSNegateBooleanTransformer

+ (BOOL) allowsReverseTransformation
{
  return YES;
}
+ (Class) transformedValueClass
{
  return [NSNumber class];
}
- (id) reverseTransformedValue: (id) value
{
  return [NSNumber numberWithBool: ![value boolValue]];
}
- (id) transformedValue: (id)value
{
  return [NSNumber numberWithBool: ![value boolValue]];
}

@end

@implementation NSIsNilTransformer

+ (BOOL) allowsReverseTransformation
{
  return NO;
}
+ (Class) transformedValueClass
{
  return [NSNumber class];
}
- (id) reverseTransformedValue: (id)value
{
  return [self notImplemented: _cmd];
}
- (id) transformedValue: (id)value
{
  return [NSNumber numberWithBool: (value == nil)];
}

@end

@implementation NSIsNotNilTransformer

+ (BOOL) allowsReverseTransformation
{
  return NO;
}
+ (Class) transformedValueClass
{
  return [NSNumber class];
}
- (id) reverseTransformedValue: (id)value
{
  return [self notImplemented: _cmd];
}
- (id) transformedValue: (id)value
{
  return [NSNumber numberWithBool: (value != nil)];
}

@end

@implementation NSUnarchiveFromDataTransformer

+ (BOOL) allowsReverseTransformation
{
  return YES;
}
+ (Class) transformedValueClass
{
  return [NSData class];
}
- (id) reverseTransformedValue: (id)value
{
  return [self notImplemented: _cmd];
}
- (id) transformedValue: (id)value
{
  return [self notImplemented: _cmd];
}

@end
