/** Interface for NSLog for GNUStep
   Copyright (C) 1996-2006 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: November 1996

   Modified:  Sheldon Gill <sheldon@westnet.net.au>
   Date: September 2006

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSLog reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "GNUstepBase/preface.h"
#include "Foundation/NSObjCRuntime.h"
#include "Foundation/NSDate.h"
#include "Foundation/NSCalendarDate.h"
#include "Foundation/NSTimeZone.h"
#include "Foundation/NSException.h"
#include "Foundation/NSProcessInfo.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSData.h"
#include "Foundation/NSThread.h"

#ifdef  HAVE_SYSLOG_H
#include <syslog.h>
#endif

#ifdef HAVE_UNISTD_H
#include <unistd.h>
#endif

#include "GSPrivate.h"

/* DEPRECATED - DELETED  Base 1.14  => we don't support this anymore
 *
 * We delete these entirely. Simpler, faster, smaller
 *
 * A variable holding the file descriptor to which NSLogv() messages are
 * written by default.  GNUstep initialises this to stderr.<br />
 * You may change this, but for thread safety should
 * use the lock provided by GSLogLock() to protect the change.
 *
 * int _NSLogDescriptor = 2;
 *
 * static NSRecursiveLock   *myLock = nil;
 * NSRecursiveLock *GSLogLock();
 *
 * You can over-ride the printf_handler and do whatever you like...
 * so we don't need the _NSLogDescriptor as another customisation method
 *
 * A pointer store is atomic so the lock isn't needed. (x86, PPC, sparc)
 * Besides which, that are you doing! Trying to change the handler multiple
 * times in different threads? Please! -SG
 */

#if defined(__MINGW32__)
/* A mechanism for a more descriptive event source registration -SG */
static const WCHAR *_source_name = NULL;
static HANDLE _eventloghandle = NULL;

/**
 * Windows applications which log to the EventLog should set a source
 * name appropriate for the local and app.
 * This must be called early, before any logging takes place
 */
void SGSetEventSource(WCHAR *aName)
{
  _source_name = aName;
  if (_eventloghandle)
      CloseHandle(_eventloghandle);
  _eventloghandle = NULL;
}

static void
send_event_to_eventlog(WORD eventtype, NSString *message)
{
  LPCWSTR msgbuffer = [message UTF16String];

  if (!_eventloghandle)
    {
      if (_source_name == NULL)
        {
          _source_name = [[[NSProcessInfo processInfo]
                              processName] UTF16String];
        }
      _eventloghandle = RegisterEventSourceW(NULL, _source_name);
    }
  if (_eventloghandle)
    {
      ReportEventW(_eventloghandle,                    // event log handle
          eventtype,                                         // event type
          0,                                              // category zero
          0,                                           // event identifier
          NULL,                                     // security identifier
          1,                                    // num substitution string
          0,                                  // num data for substitution
         &msgbuffer,                               // message string array
         NULL);                                         // pointer to data
    }
  else
    {
      [NSException raise: NSGenericException
                  format: @"Couldn't get handle for eventlog"];
    }
}

static void
_GSLog_standard_printf_handler(NSString* message)
{
  static HANDLE hStdErr = NULL;

#ifndef RELEASE_VERSION
  if (IsDebuggerPresent())
      OutputDebugStringW([message UTF16String]);
#endif

  if (hStdErr == NULL)
      hStdErr = GetStdHandle(STD_ERROR_HANDLE);

  if ((GSUserDefaultsFlag(GSLogSyslog) == YES) || (hStdErr == NULL))
    {
      send_event_to_eventlog(EVENTLOG_ERROR_TYPE, message);
    }
  else
    {
      DWORD   bytes_out;

      if (GetFileType(hStdErr) == FILE_TYPE_CHAR)
        {
          const unichar *buffer = [message UTF16String];
          if (!WriteConsoleW(hStdErr, buffer+1,
                          wcslen(buffer+1),
                          &bytes_out, NULL))
            {
              send_event_to_eventlog(EVENTLOG_ERROR_TYPE, message);
            }

        }
      else
        {
//          char *buffer = (char *)[message UTF8String];
          const char *buffer = [message UTF8String];
          if (!WriteFile(hStdErr, buffer,
                          strlen(buffer),
                          &bytes_out, NULL))
            {
              send_event_to_eventlog(EVENTLOG_ERROR_TYPE, message);
            }
        }
    }
}
#else // *nix version

int _NSLogDescriptor = 2;

static void
_GSLog_standard_printf_handler(NSString* message)
{
  const char *buf;
  unsigned   len;

  buf = [message cStringUsingEncoding: NSUTF8StringEncoding];
  len = strlen(buf);

#if defined(HAVE_SYSLOG)
  if (GSUserDefaultsFlag(GSLogSyslog) == YES
    || write(_NSLogDescriptor, buf, len) != (int)len)
    {
      syslog(SYSLOGMASK, "%s", buf);
    }
#else
  write(_NSLogDescriptor, buf, len);
#endif
}
#endif // __MINGW32

/**
 * A pointer to a function used to actually write the log data.
 * <p>
 *   GNUstep initialises this to a function implementing the standard
 *   behavior for logging, but you may change this in your program
 *   in order to implement any custom behavior you wish.
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
 *     If the platform supports writing to syslog and the user default to
 *     say that logging should be done to syslog (GSLogSyslog) is set,
 *     writes the data to the syslog(*nix) or the EventLog(ms-windows).<br />
 *   </item>
 *   <item>
 *     Otherwise, writes the data is written to stderr.<br />
 *   </item>
 * </list>
 */
NSLog_printf_handler *_NSLog_printf_handler = _GSLog_standard_printf_handler;

/**
 * <p>Provides the standard OpenStep logging facility.  For details see
 * the lower level NSLogv() function (which this function uses).
 * </p>
 * <p>GNUstep provides powerful alternatives for logging ... see
 * NSDebugLog(), NSWarnLog() and GSPrintf() for example.  We recommend
 * the use of NSDebugLog() and its relatives for debug purposes, and
 * GSPrintf() for general messages, with NSLog() being reserved
 * for reporting possible/likely errors.  See GSFunctions.h
 * </p>
 */
void
NSLog(NSString* format, ...)
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
 *   If your application is multithreaded, it will also report the
 *   thread ID as well.
 * </p>
 * <p>
 *   The resulting message is then passed to a handler function to
 *   perform actual output.  Locking is performed around the call to
 *   the function actually writing the message out, to ensure that
 *   logging is thread-safe.  However, the actual creation of the
 *   message written is only as safe as the [NSObject-description] methods
 *   of the arguments you supply.
 * </p>
 * <p>
 *   The function to write the data is pointed to by
 *   <ref type="variable" id="_NSLog_printf_handler">_NSLog_printf_handler</ref>
 * </p>
 */
void
NSLogv(NSString* format, va_list args)
{
  NSString  *outMsg;
  NSString  *idStr;
  NSString  *message;
  static NSRecursiveLock *logLock;
  CREATE_AUTORELEASE_POOL(arp);

  if (_NSLog_printf_handler == NULL)
    {
      _NSLog_printf_handler = *_GSLog_standard_printf_handler;
    }

  /* Check if there is already a newline at the end of the format */
  if ([format hasSuffix: @"\n"] == NO)
    {
      format = [format stringByAppendingString: @"\n"];
    }
  message = [NSString stringWithFormat: format arguments: args];

#ifdef  HAVE_SYSLOG
  if (GSUserDefaultsFlag(GSLogSyslog) == YES)
    {
      if ([NSThread isMultiThreaded])
        {
          outMsg = [NSString stringWithFormat: @"[thread:%x] %@",
            GSCurrentThread(),message];
        }
      else
        {
          outMsg = message;
        }
    }
  else
#endif
    {
      if ([NSThread isMultiThreaded])
        {
          idStr = [NSString stringWithFormat: @"%d, %x",
                    [[NSProcessInfo processInfo] processIdentifier],
                    GSCurrentThread()];
        }
      else
        {
          idStr = [NSString stringWithFormat: @"%d",
                    [[NSProcessInfo processInfo] processIdentifier]];
        }
      outMsg = [NSString
                 stringWithFormat: @"%@ %@[%@] %@",
        [[NSCalendarDate calendarDate]
          descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S.%F"],
        [[NSProcessInfo processInfo] processName],
        idStr,
        message];
    }

  // Lock and print the output
  if (logLock == nil)
    {
      [gnustep_global_lock lock];
      logLock = [NSRecursiveLock new];
      [gnustep_global_lock unlock];
    }
  [logLock lock];
  _NSLog_printf_handler(outMsg);
  [logLock unlock];

  RELEASE(arp);
}
