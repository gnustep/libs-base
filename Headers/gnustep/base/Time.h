/* Interface for Objective-C Time object
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: May 1993

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA 02139, USA.
*/ 

/* This is a combination of Smalltalk's Time and Date objects */

#ifndef __Time_h_GNUSTEP_BASE_INCLUDE
#define __Time_h_GNUSTEP_BASE_INCLUDE

#include <base/preface.h>
#include <base/Magnitude.h>

#ifndef __WIN32__
#include <sys/time.h>
#include <sys/resource.h>
#endif /* !__WIN32__ */

#ifdef _SEQUENT_
/* Include needed for getclock() in our replacement for gettimeofday() */
#include <sys/timers.h>

/* Include needed for tzset() in our replacement for gettimeofday() */
#include <time.h>

/* Sequent does not define struct timezone in any of it's header files */
struct timezone {
  int tz_minuteswest;
  int tz_dsttime;
};
#endif /* _SEQUENT_ */

@interface Time : Magnitude
{
  struct timeval tv;		/* seconds and useconds */
  struct timezone tz;		/* minutes from Greenwich, and correction */
}

/* Change these names? */
+ (long) secondClockValue;
+ getClockValueSeconds: (long *)sec microseconds: (long *)usec;

+ (long) millisecondsToRun: (void(*)())aFunc;
+ getSeconds: (long *)sec microseconds: (long *)usec toRun: (void(*)())aFunc;

+ (unsigned) indexOfDayName: (const char *)dayName;
+ (const char *) nameOfDayIndex: (unsigned)dayIndex;
+ (unsigned) indexOfMonthName: (const char *)monthName;
+ (const char *) nameOfMonthIndex: (unsigned)monthIndex;
+ (unsigned) daysInMonthIndex: (unsigned)monthIndex forYear: (unsigned)year;
+ (unsigned) daysInYear: (unsigned)year;
+ (BOOL) leapYear: (unsigned)year;

- initNow;
- initDayIndex: (unsigned)dayIndex 
    monthIndex: (unsigned)monthIndex 
    year: (unsigned)year;
- initSeconds: (long)numSeconds microseconds: (long)numMicroseconds;
- initSeconds: (long)numSeconds;

- setSeconds: (long)numSeconds microseconds: (long)numMicroseconds;
- setSeconds: (long)numSeconds;

- (long) days;
- (long) hours;
- (long) minutes;
- (long) seconds;
- (long) microseconds;

- addTime: (Time*)aTimeObj;
- addDays: (unsigned)num;
- addHours: (unsigned)num;
- addMinutes: (unsigned)num;
- addSeconds: (unsigned)num;

- subtractTime: (Time*)aTimeObj;
- subtractDays: (unsigned)num;
- subtractHours: (unsigned)num;
- subtractMinutes: (unsigned)num;
- subtractSeconds: (unsigned)num;

@end

#endif /* __Time_h_GNUSTEP_BASE_INCLUDE */
