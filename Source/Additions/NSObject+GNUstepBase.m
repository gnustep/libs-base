/* Implementation of extension methods to base additions

   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

*/
#import "common.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLock.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/NSDebug+GNUstepBase.h"

/**
 * Extension methods for the NSObject class
 */
@implementation NSObject (GNUstepBase)

+ (id) notImplemented: (SEL)selector
{
  [NSException raise: NSGenericException
    format: @"method %@ not implemented in %s(class)",
    selector ? (id)NSStringFromSelector(selector) : (id)@"(null)",
    NSStringFromClass(self)];
  return nil;
}

- (NSComparisonResult) compare: (id)anObject
{
  NSLog(@"WARNING: The -compare: method for NSObject is deprecated.");

  if (anObject == self)
    {
      return NSOrderedSame;
    }
  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		   format: @"nil argument for compare:"];
    }
  if ([self isEqual: anObject])
    {
      return NSOrderedSame;
    }
  /*
   * Ordering objects by their address is pretty useless,
   * so subclasses should override this is some useful way.
   */
  if ((id)self > anObject)
    {
      return NSOrderedDescending;
    }
  else
    {
      return NSOrderedAscending;
    }
}

- (BOOL) isInstance
{
  GSOnceMLog(@"Warning, the -isInstance method is deprecated. "
    @"Use 'class_isMetaClass([self class]) ? NO : YES' instead");
  return class_isMetaClass([self class]) ? NO : YES;
}

- (id) makeImmutableCopyOnFail: (BOOL)force
{
  if (force == YES)
    {
      return AUTORELEASE([self copy]);
    }
  return self;
}

- (id) notImplemented: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException
    raise: NSInvalidArgumentException
    format: @"[%@%c%@] not implemented",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  return self;	// Not reached
}

- (id) shouldNotImplement: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException
    raise: NSInvalidArgumentException
    format: @"[%@%c%@] should not be implemented",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  return self;	// Not reached
}

- (id) subclassResponsibility: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException raise: NSInvalidArgumentException
    format: @"[%@%c%@] should be overridden by subclass",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  return self;	// Not reached
}

@end

#if     defined(GNUSTEP)
struct exitLink {
  struct exitLink	*next;
  id			obj;	// Object to release or class for atExit
  SEL			sel;	// Selector for atExit or 0 if releasing
  id			*at;	// Address of static variable or NULL
};

static struct exitLink	*exited = 0;
static BOOL		enabled = NO;
static BOOL		shouldCleanUp = NO;

static void
handleExit()
{
  while (exited != 0)
    {
      struct exitLink	*tmp = exited;

      exited = tmp->next;
      if (0 != tmp->sel)
	{
	  Method	method;
	  IMP		msg;

	  method = class_getClassMethod(tmp->obj, tmp->sel);
	  msg = method_getImplementation(method);
	  if (0 != msg)
	    {
	      (*msg)(tmp->obj, tmp->sel);
	    }
	}
      else if (YES == shouldCleanUp)
	{
	  if (0 != tmp->at)
	    {
	      tmp->obj = *(tmp->at);
	      *(tmp->at) = nil;
	    }
	  [tmp->obj release];
	}
      free(tmp);
    }

}

@implementation NSObject(GSCleanup)

+ (id) leakAt: (id*)anAddress
{
  struct exitLink	*l;

  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->at = anAddress;
  l->obj = [*anAddress retain];
  l->sel = 0;
  [gnustep_global_lock lock];
  l->next = exited;
  exited = l;
  [gnustep_global_lock unlock];
  return l->obj;
}

+ (id) leak: (id)anObject
{
  struct exitLink	*l;

  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->at = 0;
  l->obj = [anObject retain];
  l->sel = 0;
  [gnustep_global_lock lock];
  l->next = exited;
  exited = l;
  [gnustep_global_lock unlock];
  return l->obj;
}

+ (BOOL) registerAtExit
{
  return [self registerAtExit: @selector(atExit)];
}

+ (BOOL) registerAtExit: (SEL)sel
{
  Method		m;
  Class			s;
  struct exitLink	*l;

  if (0 == sel)
    {
      sel = @selector(atExit);
    }

  m = class_getClassMethod(self, sel);
  if (0 == m)
    {
      return NO;	// method not implemented.
    }

  s = class_getSuperclass(self);
  if (0 != s && class_getClassMethod(s, sel) == m)
    {
      return NO;	// method not implemented in this class
    }

  [gnustep_global_lock lock];
  for (l = exited; l != 0; l = l->next)
    {
      if (l->obj == self && sel_isEqual(l->sel, sel))
	{
	  [gnustep_global_lock unlock];
	  return NO;	// Already registered
	}
    }
  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->obj = self;
  l->sel = sel;
  l->at = 0;
  l->next = exited;
  exited = l;
  if (NO == enabled)
    {
      atexit(handleExit);
      enabled = YES;
    }
  [gnustep_global_lock unlock];
  return YES;
}

+ (void) setShouldCleanUp: (BOOL)aFlag
{
  if (YES == aFlag)
    {
      [gnustep_global_lock lock];
      if (NO == enabled)
	{
	  atexit(handleExit);
	  enabled = YES;
	}
      [gnustep_global_lock unlock];
      shouldCleanUp = YES;
    }
  else
    {
      shouldCleanUp = NO;
    }
}

+ (BOOL) shouldCleanUp
{
  return shouldCleanUp;
}

@end

#else

/* Dummy implementation
 */
@implementation NSObject(GSCleanup)

+ (id) leakAt: (id*)anAddress
{
  [*anAddress retain];
}

+ (id) leak: (id)anObject
{
  return [anObject retain];
}

+ (BOOL) registerAtExit
{
  return [self registerAtExit: @selector(atExit)];
}

+ (BOOL) registerAtExit: (SEL)sel
{
  return NO;
}

+ (void) setShouldCleanUp: (BOOL)aFlag
{
  return;
}

+ (BOOL) shouldCleanUp
{
  return NO;
}

#endif

