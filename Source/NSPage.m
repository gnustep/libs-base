/* Implementation of page-related functions for GNUstep
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: May 1996
   
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
#include <string.h>
#ifndef __WIN32__
#include <unistd.h>
#endif
#include <stdio.h>
#if __mach__
#include <mach.h>
#endif

#if __linux__
#include <linux/kernel.h>
#include <linux/sys.h>
#endif

#ifdef __WIN32__
#define getpagesize() vm_page_size
#endif

#ifdef __SOLARIS__
#define getpagesize() sysconf(_SC_PAGESIZE)
#endif

#if __mach__
#define getpagesize vm_page_size
#endif

/* Cache the size of a memory page here, so we don't have to make the
   getpagesize() system call repeatedly. */
static unsigned ns_page_size = 0;

/* Return the number of bytes in a memory page. */
unsigned
NSPageSize (void)
{
  if (!ns_page_size)
    ns_page_size = (unsigned) getpagesize ();
  return ns_page_size;
}

/* Return log base 2 of the number of bytes in a memory page. */
unsigned
NSLogPageSize (void)
{
  unsigned tmp_page_size = NSPageSize();
  unsigned log = 0;

  while (tmp_page_size >>= 1)
    log++;
  return log;
}

/* Round BYTES down to the nearest multiple of the memory page size,
   and return it. */
unsigned
NSRoundDownToMultipleOfPageSize (unsigned bytes)
{
  unsigned a = NSPageSize();

  return (bytes / a) * a;
}

/* Round BYTES up to the nearest multiple of the memory page size,
   and return it. */
unsigned
NSRoundUpToMultipleOfPageSize (unsigned bytes)
{
  unsigned a = NSPageSize();

  return ((bytes % a) ? ((bytes / a + 1) * a) : bytes);
}

unsigned
NSRealMemoryAvailable ()
{
#if __linux__
  struct sysinfo info;

  if ((sysinfo(&info)) != 0)
    return 0;
  return (unsigned) info.freeram;
#else
  fprintf (stderr, "NSRealMemoryAvailable() not implemented.\n");
  return 0;
#endif
}

void *
NSAllocateMemoryPages (unsigned bytes)
{
  void *where;
#if __mach__
  kern_return_t r;
  r = vm_allocate (mach_task_self(), &where, (vm_size_t) bytes, 1);
  if (r != KERN_SUCCESS)
    return NULL;
  return where;
#else
  where = valloc (bytes);
  if (where == NULL)
    return NULL;
  memset (where, 0, bytes);
  return where;
#endif
}

void
NSDeallocateMemoryPages (void *ptr, unsigned bytes)
{
#if __mach__
  vm_deallocate (mach_task_self (), ptr, bytes);
#else
  free (ptr);
#endif
}

void
NSCopyMemoryPages (const void *source, void *dest, unsigned bytes)
{
#if __mach__
  kern_return_t r;
  r = vm_copy (mach_task_self(), source, bytes, dest);
  NSParameterAssert (r == KERN_SUCCESS);
#else
  memcpy (dest, source, bytes);
#endif
}















