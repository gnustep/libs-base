/* This tool checks that a file is a valid strings-file
   Copyright (C) 1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: February 1999

   This file is part of the GNUstep Project

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
    
   You should have received a copy of the GNU General Public  
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   */

#include "config.h"
#include	<Foundation/NSArray.h>
#include	<Foundation/NSData.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSDebug.h>
#include	<Foundation/NSAutoreleasePool.h>

int
convert_unicode(NSArray *args)
{
  int i;

  for (i = 2; i < [args count]; i++)
    {
      NSString	*file = [args objectAtIndex: i];
      
      NS_DURING
	{
	  NSData        *data;
	  NSString	*myString;
	  NSString      *output;

	  data = [NSData dataWithContentsOfFile: file];
	  myString = [[NSString alloc] initWithData: data
					   encoding: NSUTF8StringEncoding];
	  AUTORELEASE(myString);
	  if ([myString length] == 0)
	    {
	      myString = [[NSString alloc] initWithData: data
		encoding: [NSString defaultCStringEncoding]];
	    }
	  output = [[file lastPathComponent]
	    stringByAppendingPathExtension: @"unicode"];
	  data = [myString dataUsingEncoding: NSUnicodeStringEncoding];
	  [data writeToFile: output atomically: YES];
	}
      NS_HANDLER
	{
	  GSPrintf(stderr, @"Converting '%@' - %@\n", file,
	    [localException reason]);
	}
      NS_ENDHANDLER
    }
  return 0;
}

int
convert_utf8(NSArray *args)
{
  int i;

  for (i = 2; i < [args count]; i++)
    {
      NSString	*file = [args objectAtIndex: i];
      
      NS_DURING
	{
	  NSData        *data;
	  NSString	*myString;
	  NSString      *output;

	  myString = [NSString stringWithContentsOfFile: file];
	  output = [[file lastPathComponent]
	    stringByAppendingPathExtension: @"utf8"];
	  data = [myString dataUsingEncoding: NSUTF8StringEncoding];
	  [data writeToFile: output atomically: YES];
	}
      NS_HANDLER
	{
	  GSPrintf(stderr, @"Converting '%@' - %@\n", file,
	    [localException reason]);
	}
      NS_ENDHANDLER
    }
  return 0;
}

int
main(int argc, char** argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo		*proc;
  NSArray		*args;
  unsigned		i;

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  pool = [NSAutoreleasePool new];
  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      GSPrintf(stderr, @"defaults: unable to get process information!\n");
      [pool release];
      exit(0);
    }

  args = [proc arguments];

  if ([args count] <= 1 || [[args objectAtIndex: 1] isEqual: @"--help"]
      || [[args objectAtIndex: 1] isEqual: @"-h"])
    {
      printf("Usage: sfparse [--utf8] filename.\n");
      printf("--unicode    - convert an ASCII or UTF8 file to Unicode\n");
      printf("--utf8       - convert an ASCII or Unicode to UTF8\n");
    }
  else if ([[args objectAtIndex: 1] isEqual: @"--unicode"])
    {
      convert_unicode(args);
    }
  else if ([[args objectAtIndex: 1] isEqual: @"--utf8"])
    {
      convert_utf8(args);
    }
  else
    {
      for (i = 1; i < [args count]; i++)
	{
	  NSString	*file = [args objectAtIndex: i];

	  NS_DURING
	    {
	      NSString	*myString;
	      id		result;

	      myString = [NSString stringWithContentsOfFile: file];
	      result = [myString propertyListFromStringsFileFormat];
	      if (result == nil)
		GSPrintf(stderr, @"Parsing '%@' - nil property list\n", file);
	      else if ([result isKindOfClass: [NSDictionary class]] == YES)
		GSPrintf(stderr, @"Parsing '%@' - seems ok\n", file);
	      else
		GSPrintf(stderr, @"Parsing '%@' - unexpected class - %@\n",
		  file, [[result class] description]);
	    }
	  NS_HANDLER
	    {
	      GSPrintf(stderr, @"Parsing '%@' - %@\n", file,
		[localException reason]);
	    }
	  NS_ENDHANDLER
	}
    }
  [pool release];
  return 0;
}
