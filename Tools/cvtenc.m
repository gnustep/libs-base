/* This tool converts a file containing a string to a C String encoding.
   Copyright (C) 2002 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: April 2002

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
#include	<Foundation/Foundation.h>
#include	<Foundation/NSArray.h>
#include	<Foundation/NSData.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSDebug.h>
#include	<Foundation/NSFileHandle.h>
#include	<Foundation/NSAutoreleasePool.h>


int
main(int argc, char** argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo		*proc;
  NSArray		*args;
  unsigned		i;
  BOOL			found = NO;
  NSString		*n;
  NSStringEncoding	enc = 0;

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments: argv count: argc environment: env];
#endif
  pool = [NSAutoreleasePool new];
  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"defaults: unable to get process information!\n");
      [pool release];
      exit(0);
    }

  args = [proc arguments];

  n = [[NSUserDefaults standardUserDefaults] stringForKey: @"Encoding"];
  if (n == nil)
    {
      enc = [NSString defaultCStringEncoding];
    }
  else
    {
      NSStringEncoding	*e;
      NSMutableString	*names;

      names = [NSMutableString stringWithCapacity: 1024];
      e = [NSString availableStringEncodings];
      while (*e != 0)
	{
	  NSString	*name = [NSString localizedNameOfStringEncoding: *e];

	  [names appendFormat: @"  %@\n", name];
	  if ([n isEqual: name] == YES)
	    {
	      enc = *e;
	      break;
	    }
	  e++;
	}
      if (enc == 0)
	{
	  NSLog(@"defaults: unable to find encoding '%@'!\n"
	    @"Known encoding names are -\n%@", n, names);
	  [pool release];
	  exit(0);
	}
    }

  for (i = 1; found == NO && i < [args count]; i++)
    {
      NSString	*file = [args objectAtIndex: i];

      if ([file isEqual: @"-Encoding"] == YES)
	{
	  i++;
	  continue;
	}
      found = YES;
      NS_DURING
	{
	  NSData	*myData;

	  myData = [[NSData alloc] initWithContentsOfFile: file];
	  if (myData == nil)
	    {
	      NSLog(@"File read operation failed for %@.", file);
	    }
	  else
	    {
	      unsigned		l = [myData length];
	      const unichar		*b = (const unichar*)[myData bytes];
	      NSStringEncoding	iEnc;
	      NSStringEncoding	oEnc;
	      NSString		*myString;

	      if (l > 1 && (*b == 0xFFFE || *b == 0xFEFF))
		{
		  iEnc = NSUnicodeStringEncoding;
		  oEnc = enc;
		}
	      else
		{
		  iEnc = enc;
		  oEnc = NSUnicodeStringEncoding;
		}
	      
	      myString = [[NSString alloc] initWithData: myData
					       encoding: iEnc];
	      RELEASE(myData);
	      if (myString == nil)
		{
		  NSLog(@"Encoding input conversion failed for %@.", file);
		}
	      else
		{
		  myData = [myString dataUsingEncoding: oEnc
				  allowLossyConversion: NO];
		  RELEASE(myString);
		  if (myData == nil)
		    {
		      NSLog(@"Encoding output conversion failed for %@.",
			file);
		    }
		  else
		    {
		      NSFileHandle	*out;

		      out = [NSFileHandle fileHandleWithStandardOutput];
		      [out writeData: myData];
		      [out synchronizeFile];
		    }
		}
	    }
	}
      NS_HANDLER
	{
	  NSLog(@"Converting '%@' - %@", file, [localException reason]);
	}
      NS_ENDHANDLER
    }

  if (found == NO)
    {
      NSLog(@"\nThis utility expects a filename as an argument.\n"
	@"It reads the file, and writes it to STDOUT after converting it\n"
	@"to unicode from C string encoding or vice versa.\n"
	@"You can supply a '-Encoding name' option to specify the C string\n"
	@"encoding to be used, if you don't want to use the default.");
    }
  [pool release];
  return 0;
}
