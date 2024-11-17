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
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

*/
#import "common.h"
#import "GSPThread.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSException.h"
#import "Foundation/NSHashTable.h"
#import "Foundation/NSLock.h"
#import "GNUstepBase/GSObjCRuntime.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"
#import "GNUstepBase/NSDebug+GNUstepBase.h"
#import "GNUstepBase/NSThread+GNUstepBase.h"

#ifdef HAVE_MALLOC_H
#include	<malloc.h>
#endif

/* This file contains methods which nominally return an id but in fact
 * always rainse an exception and never return.
 * We need to suppress the compiler warning about that.
 */
#pragma GCC diagnostic ignored "-Wreturn-type"

/**
 * Extension methods for the NSObject class
 */
@implementation NSObject (GNUstepBase)

+ (id) notImplemented: (SEL)selector
{
  [NSException raise: NSGenericException
    format: @"method %@ not implemented in %@(class)",
    selector ? (id)NSStringFromSelector(selector) : (id)@"(null)",
    NSStringFromClass(self)];
  while (1) ;   // Does not return
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

- (BOOL) makeImmutable
{
  return NO;
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
  while (1) ;   // Does not return
}

- (id) shouldNotImplement: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException
    raise: NSInvalidArgumentException
    format: @"[%@%c%@] should not be implemented",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  while (1) ;   // Does not return
}

- (id) subclassResponsibility: (SEL)aSel
{
  char	c = (class_isMetaClass(object_getClass(self)) ? '+' : '-');

  [NSException raise: NSInvalidArgumentException
    format: @"[%@%c%@] should be overridden by subclass",
    NSStringFromClass([self class]), c,
    aSel ? (id)NSStringFromSelector(aSel) : (id)@"(null)"];
  while (1) ;   // Does not return
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
static BOOL		isExiting = NO;
static NSLock           *exitLock = nil;

static inline void setup()
{
  if (nil == exitLock)
    {
      static gs_mutex_t	setupLock = GS_MUTEX_INIT_STATIC;

      GS_MUTEX_LOCK(setupLock);
      if (nil == exitLock)
        {
          exitLock = [NSLock new];
        } 
      GS_MUTEX_UNLOCK(setupLock);
    }
}

static void
handleExit()
{
  BOOL  unknownThread;

  isExiting = YES;
  /* We turn off zombies during exiting so that we don't leak deallocated
   * objects during cleanup.
   */
//  NSZombieEnabled = NO;
  unknownThread = GSRegisterCurrentThread();
  ENTER_POOL

  while (exited != 0)
    {
      struct exitLink	*tmp = exited;

      exited = tmp->next;
      if (0 != tmp->sel)
	{
	  Method	method;
	  IMP		msg;

fprintf(stderr, "*** +[%s %s]\n", class_getName(tmp->obj), sel_getName(tmp->sel));
	  method = class_getClassMethod(tmp->obj, tmp->sel);
	  msg = method_getImplementation(method);
	  if (0 != msg)
	    {
	      (*msg)(tmp->obj, tmp->sel);
	    }
	}
      else if (shouldCleanUp)
	{
	  if (tmp->at)
	    {
	      if (tmp->obj != *(tmp->at))
		{
fprintf(stderr, "*** leaked value %p at %p changed to %p\n", tmp->obj, (const void*)tmp->at, *(tmp->at));
	          tmp->obj = *(tmp->at);
		}
	      *(tmp->at) = nil;
	    }
fprintf(stderr, "*** -[%s release] %p %p\n", class_getName(object_getClass(tmp->obj)), tmp->obj, (const void*)tmp->at);
	  [tmp->obj release];
	}
      free(tmp);
    }
  LEAVE_POOL

  if (unknownThread == YES)
    {
      GSUnregisterCurrentThread();
    }
  isExiting = NO;
}

@implementation NSObject(GSCleanUp)

+ (BOOL) isExiting
{
  return isExiting;
}

+ (id) leak: (id)anObject at: (id*)anAddress
{
  struct exitLink	*l;

  if (isExiting)
    {
      if (anAddress)
	{
          [*anAddress release];
          *anAddress = nil;
	}
      return nil;
    }
  NSAssert([anObject isKindOfClass: [NSObject class]],
    NSInvalidArgumentException);
  NSAssert(anAddress != NULL, NSInvalidArgumentException);
  setup();
  [exitLock lock];
  for (l = exited; l != NULL; l = l->next)
    {
      if (l->at == anAddress)
	{
	  [exitLock unlock];
	  [NSException raise: NSInvalidArgumentException
		      format: @"Repeated use of leak address %p", anAddress];
	}
      if (anObject != nil && anObject == l->obj)
	{
	  [exitLock unlock];
	  [NSException raise: NSInvalidArgumentException
		      format: @"Repeated use of leak object %p", anObject];
	}
    }
  ASSIGN(*anAddress, anObject);
  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->at = anAddress;
  l->obj = anObject;
  l->sel = 0;
  l->next = exited;
  exited = l;
  [exitLock unlock];
  return l->obj;
}

+ (id) leakAt: (id*)anAddress
{
  struct exitLink       *l;

  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->at = anAddress;
  l->obj = [*anAddress retain];
  l->sel = 0;
  setup();
  [exitLock lock];
  l->next = exited;
  exited = l;
  [exitLock unlock];
  return l->obj;
}

+ (id) leak: (id)anObject
{
  struct exitLink	*l;

  if (nil == anObject || isExiting)
    {
      return nil;
    }
  setup();
  [exitLock lock];
  for (l = exited; l != NULL; l = l->next)
    {
      if (l->obj == anObject || (l->at != NULL && *l->at == anObject))
	{
	  [exitLock unlock];
	  [NSException raise: NSInvalidArgumentException
		      format: @"Repeated use of leak object %p", anObject];
	}
    }
  l = (struct exitLink*)malloc(sizeof(struct exitLink));
  l->at = 0;
  l->obj = [anObject retain];
  l->sel = 0;
  l->next = exited;
  exited = l;
  [exitLock unlock];
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

  setup();
  [exitLock lock];
  for (l = exited; l != 0; l = l->next)
    {
      if (l->obj == self)
	{
	  if (sel_isEqual(l->sel, sel))
	    {
	      fprintf(stderr,
		"*** +[%s registerAtExit: %s] already registered for %s.\n",
		class_getName(self), sel_getName(sel), sel_getName(l->sel));
	      [exitLock unlock];
	      return NO;	// Already registered
	    }
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
  [exitLock unlock];
  return YES;
}

+ (void) setShouldCleanUp: (BOOL)aFlag
{
  if (YES == aFlag)
    {
      setup();
      [exitLock lock];
      if (NO == enabled)
	{
	  atexit(handleExit);
	  enabled = YES;
	}
      [exitLock unlock];
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

@implementation NSObject (MemoryFootprint)
+ (NSUInteger) contentSizeOf: (NSObject*)obj
		   excluding: (NSHashTable*)exclude
{
  Class		cls = object_getClass(obj);
  NSUInteger	size = 0;

  while (cls != Nil)
    {
      unsigned	count;
      Ivar	*vars;

      if (0 != (vars = class_copyIvarList(cls, &count)))
	{
	  while (count-- > 0)
	    {
	      const char	*type = ivar_getTypeEncoding(vars[count]);

	      type = GSSkipTypeQualifierAndLayoutInfo(type);
	      if ('@' == *type)
		{
		  NSObject	*content = object_getIvar(obj, vars[count]);
	    
		  if (content != nil)
		    {
		      size += [content sizeInBytesExcluding: exclude];
		    }
		}
	    }
	  free(vars);
	}
      cls = class_getSuperclass(cls);
    }
  return size;
}
+ (NSUInteger) sizeInBytes
{
  return 0;
}
+ (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
  return 0;
}
+ (NSUInteger) sizeOfContentExcluding: (NSHashTable*)exclude
{
  return 0;
}
+ (NSUInteger) sizeOfInstance
{
  return 0;
}
- (NSUInteger) sizeInBytes
{
  NSUInteger	bytes;
  NSHashTable	*exclude;
 
  exclude = NSCreateHashTable(NSNonOwnedPointerHashCallBacks, 0);
  bytes = [self sizeInBytesExcluding: exclude];
  NSFreeHashTable(exclude);
  return bytes;
}
- (NSUInteger) sizeInBytesExcluding: (NSHashTable*)exclude
{
  if (0 == NSHashGet(exclude, self))
    {
      NSUInteger        size = [self sizeOfInstance];

      NSHashInsert(exclude, self);
      if (size > 0)
        {
	  size += [self sizeOfContentExcluding: exclude];
        }
      return size;
    }
  return 0;
}
- (NSUInteger) sizeOfContentExcluding: (NSHashTable*)exclude
{
  return 0;
}
- (NSUInteger) sizeOfInstance
{
  NSUInteger    size;

#if     GS_SIZEOF_VOIDP > 4
  NSUInteger	xxx = (NSUInteger)(void*)self;

  if (xxx & 0x07)
    {
      return 0; // Small object has no size
    }
#endif

#if 	HAVE_MALLOC_USABLE_SIZE
  size = malloc_usable_size((void*)self - sizeof(intptr_t));
#else
  size = class_getInstanceSize(object_getClass(self));
#endif

  return size;
}

@end

/* Dummy implementation
 */
@implementation NSObject(GSCleanup)

+ (id) leak: (id)anObject at: (id*)anAddress
{
  ASSIGN(*anAddress, anObject);
  return *anAddress;
}

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

@end

#endif

