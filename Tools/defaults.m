/* This tool mimics the OPENSTEP command line tool for handling defaults.
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: January 1998

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
#include	<string.h>
#include	<base/preface.h>
#include	<Foundation/NSObject.h>
#include	<Foundation/NSArray.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSProcessInfo.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSDebug.h>
#include	<Foundation/NSAutoreleasePool.h>
#include	<Foundation/NSPathUtilities.h>


int
main(int argc, char** argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSUserDefaults	*defs;
  NSProcessInfo		*proc;
  NSArray		*args;
  NSArray		*domains;
  NSMutableDictionary	*domain;
  NSString		*owner = nil;
  NSString		*name = nil;
  NSString		*value;
  NSString		*user = nil;
  BOOL			found = NO;
  int			i;

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
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

  for (i = 1; i < [args count]; i++)
    {
      if ([[args objectAtIndex: i] isEqual: @"--help"] ||
	    [[args objectAtIndex: i] isEqual: @"help"])
	{
	  printf(
"The 'defaults' command lets you to read and modify a user's defaults.\n\n"
"This program replaces the old NeXTstep style dread, dwrite, and dremove\n"
"programs.\n\n"
"If you have access to another user's defaults database, you may include\n"
"'-u username' before any other options to use that user's database rather\n"
"than your own.\n\n");
	  printf(
"defaults read [ domain [ key] ]\n"
"    read the named default from the specified domain.\n"
"    If no 'key' is given - read all defaults from the domain.\n"
"    If no 'domain' is given - read all defaults from all domains.\n\n");
	  printf(
"defaults readkey key\n"
"    read the named default from all domains.\n\n");
	  printf(
"defaults write domain key value\n"
"    write 'value' as default 'key' in the specified domain.\n"
"    'value' must be a property list in single quotes.\n\n");
	  printf(
"defaults write domain dictionary\n"
"    write 'dictionary' as a replacement for the specified domain.\n"
"    'dictionary' must be a property list in single quotes.\n\n");
	  printf(
"defaults write\n"
"    reads standard input for defaults in the format produced by\n"
"    'defaults read' and writes them to the database.\n\n");
	  printf(
"defaults delete [ domain [ key] ]\n"
"    remove the specified default(s) from the domain.\n"
"    If no 'key' is given - delete the entire domain.\n\n");
	  printf(
"defaults delete\n"
"    read standard input for a series of lines containing pairs of domains\n"
"    and keys for defaults to be deleted.\n\n");
	  printf(
"defaults domains\n"
"    lists the domains in the database (one per line)\n\n");
	  printf(
"defaults find word\n"
"    searches domain names, default names, and default value strings for\n"
"    those equal to the specified word and lists them on standard output.\n\n");
	  printf(
"defaults plist\n"
"    output some information about property lists\n\n");
	  printf(
"defaults help\n"
"    list options fo the defaults command.\n\n");
	  [pool release];
	  exit(0);
	}
      else if ([[args objectAtIndex: i] isEqual: @"plist"])
	{
	  printf(
"A property list is a method of providing structured information consisting\n"
"of strings, arrays, dictionaries, and binary data.\n\n"
"The defaults system allows you to work with a human-readable form of a\n"
"property list which is set as the value of a default.\n\n");
	  printf(
"In a property list, strings appear as plain text (as long as they contain\n"
"no special characters), and inside quotation marks otherwise.\n"
"Special characters inside a quoted string are 'escaped' by a backslash.\n"
"This escape mechanism is used to permit the double quote mark to appear\n"
"inside a quoted string.\n"
"Unicode characters are represented as four digit hexadecimal numbers\n"
"prefixed by \\U\n"
"Arrays appear as a comma separated list of items delimited by brackets.\n"
"Dictionaries appear as a series of key-value pairs, each pair is followed\n"
"by a semicolon and the whole dictionary is delimited by curly brackets.\n"
"Data is encoded as hexadecimal digits delimited by angle brackets.\n\n");
	  printf(
"In output from 'defaults read' the defaults values are represented as\n"
"property lists enclosed in single quotes.  If a value actually contains\n"
"a string with a single quite mark in it, that quote is repeated.\n"
"Similarly, if 'defaults write' is reading a defaults value from stdin\n"
"it expects to receive the value in single quotes with any internal\n"
"single quote marks repeated.\n\n");
	  printf(
"Here is an example of a dictionary encoded as a text property list -\n\n");
	  printf(
"{\n"
"    Name = \"My Application\";\n"
"    Author = \"Just me and \\\"my other half\\\"\";\n"
"    Modules = (\n"
"	Main,\n"
"	\"'Input output'\",\n"
"	Computation\n"
"    );\n"
"    Checksum = <01014b5b 123a8b20>\n"
"}\n\n");
	  printf(
"And as output from the command 'defaults read foo bar' -\n\n");
	  printf(
"foo bar '{\n"
"    Name = \"My Application\";\n"
"    Author = \"Just me and \\\"my other half\\\"\";\n"
"    Modules = (\n"
"	Main,\n"
"	\"''Input output''\",\n"
"	Computation\n"
"    );\n"
"    Checksum = <01014b5b 123a8b20>\n"
"}'\n\n");
	  [pool release];
	  exit(0);
	}
    }

  i = 1;
  if ([args count] <= i)
    {
      NSLog(@"defaults: too few arguments supplied!\n");
      [pool release];
      exit(0);
    }
  if ([[args objectAtIndex: i] isEqual: @"-u"])
    {
      if ([args count] > ++i)
	{
	  user = [args objectAtIndex: i++];
	}
      else
	{
	  NSLog(@"defaults: no name supplied for -u option!\n");
	  [pool release];
	  exit(0);
	}
    }
  if (user)
    {
      GSSetUserName(user);
      defs = [[NSUserDefaults alloc] initWithUser: user];
    }
  else
    {
      defs = [NSUserDefaults standardUserDefaults];
    }
  if (defs == nil)
    {
      NSLog(@"defaults: unable to access defaults database!\n");
      [pool release];
      exit(0);
    }
  /* We don't want this tool in the defaults database - so remove it. */
  [defs removePersistentDomainForName: [proc processName]];

  if ([args count] <= i)
    {
      NSLog(@"defaults: too few arguments supplied!\n");
      [pool release];
      exit(0);
    }

  if ([[args objectAtIndex: i] isEqual: @"read"] ||
      [[args objectAtIndex: i] isEqual: @"readkey"])
    {
      NSDictionary	*locale = [defs dictionaryRepresentation];

      if ([[args objectAtIndex: i] isEqual: @"read"])
	{
	  if ([args count] == ++i)
	    {
	      name = nil;
	      owner = nil;
	    }
	  else
	    {
	      owner = [args objectAtIndex: i++];
	      if ([args count] > i)
		{
		  name = [args objectAtIndex: i];
		}
	    }
	}
      else
	{
	  if ([args count] == ++i)
	    {
	      NSLog(@"defaults: too few arguments supplied!\n");
	      [pool release];
	      exit(0);
	    }
	  owner = nil;
	  name = [args objectAtIndex: i];
	}

      domains = [defs persistentDomainNames];
      for (i = 0; i < [domains count]; i++)
	{
	  NSString	*domainName = [domains objectAtIndex: i];

	  if (owner == nil || [owner isEqual: domainName])
	    {
	      NSDictionary	*dom;

	      dom = [defs persistentDomainForName: domainName];
	      if (dom)
		{
		  if (name == nil)
		    {
		      NSEnumerator	*enumerator;
		      NSString		*key;

		      enumerator = [dom keyEnumerator];
		      while ((key = [enumerator nextObject]) != nil)
			{
			  id		obj = [dom objectForKey: key];
			  const char	*ptr;

			  printf("%s %s '",
				[domainName cString], [key cString]);
			  ptr = [[obj descriptionWithLocale: locale indent: 0]
			    cString];
			  while (*ptr)
			    {
			      if (*ptr == '\'')
				{
				  putchar('\'');
				}
			      putchar(*ptr);
			      ptr++;
			    }
			  printf("'\n");
			}
		    }
		  else
		    {
		      id	obj = [dom objectForKey: name];

		      if (obj)
			{
			  const char      *ptr;

			  printf("%s %s '",
				[domainName cString], [name cString]);
			  ptr = [[obj descriptionWithLocale: locale indent: 0]
			    cString];
			  while (*ptr)
			    {
			      if (*ptr == '\'')
				{
				  putchar('\'');
				}
			      putchar(*ptr);
			      ptr++;
			    }
			  printf("'\n");
			  found = YES;
			}
		    }
		}
	    }
	}

      if (found == NO && name != nil)
	{
	  printf("defaults read: couldn't read default\n");
	}
    }
  else if ([[args objectAtIndex: i] isEqual: @"write"])
    {
      id	obj;

      if ([args count] == ++i)
	{
	  int	size = BUFSIZ;
	  char	*buf = objc_malloc(size);

	  /*
	   *	Read from stdin - grow buffer as necessary since defaults
	   *	values are quoted property lists which may be huge.
	   */
	  while (fgets(buf, BUFSIZ, stdin) != 0)
	    {
	      char	*ptr;
	      char	*start;
	      char	*str;

	      start = buf;

	      /*
	       *	Expect domain name as a space delimited string.
	       */
	      ptr = start;
	      while (*ptr && !isspace(*ptr))
		{
		  ptr++;
		}
	      if (*ptr)
		{
		  *ptr++ = '\0';
		}
	      while (isspace(*ptr))
		{
		  ptr++;
		}
	      if (*start == '\0')
		{
		  printf("defaults write: invalid input - nul domain name\n");
		  [pool release];
		  exit(0);
		}
	      for (str = start; *str; str++)
		{
		  if (isspace(*str))
		    {
		      printf("defaults write: invalid input - "
				"space in domain name.\n");
		      [pool release];
		      exit(0);
		    }
		}
	      owner = [NSString stringWithCString: start];
	      start = ptr;

	      /*
	       *	Expect defaults key as a space delimited string.
	       */
	      ptr = start;
	      while (*ptr && !isspace(*ptr))
		{
		  ptr++;
		}
	      if (*ptr)
		{
		  *ptr++ = '\0';
		}
	      while (isspace(*ptr))
		{
		  ptr++;
		}
	      if (*start == '\0')
		{
		  printf("defaults write: invalid input - "
			"nul default name.\n");
		  [pool release];
		  exit(0);
		}
	      for (str = start; *str; str++)
		{
		  if (isspace(*str))
		    {
		      printf("defaults write: invalid input - "
				"space in default name.\n");
		      [pool release];
		      exit(0);
		    }
		}
	      name = [NSString stringWithCString: start];

	      /*
	       *	Expect defaults value as a quoted property list which
	       *	may cover multiple lines.
	       */
	      start = ptr;
	      if (*start == '\'')
		{
		  for (ptr = ++start; ; ptr++)
		    {
		      if (*ptr == '\0')
			{
			  int	pos = ptr - buf;

			  if (size - pos < BUFSIZ)
			    {
			      char	*tmp;
			      int	spos = start - buf;

			      tmp = objc_realloc(buf, size + BUFSIZ);
			      if (tmp)
				{
				  size += BUFSIZ;
				  buf = tmp;
				  ptr = &buf[pos];
				  start = &buf[spos];
				}
			      else
				{
				  printf("defaults write: fatal error - "
					    "out of memory.\n");
				  [pool release];
				  exit(0);
				}
			    }
			  if (fgets(ptr, BUFSIZ, stdin) == 0)
			    {
			      printf("defaults write: invalid input - "
					"no final quote.\n");
			      [pool release];
			      exit(0);
			    }
			}
		      if (*ptr == '\'')
			{
			  if (ptr[1] == '\'')
			    {
			      strcpy(ptr, &ptr[1]);
			    }
			  else
			    {
			      break;
			    }
			}
		    }
		}
	      else
		{
		  ptr = start;
		  while (*ptr && !isspace(*ptr))
		    {
		      ptr++;
		    }
		}
	      if (*ptr)
		{
		  *ptr++ = '\0';
		}
	      if (*start == '\0')
		{
		  printf("defaults write: invalid input - "
			    "empty property list\n");
		  [pool release];
		  exit(0);
		}

	      /*
	       *	Convert read property list from C string format to
	       *	an NSString or a structured property list.
	       */
	      obj = [NSString stringWithCString: start];
	      if (*start == '(' || *start == '{' || *start == '<')
		{
		  id	tmp = [obj propertyList];

		  if (tmp == nil)
		    {
		      printf("defaults write: invalid input - "
				    "bad property list\n");
		      [pool release];
		      exit(0);
		    }
		  else
		    {
		      obj = tmp;
		    }
		}

	      domain = [[defs persistentDomainForName: owner] mutableCopy];
	      if (domain == nil)
		{
		  domain = [NSMutableDictionary dictionaryWithCapacity:1];
		}
	      [domain setObject: obj forKey: name];
	      [defs setPersistentDomain: domain forName: owner];
	    }
	}
      else
	{
	  owner = [args objectAtIndex: i++];
	  if ([args count] <= i)
	    {
	      NSLog(@"defaults: no dictionary or key for write!\n");
	      [pool release];
	      exit(0);
	    }
	  name = [args objectAtIndex: i++];
	  if ([args count] > i)
	    {
	      const char	*ptr;

	      value = [args objectAtIndex: i];
	      ptr = [value cString];

	      if (*ptr == '(' || *ptr == '{' || *ptr == '<')
		{
		  obj = [value propertyList];

		  if (obj == nil)
		    {
		      printf("defaults write: invalid input - "
				    "bad property list\n");
		      [pool release];
		      exit(0);
		    }
		}
	      else
		{
		  obj = value;
		}

	      domain = [[defs persistentDomainForName: owner] mutableCopy];
	      if (domain == nil)
		{
		  domain = [NSMutableDictionary dictionaryWithCapacity:1];
		}
	      [domain setObject: obj forKey: name];
	      [defs setPersistentDomain: domain forName: owner];
	    }
	  else
	    {
	      domain = [name propertyList];
	      if (domain == nil ||
			[domain isKindOfClass: [NSDictionary class]] == NO)
		{
		  NSLog(@"defaults write: domain is not a dictionary!\n");
		  [pool release];
		  exit(0);
		}
	    }
	}

      if ([defs synchronize] == NO)
	{
	  NSLog(@"defaults: unable to write to defaults database - %s\n",
		strerror(errno));
	}
    }
  else if ([[args objectAtIndex: i] isEqual: @"delete"])
    {
      if ([args count] == ++i)
	{
	  char	buf[BUFSIZ];

	  while (fgets(buf, sizeof(buf), stdin) != 0)
	    {
	      char	*ptr;
	      char	*start;

	      start = buf;
	      ptr = start;
	      while (*ptr && !isspace(*ptr))
		{
		  ptr++;
		}
	      if (*ptr)
		{
		  *ptr++ = '\0';
		}
	      while (isspace(*ptr))
		{
		  ptr++;
		}
	      if (*start == '\0')
		{
		  printf("defaults delete: invalid input\n");
		  [pool release];
		  exit(0);
		}
	      owner = [NSString stringWithCString: start];
	      start = ptr;
	      ptr = start;
	      while (*ptr && !isspace(*ptr))
		{
		  ptr++;
		}
	      if (*ptr)
		{
		  *ptr++ = '\0';
		}
	      while (isspace(*ptr))
		{
		  ptr++;
		}
	      if (*start == '\0')
		{
		  printf("defaults delete: invalid input\n");
		  [pool release];
		  exit(0);
		}
	      name = [NSString stringWithCString: start];
	      domain = [[defs persistentDomainForName: owner] mutableCopy];
	      if (domain == nil || [domain objectForKey: name] == nil)
		{
		  printf("defaults delete: couldn't remove %s owned by %s\n",
			[name cString], [owner cString]);
		}
	      else
		{
		  [domain removeObjectForKey: name];
		  [defs setPersistentDomain: domain forName: owner];
		}
	    }
	}
      else
	{
	  owner = [args objectAtIndex: i++];
	  if ([args count] > i)
	    {
	      name = [args objectAtIndex: i];
	    }
	  else
	    {
	      name = nil;
	    }
	  if (name)
	    {
	      domain = [[defs persistentDomainForName: owner] mutableCopy];
	      if (domain == nil || [domain objectForKey: name] == nil)
		{
		  printf("dremove: couldn't remove %s owned by %s\n",
			[name cString], [owner cString]);
		}
	      else
		{
		  [domain removeObjectForKey: name];
		  [defs setPersistentDomain: domain forName: owner];
		}
	    }
	  else
	    {
	      [defs removePersistentDomainForName: owner];
	    }
	}
      if ([defs synchronize] == NO)
	{
	  NSLog(@"defaults: unable to write to defaults database - %s\n",
		strerror(errno));
	}
    }
  else if ([[args objectAtIndex: i] isEqual: @"domains"])
    {
      domains = [defs persistentDomainNames];
      for (i = 0; i < [domains count]; i++)
	{
	  NSString	*domainName = [domains objectAtIndex: i];

	  printf("%s\n", [domainName cString]);
	}
    }
  else if ([[args objectAtIndex: i] isEqual: @"find"])
    {
      if ([args count] == ++i)
	{
	  NSLog(@"defaults: no arguments for find!\n");
	  [pool release];
	  exit(0);
	}
      name = [args objectAtIndex: i];

      domains = [defs persistentDomainNames];
      for (i = 0; i < [domains count]; i++)
	{
	  NSString	*domainName = [domains objectAtIndex: i];
	  NSDictionary	*dom;

	  if ([domainName isEqual: name])
	    {
	      printf("%s\n", [domainName cString]);
	      found = YES;
	    }

	  dom = [defs persistentDomainForName: domainName];
	  if (dom)
	    {
	      NSEnumerator	*enumerator;
	      NSString		*key;

	      enumerator = [dom keyEnumerator];
	      while ((key = [enumerator nextObject]) != nil)
		{
		  id	obj = [dom objectForKey: key];

		  if ([key isEqual: name])
		    {
		      printf("%s %s\n", [domainName cString], [key cString]);
		      found = YES;
		    }
		  if ([obj isKindOfClass: [NSString class]])
		    {
		      if ([obj isEqual: name])
			{
			  printf("%s %s %s\n",
				[domainName cString],
				[key cString],
				[obj cString]);
			  found = YES;
			}
		    }
		}
	    }
	}

      if (found == NO)
	{
	  printf("defaults find: couldn't find value\n");
	}
    }
  else
    {
      NSLog(@"defaults: unknown option supplied!\n");
    }

  [pool release];
  exit(0);
}

