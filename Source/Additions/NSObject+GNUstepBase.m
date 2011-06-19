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
  return nil;
}

- (id) shouldNotImplement: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException
    raise: NSInvalidArgumentException
    format: @"[%@%c%@] should not be implemented",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  return nil;
}

- (id) subclassResponsibility: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException raise: NSInvalidArgumentException
    format: @"[%@%c%@] should be overridden by subclass",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  return nil;
}

@end

struct exitLink {
  struct exitLink	*next;
  Class			cls;
};

struct leakLink {
  struct leakLink	*next;
  id			obj;
  id			*at;
};

static struct exitLink	*exited = 0;
static struct leakLink	*leaked = 0;
static BOOL		enabled = NO;
static BOOL		shouldCleanUp = NO;

static void
handleExit()
{
  if (YES == shouldCleanUp)
    {
      while (leaked != 0)
	{
	  struct leakLink	*tmp = leaked;

	  leaked = tmp->next;
	  if (0 != tmp->at)
	    {
	      tmp->obj = *(tmp->at);
	      *(tmp->at) = nil;
	    }
	  [tmp->obj release];
	  free(tmp);
	}
    }

  while (exited != 0)
    {
      struct exitLink	*tmp = exited;

      exited = tmp->next;
      [tmp->cls atExit];
      free(tmp);
    }

  [gnustep_global_lock release];
}

@implementation NSObject(atExit)

+ (void) atExit
{
  return;
}

+ (id) leakAt: (id*)anAddress
{
  struct leakLink	*l;

  l = (struct leakLink*)malloc(sizeof(struct leakLink));
  l->at = anAddress;
  l->obj = [*anAddress retain];
  [gnustep_global_lock lock];
  l->next = leaked;
  leaked = l;
  [gnustep_global_lock unlock];
  return l->obj;
}

+ (id) leak: (id)anObject
{
  struct leakLink	*l;

  l = (struct leakLink*)malloc(sizeof(struct leakLink));
  l->at = 0;
  l->obj = [anObject retain];
  [gnustep_global_lock lock];
  l->next = leaked;
  leaked = l;
  [gnustep_global_lock unlock];
  return l->obj;
}

+ (void) registerAtExit
{
  Method	m = class_getClassMethod(self, @selector(atExit));

  if (m != 0)
    {
      Class	s = class_getSuperclass(self);

      if (0 == s || class_getClassMethod(s, @selector(atExit)) != m)
	{
	  struct exitLink	*l;

	  [gnustep_global_lock lock];
	  for (l = exited; l != 0; l = l->next)
	    {
	      if (l->cls == self)
		{
		  [gnustep_global_lock unlock];
		  return;	// Already registered
		}
	    }
	  l = (struct exitLink*)malloc(sizeof(struct exitLink));
	  l->cls = self;
	  l->next = exited;
	  exited = l;
	  if (NO == enabled)
	    {
	      atexit(handleExit);
	      enabled = YES;
	    }
	  [gnustep_global_lock lock];
	}
    }
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
      [gnustep_global_lock lock];
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

