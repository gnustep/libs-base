/* GSCompatibility - Extra definitions for compiling on MacOSX

   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Written by:  Stephane Corthesy on Sat Nov 16 2002.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

*/
#include "config.h"
#include <objc/objc-class.h>
#include "GSCompatibility.h"

/* FIXME: Need to initialize this */
NSRecursiveLock *gnustep_global_lock = NULL;

NSString *GetEncodingName(NSStringEncoding availableEncodingValue)
{
return (NSString *)CFStringGetNameOfEncoding(CFStringConvertNSStringEncodingToEncoding(availableEncodingValue));
}

NSArray *NSStandardLibraryPaths()
{
    return NSSearchPathForDirectoriesInDomains(NSAllLibrariesDirectory, NSAllDomainsMask, YES);
}

// Defined in NSDebug.m
NSString*
GSDebugMethodMsg(id obj, SEL sel, const char *file, int line, NSString *fmt)
{
    NSString	*message;
    Class		cls = (Class)obj;
    char		c = '+';

    if ([obj isInstance] == YES)
    {
        c = '-';
        cls = [obj class];
    }
    message = [NSString stringWithFormat: @"File %s: %d. In [%@ %c%@] %@",
        file, line, NSStringFromClass(cls), c, NSStringFromSelector(sel), fmt];
    return message;
}

NSString*
GSDebugFunctionMsg(const char *func, const char *file, int line, NSString *fmt)
{
    NSString *message;

    message = [NSString stringWithFormat: @"File %s: %d. In %s %@",
        file, line, func, fmt];
    return message;
}

@implementation NSArray (GSCompatibility)

/**
 * Initialize the receiver with the contents of array.
 * The order of array is preserved.<br />
 * If shouldCopy is YES then the objects are copied
 * rather than simply retained.<br />
 * Invokes -initWithObjects:count:
 */
- (id) initWithArray: (NSArray*)array copyItems: (BOOL)shouldCopy
{
  unsigned	c = [array count];
  id		objects[c];

  [array getObjects: objects];
  if (shouldCopy == YES)
    {
      unsigned	i;

      for (i = 0; i < c; i++)
	{
	  objects[i] = [objects[i] copy];
	}
      self = [self initWithObjects: objects count: c];
#if GS_WITH_GC == 0
      while (i > 0)
	{
	  [objects[--i] release];
	}
#endif
    }
  else
    {
      self = [self initWithObjects: objects count: c];
    }
  return self;
}

@end

@implementation NSProcessInfo(GNUStepGlue)

static NSMutableSet	*_debug_set = nil;

BOOL GSDebugSet(NSString *level)
// From GNUStep's
{
    static IMP debugImp = 0;
    static SEL debugSel;

    if (debugImp == 0)
    {
        debugSel = @selector(member:);
        if (_debug_set == nil)
        {
            [[NSProcessInfo processInfo] debugSet];
        }
        debugImp = [_debug_set methodForSelector: debugSel];
    }
    if ((*debugImp)(_debug_set, debugSel, level) == nil)
    {
        return NO;
    }
    return YES;
}

- (NSMutableSet *) debugSet
// Derived from GNUStep's
{
    if(_debug_set == nil){
        int				argc = [[self arguments] count];
        NSMutableSet	*mySet;
        int				i;

        mySet = [NSMutableSet new];
        for (i = 0; i < argc; i++)
        {
            NSString	*str = [[self arguments] objectAtIndex:i];

            if ([str hasPrefix: @"--GNU-Debug="])
                [mySet addObject: [str substringFromIndex: 12]];
        }
        _debug_set = mySet;
    }

    return _debug_set;
}

@end

@implementation NSString(GNUStepGlue)

// From GNUStep
/**
 * If the string consists of the words 'true' or 'yes' (case insensitive)
 * or begins with a non-zero numeric value, return YES, otherwise return
 * NO.
 */
- (BOOL) boolValue
{
    if ([self caseInsensitiveCompare: @"YES"] == NSOrderedSame)
    {
        return YES;
    }
    if ([self caseInsensitiveCompare: @"true"] == NSOrderedSame)
    {
        return YES;
    }
    return [self intValue] != 0 ? YES : NO;
}

@end

@implementation NSInvocation(GNUStepGlue)
- (retval_t) returnFrame:(arglist_t)args
{
#warning (stephane@sente.ch) Not implemented
    return (retval_t)[self notImplemented:_cmd];
}

- (id) initWithArgframe:(arglist_t)args selector:(SEL)selector
{
#warning (stephane@sente.ch) Not implemented
    return [self notImplemented:_cmd];
}

@end

@implementation NSObject(GNUStepGlue)

+ (id) notImplemented:(SEL)selector
{
#warning (stephane@sente.ch) Not implemented
    [NSException raise: NSGenericException
                format: @"method %s not implemented in %s(class)",
selector ? sel_get_name(selector) : "(null)",
        object_get_class_name(self)];
    return nil;
}

// In NSObject.m, category GNU
- (BOOL) isInstance
{
    return GSObjCIsInstance(self);
}

@end

