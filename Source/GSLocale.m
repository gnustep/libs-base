/* GSLocale - various functions for localization
    
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@gnu.org>
   Created: Oct 2000

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
#include <base/GSLocale.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSLock.h>

#ifdef HAVE_LOCALE_H

#include <locale.h>
#ifdef HAVE_LANGINFO_H
#include <langinfo.h>
#endif
#include <Foundation/NSUserDefaults.h>
#include <Foundation/NSBundle.h>

/*
 * Function called by [NSObject +initialize] to setup locale information
 * from environment variables.  Must *not* use any ObjC code since it needs
 * to run before any ObjC classes are fully initialised so that they can
 * make use of locale information.
 */
const char*
GSSetLocaleC(const char *loc)
{
  return setlocale(LC_ALL, loc);
}

/* Set the locale for libc functions from the supplied string or from
   the environment if not specified. This function should be called
   as soon as possible after the start of the program. Passing
   @"" will set the locale from the environment variables LC_ALL or LANG (or
   whatever is specified by setlocale) Passing nil will just return the
   current locale. */
NSString *
GSSetLocale(NSString *locale)
{
  const char *clocale;

  clocale = NULL;
  if (locale != nil)
    {
      clocale = [locale cString];
    }
  clocale = GSSetLocaleC(clocale);

  if (clocale == NULL || strcmp(clocale, "C") == 0 
    || strcmp(clocale, "POSIX") == 0) 
    {
      clocale = NULL;
    }

  locale = nil;
  if (clocale != 0)
    {
      locale = [NSString stringWithCString: clocale];
    }
  return locale;
}

#define GSLanginfo(value) [NSString stringWithCString: nl_langinfo (value)]

/* Creates a locale dictionary from information provided by i18n functions.
   Many, but not all, of the keys are filled in or inferred from the
   available information */
NSDictionary *
GSDomainFromDefaultLocale(void)
{
#ifdef HAVE_LANGINFO_H
  static NSDictionary	*saved = nil;
  int			i;
  struct lconv		*lconv;
  NSMutableDictionary	*dict;
  NSMutableArray	*arr;
  NSString		*str1;
  NSString		*str2;

  if (saved != nil)
    return saved;

  dict = [NSMutableDictionary dictionary];

  /* Time/Date Information */
  arr = [NSMutableArray arrayWithCapacity: 7];
  for (i = 0; i < 7; i++)
    {
      [arr addObject: GSLanginfo(DAY_1+i)];
    }
  [dict setObject: arr forKey: NSWeekDayNameArray];

  arr = [NSMutableArray arrayWithCapacity: 7];
  for (i = 0; i < 7; i++)
    {
      [arr addObject: GSLanginfo(ABDAY_1+i)];
    }
  [dict setObject: arr forKey: NSShortWeekDayNameArray];

  arr = [NSMutableArray arrayWithCapacity: 12];
  for (i = 0; i < 12; i++)
    {
      [arr addObject: GSLanginfo(MON_1+i)];
    }
  [dict setObject: arr forKey: NSMonthNameArray];

  arr = [NSMutableArray arrayWithCapacity: 12];
  for (i = 0; i < 12; i++)
    {
      [arr addObject: GSLanginfo(ABMON_1+i)];
    }
  [dict setObject: arr forKey: NSShortMonthNameArray];

  str1 = GSLanginfo(AM_STR);
  str2 = GSLanginfo(PM_STR);
  if (str1 != nil && str2 != nil)
    {
      [dict setObject: [NSArray arrayWithObjects: str1, str2, nil]
	       forKey: NSAMPMDesignation];
    }

  [dict setObject: GSLanginfo(D_T_FMT)
	   forKey: NSTimeDateFormatString];
  [dict setObject: GSLanginfo(D_FMT)
	   forKey: NSShortDateFormatString];
  [dict setObject: GSLanginfo(T_FMT)
	   forKey: NSTimeFormatString];

  lconv = localeconv();

  /* Currency Information */
  if (lconv->currency_symbol)
    {
      [dict setObject: [NSString stringWithCString: lconv->currency_symbol]
	       forKey: NSCurrencySymbol];
    }
  if (lconv->int_curr_symbol)
    {
      [dict setObject: [NSString stringWithCString: lconv->int_curr_symbol]
	       forKey: NSInternationalCurrencyString];
    }
  if (lconv->mon_decimal_point)
    {
      [dict setObject: [NSString stringWithCString: lconv->mon_decimal_point]
	       forKey: NSInternationalCurrencyString];
    }
  if (lconv->mon_thousands_sep)
    {
      [dict setObject: [NSString stringWithCString: lconv->mon_thousands_sep]
	       forKey: NSInternationalCurrencyString];
    }

  if (lconv->decimal_point)
    {
      [dict setObject: [NSString stringWithCString: lconv->decimal_point]
	       forKey: NSDecimalSeparator];
    }
  if (lconv->thousands_sep)
    {
      [dict setObject: [NSString stringWithCString: lconv->thousands_sep]
	       forKey: NSThousandsSeparator];
    }

  
  /* FIXME: Get currency format from localeconv */

  str1 = GSSetLocale(nil);
  if (str1 != nil)
    {
      [dict setObject: str1 forKey: NSLocale];
    }
  str2 = GSLanguageFromLocale(str1);
  if (str2 != nil)
    {
      [dict setObject: str2 forKey: NSLanguageName];
    }

  [gnustep_global_lock lock];
  saved = [dict mutableCopy];
  [gnustep_global_lock unlock];
  return saved;
#else /* HAVE_LANGINFO_H */
  return nil;
#endif
}

NSString *
GSLanguageFromLocale(NSString *locale)
{
  NSString	*language = nil;
  NSString	*aliases = nil;

  if (locale == nil || [locale isEqual: @"C"] || [locale isEqual: @"POSIX"])
    return @"English";

  aliases = [NSBundle pathForGNUstepResource: @"Locale"
		                      ofType: @"aliases"
		                 inDirectory: @"Resources/Languages"];  
  if (aliases != nil)
    {
      NSDictionary	*dict;

      dict = [NSDictionary dictionaryWithContentsOfFile: aliases];
      language = [dict objectForKey: locale];
      if (language == nil && [locale pathExtension] != nil)
	{
	  locale = [locale stringByDeletingPathExtension];
	  language = [dict objectForKey: locale];
	}
      if (language == nil)
	{
	  locale = [locale substringFromRange: NSMakeRange(0, 2)];
	  language = [dict objectForKey: locale];
	}
    }
      
  return language;
}

#else /* HAVE_LOCALE_H */
NSString *
GSSetLocale(NSString *locale)
{
  return nil;
}

NSDictionary *
GSDomainFromDefaultLocale(void)
{
  return nil;
}

NSString *
GSLanguageFromLocale(NSString *locale)
{
  return nil;
}

#endif /* !HAVE_LOCALE_H */


