/** Interface for NSLog for GNUStep
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

   <title>NSLog class reference</title>
   $Date$ $Revision$
   */ 

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSCalendarDate.h>
#include <Foundation/NSTimeZone.h>
#include <Foundation/NSException.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSData.h>

#ifdef	HAVE_SYSLOG_H
#include <syslog.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include "GSPrivate.h"

/**
 * A variable holding the file descriptor to which NSLogv() messages are
 * written by default.  GNUstep initialises this to stderr.<br />
 * You may change this, but for thread safety should
 * use the lock provided by GSLogLock() to protect the change.
 */
int _NSLogDescriptor = 2;

static NSRecursiveLock	*myLock = nil;

/**
 * Returns the lock used to protect the GNUstep NSLogv() implementation.
 * Use this to protect changes to
 * <ref type="variable" id="_NSLogDescriptor">_NSLogDescriptor</ref> and
 * <ref type="variable" id="_NSLog_printf_handler">_NSLog_printf_handler</ref>
 */
NSRecursiveLock *
GSLogLock()
{
  if (myLock == nil)
    {
      [gnustep_global_lock lock];
      if (myLock == nil)
	{
	  myLock = [NSRecursiveLock new];
	}
      [gnustep_global_lock unlock];
    }
  return myLock;
}

static void
_NSLog_standard_printf_handler (NSString* message)
{
  NSData	*d;
  const char	*buf;
  unsigned	len;
  static NSStringEncoding enc = 0;

  if (enc == 0)
    {
      enc = [NSString defaultCStringEncoding];
    }
  d = [message dataUsingEncoding: enc allowLossyConversion: NO];
  if (d == nil)
    {
      d = [message dataUsingEncoding: NSUTF8StringEncoding
		allowLossyConversion: NO];
    }

  if (d == nil)		// Should never happen.
    {
      buf = [message lossyCString];
      len = strlen(buf);
    }
  else
    {
      buf = (const char*)[d bytes];
      len = [d length];
    }
 
#ifdef	HAVE_SYSLOG

  if (GSUserDefaultsFlag(GSLogSyslog) == YES
    || write(_NSLogDescriptor, buf, len) != len)
    {
      int	mask;
      /* We NULL-terminate the string in order to feed it to
       * syslog.  */
      char *null_terminated_buf = objc_malloc (sizeof (char) * (len + 1));
      strncpy (null_terminated_buf, buf, len);
      null_terminated_buf[len] = '\0';

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
      syslog(mask, "%s",  null_terminated_buf);
      objc_free (null_terminated_buf);
    }
#else
  write(_NSLogDescriptor, buf, len);
#endif
}

/**
 * A pointer to a function used to actually write the log data.
 * <p>
 *   GNUstep initialises this to a function implementing the standard
 *   behavior for logging, but you may change this in your program
 *   in order to implement any custom behavior you wish.  You should
 *   use the lock returned by GSLogLock() to protect any change you make.
 * </p>
 * <p>
 *   Calls from NSLogv() to the function pointed to by this variable
 *   are protected by a lock, and should therefore be thread safe.
 * </p>
 * <p>
 *   This function should accept a single NSString argument and return void.
 * </p>
 * The default implementation in GNUstep performs as follows -
 * <list>
 *   <item>
 *     Converts the string to be logged to data in the default CString
 *     encoding or, if that is not possible, to UTF8 data.
 *   </item>
 *   <item>
 *     If the system supports writing to syslog and the user default to
 *     say that logging should be done to syslog (GSLogSyslog) is set,
 *     writes the data to the syslog.
 *   </item>
 *   <item>
 *     Otherwise, writes the data to the file descriptor stored in the
 *     variable
 *     <ref type="variable" id="_NSLogDescriptor">_NSLogDescriptor</ref>,
 *     which is set by default to stderr.<br />
 *     Your program may change this descriptor ... but you should protect
 *     changes using the lock provided by GSLogLock().<br />
 *     NB. If the write to the descriptor fails, and the system supports
 *     writing to syslog, then the log is written to syslog as if the
 *     appropriate user default had been set.
 *   </item>
 * </list>
 */
NSLog_printf_handler *_NSLog_printf_handler = _NSLog_standard_printf_handler;

/**
 * Provides a standard logging facility via NSLogv().
 */
void 
NSLog (NSString* format, ...)
{
  va_list ap;

  va_start (ap, format);
  NSLogv (format, ap);
  va_end (ap);
}

/**
 * The core logging function ...
 * <p>
 *   The function generates a standard log entry by prepending
 *   process ID and date/time information to your message, and
 *   ensuring that a newline is present at the end of the message.
 * </p>
 * <p>
 *   The resulting message is then passed to a handler function to
 *   perform actual output.  Locking is performed around the call to
 *   the function actually writing the message out, to ensure that
 *   logging is thread-safe.  However, the actual creation of the
 *   message written is only as safe as the -description methods of
 *   the arguments you supply.
 * </p>
 * <p>
 *   The function to write the data is pointed to by
 *   <ref type="variable" id="_NSLog_printf_handler">_NSLog_printf_handler</ref>
 * </p>
 */
void 
NSLogv (NSString* format, va_list args)
{
  NSString	*prefix;
  NSString	*message;
  int		pid;
  CREATE_AUTORELEASE_POOL(arp);

  if (_NSLog_printf_handler == NULL)
    _NSLog_printf_handler = *_NSLog_standard_printf_handler;

#if defined(__MINGW__)
  pid = (int)GetCurrentProcessId(),
#else
  pid = (int)getpid();
#endif

#ifdef	HAVE_SYSLOG
  if (GSUserDefaultsFlag(GSLogSyslog) == YES)
    prefix = @"";
  else
#endif
    prefix = [NSString
	     stringWithFormat: @"%@ %@[%d] ",
	     [[NSCalendarDate calendarDate] 
	       descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S.%F"],
	     [[NSProcessInfo processInfo] processName],
	     pid];

  /* Check if there is already a newline at the end of the format */
  if (![format hasSuffix: @"\n"])
    format = [format stringByAppendingString: @"\n"];
  message = [NSString stringWithFormat: format arguments: args];

  prefix = [prefix stringByAppendingString: message];

  if (myLock == nil)
    {
      GSLogLock();
    }

  [myLock lock];

  _NSLog_printf_handler(prefix);

  [myLock unlock];

  RELEASE(arp);
}

