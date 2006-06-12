/** This tool tidies up a load of common formatting errors in objc code.
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: May 2006

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

#include	<Foundation/Foundation.h>


int
main(int argc, char** argv, char **env)
{
  NSAutoreleasePool	*pool;
  NSProcessInfo		*proc;
  NSCharacterSet	*ops;
  NSCharacterSet	*ws;
  NSCharacterSet	*nws;
  NSArray		*args;

#ifdef GS_PASS_ARGUMENTS
  [NSProcessInfo initializeWithArguments:argv count:argc environment:env];
#endif
  pool = [NSAutoreleasePool new];
  proc = [NSProcessInfo processInfo];
  if (proc == nil)
    {
      NSLog(@"pldes: unable to get process information!\n");
      [pool release];
      exit(EXIT_SUCCESS);
    }

  ops = [NSCharacterSet characterSetWithCharactersInString: @"+-*/%^&|=><"];
  ws = [NSCharacterSet whitespaceCharacterSet];
  nws = [ws invertedSet];
  args = [proc arguments];

  if ([args count] <= 1)
    {
      GSPrintf(stderr, @"No file names given to tidy (try --help).\n");
    }
  else if ([args containsObject: @"--help"])
    {
      GSPrintf(stderr,
@"\nThis is a program to make a rough attempt at tidying up code which was\n"
@"written in a coding style radically different from the GNUstep standard.\n"
@"\nIt is a STUPID program using simple rules to try and do the main work\n"
@"of making such code readably by GNUstep developers/users, and because\n"
@"it doesn't even distinguish beteen code, comments, and string literals,\n"
@"it is highly likely to break any complex code ... so you MUST review\n"
@"it's output, comprehend the code, and fix it.\n"
@"\nThe aim of the tool is simply to do the initial work for you so that you\n"
@"don't have to waste a lot of time getting code to a state where you can\n"
@"read it.\n"
@"\nThe program expects, as arguments,  a list of filenames to 'tidy' and it\n"
@"writes its output to files of the same names with a '.tidied' extension.\n"
@"\n"
);
    }
  else
    {
      unsigned	i;

      for (i = 1; i < [args count]; i++)
	{
	  NSString		*fileName = [args objectAtIndex: i];
	  NSString		*result;
	  NSString		*file;
	  NSMutableArray	*lines;
	  unsigned		numberOfLines;
	  unsigned		indentation = 0;
	  BOOL			tempIndent = NO;
	  NSRange		r;
	  unsigned		j;
	  unsigned		l;

	  result = [fileName stringByAppendingString: @".tidied"];
	  file = [NSString stringWithContentsOfFile: fileName];
	  lines = [[file componentsSeparatedByString: @"\n"] mutableCopy];

	  numberOfLines = [lines count];
	  for (j = 0; j < numberOfLines; j++)
	    {
	      NSMutableString	*line = [[lines objectAtIndex: j] mutableCopy];
	      unsigned		pos;

	      /* Some code uses a tab character for indentation when
	       * it should actually be two spaces.
	       */
	      [line replaceString: @"\t" withString: @"  "];

	      /* some code leaves out white space around operators,
	       * so we try to reinstate it.
	       */
	      [line replaceString: @"=" withString: @" = "];
	      [line replaceString: @"+" withString: @" + "];
	      [line replaceString: @"-" withString: @" - "];
	      [line replaceString: @"/" withString: @" / "];
	      [line replaceString: @"|" withString: @" | "];
	      [line replaceString: @"&" withString: @" & "];
	      [line replaceString: @"<" withString: @" < "];
	      [line replaceString: @">" withString: @" > "];
	      [line replaceString: @"!" withString: @" ! "];
	      [line replaceString: @"^" withString: @" ^ "];
	      [line replaceString: @"~" withString: @" ~ "];
	      [line replaceString: @"," withString: @", "];
	      [line replaceString: @")" withString: @") "];
	      [line trimSpaces];


	      /* Some code has excess whitespace .. compress it.
	       */
	      l = [line length];
	      r = NSMakeRange(0, l);
	      while ((r = [line rangeOfString: @"  "
				      options: NSLiteralSearch
					range: r]).length > 0)
		{
		  [line replaceCharactersInRange: r withString: @" "];
		  l--;
		  r = NSMakeRange(r.location, l - r.location);
		}

	      /* Now repair any excess space round operators.
	       */
	      [line replaceString: @"+ +" withString: @"++"];
	      [line replaceString: @"+ =" withString: @"+="];
	      [line replaceString: @"- -" withString: @"--"];
	      [line replaceString: @"- =" withString: @"-="];
	      [line replaceString: @"/ /" withString: @"//"];
	      [line replaceString: @"/ =" withString: @"/="];
	      [line replaceString: @"| |" withString: @"||"];
	      [line replaceString: @"| =" withString: @"|="];
	      [line replaceString: @"& &" withString: @"&&"];
	      [line replaceString: @"& =" withString: @"&="];
	      [line replaceString: @"< <" withString: @"<<"];
	      [line replaceString: @"< =" withString: @"<="];
	      [line replaceString: @"> >" withString: @">>"];
	      [line replaceString: @"> =" withString: @">="];
	      [line replaceString: @"/ =" withString: @"/="];
	      [line replaceString: @"% =" withString: @"%="];
	      [line replaceString: @"~ =" withString: @"~="];
	      [line replaceString: @"^ =" withString: @"^="];
	      [line replaceString: @"| =" withString: @"|="];
	      [line replaceString: @"& =" withString: @"&="];
	      [line replaceString: @"! =" withString: @"!="];
	      [line replaceString: @"- >" withString: @"->"];
	      [line replaceString: @"-> " withString: @"->"];
	      [line replaceString: @" ->" withString: @"->"];
	      [line replaceString: @" ," withString: @","];
	      [line replaceString: @"! " withString: @"!"];

	      /* some code omits space between keywords and brackets
	       */
	      [line replaceString: @"if(" withString: @"if ("];
	      [line replaceString: @"for(" withString: @"for ("];
	      [line replaceString: @"while(" withString: @"while ("];

	      /* some code puts bogus space in around brackets
	       */
	      [line replaceString: @"( " withString: @"("];
	      [line replaceString: @" )" withString: @")"];
	      [line replaceString: @"[ " withString: @"["];
	      [line replaceString: @" ]" withString: @"]"];
	      [line replaceString: @"{ " withString: @"{"];
	      [line replaceString: @" }" withString: @"}"];

	      /* some code has no space between colon and method arg
	       */
	      [line replaceString: @":" withString: @": "];
	      [line replaceString: @":  " withString: @": "];
	   
	      /* sometimes braces are used oddly to put a load of stuff
	       * on one line rather than laying it out nicely.
	       * We split such lines apart.
	       */
	      r = [line rangeOfString: @"{"];
	      if (r.length > 0 && r.location > indentation)
		{
		  NSMutableString	*s;

		  s = [[line substringFromIndex: r.location] mutableCopy];
		  r = NSMakeRange(r.location, [line length] - r.location);
		  [line replaceCharactersInRange: r withString: @""];
		  [line trimTailSpaces];
		  [s trimSpaces];
		  [lines insertObject: s atIndex: j + 1];
		  numberOfLines++;
		}

	      r = [line rangeOfString: @"{"];
	      if (r.length > 0 && NSMaxRange(r) < [line length])
		{
		  NSMutableString	*s;

		  s = [[line substringFromIndex: NSMaxRange(r)] mutableCopy];
		  r = NSMakeRange(NSMaxRange(r), [line length] - NSMaxRange(r));
		  [line replaceCharactersInRange: r withString: @""];
		  [s trimSpaces];
		  [lines insertObject: s atIndex: j + 1];
		  numberOfLines++;
		}

	      r = [line rangeOfString: @"}"];
	      if (r.length > 0 && r.location > indentation)
		{
		  NSMutableString	*s;

		  s = [[line substringFromIndex: r.location] mutableCopy];
		  r = NSMakeRange(r.location, [line length] - r.location);
		  [line replaceCharactersInRange: r withString: @""];
		  [line trimTailSpaces];
		  [s trimSpaces];
		  [lines insertObject: s atIndex: j + 1];
		  numberOfLines++;
		}

	      /* some code has a bogus semicolon in a method implementation
	       */
	      if (indentation == 0 && j < numberOfLines - 1
		&& ([line hasPrefix: @"-"] || [line hasPrefix: @"+"])
		&& [line hasSuffix: @";"]
		&& ([[[lines objectAtIndex: j+1] stringByTrimmingSpaces]
		  hasPrefix: @"{"]))
		{
		  r = NSMakeRange([line length] - 1, 1);
		  [line replaceCharactersInRange: r withString: @""];
		  [line trimTailSpaces];
		}

	      pos = indentation;
	      if ([line isEqualToString: @"{"])
		{
		  if (indentation == 0)
		    {
		      pos = 0;
		      indentation = 2;
		    }
		  else
		    {
		      pos = indentation + 2;
		      indentation += 4;
		    }
		}
	      else if ([line isEqualToString: @"}"])
		{
		  if (indentation >= 2)
		    {
		      pos = indentation - 2;
		      if (indentation >= 4)
			{
			  indentation -= 4;
			}
		      else
			{
			  indentation = 0;
			}
		    }
		  else
		    {
		      pos = 0;
		      indentation = 0;
		    }
		}
	      else
		{
		  pos = indentation;
		}
	      if (tempIndent == YES)
		{
		  pos += 2;
		}
	      tempIndent = NO;

	      if ((pos < 80) && ([line length] + pos >= 80))
		{
		  unsigned	off = 80 - pos;

		  /*
		   * Look for a break in a method call/name
		   */
		  r = [line rangeOfString: @": "
				  options: NSBackwardsSearch
				    range: NSMakeRange(0, off)];
		  if (r.length == 0)
		    {
		      /*
		       * Look for a comma in a function call/name
		       */
		      r = [line rangeOfString: @": "
				      options: NSBackwardsSearch
					range: NSMakeRange(0, off)];
		    }
		  if (r.length == 0)
		    {
		      /*
		       * Look for an operator.
		       */
		      while (off > 0
			&& ![ops characterIsMember:
			[line characterAtIndex: off]])
			{
			  off--;
			}
		      while (off > 0
			&& [ops characterIsMember:
			[line characterAtIndex: off]])
			{
			  off--;
			}
		      if (off > 0
			&& ![ops characterIsMember:
			[line characterAtIndex: off]])
			{
			  tempIndent = YES;
			}
		    }
		  else
		    {
		      off = r.location;
		      tempIndent = YES;
		    }

		  if (tempIndent == YES)
		    {
		      NSMutableString	*s;

		      off++;
		      s = [[line substringFromIndex: off] mutableCopy];
		      r = NSMakeRange(off, [line length] - off);
		      [line replaceCharactersInRange: r withString: @""];
		      [line trimTailSpaces];
		      [s trimSpaces];
		      [lines insertObject: s atIndex: j + 1];
		      numberOfLines++;
		    }
		}

	      if ([line hasPrefix: @"#"])
	        {
		  [line replaceString: @"#import" withString: @"#include"];
		  if ([line hasPrefix: @"#include"])
		    {
		      [line replaceString: @"< " withString: @"<"];
		      [line replaceString: @" >" withString: @">"];
		      [line replaceString: @"> " withString: @">"];
		      [line replaceString: @" / " withString: @"/"];
		    }
		}
	      else
	        {
		  /* repair indentation
		   */
		  while (pos-- > 0)
		    {
		      [line replaceCharactersInRange: NSMakeRange(0, 0)
					  withString: @" "];
		    }
		}

	      [lines replaceObjectAtIndex: j withObject: line];
	      if ([line length] > 80)
		{
		  GSPrintf(stderr, @"%@: line %u is too long.\n",
		    result, j + 1);
		}
	
	      /* Must have a blank line after a function/method end.
	       */
	      if (indentation == 0 && j > 0 && [line length] > 0
		&& [[lines objectAtIndex: j - 1] isEqualToString: @"}"])
		{
		  [lines insertObject: @"" atIndex: j];
		  numberOfLines++;
		  j++;
		}
	      RELEASE(line);
	    }

	  file = [lines componentsJoinedByString: @"\n"];
	  RELEASE(lines);
	  [file writeToFile: result atomically: NO];
	}
    }
  [pool release];
  return 0;
}
