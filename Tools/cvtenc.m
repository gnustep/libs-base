/** This tool converts a file containing a string to a C String encoding.
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
   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

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
#import "GNUstepBase/NSString+GNUstepBase.h"
#import "GNUstepBase/GSMime.h"
#ifdef NeXT_Foundation_LIBRARY
#include "GNUstepBase/GSCategories.h"
#endif

#include	<ctype.h>

/** Return whether value ch between min and max. */
#define inrange(ch,min,max) ((ch)>=(min) && (ch)<=(max))
/** Convert hex digit in ascii to decimal equivalent. */
#define char2num(ch) \
inrange(ch,'0','9') \
? ((ch)-0x30) \
: (inrange(ch,'a','f') \
? ((ch)-0x57) : ((ch)-0x37))


/** <p>Converts  a file encoded in a specified or default non-unicode encoding
 *  to unicode, or, if the file is already in unicode,  converts  it  to  a
 *  specified  or  default  non-unicode  encoding.   The  converted text is
 *  printed to standard out.</p>
 */
int
main(int argc, char** argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo		*proc;
  NSArray		*args;
  unsigned		i;
  BOOL			found = NO;
  BOOL			eIn;
  BOOL			eOut;
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
      exit(EXIT_SUCCESS);
    }

  args = [proc arguments];

  eIn = [[NSUserDefaults standardUserDefaults] boolForKey: @"EscapeIn"];
  eOut = [[NSUserDefaults standardUserDefaults] boolForKey: @"EscapeOut"];
  n = [[NSUserDefaults standardUserDefaults] stringForKey: @"Encoding"];
  if (n == nil)
    {
      enc = [NSString defaultCStringEncoding];
    }
  else if (0 == (enc = [GSMimeDocument encodingFromCharset: n]))
    {
      const NSStringEncoding	*e;
      NSMutableString	*names;

      names = [NSMutableString stringWithCapacity: 1024];
      e = [NSString availableStringEncodings];
      while (*e != 0)
	{
	  NSString	*name = [NSString localizedNameOfStringEncoding: *e];

	  [names appendFormat: @"  '%@'\n", name];
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
	    @"Localised encoding names are -\n%@", n, names);
	  [pool release];
	  exit(EXIT_SUCCESS);
	}
    }

  n = [[NSUserDefaults standardUserDefaults] stringForKey: @"Unicode"];
  n = [[n stringByTrimmingSpaces] lowercaseString];
  if ([n length] > 0)
    {
      if ([n isEqual: @"in"] || [n isEqual: @"i"])
	{
	  n = @"i";
	}
      else if ([n isEqual: @"out"] || [n isEqual: @"o"])
	{
	  n = @"o";
	}
      else
	{
	  n = nil;
	}
    }
  else
    {
      n = nil;
    }

  for (i = 1; found == NO && i < [args count]; i++)
    {
      NSString	*file = [args objectAtIndex: i];

      if ([file hasPrefix: @"-"] == YES && NO == [file isEqual: @"-"])
	{
	  i++;
	  continue;
	}
      found = YES;
      NS_DURING
	{
	  NSData	*myData;

          if (YES == [file isEqual: @"-"])
	    {
	      myData = [[[NSFileHandle fileHandleWithStandardInput]
		readDataToEndOfFile] retain];
	    }
	  else
	    {
	      myData = [[NSData alloc] initWithContentsOfFile: file];
	    }
	  if (myData == nil)
	    {
	      NSLog(@"File read operation failed for %@.", file);
	    }
	  else
	    {
	      unsigned		l = [myData length];
	      const unichar	*b = (const unichar*)[myData bytes];
	      NSStringEncoding	iEnc;
	      NSStringEncoding	oEnc;
	      NSString		*myString;

	      if (nil == n)
		{
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
		}
	      else if ([n isEqualToString: @"i"])
		{
		  /* Unicode (UTF16) in
		   */
		  iEnc = NSUnicodeStringEncoding;
		  oEnc = enc;
		}
	      else
		{
		  /* Unicode (UTF16) out
		   */
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
		  if (eIn == YES)
		    {
		      unsigned	l = [myString length];
		      unichar	*u;
		      NSZone	*z = NSDefaultMallocZone();
		      unsigned	i = 0;
		      unsigned	o = 0;

		      u = NSZoneMalloc(z, sizeof(unichar)*l);
		      [myString getCharacters: u];

		      while (i < l)
			{
			  unichar	c = u[i++];

			  if (c == '\\' && i <= l - 6)
			    {
			      c = u[i++];

			      if (c == 'u' || c == 'U')
				{
				  unichar	v;

				  v = 0;
				  c = u[i++];
				  v |= char2num(c);

				  v <<= 4;
				  c = u[i++];
				  v |= char2num(c);
				
				  v <<= 4;
				  c = u[i++];
				  v |= char2num(c);
				
				  v <<= 4;
				  c = u[i++];
				  v |= char2num(c);

				  c = v;
				}
			      else
				{
				  u[o++] = '\\';
				}
			    }
			  u[o++] = c;
			}

		      RELEASE(myString);
		      myString = [[NSString alloc] initWithCharactersNoCopy: u
			length: o freeWhenDone: YES];
		    }
		  if (eOut == YES)
		    {
		      unsigned	l = [myString length];
		      unichar	*u;
		      char	*c;
		      NSZone	*z = NSDefaultMallocZone();
		      unsigned	o = 0;
		      unsigned	i;

		      u = NSZoneMalloc(z, sizeof(unichar)*l);
		      c = NSZoneMalloc(z, 6*l);
		      [myString getCharacters: u];
		      for (i = 0; i < l; i++)
			{
			  if (u[i] < 128)
			    {
			      c[o++] = u[i];
			    }
			  else
			    {
			      snprintf(&c[o], 6, "\\U%04x", u[i]);
			      o += 6;
			    }
			}
		      NSZoneFree(z, u);
		      myData = [[[NSData alloc]
			initWithBytesNoCopy: c length: o] autorelease];
		    }
		  else if (eIn == YES)
		    {
		      myData = [myString dataUsingEncoding: iEnc
				      allowLossyConversion: NO];
		    }
		  else
		    {
		      myData = [myString dataUsingEncoding: oEnc
				      allowLossyConversion: NO];
		    }
		  RELEASE(myString);
		  if (myData == nil)
		    {
		      NSLog(@"Encoding output conversion failed for %@.",
			file);
		    }
		  else
		    {
		      NSFileHandle	*out;
		      CREATE_AUTORELEASE_POOL(arp);

		      out = [NSFileHandle fileHandleWithStandardOutput];
		      [out writeData: myData];
		      [out synchronizeFile];
		      RELEASE(arp);
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
	@"to unicode (UTF16) from C-string encoding or vice versa.\n"
	@"You can use '-' as the filename argument to read from STDIN.\n"
	@"You can supply a '-Encoding name' option to specify the C-string\n"
	@"encoding to be used, if you don't want to use the default.\n"
	@"If you supply an unknown encoding the tool will print a list\n"
	@"of all the known encodings.\n"
	@"You can supply a '-EscapeIn YES' option to specify that input\n"
	@"should be parsed for \\U escape sequences (as in property lists).\n"
	@"You can supply a '-EscapeOut YES' option to specify that output\n"
	@"should be ascii with \\U escape sequences (for property lists).\n"
	@"You can supply a '-Unicode in/out' option to specify that the\n"
	@"conversion is from/to unicode (UTF16).  This suppresses the normal\n"
	@"behavior of guessing the direction of conversion from the content\n"
	@"of the incoming data.\n");
    }
  [pool release];
  return 0;
}
