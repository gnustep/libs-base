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

#include	<Foundation/NSArray.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSDebug.h>
#include	<Foundation/NSAutoreleasePool.h>


int
main(int argc, char** argv)
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NSUserDefaults	*defs;
  NSProcessInfo		*proc;
  NSArray		*args;
  unsigned		i;

  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"defaults: unable to get process information!\n");
      [pool release];
      exit(0);
    }

  args = [proc arguments];

  if ([args count] <= 1)
    {
      NSLog(@"No file names given to parse.");
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
		NSLog(@"Parsing '%@' - nil property list", file);
	      else if ([result isKindOfClass: [NSDictionary class]] == YES)
		NSLog(@"Parsing '%@' - seems ok", file);
	      else
		NSLog(@"Parsing '%@' - unexpected class - %@",
			file, [[result class] description]);
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Parsing '%@' - %@", file, [localException reason]);
	    }
	  NS_ENDHANDLER
	}
    }
  [pool release];
  return 0;
}
