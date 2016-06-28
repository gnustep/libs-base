/** Debugging utilities for GNUStep and OpenStep
   Copyright (C) 1997,1999,2000,2001 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997
   Extended by: Nicola Pero <n.pero@mi.flashnet.it>
   Date: December 2000, April 2001

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

   <title>NSDebug utilities reference</title>
   $Date$ $Revision$
   */

#import "common.h"
#include <stdio.h>
#import "GSPrivate.h"
#import "GNUstepBase/GSLock.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSNotification.h"
#import "Foundation/NSNotificationQueue.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSValue.h"

#import "GSSorting.h"

#if     HAVE_EXECINFO_H
#include        <execinfo.h>
#endif

typedef struct {
  Class	class;
  /* The following are used for statistical info */
  unsigned int	count;
  unsigned int	lastc;
  unsigned int	total;
  unsigned int   peak;
  /* The following are used to record actual objects */
  BOOL  is_recording;
  id    *recorded_objects;
  id    *recorded_tags;
  unsigned int   num_recorded_objects;
  unsigned int   stack_size;
} table_entry;

typedef struct {
  const char    *name;
  int           count;
} list_entry;

static NSInteger itemComp(id v0, id v1, void *ctxt)
{
  int i = strcmp(((list_entry*)v0)->name, ((list_entry *)v1)->name);
  if (i < 0) return NSOrderedAscending;
  if (i > 0) return NSOrderedDescending;
  return NSOrderedSame;
}

static	unsigned int	num_classes = 0;
static	unsigned int	table_size = 0;

static table_entry*	the_table = 0;

static BOOL	debug_allocation = NO;

static NSRecursiveLock	*uniqueLock = nil;
static SEL              doLockSel = 0;
static SEL              unLockSel = 0;
static IMP              doLockImp = 0;
static IMP              unLockImp = 0;

static void     _GSDebugAllocationFetch(list_entry *items, BOOL difference);
static void     _GSDebugAllocationFetchAll(list_entry *items);

static void _GSDebugAllocationAdd(Class c, id o);
static void _GSDebugAllocationRemove(Class c, id o);

static void (*_GSDebugAllocationAddFunc)(Class c, id o)
  = _GSDebugAllocationAdd;
static void (*_GSDebugAllocationRemoveFunc)(Class c, id o)
  = _GSDebugAllocationRemove;

#define doLock() (*doLockImp)(uniqueLock, doLockSel)
#define unLock() (*unLockImp)(uniqueLock, unLockSel)

@interface GSDebugAlloc : NSObject
+ (void) initialize;
@end

@implementation GSDebugAlloc
+ (void) initialize
{
  uniqueLock = [NSRecursiveLock new];
  doLockSel = @selector(lock);
  unLockSel = @selector(unlock);
  doLockImp = [uniqueLock methodForSelector: doLockSel];
  unLockImp = [uniqueLock methodForSelector: unLockSel];
  [[NSObject leakAt: &uniqueLock] release];
}
@end

void
GSSetDebugAllocationFunctions(void (*newAddObjectFunc)(Class c, id o),
  void (*newRemoveObjectFunc)(Class c, id o))
{
  doLock();

  if (newAddObjectFunc && newRemoveObjectFunc)
    {	   	
      _GSDebugAllocationAddFunc = newAddObjectFunc;
      _GSDebugAllocationRemoveFunc = newRemoveObjectFunc;
    }
  else
    {
      // Back to default
      _GSDebugAllocationAddFunc = _GSDebugAllocationAdd;
      _GSDebugAllocationRemoveFunc = _GSDebugAllocationRemove;
    }

  unLock();
}

BOOL
GSDebugAllocationActive(BOOL active)
{
  BOOL	old = debug_allocation;

  [GSDebugAlloc class];		/* Ensure thread support is working */
  debug_allocation = active ? YES : NO;
  return old;
}

BOOL
GSDebugAllocationRecordObjects(Class c, BOOL newState)
{
  BOOL oldState = NO;
  unsigned int i;

  if (newState)
    {
      GSDebugAllocationActive(YES);
    }

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  doLock();
          oldState = (YES == the_table[i].is_recording) ? YES : NO;
          if (newState)
            {
              the_table[i].is_recording = YES;
            }
          else if (YES == oldState)
            {
              while (the_table[i].num_recorded_objects > 0)
                {
                  int   j = the_table[i].num_recorded_objects;

                  the_table[i].num_recorded_objects = --j;
                  [the_table[i].recorded_objects[j] release];
                  the_table[i].recorded_objects[j] = nil;
                  [the_table[i].recorded_tags[j] release];
                  the_table[i].recorded_tags[j] = nil;
                }
            }
	  unLock();
	  return oldState;
	}
    }
  if (YES == newState)
    {
      doLock();
      if (num_classes >= table_size)
        {
          int		more = table_size + 128;
          table_entry	*tmp;

          tmp = NSZoneMalloc(NSDefaultMallocZone(), more * sizeof(table_entry));

          if (tmp == 0)
            {
              unLock();
              return NO;
            }
          if (the_table)
            {
              memcpy(tmp, the_table, num_classes * sizeof(table_entry));
              NSZoneFree(NSDefaultMallocZone(), the_table);
            }
          the_table = tmp;
          table_size = more;
        }
      the_table[num_classes].class = c;
      the_table[num_classes].count = 0;
      the_table[num_classes].lastc = 0;
      the_table[num_classes].total = 0;
      the_table[num_classes].peak = 0;
      the_table[num_classes].is_recording = YES;
      the_table[num_classes].recorded_objects = NULL;
      the_table[num_classes].recorded_tags = NULL;
      the_table[num_classes].num_recorded_objects = 0;
      the_table[num_classes].stack_size = 0;
      num_classes++;
      unLock();
    }
  return oldState;
}

void
GSDebugAllocationActiveRecordingObjects(Class c)
{
  GSDebugAllocationRecordObjects(c, YES);
}

void
GSDebugAllocationAdd(Class c, id o)
{
  (*_GSDebugAllocationAddFunc)(c,o);
}

void
_GSDebugAllocationAdd(Class c, id o)
{
  if (debug_allocation == YES)
    {
      unsigned int	i;

      for (i = 0; i < num_classes; i++)
	{
	  if (the_table[i].class == c)
	    {
	      doLock();
	      the_table[i].count++;
	      the_table[i].total++;
	      if (the_table[i].count > the_table[i].peak)
		{
		  the_table[i].peak = the_table[i].count;
		}
	      if (the_table[i].is_recording == YES)
		{
		  if (the_table[i].num_recorded_objects
		    >= the_table[i].stack_size)
		    {
		      int	more = the_table[i].stack_size + 128;
		      id	*tmp;
		      id	*tmp1;

		      tmp = NSZoneMalloc(NSDefaultMallocZone(),
					 more * sizeof(id));
		      if (tmp == 0)
			{
			  unLock();
			  return;
			}

		      tmp1 = NSZoneMalloc(NSDefaultMallocZone(),
					 more * sizeof(id));
		      if (tmp1 == 0)
			{
			  NSZoneFree(NSDefaultMallocZone(),  tmp);
			  unLock();
			  return;
			}


		      if (the_table[i].recorded_objects != NULL)
			{
			  memcpy(tmp, the_table[i].recorded_objects,
				 the_table[i].num_recorded_objects
				 * sizeof(id));
			  NSZoneFree(NSDefaultMallocZone(),
				     the_table[i].recorded_objects);
			  memcpy(tmp1, the_table[i].recorded_tags,
				 the_table[i].num_recorded_objects
				 * sizeof(id));
			  NSZoneFree(NSDefaultMallocZone(),
				     the_table[i].recorded_tags);
			}
		      the_table[i].recorded_objects = tmp;
		      the_table[i].recorded_tags = tmp1;
		      the_table[i].stack_size = more;
		    }
		
		  (the_table[i].recorded_objects)
		    [the_table[i].num_recorded_objects] = o;
		  (the_table[i].recorded_tags)
		    [the_table[i].num_recorded_objects] = nil;
		  the_table[i].num_recorded_objects++;
		}
	      unLock();
	      return;
	    }
	}
      doLock();
      if (num_classes >= table_size)
	{
	  unsigned int	more = table_size + 128;
	  table_entry	*tmp;
	
	  tmp = NSZoneMalloc(NSDefaultMallocZone(), more * sizeof(table_entry));
	
	  if (tmp == 0)
	    {
	      unLock();
	      return;		/* Argh	*/
	    }
	  if (the_table)
	    {
	      memcpy(tmp, the_table, num_classes * sizeof(table_entry));
	      NSZoneFree(NSDefaultMallocZone(), the_table);
	    }
	  the_table = tmp;
	  table_size = more;
	}
      the_table[num_classes].class = c;
      the_table[num_classes].count = 1;
      the_table[num_classes].lastc = 0;
      the_table[num_classes].total = 1;
      the_table[num_classes].peak = 1;
      the_table[num_classes].is_recording = NO;
      the_table[num_classes].recorded_objects = NULL;
      the_table[num_classes].recorded_tags = NULL;
      the_table[num_classes].num_recorded_objects = 0;
      the_table[num_classes].stack_size = 0;
      num_classes++;
      unLock();
    }
}

int
GSDebugAllocationCount(Class c)
{
  unsigned int	i;

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  return the_table[i].count;
	}
    }
  return 0;
}

int
GSDebugAllocationTotal(Class c)
{
  unsigned int	i;

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  return the_table[i].total;
	}
    }
  return 0;
}

int
GSDebugAllocationPeak(Class c)
{
  unsigned int	i;

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  return the_table[i].peak;
	}
    }
  return 0;
}

Class *
GSDebugAllocationClassList()
{
  Class *ans;
  size_t siz;
  unsigned int	i;

  doLock();

  siz = sizeof(Class) * (num_classes + 1);
  ans = NSZoneMalloc(NSDefaultMallocZone(), siz);

  for (i = 0; i < num_classes; i++)
    {
      ans[i] = the_table[i].class;
    }
  ans[num_classes] = NULL;

  unLock();

  return ans;
}

const char*
GSDebugAllocationList(BOOL changeFlag)
{
  list_entry    *items;
  unsigned      size;

  if (debug_allocation == NO)
    {
      return "Debug allocation system is not active!\n";
    }

  doLock();
  size = num_classes;
  if (size > 0)
    {
      items = malloc(sizeof(list_entry) * size);
      _GSDebugAllocationFetch(items, changeFlag);
    }
  else
    {
      items = 0;
    }
  unLock();

  while (size > 0 && 0 == items[size - 1].name)
    {
      size--;
    }
  if (0 == size)
    {
      if (items != 0)
        {
          free(items);
        }
      if (changeFlag)
        {
          return "There are NO newly allocated or deallocated object!\n";
        }
      else
        {
          return "I can find NO allocated object!\n";
        }
    }
  else
    {
      NSMutableString   *result;
      id                order[size];
      unsigned          index;

      for (index = 0; index < size; index++)
        {
          order[index] = (id)&items[index];
        }
      GSSortUnstable(order, NSMakeRange(0,size), (id)itemComp,
        GSComparisonTypeFunction, 0);

      result = [NSMutableString stringWithCapacity: 1000];
      for (index = 0; index < size; index++)
        {
          list_entry    *item = (list_entry*)order[index];

          [result appendFormat: @"%d\t%s\n", item->count, item->name];
        }
      free(items);
      return [result UTF8String];
    }
}

const char*
GSDebugAllocationListAll()
{
  list_entry    *items;
  unsigned      size;

  if (debug_allocation == NO)
    {
      return "Debug allocation system is not active!\n";
    }

  doLock();
  size = num_classes;
  if (size > 0)
    {
      items = malloc(sizeof(list_entry) * size);
      _GSDebugAllocationFetchAll(items);
    }
  else
    {
      items = 0;
    }
  unLock();

  if (0 == items)
    {
      return "I can find NO allocated object!\n";
    }
  else
    {
      NSMutableString   *result;
      id                order[size];
      unsigned          index;

      for (index = 0; index < size; index++)
        {
          order[index] = (id)&items[index];
        }
      GSSortUnstable(order, NSMakeRange(0,size), (id)itemComp,
        GSComparisonTypeFunction, 0);

      result = [NSMutableString stringWithCapacity: 1000];
      for (index = 0; index < size; index++)
        {
          list_entry    *item = (list_entry*)order[index];

          [result appendFormat: @"%d\t%s\n", item->count, item->name];
        }
      free(items);
      return [result UTF8String];
    }
}

static void
_GSDebugAllocationFetch(list_entry *items, BOOL difference)
{
  unsigned      i;
  unsigned      pos;

  for (i = pos = 0; i < num_classes; i++)
    {
      int	val = the_table[i].count;

      if (difference)
	{
	  val -= the_table[i].lastc;
          the_table[i].lastc = the_table[i].count;
	}
      if (val)
        {
          items[pos].name = class_getName(the_table[i].class);
          items[pos].count = val;
          pos++;
        }
    }
  while (pos < num_classes)
    {
      items[pos].name = 0;
      items[pos].count = 0;
      pos++;
    }
}

static void
_GSDebugAllocationFetchAll(list_entry *items)
{
  unsigned      i;

  for (i = 0; i < num_classes; i++)
    {
      items[i].name = class_getName(the_table[i].class);
      items[i].count = the_table[i].total;
    }
}

void
GSDebugAllocationRemove(Class c, id o)
{
  (*_GSDebugAllocationRemoveFunc)(c,o);
}

void
_GSDebugAllocationRemove(Class c, id o)
{
  if (debug_allocation == YES)
    {
      unsigned int	i;

      for (i = 0; i < num_classes; i++)
	{
	  if (the_table[i].class == c)
	    {
	      id	tag = nil;

	      doLock();
	      the_table[i].count--;
	      if (the_table[i].is_recording)
		{
		  unsigned j, k;

		  for (j = 0; j < the_table[i].num_recorded_objects; j++)
		    {
		      if ((the_table[i].recorded_objects)[j] == o)
			{
			  tag = (the_table[i].recorded_tags)[j];
			  break;
			}
		    }
		  if (j < the_table[i].num_recorded_objects)
		    {
		      for (k = j;
                        k + 1 < the_table[i].num_recorded_objects;
			k++)
			{
			  (the_table[i].recorded_objects)[k] =
			    (the_table[i].recorded_objects)[k + 1];
			  (the_table[i].recorded_tags)[k] =
			    (the_table[i].recorded_tags)[k + 1];
			}
		      the_table[i].num_recorded_objects--;
		    }
		  else
		    {
		      /* Not found - no problem - this happens if the
                         object was allocated before we started
                         recording */
		      ;
		    }
		}
	      unLock();
	      [tag release];
	      return;
	    }
	}
    }
}

id
GSDebugAllocationTagRecordedObject(id object, id tag)
{
  Class c = [object class];
  id	o = nil;
  int	i;
  int	j;

  if (debug_allocation == NO)
    {
      return nil;
    }
  doLock();

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
        {
	  break;
	}
    }

  if (i == num_classes
    || the_table[i].is_recording == NO
    || the_table[i].num_recorded_objects == 0)
    {
      unLock();
      return nil;
    }

  for (j = 0; j < the_table[i].num_recorded_objects; j++)
    {
      if (the_table[i].recorded_objects[j] == object)
	{
	  o = the_table[i].recorded_tags[j];
	  the_table[i].recorded_tags[j] = RETAIN(tag);
	  break;
	}
    }

  unLock();
  return AUTORELEASE(o);
}

NSArray *
GSDebugAllocationListRecordedObjects(Class c)
{
  NSArray *answer;
  unsigned int i, k;
  id *tmp;

  if (debug_allocation == NO)
    {
      return nil;
    }

  doLock();

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  break;
	}
    }

  if (i == num_classes)
    {
      unLock();
      return nil;
    }

  if (the_table[i].is_recording == NO)
    {
      unLock();
      return nil;
    }

  if (the_table[i].num_recorded_objects == 0)
    {
      unLock();
      return [NSArray array];
    }

  tmp = NSZoneMalloc(NSDefaultMallocZone(),
    the_table[i].num_recorded_objects * sizeof(id));
  if (tmp == 0)
    {
      unLock();
      return nil;
    }

  /* First, we copy the objects into a temporary buffer */
  memcpy(tmp, the_table[i].recorded_objects,
    the_table[i].num_recorded_objects * sizeof(id));

  /* Retain all the objects - NB: if retaining one of the objects as a
   * side effect releases another one of them , we are broken ... */
  for (k = 0; k < the_table[i].num_recorded_objects; k++)
    {
      [tmp[k] retain];
    }

  /* Then, we bravely unlock the lock */
  unLock();

  /* Only then we create an array with them - this is now safe as we
   * have copied the objects out, unlocked, and retained them. */
  answer = [NSArray arrayWithObjects: tmp
    count: the_table[i].num_recorded_objects];

  /* Now we release all the objects to balance the retain */
  for (k = 0; k < the_table[i].num_recorded_objects; k++)
    {
      [tmp[k] release];
    }

  /* And free the space used by them */
  NSZoneFree(NSDefaultMallocZone(), tmp);

  return answer;
}

#if	!defined(HAVE_BUILTIN_EXTRACT_RETURN_ADDRESS)
# define	__builtin_extract_return_address(X)	X
#endif

#define _NS_FRAME_HACK(a) \
case a: env->addr = __builtin_frame_address(a + 1); break;
#define _NS_RETURN_HACK(a) \
case a: env->addr = (__builtin_frame_address(a + 1) ? \
__builtin_extract_return_address(__builtin_return_address(a + 1)) : 0); break;

/*
 * The following horrible signal handling code is a workaround for the fact
 * that the __builtin_frame_address() and __builtin_return_address()
 * functions are not reliable (at least not on my EM64T based system) and
 * will sometimes walk off the stack and access illegal memory locations.
 * In order to prevent such an occurrance from crashing the application,
 * we use sigsetjmp() and siglongjmp() to ensure that we can recover, and
 * we keep the jump buffer in thread-local memory to avoid possible thread
 * safety issues.
 * Of course this will fail horribly if an exception occurs in one of the
 * few methods we use to manage the per-thread jump buffer.
 */
#if	defined(HAVE_SYS_SIGNAL_H)
#  include	<sys/signal.h>
#elif	defined(HAVE_SIGNAL_H)
#  include	<signal.h>
#endif

#if	defined(_WIN32)
#ifndef SIGBUS
#define SIGBUS  SIGILL
#endif
#endif

/* sigsetjmp may be a function or a macro.  The test for the function is
 * done at configure time so we can tell here if either is available.
 */
#if	!defined(HAVE_SIGSETJMP) && !defined(sigsetjmp)
#define	siglongjmp(A,B)	longjmp(A,B)
#define	sigsetjmp(A,B)	setjmp(A)
#define	sigjmp_buf	jmp_buf
#endif

typedef struct {
  sigjmp_buf    buf;
  void          *addr;
  void          (*bus)(int);
  void          (*segv)(int);
} jbuf_type;

static jbuf_type *
jbuf()
{
  NSMutableData	*d;
  NSMutableDictionary	*dict;

  dict = [[NSThread currentThread] threadDictionary];
  d = [dict objectForKey: @"GSjbuf"];
  if (d == nil)
    {
      d = [[NSMutableData alloc] initWithLength: sizeof(jbuf_type)];
      [dict setObject: d forKey: @"GSjbuf"];
      RELEASE(d);
    }
  return (jbuf_type*)[d mutableBytes];
}

static void
recover(int sig)
{
  siglongjmp(jbuf()->buf, 1);
}

void *
NSFrameAddress(NSUInteger offset)
{
  jbuf_type     *env;

  env = jbuf();
  if (sigsetjmp(env->buf, 1) == 0)
    {
      env->segv = signal(SIGSEGV, recover);
      env->bus = signal(SIGBUS, recover);
      switch (offset)
	{
	  _NS_FRAME_HACK(0); _NS_FRAME_HACK(1); _NS_FRAME_HACK(2);
	  _NS_FRAME_HACK(3); _NS_FRAME_HACK(4); _NS_FRAME_HACK(5);
	  _NS_FRAME_HACK(6); _NS_FRAME_HACK(7); _NS_FRAME_HACK(8);
	  _NS_FRAME_HACK(9); _NS_FRAME_HACK(10); _NS_FRAME_HACK(11);
	  _NS_FRAME_HACK(12); _NS_FRAME_HACK(13); _NS_FRAME_HACK(14);
	  _NS_FRAME_HACK(15); _NS_FRAME_HACK(16); _NS_FRAME_HACK(17);
	  _NS_FRAME_HACK(18); _NS_FRAME_HACK(19); _NS_FRAME_HACK(20);
	  _NS_FRAME_HACK(21); _NS_FRAME_HACK(22); _NS_FRAME_HACK(23);
	  _NS_FRAME_HACK(24); _NS_FRAME_HACK(25); _NS_FRAME_HACK(26);
	  _NS_FRAME_HACK(27); _NS_FRAME_HACK(28); _NS_FRAME_HACK(29);
	  _NS_FRAME_HACK(30); _NS_FRAME_HACK(31); _NS_FRAME_HACK(32);
	  _NS_FRAME_HACK(33); _NS_FRAME_HACK(34); _NS_FRAME_HACK(35);
	  _NS_FRAME_HACK(36); _NS_FRAME_HACK(37); _NS_FRAME_HACK(38);
	  _NS_FRAME_HACK(39); _NS_FRAME_HACK(40); _NS_FRAME_HACK(41);
	  _NS_FRAME_HACK(42); _NS_FRAME_HACK(43); _NS_FRAME_HACK(44);
	  _NS_FRAME_HACK(45); _NS_FRAME_HACK(46); _NS_FRAME_HACK(47);
	  _NS_FRAME_HACK(48); _NS_FRAME_HACK(49); _NS_FRAME_HACK(50);
	  _NS_FRAME_HACK(51); _NS_FRAME_HACK(52); _NS_FRAME_HACK(53);
	  _NS_FRAME_HACK(54); _NS_FRAME_HACK(55); _NS_FRAME_HACK(56);
	  _NS_FRAME_HACK(57); _NS_FRAME_HACK(58); _NS_FRAME_HACK(59);
	  _NS_FRAME_HACK(60); _NS_FRAME_HACK(61); _NS_FRAME_HACK(62);
	  _NS_FRAME_HACK(63); _NS_FRAME_HACK(64); _NS_FRAME_HACK(65);
	  _NS_FRAME_HACK(66); _NS_FRAME_HACK(67); _NS_FRAME_HACK(68);
	  _NS_FRAME_HACK(69); _NS_FRAME_HACK(70); _NS_FRAME_HACK(71);
	  _NS_FRAME_HACK(72); _NS_FRAME_HACK(73); _NS_FRAME_HACK(74);
	  _NS_FRAME_HACK(75); _NS_FRAME_HACK(76); _NS_FRAME_HACK(77);
	  _NS_FRAME_HACK(78); _NS_FRAME_HACK(79); _NS_FRAME_HACK(80);
	  _NS_FRAME_HACK(81); _NS_FRAME_HACK(82); _NS_FRAME_HACK(83);
	  _NS_FRAME_HACK(84); _NS_FRAME_HACK(85); _NS_FRAME_HACK(86);
	  _NS_FRAME_HACK(87); _NS_FRAME_HACK(88); _NS_FRAME_HACK(89);
	  _NS_FRAME_HACK(90); _NS_FRAME_HACK(91); _NS_FRAME_HACK(92);
	  _NS_FRAME_HACK(93); _NS_FRAME_HACK(94); _NS_FRAME_HACK(95);
	  _NS_FRAME_HACK(96); _NS_FRAME_HACK(97); _NS_FRAME_HACK(98);
	  _NS_FRAME_HACK(99);
	  default: env->addr = NULL; break;
	}
      signal(SIGSEGV, env->segv);
      signal(SIGBUS, env->bus);
    }
  else
    {
      env = jbuf();
      signal(SIGSEGV, env->segv);
      signal(SIGBUS, env->bus);
      env->addr = NULL;
    }
  return env->addr;
}

NSUInteger NSCountFrames(void)
{
  jbuf_type	*env;

  env = jbuf();
  if (sigsetjmp(env->buf, 1) == 0)
    {
      env->segv = signal(SIGSEGV, recover);
      env->bus = signal(SIGBUS, recover);
      env->addr = 0;

#define _NS_COUNT_HACK(X) if (__builtin_frame_address(X + 1) == 0) \
        goto done; else env->addr = (void*)(X + 1);

      _NS_COUNT_HACK(0); _NS_COUNT_HACK(1); _NS_COUNT_HACK(2);
      _NS_COUNT_HACK(3); _NS_COUNT_HACK(4); _NS_COUNT_HACK(5);
      _NS_COUNT_HACK(6); _NS_COUNT_HACK(7); _NS_COUNT_HACK(8);
      _NS_COUNT_HACK(9); _NS_COUNT_HACK(10); _NS_COUNT_HACK(11);
      _NS_COUNT_HACK(12); _NS_COUNT_HACK(13); _NS_COUNT_HACK(14);
      _NS_COUNT_HACK(15); _NS_COUNT_HACK(16); _NS_COUNT_HACK(17);
      _NS_COUNT_HACK(18); _NS_COUNT_HACK(19); _NS_COUNT_HACK(20);
      _NS_COUNT_HACK(21); _NS_COUNT_HACK(22); _NS_COUNT_HACK(23);
      _NS_COUNT_HACK(24); _NS_COUNT_HACK(25); _NS_COUNT_HACK(26);
      _NS_COUNT_HACK(27); _NS_COUNT_HACK(28); _NS_COUNT_HACK(29);
      _NS_COUNT_HACK(30); _NS_COUNT_HACK(31); _NS_COUNT_HACK(32);
      _NS_COUNT_HACK(33); _NS_COUNT_HACK(34); _NS_COUNT_HACK(35);
      _NS_COUNT_HACK(36); _NS_COUNT_HACK(37); _NS_COUNT_HACK(38);
      _NS_COUNT_HACK(39); _NS_COUNT_HACK(40); _NS_COUNT_HACK(41);
      _NS_COUNT_HACK(42); _NS_COUNT_HACK(43); _NS_COUNT_HACK(44);
      _NS_COUNT_HACK(45); _NS_COUNT_HACK(46); _NS_COUNT_HACK(47);
      _NS_COUNT_HACK(48); _NS_COUNT_HACK(49); _NS_COUNT_HACK(50);
      _NS_COUNT_HACK(51); _NS_COUNT_HACK(52); _NS_COUNT_HACK(53);
      _NS_COUNT_HACK(54); _NS_COUNT_HACK(55); _NS_COUNT_HACK(56);
      _NS_COUNT_HACK(57); _NS_COUNT_HACK(58); _NS_COUNT_HACK(59);
      _NS_COUNT_HACK(60); _NS_COUNT_HACK(61); _NS_COUNT_HACK(62);
      _NS_COUNT_HACK(63); _NS_COUNT_HACK(64); _NS_COUNT_HACK(65);
      _NS_COUNT_HACK(66); _NS_COUNT_HACK(67); _NS_COUNT_HACK(68);
      _NS_COUNT_HACK(69); _NS_COUNT_HACK(70); _NS_COUNT_HACK(71);
      _NS_COUNT_HACK(72); _NS_COUNT_HACK(73); _NS_COUNT_HACK(74);
      _NS_COUNT_HACK(75); _NS_COUNT_HACK(76); _NS_COUNT_HACK(77);
      _NS_COUNT_HACK(78); _NS_COUNT_HACK(79); _NS_COUNT_HACK(80);
      _NS_COUNT_HACK(81); _NS_COUNT_HACK(82); _NS_COUNT_HACK(83);
      _NS_COUNT_HACK(84); _NS_COUNT_HACK(85); _NS_COUNT_HACK(86);
      _NS_COUNT_HACK(87); _NS_COUNT_HACK(88); _NS_COUNT_HACK(89);
      _NS_COUNT_HACK(90); _NS_COUNT_HACK(91); _NS_COUNT_HACK(92);
      _NS_COUNT_HACK(93); _NS_COUNT_HACK(94); _NS_COUNT_HACK(95);
      _NS_COUNT_HACK(96); _NS_COUNT_HACK(97); _NS_COUNT_HACK(98);
      _NS_COUNT_HACK(99);

done:
      signal(SIGSEGV, env->segv);
      signal(SIGBUS, env->bus);
    }
  else
    {
      env = jbuf();
      signal(SIGSEGV, env->segv);
      signal(SIGBUS, env->bus);
    }

  return (uintptr_t)env->addr;
}

void *
NSReturnAddress(NSUInteger offset)
{
  jbuf_type	*env;

  env = jbuf();
  if (sigsetjmp(env->buf, 1) == 0)
    {
      env->segv = signal(SIGSEGV, recover);
      env->bus = signal(SIGBUS, recover);
      switch (offset)
	{
	  _NS_RETURN_HACK(0); _NS_RETURN_HACK(1); _NS_RETURN_HACK(2);
	  _NS_RETURN_HACK(3); _NS_RETURN_HACK(4); _NS_RETURN_HACK(5);
	  _NS_RETURN_HACK(6); _NS_RETURN_HACK(7); _NS_RETURN_HACK(8);
	  _NS_RETURN_HACK(9); _NS_RETURN_HACK(10); _NS_RETURN_HACK(11);
	  _NS_RETURN_HACK(12); _NS_RETURN_HACK(13); _NS_RETURN_HACK(14);
	  _NS_RETURN_HACK(15); _NS_RETURN_HACK(16); _NS_RETURN_HACK(17);
	  _NS_RETURN_HACK(18); _NS_RETURN_HACK(19); _NS_RETURN_HACK(20);
	  _NS_RETURN_HACK(21); _NS_RETURN_HACK(22); _NS_RETURN_HACK(23);
	  _NS_RETURN_HACK(24); _NS_RETURN_HACK(25); _NS_RETURN_HACK(26);
	  _NS_RETURN_HACK(27); _NS_RETURN_HACK(28); _NS_RETURN_HACK(29);
	  _NS_RETURN_HACK(30); _NS_RETURN_HACK(31); _NS_RETURN_HACK(32);
	  _NS_RETURN_HACK(33); _NS_RETURN_HACK(34); _NS_RETURN_HACK(35);
	  _NS_RETURN_HACK(36); _NS_RETURN_HACK(37); _NS_RETURN_HACK(38);
	  _NS_RETURN_HACK(39); _NS_RETURN_HACK(40); _NS_RETURN_HACK(41);
	  _NS_RETURN_HACK(42); _NS_RETURN_HACK(43); _NS_RETURN_HACK(44);
	  _NS_RETURN_HACK(45); _NS_RETURN_HACK(46); _NS_RETURN_HACK(47);
	  _NS_RETURN_HACK(48); _NS_RETURN_HACK(49); _NS_RETURN_HACK(50);
	  _NS_RETURN_HACK(51); _NS_RETURN_HACK(52); _NS_RETURN_HACK(53);
	  _NS_RETURN_HACK(54); _NS_RETURN_HACK(55); _NS_RETURN_HACK(56);
	  _NS_RETURN_HACK(57); _NS_RETURN_HACK(58); _NS_RETURN_HACK(59);
	  _NS_RETURN_HACK(60); _NS_RETURN_HACK(61); _NS_RETURN_HACK(62);
	  _NS_RETURN_HACK(63); _NS_RETURN_HACK(64); _NS_RETURN_HACK(65);
	  _NS_RETURN_HACK(66); _NS_RETURN_HACK(67); _NS_RETURN_HACK(68);
	  _NS_RETURN_HACK(69); _NS_RETURN_HACK(70); _NS_RETURN_HACK(71);
	  _NS_RETURN_HACK(72); _NS_RETURN_HACK(73); _NS_RETURN_HACK(74);
	  _NS_RETURN_HACK(75); _NS_RETURN_HACK(76); _NS_RETURN_HACK(77);
	  _NS_RETURN_HACK(78); _NS_RETURN_HACK(79); _NS_RETURN_HACK(80);
	  _NS_RETURN_HACK(81); _NS_RETURN_HACK(82); _NS_RETURN_HACK(83);
	  _NS_RETURN_HACK(84); _NS_RETURN_HACK(85); _NS_RETURN_HACK(86);
	  _NS_RETURN_HACK(87); _NS_RETURN_HACK(88); _NS_RETURN_HACK(89);
	  _NS_RETURN_HACK(90); _NS_RETURN_HACK(91); _NS_RETURN_HACK(92);
	  _NS_RETURN_HACK(93); _NS_RETURN_HACK(94); _NS_RETURN_HACK(95);
	  _NS_RETURN_HACK(96); _NS_RETURN_HACK(97); _NS_RETURN_HACK(98);
	  _NS_RETURN_HACK(99);
	  default: env->addr = NULL; break;
	}
      signal(SIGSEGV, env->segv);
      signal(SIGBUS, env->bus);
    }
  else
    {
      env = jbuf();
      signal(SIGSEGV, env->segv);
      signal(SIGBUS, env->bus);
      env->addr = NULL;
    }

  return env->addr;
}

NSMutableArray *
GSPrivateStackAddresses(void)
{
  NSMutableArray        *stack;
  NSAutoreleasePool	*pool;

#if HAVE_BACKTRACE
  void                  *addresses[1024];
  int                   n = backtrace(addresses, 1024);
  int                   i;

  stack = [NSMutableArray arrayWithCapacity: n];
  pool = [NSAutoreleasePool new];
  for (i = 0; i < n; i++)
    {
      [stack addObject: [NSValue valueWithPointer: addresses[i]]];
    }

#else
  unsigned              n = NSCountFrames();
  unsigned              i;
  jbuf_type             *env;

  stack = [NSMutableArray arrayWithCapacity: n];
  pool = [NSAutoreleasePool new];
  /* There should be more frame addresses than return addresses.
   */
  if (n > 0)
    {
      n--;
    }
  if (n > 0)
    {
      n--;
    }

  env = jbuf();
  if (sigsetjmp(env->buf, 1) == 0)
    {
      env->segv = signal(SIGSEGV, recover);
      env->bus = signal(SIGBUS, recover);

      for (i = 0; i < n; i++)
        {
          switch (i)
            {
              _NS_RETURN_HACK(0); _NS_RETURN_HACK(1); _NS_RETURN_HACK(2);
              _NS_RETURN_HACK(3); _NS_RETURN_HACK(4); _NS_RETURN_HACK(5);
              _NS_RETURN_HACK(6); _NS_RETURN_HACK(7); _NS_RETURN_HACK(8);
              _NS_RETURN_HACK(9); _NS_RETURN_HACK(10); _NS_RETURN_HACK(11);
              _NS_RETURN_HACK(12); _NS_RETURN_HACK(13); _NS_RETURN_HACK(14);
              _NS_RETURN_HACK(15); _NS_RETURN_HACK(16); _NS_RETURN_HACK(17);
              _NS_RETURN_HACK(18); _NS_RETURN_HACK(19); _NS_RETURN_HACK(20);
              _NS_RETURN_HACK(21); _NS_RETURN_HACK(22); _NS_RETURN_HACK(23);
              _NS_RETURN_HACK(24); _NS_RETURN_HACK(25); _NS_RETURN_HACK(26);
              _NS_RETURN_HACK(27); _NS_RETURN_HACK(28); _NS_RETURN_HACK(29);
              _NS_RETURN_HACK(30); _NS_RETURN_HACK(31); _NS_RETURN_HACK(32);
              _NS_RETURN_HACK(33); _NS_RETURN_HACK(34); _NS_RETURN_HACK(35);
              _NS_RETURN_HACK(36); _NS_RETURN_HACK(37); _NS_RETURN_HACK(38);
              _NS_RETURN_HACK(39); _NS_RETURN_HACK(40); _NS_RETURN_HACK(41);
              _NS_RETURN_HACK(42); _NS_RETURN_HACK(43); _NS_RETURN_HACK(44);
              _NS_RETURN_HACK(45); _NS_RETURN_HACK(46); _NS_RETURN_HACK(47);
              _NS_RETURN_HACK(48); _NS_RETURN_HACK(49); _NS_RETURN_HACK(50);
              _NS_RETURN_HACK(51); _NS_RETURN_HACK(52); _NS_RETURN_HACK(53);
              _NS_RETURN_HACK(54); _NS_RETURN_HACK(55); _NS_RETURN_HACK(56);
              _NS_RETURN_HACK(57); _NS_RETURN_HACK(58); _NS_RETURN_HACK(59);
              _NS_RETURN_HACK(60); _NS_RETURN_HACK(61); _NS_RETURN_HACK(62);
              _NS_RETURN_HACK(63); _NS_RETURN_HACK(64); _NS_RETURN_HACK(65);
              _NS_RETURN_HACK(66); _NS_RETURN_HACK(67); _NS_RETURN_HACK(68);
              _NS_RETURN_HACK(69); _NS_RETURN_HACK(70); _NS_RETURN_HACK(71);
              _NS_RETURN_HACK(72); _NS_RETURN_HACK(73); _NS_RETURN_HACK(74);
              _NS_RETURN_HACK(75); _NS_RETURN_HACK(76); _NS_RETURN_HACK(77);
              _NS_RETURN_HACK(78); _NS_RETURN_HACK(79); _NS_RETURN_HACK(80);
              _NS_RETURN_HACK(81); _NS_RETURN_HACK(82); _NS_RETURN_HACK(83);
              _NS_RETURN_HACK(84); _NS_RETURN_HACK(85); _NS_RETURN_HACK(86);
              _NS_RETURN_HACK(87); _NS_RETURN_HACK(88); _NS_RETURN_HACK(89);
              _NS_RETURN_HACK(90); _NS_RETURN_HACK(91); _NS_RETURN_HACK(92);
              _NS_RETURN_HACK(93); _NS_RETURN_HACK(94); _NS_RETURN_HACK(95);
              _NS_RETURN_HACK(96); _NS_RETURN_HACK(97); _NS_RETURN_HACK(98);
              _NS_RETURN_HACK(99);
              default: env->addr = 0; break;
            }
          if (env->addr == 0)
            {
              break;
            }
          [stack addObject: [NSValue valueWithPointer: env->addr]];
        }
      signal(SIGSEGV, env->segv);
      signal(SIGBUS, env->bus);
    }
  else
    {
      env = jbuf();
      signal(SIGSEGV, env->segv);
      signal(SIGBUS, env->bus);
    }
#endif
  [pool drain];
  return stack;
}


const char *
_NSPrintForDebugger(id object)
{
  if (object && [object respondsToSelector: @selector(description)])
    return [[object description] UTF8String];

  return NULL;
}

NSString *
_NSNewStringFromCString(const char *cstring)
{
  NSString      *string;

  string = [NSString stringWithCString: cstring
			      encoding: [NSString defaultCStringEncoding]];
  if (nil == string)
    {
      string = [NSString stringWithUTF8String: cstring];
      if (nil == string)
        {
          string = [NSString stringWithCString: cstring
                                      encoding: NSISOLatin1StringEncoding];
        }
    }
  return string;
}

