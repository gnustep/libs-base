/* 
   This tool produces a desktop link file for KDE and Gnome out of a GNUstep 
   property list.
   Copyright (C) 20010 Free Software Foundation, Inc.

   Written by:  Fred Kiefer <FredKiefer@gmx.de>
   Created: December 2001

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

#include        <Foundation/Foundation.h>
#include	<Foundation/NSArray.h>
#include	<Foundation/NSAutoreleasePool.h>
#include	<Foundation/NSData.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSException.h>
#include	<Foundation/NSFileManager.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSString.h>

int
main(int argc, char** argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo		*procinfo;
  NSArray		*args;
  NSString		*sourceName;
  NSString		*destName;
  NSMutableString	*fileContents;
  NSDictionary	        *plist;
  NSArray		*list;
  NSString		*entry;

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  pool = [NSAutoreleasePool new];
  procinfo = [NSProcessInfo processInfo];
  if (procinfo == nil)
    {
      NSLog(@"plmerge: unable to get process information!");
      [pool release];
      exit(0);
    }

  args = [procinfo arguments];

  if ([args count] < 2)
    {
      GSPrintf(stderr, @"Usage: %@ input-file [destination-file]\n",
	[procinfo processName]);
      [pool release];
      exit(0);
    }

  sourceName = [args objectAtIndex: 1];
  if ([args count] > 2)
    {
      destName = [args objectAtIndex: 2];
    }
  else
    {
      /* Filled in later */
      destName = nil;
    }
  NS_DURING
    {
      fileContents = [NSString stringWithContentsOfFile: sourceName];
      plist = [fileContents propertyList];
    }
  NS_HANDLER
    {
      GSPrintf(stderr, @"Parsing '%@' - %@\n", sourceName,
	[localException reason]);
    }
  NS_ENDHANDLER

  if ((plist == nil) || ![plist isKindOfClass: [NSDictionary class]])
    {
      GSPrintf(stderr,
	@"The source property list must contain an NSDictionary.\n");
      [pool release];
      exit(1);
    }

  fileContents = [NSMutableString stringWithCapacity: 200];
  [fileContents appendString: @"[Desktop Entry]\nEncoding=UTF-8\nType=Application\n"];
  entry = [plist objectForKey: @"ApplicationRelease"];
  if (entry != nil)
    [fileContents appendFormat: @"Version=%@\n", entry];
  entry = [plist objectForKey: @"ApplicationName"];
  if (entry != nil)
    {
      [fileContents appendFormat: @"Name=%@\n", entry];
      if (destName == nil)
	destName = [entry stringByAppendingString: @".desktop"];
    }
  entry = [plist objectForKey: @"NSIcon"];
  if (entry != nil)
  {
    if ([[entry pathExtension] isEqualToString: @""])
      [fileContents appendFormat: @"Icon=%@.tiff\n", entry];
    else
      [fileContents appendFormat: @"Icon=%@\n", entry];
  }
  entry = [plist objectForKey: @"NSExecutable"];
  if (entry != nil)
    {
      [fileContents appendFormat: @"Exec=openapp %@.app\n", entry];
      [fileContents appendFormat: @"#TryExec=%@.app\n", entry];
    }

  list = [plist objectForKey: @"NSTypes"];
  if (list != nil)
  {
    int i;

    [fileContents appendString: @"MimeType="];
    for (i = 0; i < [list count]; i++)
    {
      NSArray *types;
      int j;

      plist = [list objectAtIndex: i];
      types = [plist objectForKey: @"NSMIMETypes"];
      if (types != nil)
        {
	  for (j = 0; j < [types count]; j++)
	  {
	    entry = [types objectAtIndex: j];
	    [fileContents appendFormat: @"%@;", entry];
	  }
	}
    }
    [fileContents appendString: @"\n"];
  }

  if ([[fileContents dataUsingEncoding: NSUTF8StringEncoding] 
    writeToFile: destName atomically: YES] == NO)
    {
      GSPrintf(stderr, @"Error writing property list to '%@'\n", destName);
    }
  [pool release];
  exit(0);
}
