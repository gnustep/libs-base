/* Interface for NSLog for GNUStep
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: November 1996
   
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
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProcessInfo.h>

NSLog_printf_handler *_NSLog_printf_handler;

static void
_NSLog_standard_printf_handler (NSString* message)
{
  fprintf (stderr, [message cStringNoCopy]);
}

void 
NSLog (NSString* format, ...)
{
  va_list ap;

  va_start (ap, format);
  NSLogv (format, ap);
  va_end (ap);
}

void 
NSLogv (NSString* format, va_list args)
{
  NSString* prefix;
  NSString* message;

  if (_NSLog_printf_handler == NULL)
    _NSLog_printf_handler = *_NSLog_standard_printf_handler;

  prefix = [NSString
	     stringWithFormat: @"%@ %@[%d] ",
	     [[NSCalendarDate calendarDate] 
	       descriptionWithCalendarFormat: @"%b %d %H:%M:%S"],
	     [[[NSProcessInfo processInfo] processName] lastPathComponent],
	     getpid()];

  /* Check if there is already a newline at the end of the format */
  if (![format hasSuffix: @"\n"])
    format = [format stringByAppendingString: @"\n"];
  message = [NSString stringWithFormat: format arguments: args];

  prefix = [prefix stringByAppendingString: message];
  _NSLog_printf_handler (prefix);
}

