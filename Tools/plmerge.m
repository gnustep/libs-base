/* This tool merges text property lists into a single property list.
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Jonathan Gapen  <jagapen@whitewater.chem.wisc.edu>
   Created: April 2000

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
  NSString		*destName;
  NSString		*fileContents;
  NSMutableDictionary	*plist;
  unsigned		i;

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

  if ([args count] < 3)
    {
      NSLog(@"Usage: %@ [destination-file] [input-file ...]",
              [procinfo processName]);
      [pool release];
      exit(0);
    }

  destName = [args objectAtIndex: 1];
  if ([[NSFileManager defaultManager] fileExistsAtPath: destName])
    {
      NS_DURING
        {
          fileContents = [NSString stringWithContentsOfFile: destName];
          plist = [fileContents propertyList];
        }
      NS_HANDLER
        {
          NSLog(@"Parsing '%@' - %@", destName, [localException reason]);
        }
      NS_ENDHANDLER

      if ((plist == nil) || ![plist isKindOfClass: [NSDictionary class]])
        {
          NSLog(@"The destination property list must contain an NSDictionary.");
          [pool release];
          exit(1);
        }
    }
  else
    {
      plist = [NSMutableDictionary new];
    }

  for (i = 2; i < [args count]; i++)
    {
      NSString		*filename = [args objectAtIndex: i];
      NSString		*key = filename;
      id		object = nil;

      NS_DURING
        {
          fileContents = [NSString stringWithContentsOfFile: filename];
          object = [fileContents propertyList];
        }
      NS_HANDLER
        {
          NSLog(@"Parsing '%@' - %@", filename, [localException reason]);
        }
      NS_ENDHANDLER

      if ([[filename pathExtension] isEqualToString: @"plist"])
	{
	  key = [filename stringByDeletingPathExtension];
	}

      if (object == nil)
        NSLog(@"Parsing '%@' - nil property list", filename);
      else if ([object isKindOfClass: [NSArray class]] == YES)
        [plist setObject: object forKey: key];
      else if ([object isKindOfClass: [NSData class]] == YES)
        [plist setObject: object forKey: key];
      else if ([object isKindOfClass: [NSDictionary class]] == YES)
        [plist addEntriesFromDictionary: object];
      else if ([object isKindOfClass: [NSString class]] == YES)
        [plist setObject: object forKey: key];
      else
        NSLog(@"Parsing '%@' - unexpected class - %@",
                filename, [[object class] description]);
    }

  if ([plist writeToFile: destName atomically: YES] == NO)
    NSLog(@"Error writing property list to '%@'", destName);

  [pool release];
  exit(0);
}
