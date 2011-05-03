/** externs.m Program to test correct initialization of externs.
   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  David Ayers  <d.ayers@inode.at>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02111 USA.
*/

#include <Foundation/Foundation.h>

#include <assert.h>

#define MyAssert1(IDENT) do { \
                           cache[i++] = IDENT; \
                           assert (IDENT != 0); \
                         } while (0)

#define MyAssert2(IDENT) do { \
                           NSCAssert2([IDENT isEqual: \
			       [NSString stringWithUTF8String: #IDENT]], \
                                      @"Invalid value: %@ for: %s", \
                                      IDENT, #IDENT); \
                           NSCAssert2([cache[i++] isEqual: IDENT], \
                                      @"Initial values differ:%@ %@", \
                                      cache[i-1], IDENT); \
                         } while (0)

#define CACHE_SIZE  256
NSString *cache[CACHE_SIZE];

int
main()
{
  NSAutoreleasePool *pool;
  int i = 0;

  /* Insure extern identifiers are initialized
     before ObjC code is executed.  */
  MyAssert1(NSConnectionDidDieNotification);
  MyAssert1(NSConnectionDidInitializeNotification);
  MyAssert1(NSWillBecomeMultiThreadedNotification);
  MyAssert1(NSThreadDidStartNotification);
  MyAssert1(NSThreadWillExitNotification);
  MyAssert1(NSPortDidBecomeInvalidNotification);
  MyAssert1(NSConnectionReplyMode);
  MyAssert1(NSBundleDidLoadNotification);
  MyAssert1(NSShowNonLocalizedStrings);
  MyAssert1(NSLoadedClasses);
  //  MyAssert1(StreamException);
  MyAssert1(NSArgumentDomain);
  MyAssert1(NSGlobalDomain);
  MyAssert1(NSRegistrationDomain);
  MyAssert1(NSUserDefaultsDidChangeNotification);
  MyAssert1(NSWeekDayNameArray);
  MyAssert1(NSShortWeekDayNameArray);
  MyAssert1(NSMonthNameArray);
  MyAssert1(NSShortMonthNameArray);
  MyAssert1(NSTimeFormatString);
  MyAssert1(NSDateFormatString);
  MyAssert1(NSShortDateFormatString);
  MyAssert1(NSTimeDateFormatString);
  MyAssert1(NSShortTimeDateFormatString);
  MyAssert1(NSCurrencySymbol);
  MyAssert1(NSDecimalSeparator);
  MyAssert1(NSThousandsSeparator);
  MyAssert1(NSInternationalCurrencyString);
  MyAssert1(NSCurrencyString);
  //  MyAssert1(NSNegativeCurrencyFormatString);
  //  MyAssert1(NSPositiveCurrencyFormatString);
  MyAssert1(NSDecimalDigits);
  MyAssert1(NSAMPMDesignation);
  MyAssert1(NSHourNameDesignations);
  MyAssert1(NSYearMonthWeekDesignations);
  MyAssert1(NSEarlierTimeDesignations);
  MyAssert1(NSLaterTimeDesignations);
  MyAssert1(NSThisDayDesignations);
  MyAssert1(NSNextDayDesignations);
  MyAssert1(NSNextNextDayDesignations);
  MyAssert1(NSPriorDayDesignations);
  MyAssert1(NSDateTimeOrdering);
  MyAssert1(NSLanguageCode);
  MyAssert1(NSLanguageName);
  MyAssert1(NSFormalName);
  MyAssert1(NSLocale);
  MyAssert1(NSConnectionRepliesReceived);
  MyAssert1(NSConnectionRepliesSent);
  MyAssert1(NSConnectionRequestsReceived);
  MyAssert1(NSConnectionRequestsSent);
  MyAssert1(NSConnectionLocalCount);
  MyAssert1(NSConnectionProxyCount);
  MyAssert1(NSClassDescriptionNeededForClassNotification);

  assert(i < CACHE_SIZE);  /* incread the cache size.  */

  [NSAutoreleasePool enableDoubleReleaseCheck:YES];
  pool = [[NSAutoreleasePool alloc] init];

  i = 0;
  MyAssert2(NSConnectionDidDieNotification);
  MyAssert2(NSConnectionDidInitializeNotification);
  MyAssert2(NSWillBecomeMultiThreadedNotification);
  MyAssert2(NSThreadDidStartNotification);
  MyAssert2(NSThreadWillExitNotification);
  MyAssert2(NSPortDidBecomeInvalidNotification);
  MyAssert2(NSConnectionReplyMode);
  MyAssert2(NSBundleDidLoadNotification);
  MyAssert2(NSShowNonLocalizedStrings);
  MyAssert2(NSLoadedClasses);
  MyAssert2(NSArgumentDomain);
  MyAssert2(NSGlobalDomain);
  MyAssert2(NSRegistrationDomain);
  MyAssert2(NSUserDefaultsDidChangeNotification);
  MyAssert2(NSWeekDayNameArray);
  MyAssert2(NSShortWeekDayNameArray);
  MyAssert2(NSMonthNameArray);
  MyAssert2(NSShortMonthNameArray);
  MyAssert2(NSTimeFormatString);
  MyAssert2(NSDateFormatString);
  MyAssert2(NSShortDateFormatString);
  MyAssert2(NSTimeDateFormatString);
  MyAssert2(NSShortTimeDateFormatString);
  MyAssert2(NSCurrencySymbol);
  MyAssert2(NSDecimalSeparator);
  MyAssert2(NSThousandsSeparator);
  MyAssert2(NSInternationalCurrencyString);
  MyAssert2(NSCurrencyString);
  //  MyAssert2(NSNegativeCurrencyFormatString);
  //  MyAssert2(NSPositiveCurrencyFormatString);
  MyAssert2(NSDecimalDigits);
  MyAssert2(NSAMPMDesignation);
  MyAssert2(NSHourNameDesignations);
  MyAssert2(NSYearMonthWeekDesignations);
  MyAssert2(NSEarlierTimeDesignations);
  MyAssert2(NSLaterTimeDesignations);
  MyAssert2(NSThisDayDesignations);
  MyAssert2(NSNextDayDesignations);
  MyAssert2(NSNextNextDayDesignations);
  MyAssert2(NSPriorDayDesignations);
  MyAssert2(NSDateTimeOrdering);
  MyAssert2(NSLanguageCode);
  MyAssert2(NSLanguageName);
  MyAssert2(NSFormalName);
  MyAssert2(NSLocale);
  MyAssert2(NSConnectionRepliesReceived);
  MyAssert2(NSConnectionRepliesSent);
  MyAssert2(NSConnectionRequestsReceived);
  MyAssert2(NSConnectionRequestsSent);
  MyAssert2(NSConnectionLocalCount);
  MyAssert2(NSConnectionProxyCount);
  MyAssert2(NSClassDescriptionNeededForClassNotification);

  [pool release];

  exit(0);
}
