/* Debugging utilities for GNUStep and OpenStep
   Copyright (C) 1997,1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: August 1997

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

#include <config.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSString.h>

#ifndef HAVE_STRERROR
const char*
strerror(int eno)
{
  extern char*	sys_errlist[];
  extern int	sys_nerr;

  if (eno < 0 || eno >= sys_nerr)
    {
      return("unknown error number");
    }
  return(sys_errlist[eno]);
}
#endif

typedef struct {
  Class	class;
  int	count;
  int	lastc;
  int	total;
} table_entry;

static	int	num_classes = 0;
static	int	table_size = 0;

static table_entry*	the_table = 0;

static BOOL	debug_allocation = NO;

BOOL
GSDebugAllocationActive(BOOL active)
{
  BOOL	old = debug_allocation;

  debug_allocation = active;
  return old;
}

void
GSDebugAllocationAdd(Class c)
{
  if (debug_allocation)
    {
      int	i;

      for (i = 0; i < num_classes; i++)
	{
	  if (the_table[i].class == c)
	    {
	      the_table[i].count++;
	      the_table[i].total++;
	      return;
	    }
	}
      if (num_classes >= table_size)
	{
	  int		more = table_size + 128;
	  table_entry	*tmp;

	  tmp = NSZoneMalloc(NSDefaultMallocZone(), more * sizeof(table_entry));

	  if (tmp == 0)
	    {
	      return;		/* Argh	*/
	    }
	  if (the_table)
	    {
	      memcpy(tmp, the_table, num_classes * sizeof(table_entry));
	      NSZoneFree(NSDefaultMallocZone(), the_table);
	    }
	  the_table = tmp;
	}
      the_table[num_classes].class = c;
      the_table[num_classes].count = 1;
      the_table[num_classes].lastc = 0;
      the_table[num_classes].total = 1;
      num_classes++;
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

/*
 *	This function returns a string listing all those classes for which
 *	either objects are currently allocated (difference == 0), or there
 *	has been a change in the number of objects allocated since the last
 *	call (difference != 0).
 */
const char*
GSDebugAllocationList(BOOL difference)
{
  int		pos = 0;
  int		i;
  static int	siz = 0;
  static char	*buf = 0;

  if (debug_allocation == NO)
    {
      return "Debug allocation system is not active!\n";
    }
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
	      sprintf(&buf[pos], "%s\t%d\n", the_table[i].class->name, val);
	      pos += strlen(&buf[pos]);
	    }
	}
    }
  return buf;
}

const char*
GSDebugAllocationListAll()
{
  int		pos = 0;
  int		i;
  static int	siz = 0;
  static char	*buf = 0;

  if (debug_allocation == NO)
    {
      return "Debug allocation system is not active!\n";
    }
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
	      sprintf(&buf[pos], "%s\t%d\n", the_table[i].class->name, val);
	      pos += strlen(&buf[pos]);
	    }
	}
    }
  return buf;
}

void
GSDebugAllocationRemove(Class c)
{
  if (debug_allocation)
    {
      int	i;

      for (i = 0; i < num_classes; i++)
	{
	  if (the_table[i].class == c)
	    {
	      the_table[i].count--;
	      return;
	    }
	}
    }
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

