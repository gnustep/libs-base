/* This tool builds a cache of service specifications
   Copyright (C) 1998 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: November 1998

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */

#include	<Foundation/NSArray.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSFileManager.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSData.h>
#include	<Foundation/NSDebug.h>
#include	<Foundation/NSAutoreleasePool.h>
#include	<Foundation/NSSerialization.h>

static void scanDirectory(NSMutableDictionary *services, NSString *path);
static NSMutableArray *validateEntry(id svcs, NSString* path);
static NSMutableDictionary *validateService(NSDictionary *service, NSString* path, unsigned i);

static NSString		*cacheName = @".GNUstepServices";
static NSString		*infoLoc = @"Resources/Info-gnustep.plist";

static	BOOL verbose = NO;
static	NSMutableDictionary	*serviceMap;
static	NSMutableDictionary	*filterMap;
static	NSMutableDictionary	*printMap;
static	NSMutableDictionary	*spellMap;

int
main(int argc, char** argv)
{
  NSAutoreleasePool	*pool;
  NSData		*data;
  NSProcessInfo		*proc;
  NSFileManager		*mgr;
  NSDictionary		*env;
  NSMutableDictionary	*services;
  NSMutableArray	*roots;
  NSArray		*args;
  NSArray		*locations;
  NSString		*usrRoot;
  NSString		*str;
  unsigned		index;
  BOOL			isDir;
  NSMutableDictionary	*fullMap;

  pool = [NSAutoreleasePool new];

  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"unable to get process information!\n");
      [pool release];
      exit(0);
    }

  serviceMap = [NSMutableDictionary dictionaryWithCapacity: 64];
  filterMap = [NSMutableDictionary dictionaryWithCapacity: 66];
  printMap = [NSMutableDictionary dictionaryWithCapacity: 8];
  spellMap = [NSMutableDictionary dictionaryWithCapacity: 8];

  env = [proc environment];
  args = [proc arguments];

  for (index = 0; index < [args count]; index++)
    {
      if ([[args objectAtIndex: index] isEqual: @"--verbose"])
	verbose = YES;
      if ([[args objectAtIndex: index] isEqual: @"--help"])
	{
	  printf(
"make_services builds a validated cache of service information for use by\n"
"programs that want to use the OpenStep services facility.\n"
"This cache is stored in '%s' in the users GNUstep directory.\n"
"\n"
"You may use 'make_services --test filename' to test that the property list\n"
"in 'filename' contains a valid services definition.\n", [cacheName cString]);
	  exit(0);
	}
      if ([[args objectAtIndex: index] isEqual: @"--test"])
	{
	  verbose = YES;
	  while (++index < [args count])
	    {
	      NSString		*file = [args objectAtIndex: index];
	      NSDictionary	*info;

	      info = [NSDictionary dictionaryWithContentsOfFile: file];
	      if (info)
		{
		  id	svcs = [info objectForKey: @"NSServices"];

		  if (svcs)
		    {
		      validateEntry(svcs, file);
		    }
		  else
		    {
		      NSLog(@"bad info - %@\n", file);
		    }
		}
	      else
		{
		  NSLog(@"bad info - %@\n", file);
		}
	    }
	  exit(0);
	}
    }

  roots = [NSMutableArray arrayWithCapacity: 3];

  /*
   *	Build a list of 'root' directories to search for applications.
   *	Order is important - later duplicates of services are ignored.
   */
  str = [env objectForKey: @"GNUSTEP_USER_ROOT"];
  if (str != nil)
    usrRoot = str;
  else
    usrRoot = [NSString stringWithFormat: @"%@/GNUstep", NSHomeDirectory()];
  [roots addObject: usrRoot];

  str = [env objectForKey: @"GNUSTEP_LOCAL_ROOT"];
  if (str != nil)
    [roots addObject: str];
  else
    [roots addObject: @"/usr/GNUstep/Local"];

  str = [env objectForKey: @"GNUSTEP_SYSTEM_ROOT"];
  if (str != nil)
    [roots addObject: str];
  else
    [roots addObject: @"/usr/GNUstep"];

  /*
   *	List of directory names to search within each root directory
   *	when looking for applications providing services.
   */
  locations = [NSArray arrayWithObjects: @"Apps", @"Library/Services", nil];

  services = [NSMutableDictionary dictionaryWithCapacity: 200];

  for (index = 0; index < [roots count]; index++)
    {
      NSString		*root = [roots objectAtIndex: index];
      unsigned		dirIndex;

      for (dirIndex = 0; dirIndex < [locations count]; dirIndex++)
	{
	  NSString	*loc = [locations objectAtIndex: dirIndex];
	  NSString	*path = [root stringByAppendingPathComponent: loc];

	  scanDirectory(services, path);
	}
    }

  mgr = [NSFileManager defaultManager];
  if (([mgr fileExistsAtPath: usrRoot isDirectory: &isDir] && isDir) == 0)
    {
      if ([mgr createDirectoryAtPath: usrRoot attributes: nil] == NO)
	{
	  NSLog(@"couldn't create %@\n", usrRoot);
	  [pool release];
	  exit(1);
	}
    }

  fullMap = [NSMutableDictionary dictionaryWithCapacity: 5];
  [fullMap setObject: services forKey: @"ByPath"];
  [fullMap setObject: serviceMap forKey: @"ByService"];
  [fullMap setObject: filterMap forKey: @"ByFilter"];
  [fullMap setObject: printMap forKey: @"ByPrint"];
  [fullMap setObject: spellMap forKey: @"BySpell"];

  str = [usrRoot stringByAppendingPathComponent: cacheName];
  data = [NSSerializer serializePropertyList: fullMap];
  if ([data writeToFile: str atomically: YES] == NO)
    {
      NSLog(@"couldn't write %@\n", str);
      [pool release];
      exit(1);
    }
  [pool release];
  exit(0);
}

static void
scanDirectory(NSMutableDictionary *services, NSString *path)
{
  NSFileManager		*mgr = [NSFileManager defaultManager];
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSArray		*contents = [mgr directoryContentsAtPath: path];
  unsigned		index;

  for (index = 0; index < [contents count]; index++)
    {
      NSString	*name = [contents objectAtIndex: index];
      NSString	*ext = [name pathExtension];
      NSString	*newPath;
      BOOL	isDir;


      if (ext != nil &&
	  ([ext isEqualToString: @"app"] || [ext isEqualToString: @"debug"]))
	{
	  newPath = [path stringByAppendingPathComponent: name];
	  if ([mgr fileExistsAtPath: newPath isDirectory: &isDir] && isDir)
	    {
	      NSString	*infPath;

	      infPath = [newPath stringByAppendingPathComponent: infoLoc];
	      if ([mgr fileExistsAtPath: infPath isDirectory: &isDir] && !isDir)
		{
		  NSDictionary	*info;

		  info = [NSDictionary dictionaryWithContentsOfFile: infPath];
		  if (info)
		    {
		      id	svcs = [info objectForKey: @"NSServices"];

		      if (svcs)
			{
			  NSMutableArray	*entry;

			  entry = validateEntry(svcs, newPath);
			  if (entry)
			    {
			      [services setObject: entry forKey: newPath];
			    }
			}
		    }
		  else
		    {
		      NSLog(@"bad app info - %@\n", infPath);
		    }
		}
	    }
	  else
	    {
	      NSLog(@"bad application - %@\n", newPath);
	    }
	}
      else if (ext != nil && [ext isEqualToString: @"service"])
	{
	  newPath = [path stringByAppendingPathComponent: name];
	  if ([mgr fileExistsAtPath: newPath isDirectory: &isDir] && isDir)
	    {
	      NSString	*infPath;

	      infPath = [newPath stringByAppendingPathComponent: infoLoc];
	      if ([mgr fileExistsAtPath: infPath isDirectory: &isDir] && !isDir)
		{
		  NSDictionary	*info;

		  info = [NSDictionary dictionaryWithContentsOfFile: infPath];
		  if (info)
		    {
		      id	svcs = [info objectForKey: @"NSServices"];

		      if (svcs)
			{
			  NSMutableArray	*entry;

			  entry = validateEntry(svcs, newPath);
			  if (entry)
			    {
			      [services setObject: entry forKey: newPath];
			    }
			}
		      else
			{
			  NSLog(@"missing info - %@\n", infPath);
			}
		    }
		  else
		    {
		      NSLog(@"bad service info - %@\n", infPath);
		    }
		}
	    }
	  else
	    {
	      NSLog(@"bad services bundle - %@\n", newPath);
	    }
	}
      else
	{
	  newPath = [path stringByAppendingPathComponent: name];
	  if ([mgr fileExistsAtPath: newPath isDirectory: &isDir] && isDir)
	    {
	      scanDirectory(services, newPath);
	    }
	}
    }
  [arp release];
}

static NSMutableArray*
validateEntry(id svcs, NSString *path)
{
  NSMutableArray	*newServices;
  NSArray		*services;
  unsigned		pos;

  if ([svcs isKindOfClass: [NSArray class]] == NO)
    {
      NSLog(@"NSServices entry not an array - %@\n", path);
      return nil;
    }

  services = (NSArray*)svcs;
  newServices = [NSMutableArray arrayWithCapacity: [services count]];
  for (pos = 0; pos < [services count]; pos++)
    {
      id			svc;

      svc = [services objectAtIndex: pos];
      if ([svc isKindOfClass: [NSDictionary class]])
	{
	  NSDictionary		*service = (NSDictionary*)svc;
	  NSMutableDictionary	*newService;

	  newService = validateService(service, path, pos);
	  if (newService)
	    {
	      [newServices addObject: newService];
	    }
	}
      else
	{
	  NSLog(@"NSServices entry %u not a dictionary - %@\n",
		pos, path);
	}
    }
  return newServices;
}

static NSMutableDictionary*
validateService(NSDictionary *service, NSString *path, unsigned pos)
{
  static NSDictionary	*fields = nil;
  static Class		aClass;
  static Class		dClass;
  static Class		sClass;
  NSEnumerator		*e;
  NSMutableDictionary	*result;
  NSString		*k;
  id			obj;

  if (fields == nil)
    {
      aClass = [NSArray class];
      dClass = [NSDictionary class];
      sClass = [NSString class];
      fields = [NSDictionary dictionaryWithObjectsAndKeys:
	@"string", @"NSMessage",
	@"string", @"NSPortName",
	@"array", @"NSSendTypes",
	@"array", @"NSReturnTypes",
	@"dictionary", @"NSMenuItem",
	@"dictionary", @"NSKeyEquivalent",
	@"string", @"NSUserData",
	@"string", @"NSTimeout",
	@"string", @"NSHost",
	@"string", @"NSExecutable",
	@"string", @"NSFilter",
	@"string", @"NSInputMechanism",
	@"string", @"NSPrintFilter",
	@"string", @"NSDeviceDependent",
	@"array", @"NSLanguages",
	@"string", @"NSSpellChecker",
	nil]; 
      [fields retain];
    }

  result = [NSMutableDictionary dictionaryWithCapacity: [service count]];

  /*
   *	Step through and check that each field is a known one and of the
   *	correct type.
   */
  e = [service keyEnumerator];
  while ((k = [e nextObject]) != nil)
    {
      NSString	*type = [fields objectForKey: k];

      if (type == nil)
	{
	  NSLog(@"NSServices entry %u spurious field (%@)- %@\n", pos, k, path);
	}
      else
	{
	  obj = [service objectForKey: k];
	  if ([type isEqualToString: @"string"])
	    {
	      if ([obj isKindOfClass: sClass] == NO)
		{
		  NSLog(@"NSServices entry %u field %@ is not a string - %@\n", pos, k, path);
		  return nil;
		}
	      [result setObject: obj forKey: k];
	    }
	  else if ([type isEqualToString: @"array"])
	    {
	      NSArray	*a;

	      if ([obj isKindOfClass: aClass] == NO)
		{
		  NSLog(@"NSServices entry %u field %@ is not an array - %@\n", pos, k, path);
		  return nil;
		}
	      a = (NSArray*)obj;
	      if ([a count] == 0)
		{
		  NSLog(@"NSServices entry %u field %@ is an empty array - %@\n", pos, k, path);
		}
	      else
		{
		  unsigned	i;

		  for (i = 0; i < [a count]; i++)
		    {
		      if ([[a objectAtIndex: i] isKindOfClass: sClass] == NO)
			{
			  NSLog(@"NSServices entry %u field %@ element %u is not a string - %@\n", pos, k, i, path);
			  return nil;
			}
		    }
		  [result setObject: obj forKey: k];
		}
	    }
	  else if ([type isEqualToString: @"dictionary"])
	    {
	      NSDictionary	*d;

	      if ([obj isKindOfClass: dClass] == NO)
		{
		  NSLog(@"NSServices entry %u field %@ is not a dictionary - %@\n", pos, k, path);
		  return nil;
		}
	      d = (NSDictionary*)obj;
	      if ([d objectForKey: @"default"] == nil)
		{
		  NSLog(@"NSServices entry %u field %@ has no default value - %@\n", pos, k, path);
		}
	      else
		{
		  NSEnumerator	*e = [d objectEnumerator];

		  while ((obj = [e nextObject]) != nil)
		    {
		      if ([obj isKindOfClass: sClass] == NO)
			{
			  NSLog(@"NSServices entry %u field %@ contains non-string value - %@\n", pos, k, path);
			  return nil;
			}
		    }
		  [result setObject: obj forKey: k];
		}
	    }
	}
    }

  /*
   *	Record in this service dictionary where it is to be found.
   */
  [result setObject: path forKey: @"ServicePath"];

  /*
   *	Now check that we have the required fields for the service.
   */
  if ((obj = [result objectForKey: @"NSMessage"]) != nil)
    {
      NSDictionary	*item;
      NSEnumerator	*e;
      NSString		*k;
      BOOL		used = NO;

      if ([result objectForKey: @"NSPortName"] == nil)
	{
	  NSLog(@"NSServices entry %u NSPortName missing - %@\n", pos, path);
	  return nil;
	}
      if ([result objectForKey: @"NSSendTypes"] == nil &&
	  [result objectForKey: @"NSReturnTypes"] == nil)
	{
	  NSLog(@"NSServices entry %u types missing - %@\n", pos, path);
	  return nil;
	}
      if ((item = [result objectForKey: @"NSMenuItem"]) == nil)
	{
	  NSLog(@"NSServices entry %u NSMenuItem missing - %@\n", pos, path);
	  return nil;
	}

      /*
       *	For each language, check to see if we already have a service
       *	by this name - if so - we ignore this one.
       */
      e = [item keyEnumerator];
      while ((k = [e nextObject]) != nil)
	{
	  NSString		*name = [item objectForKey: k];
	  NSMutableDictionary	*names;

	  names = [serviceMap objectForKey: k];
	  if (names == nil)
	    {
	      names = [NSMutableDictionary dictionaryWithCapacity: 1];
	      [serviceMap setObject: names forKey: k];
	    }
	  if ([names objectForKey: name] == nil)
	    {
	      [names setObject: result forKey: name];
	      used = YES;
	    }
	}
      if (used == NO)
	{
	  if (verbose)
	    NSLog(@"Ignoring entry %u in %@ -\n%@\n", pos, path, result);
	  return nil;	/* Ignore - already got service with this name	*/
	}
    }
  else if ((obj = [result objectForKey: @"NSFilter"]) != nil)
    {
      NSString	*str;
      NSArray	*snd;
      NSArray	*ret;
      unsigned	spos;
      BOOL	used = NO;

      str = [result objectForKey: @"NSInputMechanism"];
      if (str)
	{
	  if ([str isEqualToString: @"NSUnixStdio"] == NO &&
	      [str isEqualToString: @"NSMapFile"] == NO &&
	      [str isEqualToString: @"NSIdentity"] == NO)
	  {
	    NSLog(@"NSServices entry %u bad input mechanism - %@\n", pos, path);
	    return nil;
	  }
	}

      snd = [result objectForKey: @"NSSendTypes"];
      ret = [result objectForKey: @"NSReturnTypes"];
      if (snd == nil || ret == nil)
	{
	  NSLog(@"NSServices entry %u types missing - %@\n", pos, path);
	  return nil;
	}

      /*
       *	For each send-type/return-type combination, see if we
       *	already have a filter - if so - ignore this one.
       */
      spos = [snd count];
      while (spos-- > 0)
	{
	  NSString		*stype = [snd objectAtIndex: spos];
	  NSMutableDictionary	*sdict = [filterMap objectForKey: stype];
	  unsigned		rpos;

	  if (sdict == nil)
	    {
	      sdict = [NSMutableDictionary dictionaryWithCapacity: [snd count]];
	      [filterMap setObject: sdict forKey: stype];
	    }
	  rpos = [ret count];
	  while (rpos-- > 0)
	    {
	      NSString			*rtype = [ret objectAtIndex: rpos];

	      if ([sdict objectForKey: rtype] == nil)
		{
		  [sdict setObject: result forKey: rtype];
		  used = YES;
		}
	    }
	}
      if (used == NO)
	{
	  if (verbose)
	    NSLog(@"Ignoring entry %u in %@ -\n%@\n", pos, path, result);
	  return nil;	/* Ignore - already got filter for types.	*/
	}
    }
  else if ((obj = [result objectForKey: @"NSPrintFilter"]) != nil)
    {
      NSDictionary	*item;
      NSEnumerator	*e;
      NSString		*k;
      BOOL		used = NO;

      if ((item = [result objectForKey: @"NSMenuItem"]) == nil)
	{
	  NSLog(@"NSServices entry %u NSMenuItem missing - %@\n", pos, path);
	  return nil;
	}
      /*
       *	For each language, check to see if we already have a print
       *	filter by this name - if so - we ignore this one.
       */
      e = [item keyEnumerator];
      while ((k = [e nextObject]) != nil)
	{
	  NSString		*name = [item objectForKey: k];
	  NSMutableDictionary	*names;

	  names = [printMap objectForKey: k];
	  if (names == nil)
	    {
	      names = [NSMutableDictionary dictionaryWithCapacity: 1];
	      [printMap setObject: names forKey: k];
	    }
	  if ([names objectForKey: name] == nil)
	    {
	      [names setObject: result forKey: name];
	      used = YES;
	    }
	}
      if (used == NO)
	{
	  if (verbose)
	    NSLog(@"Ignoring entry %u in %@ -\n%@\n", pos, path, result);
	  return nil;	/* Ignore - already got filter with this name	*/
	}
    }
  else if ((obj = [result objectForKey: @"NSSpellChecker"]) != nil)
    {
      NSArray	*item;
      unsigned	pos;
      BOOL	used = NO;

      if ((item = [result objectForKey: @"NSLanguages"]) == nil)
	{
	  NSLog(@"NSServices entry %u NSLanguages missing - %@\n", pos, path);
	  return nil;
	}
      /*
       *	For each language, check to see if we already have a spell
       *	checker by this name - if so - we ignore this one.
       */
      pos = [item count];
      while (pos-- > 0)
	{
	  NSString	*lang = [item objectAtIndex: pos];

	  if ([spellMap objectForKey: lang] == nil)
	    {
	      [spellMap setObject: result forKey: lang];
	      used = YES;
	    }
	}
      if (used == NO)
	{
	  if (verbose)
	    NSLog(@"Ignoring entry %u in %@ -\n%@\n", pos, path, result);
	  return nil;	/* Ignore - already got speller with language.	*/
	}
    }
  else
    {
      NSLog(@"NSServices entry %u unknown service/filter - %@\n", pos, path);
      return nil;
    }
  
  return result;
}

