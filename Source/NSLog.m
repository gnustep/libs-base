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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSAutoreleasePool.h>

#ifdef	HAVE_SYSLOG_H
#include <syslog.h>
#endif

#include <unistd.h>

static void
_NSLog_standard_printf_handler (NSString* message)
{
  unsigned	len = [message cStringLength];
  char		buf[len+1];

  [message getCString: buf];
  buf[len] = '\0';

#ifdef	HAVE_SYSLOG

  if (write(2, buf, len) != len)
    {
      int	mask;

#ifdef	LOG_ERR
      mask = LOG_ERR;
#else
# ifdef	LOG_ERROR
      mask = LOG_ERROR;
# else
#   error "Help, I can't find a logging level for syslog"
# endif
#endif

#ifdef	LOG_USER
      mask |= LOG_USER;
#endif
      syslog(mask, "%s",  buf);
    }
#else
  write(2, buf, len);
#endif
}

NSLog_printf_handler *_NSLog_printf_handler = _NSLog_standard_printf_handler;

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
  static NSRecursiveLock	*myLock = nil;
  NSAutoreleasePool		*arp;
  NSString			*prefix;
  NSString			*message;
  int				pid;

  arp = [NSAutoreleasePool new];

  if (_NSLog_printf_handler == NULL)
    _NSLog_printf_handler = *_NSLog_standard_printf_handler;

#if defined(__WIN32__)
  pid = (int)GetCurrentProcessId(),
#else
  pid = (int)getpid();
#endif

  prefix = [NSString
	     stringWithFormat: @"%@ %@[%d] ",
	     [[NSCalendarDate calendarDate] 
	       descriptionWithCalendarFormat: @"%b %d %H:%M:%S"],
	     [[NSProcessInfo processInfo] processName],
	     pid];

  /* Check if there is already a newline at the end of the format */
  if (![format hasSuffix: @"\n"])
    format = [format stringByAppendingString: @"\n"];
  message = [NSString stringWithFormat: format arguments: args];

  prefix = [prefix stringByAppendingString: message];

  if (myLock == nil)
    {
      [gnustep_global_lock lock];
      if (myLock == nil)
	{
	  myLock = [NSRecursiveLock new];
	}
      [gnustep_global_lock unlock];
    }
  [myLock lock];

  _NSLog_printf_handler(prefix);

  [myLock unlock];

  [arp release];
}

