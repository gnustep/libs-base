/* This tool converts a serialised proerty list to a text representation.
   Copyright (C) 1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: may 1999

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
#include	<Foundation/NSData.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSDebug.h>
#include	<Foundation/NSFileHandle.h>
#include	<Foundation/NSAutoreleasePool.h>


int
main(int argc, char** argv)
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
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
      NSLog(@"No file names given to deserialize.");
    }
  else
    {
      for (i = 1; i < [args count]; i++)
	{
	  NSString	*file = [args objectAtIndex: i];

	  NS_DURING
	    {
	      NSData	*myData;
	      NSString	*myString;
	      id	result;

	      myData = [NSData dataWithContentsOfFile: file];
	      result = [NSDeserializer deserializePropertyListFromData: myData
						     mutableContainers: NO];
	      if (result == nil)
		NSLog(@"Loading '%@' - nil property list", file);
	      else
		{
		  NSFileHandle	*out;

		  myString = [result description];
		  out = [NSFileHandle fileHandleWithStandardOutput];
		  myData = [myString dataUsingEncoding: NSASCIIStringEncoding];
		  [out writeData: myData];
		  [out synchronizeFile];
		}
	    }
	  NS_HANDLER
	    {
	      NSLog(@"Loading '%@' - %@", file, [localException reason]);
	    }
	  NS_ENDHANDLER
	}
    }
  [pool release];
  return 0;
}
