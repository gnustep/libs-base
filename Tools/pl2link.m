/*
   This tool produces a desktop link file for KDE and Gnome out of a GNUstep
   property list.
   Copyright (C) 20010 Free Software Foundation, Inc.

   Written by:  Fred Kiefer <FredKiefer@gmx.de>
   Created: December 2001

   This file is part of the GNUstep Project

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either
   version 3 of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this program; see the file COPYINGv3.
   If not, write to the Free Software Foundation,
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
*/

#include <stdlib.h>

#import	"common.h"

#import	"Foundation/NSArray.h"
#import	"Foundation/NSAutoreleasePool.h"
#import	"Foundation/NSData.h"
#import	"Foundation/NSDictionary.h"
#import	"Foundation/NSException.h"
#import	"Foundation/NSFileManager.h"
#import	"Foundation/NSProcessInfo.h"

int
main(int argc, char** argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo		*procinfo;
  NSArray		*args;
  NSString		*sourceName;
  NSString		*destName;
  NSMutableString	*fileContents;
  NSDictionary	        *plist = nil;
  NSArray		*list;
  NSString		*entry;

#ifdef GS_PASS_ARGUMENTS
  GSInitializeProcess(argc, argv, env);
#endif
  pool = [NSAutoreleasePool new];
  procinfo = [NSProcessInfo processInfo];
  if (procinfo == nil)
    {
      NSLog(@"plmerge: unable to get process information!");
      [pool release];
      exit(EXIT_SUCCESS);
    }

  args = [procinfo arguments];

  if ([args count] < 2)
    {
      GSPrintf(stderr, @"Usage: %@ input-file [destination-file]\n",
	[procinfo processName]);
      [pool release];
      exit(EXIT_SUCCESS);
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
      exit(EXIT_FAILURE);
    }

  fileContents = [NSMutableString stringWithCapacity: 200];
  [fileContents appendString:
    @"[Desktop Entry]\nEncoding=UTF-8\nType=Application\n"];
  [fileContents appendString:
    @"Version=0.94\nCategories=GNUstep\n"];
  entry = [plist objectForKey: @"ApplicationName"];
  if (entry != nil)
    {
      [fileContents appendFormat: @"Name=%@\n", entry];
      if (destName == nil)
	destName = [entry stringByAppendingString: @".desktop"];
    }
  entry = [plist objectForKey: @"ApplicationDescription"];
  if (entry != nil)
    {
      [fileContents appendFormat: @"Comment=%@\n", entry];
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
      [fileContents appendFormat: @"FilePattern=%@.app;%@\n", entry, entry];
    }

  list = [plist objectForKey: @"NSTypes"];
  if (list != nil)
    {
      unsigned int i;

      [fileContents appendString: @"MimeType="];
      for (i = 0; i < [list count]; i++)
	{
	  NSArray *types;
	  unsigned int j;

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
  exit(EXIT_SUCCESS);
}
