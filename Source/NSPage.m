/* Implementation of page-related functions for GNUstep
   Copyright (C) 1996 Free Software Foundation, Inc.
   
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

#include <gnustep/base/preface.h>
#include <unistd.h>
#include <stdio.h>
#if __mach__
#include <mach.h>
#endif

/* Cache the size of a memory page here, so we don't have to make the
   getpagesize() system call repeatedly. */
static unsigned ns_page_size = 0;

/* Return the number of bytes in a memory page. */
unsigned
NSPageSize (void)
{
  if (!ns_page_size)
#if __mach__
    ns_page_size = (unsigned) vm_page_size ();
#else
    ns_page_size = (unsigned) getpagesize ();
#endif
  return ns_page_size;
}

/* Return log base 2 of the number of bytes in a memory page. */
unsigned
NSLogPageSize (void)
{
  unsigned tmp_page_size;
  unsigned log = 1;

  if (!ns_page_size)
    ns_page_size = (unsigned) getpagesize ();
  tmp_page_size = ns_page_size;
  while (tmp_page_size >> 1)
    log++;
  return log;
}

/* Round BYTES down to the nearest multiple of the memory page size,
   and return it. */
unsigned
NSRoundDownToMultipleOfPageSize (unsigned bytes)
{
  if (!ns_page_size)
    ns_page_size = (unsigned) getpagesize ();
  return (bytes / ns_page_size) * ns_page_size;
}

/* Round BYTES up to the nearest multiple of the memory page size,
   and return it. */
unsigned
NSRoundUpToMultipleOfPageSize (unsigned bytes)
{
  if (!ns_page_size)
    ns_page_size = (unsigned) getpagesize ();
  return ((bytes % ns_page_size)
	  ? ((bytes / ns_page_size + 1) * ns_page_size)
	  : bytes);
}

unsigned
NSRealMemoryAvailable ()
{
  fprintf (stderr, "NSRealMemoryAvailable() not implemented.\n");
  return 0;
}

void *
NSAllocateMemoryPages (unsigned bytes)
{
#if __mach__
  void *where;
  kern_return_t r;
  r = vm_allocate (mach_task_self(), &where, (vm_size_t) bytes, 1);
  NSParameterAssert (r == KERN_SUCCESS);
  return where;
#else
  return calloc (bytes, 1);
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

