/** Debugging utilities for GNUStep and OpenStep
   Copyright (C) 1997,1999,2000,2001 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997
   Extended by: Nicola Pero <n.pero@mi.flashnet.it>
   Date: December 2000, April 2001

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

   <title>NSDebug class reference</title>
   $Date$ $Revision$
   */

#include <config.h>
#include <stdio.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSString.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSThread.h>

typedef struct {
  Class	class;
  /* The following are used for statistical info */
  int	count;
  int	lastc;
  int	total;
  int   peak;
  /* The following are used to record actual objects */
  BOOL  is_recording;
  id    *recorded_objects;
  int   num_recorded_objects;
  int   stack_size;
} table_entry;

static	int	num_classes = 0;
static	int	table_size = 0;

static table_entry*	the_table = 0;

static BOOL	debug_allocation = NO;

static NSLock	*uniqueLock;

static const char*	_GSDebugAllocationList(BOOL difference);
static const char*	_GSDebugAllocationListAll();

@interface GSDebugAlloc : NSObject
+ (void) initialize;
+ (void) _becomeThreaded: (NSNotification*)notification;
@end

@implementation GSDebugAlloc

+ (void) initialize
{
  if ([NSThread isMultiThreaded])
    {
      [self _becomeThreaded: nil];
    }
  else
    {
      [[NSNotificationCenter defaultCenter]
	addObserver: self
	selector: @selector(_becomeThreaded:)
	name: NSWillBecomeMultiThreadedNotification
	object: nil];
    }
}

+ (void) _becomeThreaded: (NSNotification*)notification
{
  uniqueLock = [NSRecursiveLock new];
}

@end

BOOL
GSDebugAllocationActive(BOOL active)
{
  BOOL	old = debug_allocation;

  [GSDebugAlloc class];		/* Ensure thread support is working */
  debug_allocation = active;
  return old;
}

void
GSDebugAllocationActiveRecordingObjects(Class c)
{
  unsigned i;
  
  GSDebugAllocationActive(YES);

  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  if (uniqueLock != nil)
	    [uniqueLock lock];
	  the_table[i].is_recording = YES;
	  if (uniqueLock != nil)
	    [uniqueLock unlock];
	  return;
	}
    }
  if (uniqueLock != nil)
    [uniqueLock lock];
  if (num_classes >= table_size)
    {
      int		more = table_size + 128;
      table_entry	*tmp;
      
      tmp = NSZoneMalloc(NSDefaultMallocZone(), more * sizeof(table_entry));
      
      if (tmp == 0)
	{
	  if (uniqueLock != nil)
	    [uniqueLock unlock];
	  return;
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
  the_table[num_classes].num_recorded_objects = 0;
  the_table[num_classes].stack_size = 0;
  num_classes++;
  if (uniqueLock != nil)
    [uniqueLock unlock];
}

void
GSDebugAllocationAdd(Class c, id o)
{
  if (debug_allocation)
    {
      int	i;

      for (i = 0; i < num_classes; i++)
	{
	  if (the_table[i].class == c)
	    {
	      if (uniqueLock != nil)
		[uniqueLock lock];
	      the_table[i].count++;
	      the_table[i].total++;
	      if (the_table[i].count > the_table[i].peak)
		{
		  the_table[i].peak = the_table[i].count;
		}
	      if (the_table[i].is_recording == YES)
		{
		  if (the_table[i].num_recorded_objects >= 
		      the_table[i].stack_size)
		    {
		      int more = the_table[i].stack_size + 128;
		      id	*tmp;
      
		      tmp = NSZoneMalloc(NSDefaultMallocZone(), 
					 more * sizeof(id));

		      if (tmp == 0)
			{
			  if (uniqueLock != nil)
			    [uniqueLock unlock];
			  return;
			}
		      if (the_table[i].recorded_objects != NULL)
			{
			  memcpy(tmp, the_table[i].recorded_objects, 
				 the_table[i].num_recorded_objects 
				 * sizeof(id));
			  NSZoneFree(NSDefaultMallocZone(), 
				     the_table[i].recorded_objects);
			}
		      the_table[i].recorded_objects = tmp;
		      the_table[i].stack_size = more;
		    }
		  
		  (the_table[i].recorded_objects)
		    [the_table[i].num_recorded_objects] = o;
		  the_table[i].num_recorded_objects++;
		}
	      if (uniqueLock != nil)
		[uniqueLock unlock];
	      return;
	    }
	}
      if (uniqueLock != nil)
	[uniqueLock lock];
      if (num_classes >= table_size)
	{
	  int		more = table_size + 128;
	  table_entry	*tmp;
	  
	  tmp = NSZoneMalloc(NSDefaultMallocZone(), more * sizeof(table_entry));
	  
	  if (tmp == 0)
	    {
	      if (uniqueLock != nil)
		[uniqueLock unlock];
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
      the_table[num_classes].num_recorded_objects = 0;
      the_table[num_classes].stack_size = 0;
      num_classes++;
      if (uniqueLock != nil)
	[uniqueLock unlock];
    }
}

int
GSDebugAllocationCount(Class c)
{
  int	i;

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
  int	i;

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
  int	i;

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
  int	i;

  if (uniqueLock != nil)
    [uniqueLock lock];
  
  siz = sizeof(Class) * (num_classes + 1);
  ans = NSZoneMalloc(NSDefaultMallocZone(), siz);

  for (i = 0; i < num_classes; i++)
    {
      ans[i] = the_table[i].class;
    }
  ans[num_classes] = NULL;

  if (uniqueLock != nil)
    [uniqueLock unlock];

  return ans;
}

/*
 *	This function returns a string listing all those classes for which
 *	either objects are currently allocated (difference == 0), or there
 *	has been a change in the number of objects allocated since the last
 *	call (difference != 0).
 */
const char*
GSDebugAllocationList(BOOL difference)
{
  const char *ans;
  if (debug_allocation == NO)
    {
      return "Debug allocation system is not active!\n";
    }
  if (uniqueLock != nil)
    [uniqueLock lock];
  ans = _GSDebugAllocationList(difference);
  if (uniqueLock != nil)
    [uniqueLock unlock];
  return ans;
}

static const char*
_GSDebugAllocationList(BOOL difference)
{
  int		pos = 0;
  int		i;
  static int	siz = 0;
  static char	*buf = 0;

  for (i = 0; i < num_classes; i++)
    {
      int	val = the_table[i].count;

      if (difference)
	{
	  val -= the_table[i].lastc;
	}
      if (val != 0)
	{
	  pos += 11 + strlen(the_table[i].class->name);
	}
    }
  if (pos == 0)
    {
      if (difference)
	{
	  return "There are NO newly allocated or deallocated object!\n";
	}
      else
	{
	  return "I can find NO allocated object!\n";
	}
    }

  pos++;

  if (pos > siz)
    {
      if (pos & 0xff)
	{
	  pos = ((pos >> 8) + 1) << 8;
	}
      siz = pos;
      if (buf)
	{
	  NSZoneFree(NSDefaultMallocZone(), buf);
	}
      buf = NSZoneMalloc(NSDefaultMallocZone(), siz);
    }

  if (buf)
    {
      pos = 0;
      for (i = 0; i < num_classes; i++)
	{
	  int	val = the_table[i].count;

	  if (difference)
	    {
	      val -= the_table[i].lastc;
	    }
	  the_table[i].lastc = the_table[i].count;

	  if (val != 0)
	    {
	      sprintf(&buf[pos], "%d\t%s\n", val, the_table[i].class->name);
	      pos += strlen(&buf[pos]);
	    }
	}
    }
  return buf;
}

const char*
GSDebugAllocationListAll()
{
  const char *ans;
  if (debug_allocation == NO)
    {
      return "Debug allocation system is not active!\n";
    }
  if (uniqueLock != nil)
    [uniqueLock lock];
  ans = _GSDebugAllocationListAll();
  if (uniqueLock != nil)
    [uniqueLock unlock];
  return ans;
}

static const char*
_GSDebugAllocationListAll()
{
  int		pos = 0;
  int		i;
  static int	siz = 0;
  static char	*buf = 0;

  for (i = 0; i < num_classes; i++)
    {
      int	val = the_table[i].total;

      if (val != 0)
	{
	  pos += 11 + strlen(the_table[i].class->name);
	}
    }
  if (pos == 0)
    {
      return "I can find NO allocated object!\n";
    }
  pos++;

  if (pos > siz)
    {
      if (pos & 0xff)
	{
	  pos = ((pos >> 8) + 1) << 8;
	}
      siz = pos;
      if (buf)
	{
	  NSZoneFree(NSDefaultMallocZone(), buf);
	}
      buf = NSZoneMalloc(NSDefaultMallocZone(), siz);
    }

  if (buf)
    {
      pos = 0;
      for (i = 0; i < num_classes; i++)
	{
	  int	val = the_table[i].total;

	  if (val != 0)
	    {
	      sprintf(&buf[pos], "%d\t%s\n", val, the_table[i].class->name);
	      pos += strlen(&buf[pos]);
	    }
	}
    }
  return buf;
}

void
GSDebugAllocationRemove(Class c, id o)
{
  if (debug_allocation)
    {
      int	i;

      for (i = 0; i < num_classes; i++)
	{
	  if (the_table[i].class == c)
	    {
	      if (uniqueLock != nil)
		[uniqueLock lock];
	      the_table[i].count--;
	      if (the_table[i].is_recording)
		{
		  unsigned j, k;

		  for (j = 0; j < the_table[i].num_recorded_objects; j++)
		    {
		      if ((the_table[i].recorded_objects)[j] == o)
			{
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
	      if (uniqueLock != nil)
		[uniqueLock unlock];
	      return;
	    }
	}
    }
}

NSArray *
GSDebugAllocationListRecordedObjects(Class c)
{
  NSArray *answer;
  unsigned i, k;
  id *tmp;

  if (debug_allocation == NO)
    {
      return nil;
    }

  if (uniqueLock != nil)
    [uniqueLock lock];
  
  for (i = 0; i < num_classes; i++)
    {
      if (the_table[i].class == c)
	{
	  break;
	}
    }
  
  if (i == num_classes)
    {
      if (uniqueLock != nil)
	[uniqueLock unlock];
      return nil;
    }

  if (the_table[i].is_recording == NO)
    {
      if (uniqueLock != nil)
	[uniqueLock unlock];
      return nil;
    }

  if (the_table[i].num_recorded_objects == 0)
    {
      if (uniqueLock != nil)
	[uniqueLock unlock];
      return [NSArray array];
    }

  tmp = NSZoneMalloc(NSDefaultMallocZone(), 
		     the_table[i].num_recorded_objects * sizeof(id));
  
  if (tmp == 0)
    {
      if (uniqueLock != nil)
	[uniqueLock unlock];
      return nil;
    }
  
  /* First, we copy the objects into a temporary buffer */
  memcpy(tmp, the_table[i].recorded_objects, 
	 the_table[i].num_recorded_objects * sizeof(id));

  /* Then, we bravely unlock the lock */
  if (uniqueLock != nil)
    [uniqueLock unlock];
  
  /* Retain all the objects - NB: if retaining one of the objects as a
     side effect releases another one of them , we are broken ... */
  for (k = 0; k < the_table[i].num_recorded_objects; k++)
    {
      RETAIN (tmp[k]);
    }

  /* Only then we create an array with them - this is now safe as we
     have copied the objects out, unlocked, and retained them. */
  answer = [NSArray arrayWithObjects: tmp  
		    count: the_table[i].num_recorded_objects];
  
  /* Now we release all the objects to balance the retain */
  for (k = 0; k < the_table[i].num_recorded_objects; k++)
    {
      RELEASE (tmp[k]);
    }

  /* And free the space used by them */
  NSZoneFree(NSDefaultMallocZone(), tmp);
  
  return answer;  
}



NSString*
GSDebugFunctionMsg(const char *func, const char *file, int line, NSString *fmt)
{
  NSString *message;

  message = [NSString stringWithFormat: @"File %s: %d. In %s %@",
	file, line, func, fmt];
  return message;
}

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

static void *_frameOffsets[100];

#define _NS_FRAME_HACK(a) case a: return __builtin_frame_address(a + 1)
#define _NS_RETURN_HACK(a) case a: return __builtin_return_address(a + 1)

void *NSFrameAddress(int offset)
{
   switch (offset) {
      _NS_FRAME_HACK( 0); _NS_FRAME_HACK( 1); _NS_FRAME_HACK( 2);
      _NS_FRAME_HACK( 3); _NS_FRAME_HACK( 4); _NS_FRAME_HACK( 5);
      _NS_FRAME_HACK( 6); _NS_FRAME_HACK( 7); _NS_FRAME_HACK( 8);
      _NS_FRAME_HACK( 9); _NS_FRAME_HACK(10); _NS_FRAME_HACK(11);
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
   }

   return NULL;
}

unsigned NSCountFrames(void)
{
   unsigned    x = 0;

   while (NSFrameAddress(x + 1)) x++;

   return x;
}

void *NSReturnAddress(int offset)
{
   switch (offset) {
      _NS_RETURN_HACK( 0); _NS_RETURN_HACK( 1); _NS_RETURN_HACK( 2);
      _NS_RETURN_HACK( 3); _NS_RETURN_HACK( 4); _NS_RETURN_HACK( 5);
      _NS_RETURN_HACK( 6); _NS_RETURN_HACK( 7); _NS_RETURN_HACK( 8);
      _NS_RETURN_HACK( 9); _NS_RETURN_HACK(10); _NS_RETURN_HACK(11);
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
   }

   return NULL;
}

const char *_NSPrintForDebugger(id object)
{
  if (object && [object respondsToSelector: @selector(description)])
    return [[object description] cString];

  return NULL;
}
