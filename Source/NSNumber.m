/* NSNumber - Object encapsulation of numbers
    
   Copyright (C) 1993, 1994, 1996 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Created: Mar 1995

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

#include <config.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSCoder.h>

@implementation NSNumber

/* Returns the concrete class associated with the type encoding. Note 
   that we don't allow NSNumber to instantiate any class but its own
   concrete subclasses (see check at end of method) */
+ (Class)valueClassWithObjCType:(const char *)type
{
    Class theClass = Nil;

    switch (*type) {
    case _C_CHR:
	theClass = [NSCharNumber class];
	break;
    case _C_UCHR:
	theClass = [NSUCharNumber class];
	break;
    case _C_SHT:
	theClass = [NSShortNumber class];
	break;
    case _C_USHT:
	theClass = [NSUShortNumber class];
	break;
    case _C_INT:
	theClass = [NSIntNumber class];
	break;
    case _C_UINT:
	theClass = [NSUIntNumber class];
	break;
    case _C_LNG:
	theClass = [NSLongNumber class];
	break;
    case _C_ULNG:
	theClass = [NSULongNumber class];
	break;
    case 'q':
	theClass = [NSLongLongNumber class];
	break;
    case 'Q':
	theClass = [NSULongLongNumber class];
	break;
    case _C_FLT:
	theClass = [NSFloatNumber class];
	break;
    case _C_DBL:
	theClass = [NSDoubleNumber class];
	break;
    default:
	break;
    }

    if (theClass == Nil && self == [NSNumber class]) {
	[NSException raise:NSInvalidArgumentException
		format:@"Invalid number type"];
	/* NOT REACHED */
    } else if (theClass == Nil)
    	theClass = [super valueClassWithObjCType:type];

    return theClass;
}

+ (NSNumber *)numberWithBool:(BOOL)value
{
    return [[[NSBoolNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithChar:(char)value
{
    return [[[NSCharNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithDouble:(double)value
{
    return [[[NSDoubleNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithFloat:(float)value
{
    return [[[NSFloatNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithInt:(int)value
{
    return [[[NSIntNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithLong:(long)value
{
    return [[[NSLongNumber alloc] initValue:&value withObjCType:NULL] autorelease];
}

+ (NSNumber *)numberWithLongLong:(long long)value
{
    return [[[NSLongLongNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithShort:(short)value
{
    return [[[NSShortNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithUnsignedChar:(unsigned char)value
{
    return [[[NSUCharNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithUnsignedInt:(unsigned int)value
{
    return [[[NSUIntNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithUnsignedLong:(unsigned long)value
{
    return [[[NSULongNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithUnsignedLongLong:(unsigned long long)value
{
    return [[[NSULongLongNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ (NSNumber *)numberWithUnsignedShort:(unsigned short)value
{
    return [[[NSUShortNumber alloc] initValue:&value withObjCType:NULL] 
	autorelease];
}

+ valueFromString: (NSString *)string
{
  /* FIXME: implement this better */
  const char *str;

  str = [string cString];
  if (strchr(str, '.') >= 0 || strchr(str, 'e') >= 0 
      || strchr(str, 'E') >= 0)
    return [NSNumber numberWithDouble: atof(str)];
  else if (strchr(str, '-') >= 0)
    return [NSNumber numberWithInt: atoi(str)];
  else
    return [NSNumber numberWithUnsignedInt: atoi(str)];
  return [NSNumber numberWithInt: 0];
}

- (id)initWithBool:(BOOL)value
{
    [self dealloc];
    return self=[[NSBoolNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithChar:(char)value
{
    [self dealloc];
    return self=[[NSCharNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithDouble:(double)value
{
    [self dealloc];
    return self=[[NSDoubleNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithFloat:(float)value
{
    [self dealloc];
    return self=[[NSFloatNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithInt:(int)value
{
    [self dealloc];
    return self=[[NSIntNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithLong:(long)value
{
    [self dealloc];
    return self=[[NSLongNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithLongLong:(long long)value
{
    [self dealloc];
    return self=[[NSLongLongNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithShort:(short)value
{
    [self dealloc];
    return self=[[NSShortNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedChar:(unsigned char)value
{
    [self dealloc];
    return self=[[NSUCharNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedInt:(unsigned int)value
{
    [self dealloc];
    return self=[[NSUIntNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedLong:(unsigned long)value
{
    [self dealloc];
    return self=[[NSULongNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedLongLong:(unsigned long long)value
{
    [self dealloc];
    return self=[[NSULongLongNumber alloc] initValue:&value withObjCType:NULL];
}

- (id)initWithUnsignedShort:(unsigned short)value
{
    [self dealloc];
    return self=[[NSUShortNumber alloc] initValue:&value withObjCType:NULL];
}

- (id) copy
{
    return [self retain];
}

- copyWithZone: (NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone)) {
        return [self retain];
    }
    else {
        return NSCopyObject(self, 0, zone);
    }
}

- (NSString*) description
{
    return [self descriptionWithLocale: nil];
}

- (NSString*) descriptionWithLocale: (NSDictionary*)locale
{
    [self subclassResponsibility:_cmd];
    return nil;
}

/* All the rest of these methods must be implemented by a subclass */
- (BOOL)boolValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (char)charValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (double)doubleValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (float)floatValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (int)intValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (long long)longLongValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (long)longValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (short)shortValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (NSString *)stringValue
{
    return [self descriptionWithLocale: nil];
}

- (unsigned char)unsignedCharValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned int)unsignedIntValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned long long)unsignedLongLongValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned long)unsignedLongValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned short)unsignedShortValue
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (NSComparisonResult)compare:(NSNumber *)otherNumber
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (unsigned) hash
{
    [self subclassResponsibility:_cmd];
    return 0;
}

- (BOOL)isEqualToNumber:(NSNumber *)otherNumber
{
    [self subclassResponsibility:_cmd];
    return NO;
}

// NSCoding (done by subclasses)
- (void)encodeWithCoder:(NSCoder *)coder
{
    [super encodeWithCoder:coder];
}

- (id)initWithCoder:(NSCoder *)coder
{
    [NSException raise:NSInconsistentArchiveException
	format:@"Cannot unarchive from NSNumber class - Need NSValueDecoder."];
    return self;
}

@end
