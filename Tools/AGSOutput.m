/**

   <title>AGSOutput ... a class to output gsdoc source</title>
   Copyright (C) <copy>2001 Free Software Foundation, Inc.</copy>

   <author name="Richard Frith-Macdonald"></author><richard@brainstorm.co.uk>
   Created: October 2001

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

#include "AGSOutput.h"

static BOOL snuggleEnd(NSString *t)
{
  static NSCharacterSet	*set = nil;

  if ([t hasPrefix: @"</"] == YES)
    {
      return YES;
    }
  if (set == nil)
    {
      set = [NSCharacterSet characterSetWithCharactersInString: @"]}).,;?!"];
      RETAIN(set);
    }
  return [set characterIsMember: [t characterAtIndex: 0]];
}

static BOOL snuggleStart(NSString *t)
{
  static NSCharacterSet	*set = nil;

  if (set == nil)
    {
      set = [NSCharacterSet characterSetWithCharactersInString: @"[{("];
      RETAIN(set);
    }
  return [set characterIsMember: [t characterAtIndex: [t length] - 1]];
}


@implementation	AGSOutput

- (void) dealloc
{
  DESTROY(identifier);
  DESTROY(identStart);
  DESTROY(spaces);
  DESTROY(spacenl);
  [super dealloc];
}

- (unsigned) fitWords: (NSArray*)a
		 from: (unsigned)start
		   to: (unsigned)end
	      maxSize: (unsigned)limit
	       output: (NSMutableString*)buf
{
  unsigned	size = 0;
  unsigned	nest = 0;
  unsigned	i;
  int		lastOk = -1;
  BOOL		addSpace = NO;

  for (i = start; size < limit && i < end; i++)
    {
      NSString	*t = [a objectAtIndex: i];

      if (nest == 0 && [t hasPrefix: @"</"] == YES)
	{
	  break;	// End of element reached.
	}

      /*
       * Check sizing and output this word if necessary.
       */
      if (addSpace == YES && snuggleEnd(t) == NO)
	{
	  size++;
	  if (buf != nil)
	    {
	      [buf appendString: @" "];
	    }
	}
      size += [t length];
      if (buf != nil)
	{
	  [buf appendString: t];
	}

      /*
       * Determine nesting level changes produced by this word, and
       * whether we need a space before the next word.
       */
      if ([t hasPrefix: @"</"] == YES)
	{
	  nest--;
	  addSpace = YES;
	}
      else if ([t hasPrefix: @"<"] == YES)
	{
	  if ([t hasSuffix: @"/>"] == YES)
	    {
	      addSpace = YES;
	    }
	  else
	    {
	      nest++;
	      addSpace = NO;
	    }
	}
      else
	{
	  if (snuggleStart(t) == NO)
	    {
	      addSpace = YES;
	    }
	  else
	    {
	      addSpace = NO;
	    }
	}

      /*
       * Record whether the word we just checked was at nesting level 0
       * and had not exceeded the line length limit.
       */
      if (nest == 0 && size <= limit)
	{
	  lastOk = i;
	}
    }
  return lastOk + 1;
}

- (id) init
{
  NSMutableCharacterSet	*m;

  m = [[NSCharacterSet controlCharacterSet] mutableCopy];
  [m addCharactersInString: @" "];
  spacenl = [m copy];
  [m removeCharactersInString: @"\n"];
  spaces = [m copy];
  RELEASE(m);
  identifier = RETAIN([NSCharacterSet characterSetWithCharactersInString:
    @"_0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"]);
  identStart = RETAIN([NSCharacterSet characterSetWithCharactersInString:
    @"_abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"]);

  return self;
}

- (NSString*) output: (NSDictionary*)d
{
  NSMutableString	*str = [NSMutableString stringWithCapacity: 10240];
  NSDictionary		*classes;
  NSDictionary		*categories;
  NSDictionary		*protocols;
  NSArray		*authors;
  NSString		*tmp;

  info = d;

  classes = [info objectForKey: @"Classes"];
  categories = [info objectForKey: @"Categories"];
  protocols = [info objectForKey: @"Protocols"];

  [str appendString: @"<?xml version=\"1.0\"?>\n"];
  [str appendString: @"<!DOCTYPE gsdoc PUBLIC "];
  [str appendString: @"\"-//GNUstep//DTD gsdoc 0.6.6//EN\" "];
  [str appendString: @"\"http://www.gnustep.org/gsdoc-0_6_6.xml\">\n"];
  [str appendFormat: @"<gsdoc"];

  tmp = [info objectForKey: @"Base"];
  if (tmp != nil)
    {
      [str appendString: @" base=\""];
      [str appendString: tmp];
    }

  tmp = [info objectForKey: @"Next"];
  if (tmp != nil)
    {
      [str appendString: @" next=\""];
      [str appendString: tmp];
    }

  tmp = [info objectForKey: @"Prev"];
  if (tmp != nil)
    {
      [str appendString: @" prev=\""];
      [str appendString: tmp];
    }

  tmp = [info objectForKey: @"Up"];
  if (tmp != nil)
    {
      [str appendString: @" up=\""];
      [str appendString: tmp];
    }

  [str appendString: @">\n"];
  [str appendString: @"  <head>\n"];

  /*
   * A title is mandatory in the head element ... obtain it
   * from the info dictionary.  Guess at a title if necessary.
   */
  tmp = [info objectForKey: @"title"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 4 to: str];
    }
  else
    {
      [str appendString: @"    <title>"];
      if ([classes count] == 1)
	{
	  [str appendString: [[classes allKeys] lastObject]];
	  [str appendString: @" class documentation"];
	}
      else
	{
	  [str appendString: @"Automatically generated documentation"];
	}
      [str appendString: @"</title>\n"];
    }

  /*
   * The author element is compulsory ... fill in.
   */
  authors = [info objectForKey: @"authors"];
  if (authors == nil)
    {
      tmp = [NSString stringWithFormat: @"Generated by %@", NSUserName()];
      [str appendString: @"    <author name=\""];
      [str appendString: tmp];
      [str appendString: @"\"></author>\n"];
    }
  else
    {
      unsigned	i;

      for (i = 0; i < [authors count]; i++)
	{
	  NSString	*author = [authors objectAtIndex: i];

	  [self reformat: author withIndent: 4 to: str];
	}
    }
  
  /*
   * The version element is optional ... fill in if available.
   */
  tmp = [info objectForKey: @"version"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 4 to: str];
    }
  
  /*
   * The date element is optional ... fill in if available.
   */
  tmp = [info objectForKey: @"date"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 4 to: str];
    }
  
  /*
   * The abstract element is optional ... fill in if available.
   */
  tmp = [info objectForKey: @"abstract"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 4 to: str];
    }
  
  /*
   * The copy element is optional ... fill in if available.
   */
  tmp = [info objectForKey: @"copy"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 4 to: str];
    }
  
  [str appendString: @"  </head>\n"];
  [str appendString: @"  <body>\n"];

  // Output document forward if available.
  tmp = [info objectForKey: @"front"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 4 to: str];
    }

  // Output document main chapter if available
  tmp = [info objectForKey: @"chapter"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 4 to: str];
    }

  if ([classes count] > 0)
    {
      NSArray	*names;
      unsigned	i;

      names = [classes allKeys];
      names = [names sortedArrayUsingSelector: @selector(compare:)];
      for (i = 0; i < [names count]; i++)
	{
	  NSString	*name = [names objectAtIndex: i];
	  NSDictionary	*d = [classes objectForKey: name];

	  [self outputUnit: d to: str];
	}
    }

  if ([categories count] > 0)
    {
      NSArray	*names;
      unsigned	i;

      names = [categories allKeys];
      names = [names sortedArrayUsingSelector: @selector(compare:)];
      for (i = 0; i < [names count]; i++)
	{
	  NSString	*name = [names objectAtIndex: i];
	  NSDictionary	*d = [categories objectForKey: name];

	  [self outputUnit: d to: str];
	}
    }

  if ([protocols count] > 0)
    {
      NSArray	*names;
      unsigned	i;

      names = [protocols allKeys];
      names = [names sortedArrayUsingSelector: @selector(compare:)];
      for (i = 0; i < [names count]; i++)
	{
	  NSString	*name = [names objectAtIndex: i];
	  NSDictionary	*d = [protocols objectForKey: name];

	  [self outputUnit: d to: str];
	}
    }

  // Output document appendix if available.
  tmp = [info objectForKey: @"back"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 4 to: str];
    }

  [str appendString: @"  </body>\n"];
  [str appendString: @"</gsdoc>\n"];
  return str;
}

- (BOOL) output: (NSDictionary*)d file: (NSString*)name
{
  NSString	*str = [self output: d];

  return [str writeToFile: name atomically: YES];
}

/**
 * Uses -split: and -reformat:withIndent:to:.
 * Also has fun with YES, NO, and nil.
 */
- (void) outputMethod: (NSDictionary*)d to: (NSMutableString*)str
{
  NSArray	*sels = [d objectForKey: @"Sels"];
  NSArray	*types = [d objectForKey: @"Types"];
  NSString	*name = [d objectForKey: @"Name"];
  NSString	*tmp;
  unsigned	i;
  BOOL		isInitialiser = NO;
  NSString	*override = nil;
  NSString	*standards = nil;

  args = [d objectForKey: @"Args"];	// Used when splitting.

  tmp = [d objectForKey: @"Comment"];

  /**
   * Check special markup which should be removed from the text
   * actually placed in the gsdoc method documentation ... the
   * special markup is included in the gsdoc markup differently.
   */ 
  if (tmp != nil)
    {
      NSMutableString	*m = nil;
      NSRange		r;

      do
	{
	  r = [tmp rangeOfString: @"<init>"];
	  if (r.length > 0)
	    {
	      if (m == nil)
		{
		  m = [tmp mutableCopy];
		}
	      [m deleteCharactersInRange: r];
	      tmp = m;
	      isInitialiser = YES;
	    }
	} while (r.length > 0);
      do
	{
	  r = [tmp rangeOfString: @"<override-subclass>"];
	  if (r.length > 0)
	    {
	      if (m == nil)
		{
		  m = [tmp mutableCopy];
		}
	      [m deleteCharactersInRange: r];
	      tmp = m;
	      override = @"subclass";
	    }
	} while (r.length > 0);
      do
	{
	  r = [tmp rangeOfString: @"<override-never>"];
	  if (r.length > 0)
	    {
	      if (m == nil)
		{
		  m = [tmp mutableCopy];
		}
	      [m deleteCharactersInRange: r];
	      tmp = m;
	      override = @"never";
	    }
	} while (r.length > 0);
      r = [tmp rangeOfString: @"<standards>"];
      if (r.length > 0)
	{
	  unsigned  i = r.location;

	  r = NSMakeRange(i, [tmp length] - i);
	  r = [tmp rangeOfString: @"</standards>"
			 options: NSLiteralSearch
			   range: r];
	  if (r.length > 0)
	    {
	      r = NSMakeRange(i, NSMaxRange(r) - i);
	      standards = [tmp substringWithRange: r];
	      if (m == nil)
		{
		  m = [tmp mutableCopy];
		}
	      [m deleteCharactersInRange: r];
	      tmp = m;
	    }
	  else
	    {
	      NSLog(@"unterminated <standards> in comment for %@", name);
	    }
	}
      if (m != nil)
	{
	  RELEASE(m);
	}
    }

  [str appendString: @"        <method type=\""];
  [str appendString: [d objectForKey: @"ReturnType"]];
  if ([name hasPrefix: @"+"] == YES)
    {
      [str appendString: @"\" factory=\"yes"];
    }
  if (isInitialiser == YES)
    {
      [str appendString: @"\" init=\"yes"];
    }
  if (override != nil)
    {
      [str appendString: @"\" override=\""];
      [str appendString: override];
    }
  [str appendString: @"\">\n"];

  for (i = 0; i < [sels count]; i++)
    {
      [str appendString: @"          <sel>"];
      [str appendString: [sels objectAtIndex: i]];
      [str appendString: @"</sel>\n"];
      if (i < [args count])
	{
	  [str appendString: @"          <arg type=\""];
	  [str appendString: [types objectAtIndex: i]];
	  [str appendString: @"\">"];
	  [str appendString: [args objectAtIndex: i]];
	  [str appendString: @"</arg>\n"];
	}
    }

  [str appendString: @"          <desc>\n"];
  tmp = [d objectForKey: @"Comment"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 12 to: str];
    }
  [str appendString: @"          </desc>\n"];
  if (standards != nil)
    {
      [self reformat: standards withIndent: 10 to: str];
    }
  [str appendString: @"        </method>\n"];
  args = nil;
}

- (void) outputUnit: (NSDictionary*)d to: (NSMutableString*)str
{
  NSString	*name = [d objectForKey: @"Name"];
  NSString	*type = [d objectForKey: @"Type"];
  NSDictionary	*methods = [d objectForKey: @"Methods"];
  NSArray	*names;
  NSArray	*protocols;
  NSString	*tmp;
  unsigned	i;

  [str appendString: @"    <chapter>\n"];

  [str appendString: @"      <heading>"];
  [str appendString: @"Software documentation for the "];
  [str appendString: name];
  [str appendString: @" "];
  [str appendString: type];
  [str appendString: @"</heading>\n"];

  [str appendString: @"      <"];
  [str appendString: type];
  [str appendString: @" name=\""];
  if ([type isEqual: @"category"] == YES)
    {
      [str appendString: [d objectForKey: @"Category"]];
    }
  else
    {
      [str appendString: name];
    }
  tmp = [d objectForKey: @"BaseClass"];
  if (tmp != nil)
    {
      if ([type isEqual: @"class"] == YES)
	{
	  [str appendString: @"\" super=\""];
	}
      else if ([type isEqual: @"category"] == YES)
	{
	  [str appendString: @"\" class=\""];
	}
      [str appendString: tmp];
    }
  [str appendString: @"\">\n"];

  [str appendString: @"        <declared>"];
  [str appendString: [d objectForKey: @"Declared"]];
  [str appendString: @"</declared>\n"];

  protocols = [d objectForKey: @"Protocols"];
  if ([protocols count] > 0)
    {
      for (i = 0; i < [protocols count]; i++)
	{
	  [str appendString: @"        <conform>"];
	  [str appendString: [protocols objectAtIndex: i]];
	  [str appendString: @"</conform>\n"];
	}
    }

  [str appendString: @"        <desc>\n"];
  tmp = [d objectForKey: @"Comment"];
  if (tmp != nil)
    {
      [self reformat: tmp withIndent: 10 to: str];
    }
  [str appendString: @"        </desc>\n"];
  
  names = [[methods allKeys] sortedArrayUsingSelector: @selector(compare:)];
  for (i = 0; i < [names count]; i++)
    {
      NSString	*mName = [names objectAtIndex: i];

      [self outputMethod: [methods objectForKey: mName] to: str];
    }

  [str appendString: @"      </"];
  [str appendString: type];
  [str appendString: @">\n"];
  [str appendString: @"    </chapter>\n"];
}

- (void) reformat: (NSString*)str
       withIndent: (unsigned)ind
	       to: (NSMutableString*)buf
{
  CREATE_AUTORELEASE_POOL(arp);
  unsigned	l = [str length];
  NSRange	r = NSMakeRange(0, l);
  unsigned	i = 0;
  NSArray	*a;

  /*
   * Split out <example>...</example> sequences and output them literally.
   * All other text has reformatting applied as necessary.
   */
  r = [str rangeOfString: @"<example"];
  while (r.length > 0)
    {
      NSString	*tmp;

      if (r.location > i)
	{
	  /*
	   * There was some text before the example - call this method
	   * recursively to format and output it.
	   */
	  tmp = [str substringWithRange: NSMakeRange(i, r.location - i)];
	  [self reformat: str withIndent: ind to: buf];
	  i = r.location;
	}
      /*
       * Now find the end of the exmple, and output the whole example
       * literally as it appeared in the comment.
       */
      r = [str rangeOfString: @"</example>"
		     options: NSLiteralSearch
		       range: NSMakeRange(i, l - i)];
      if (r.length == 0)
	{
	  NSLog(@"unterminated <example>");
	  return;
	}
      tmp = [str substringWithRange: NSMakeRange(i, NSMaxRange(r) - i)];
      [buf appendString: tmp];
      [buf appendString: @"\n"];
      /*
       * Set up the start location and search for another example so
       * we will loop round again if necessary.
       */
      i = NSMaxRange(r);
      r = [str rangeOfString: @"<example"
		     options: NSLiteralSearch
		       range: NSMakeRange(i, l - i)];
    }

  /*
   * If part of the string has already been consumed, just use
   * the remaining substring.
   */
  if (i > 0)
    {
      str = [str substringWithRange: NSMakeRange(i, l - i)];
    }

  /*
   * Split the string up into parts separated by newlines.
   */
  a = [self split: str];
  for (i = 0; i < [a count]; i++)
    {
      int	j;

      str = [a objectAtIndex: i];

      if ([str hasPrefix: @"</"] == YES)
	{
	  if (ind > 2)
	    {
	      /*
	       * decrement indentation after the end of an element.
	       */
	      ind -= 2;
	    }
	  for (j = 0; j < ind; j++)
	    {
	      [buf appendString: @" "];
	    }
	  [buf appendString: str];
	  [buf appendString: @"\n"];
	}
      else
	{
	  unsigned	size = 70 - ind - [str length];
	  unsigned	end;

	  for (j = 0; j < ind; j++)
	    {
	      [buf appendString: @" "];
	    }
	  end = [self fitWords: a
			  from: i
			    to: [a count]
		       maxSize: size
			output: nil];
	  if (end <= i)
	    {
	      [buf appendString: str];
	      if ([str hasPrefix: @"<"] == YES && [str hasSuffix: @" />"] == NO)
		{
		  ind += 2;
		}
	    }
	  else
	    {
	      [self fitWords: a
			from: i
			  to: end
		     maxSize: size
		      output: buf];
	      i = end - 1;
	    }
	  [buf appendString: @"\n"];
	}
    }
  RELEASE(arp);
}

- (NSArray*) split: (NSString*)str
{
  NSMutableArray	*a = [NSMutableArray arrayWithCapacity: 128];
  unsigned		l = [str length];
  NSMutableData		*data;
  unichar		*ptr;
  unichar		*end;
  unichar		*buf;

  /**
   * Phase 1 ... we take the supplied string and check for white space.
   * Any white space sequence is deleted and treated as a word separator
   * except within xml element markup.  The format of element start and
   * end marks is tidied for consistency.  The resulting data is made
   * into an array of strings, each containing either an element start
   * or end tag, or one of the whitespace separated words.
   * What about str?
   */
  data = [[NSMutableData alloc] initWithLength: l * sizeof(unichar)];
  ptr = buf = [data mutableBytes];
  [str getCharacters: buf];
  end = buf + l;
  while (ptr < end)
    {
      if ([spacenl characterIsMember: *ptr] == YES)
	{
	  if (ptr != buf)
	    {
	      NSString	*tmp;

	      tmp = [NSString stringWithCharacters: buf length: ptr - buf];
	      [a addObject: tmp];
	      buf = ptr;
	    }
	  ptr++;
	  buf++;
	}
      else if (*ptr == '<')
	{
	  BOOL		elideSpace = YES;
	  unichar	*optr = ptr;

	  if (ptr != buf)
	    {
	      NSString	*tmp;

	      tmp = [NSString stringWithCharacters: buf length: ptr - buf];
	      [a addObject: tmp];
	      buf = ptr;
	    }
	  while (ptr < end && *ptr != '>')
	    {
	      /*
	       * We convert whitespace sequences inside element markup
	       * to single space characters unless protected by quotes.
	       */
	      if ([spacenl characterIsMember: *ptr] == YES)
		{
		  if (elideSpace == NO)
		    {
		      *optr++ = ' ';
		      elideSpace = YES;
		    }
		  ptr++;
		}
	      else if (*ptr == '"')
		{
		  while (ptr < end && *ptr != '"')
		    {
		      *optr++ = *ptr++;
		    }
		  if (ptr < end)
		    {
		      *optr++ = *ptr++;
		    }
		  elideSpace = NO;
		}
	      else
		{
		  /*
		   * We want param=value sequences to be standardised to
		   * not have spaces around the equals sign.
		   */
		  if (*ptr == '=')
		    {
		      elideSpace = YES;
		      if (optr[-1] == ' ')
			{
			  optr--;
			}
		    }
		  else
		    {
		      elideSpace = NO;
		    }
		  *optr++ = *ptr++;
		}
	    }
	  if (*ptr == '>')
	    {
	      /*
	       * remove space immediately before closing bracket.
	       */
	      if (optr[-1] == ' ')
		{
		  optr--;
		}
	      *optr++ = *ptr++;
	    }
	  if (optr != buf)
	    {
	      NSString	*tmp;

	      /*
	       * Ensure that elements with no content ('/>' endings)
	       * are standardised to have a space before their terminators.
	       */
	      if (optr[-2] == '/' && optr[-3] != ' ')
		{
		  unsigned	len = ptr - buf;
		  unichar	c[len + 1];

		  memcpy(c, buf, (len+1)*sizeof(unichar));
		  c[len-2] = ' ';
		  c[len-1] = '/';
		  c[len] = '>';
		  tmp = [NSString stringWithCharacters: c length: len+1];
		}
	      else
		{
		  tmp = [NSString stringWithCharacters: buf length: ptr - buf];
		}
	      [a addObject: tmp];
	    }
	  buf = ptr;
	}
      else
	{
	  ptr++;
	}
    }
  if (ptr != buf)
    {
      NSString	*tmp;

      tmp = [NSString stringWithCharacters: buf length: ptr - buf];
      [a addObject: tmp];
    }

  /*
   * Phase 2 ... the array of words is checked to see if a word contains
   * a well known constant, or a method name specification.
   * Where these special cases apply, the array of words is modified to
   * insert extra gsdoc markup to highlight the constants and to create
   * references to where the named methods are documented.
   */
  for (l = 0; l < [a count]; l++)
    {
      static NSArray	*constants = nil;
      unsigned		count;
      NSString		*tmp = [a objectAtIndex: l];
      unsigned		pos;
      NSRange		r;
      BOOL		hadMethod = NO;

      if (constants == nil)
	{
	  constants = [[NSArray alloc] initWithObjects:
	    @"YES", @"NO", @"nil", nil];
	}

      if (l == 0 || [[a objectAtIndex: l-1] isEqual: @"<code>"] == NO)
	{
	  /*
	   * Ensure that well known constants are rendered as 'code'
	   */
	  count = [constants count];
	  for (pos = 0; pos < count; pos++)
	    {
	      NSString	*c = [constants objectAtIndex: pos];

	      r = [tmp rangeOfString: c];

	      if (r.length > 0)
		{
		  NSString	*start;
		  NSString	*end;

		  if (r.location > 0)
		    {
		      start = [tmp substringToIndex: r.location];
		    }
		  else
		    {
		      start = nil;
		    }
		  if (NSMaxRange(r) < [tmp length])
		    {
		      end = [tmp substringFromIndex: NSMaxRange(r)];
		    }
		  else
		    {
		      end = nil;
		    }
		  if ((start == nil || snuggleStart(start) == YES)
		    && (end == nil || snuggleEnd(end) == YES))
		    {
		      NSString	*sub;

		      if (start != nil || end != nil)
			{
			  sub = [tmp substringWithRange: r];
			}
		      else
			{
			  sub = nil;
			}
		      if (start != nil)
			{
			  [a insertObject: start atIndex: l++];
			}
		      [a insertObject: @"<code>" atIndex: l++];
		      if (sub != nil)
			{
			  [a replaceObjectAtIndex: l withObject: sub];
			}
		      l++;
		      [a insertObject: @"</code>" atIndex: l];
		      if (end != nil)
			{
			  [a insertObject: end atIndex: ++l];
			}
		    }
		}
	    }
	}

      /*
       * Ensure that method arguments are rendered as 'var'
       */
      if (l == 0 || [[a objectAtIndex: l-1] isEqual: @"<var>"] == NO)
	{
	  count = [args count];
	  for (pos = 0; pos < count; pos++)
	    {
	      NSString	*c = [args objectAtIndex: pos];

	      r = [tmp rangeOfString: c];

	      if (r.length > 0)
		{
		  NSString	*start;
		  NSString	*end;

		  if (r.location > 0)
		    {
		      start = [tmp substringToIndex: r.location];
		    }
		  else
		    {
		      start = nil;
		    }
		  if (NSMaxRange(r) < [tmp length])
		    {
		      end = [tmp substringFromIndex: NSMaxRange(r)];
		    }
		  else
		    {
		      end = nil;
		    }
		  if ((start == nil || snuggleStart(start) == YES)
		    && (end == nil || snuggleEnd(end) == YES))
		    {
		      NSString	*sub;

		      if (start != nil || end != nil)
			{
			  sub = [tmp substringWithRange: r];
			}
		      else
			{
			  sub = nil;
			}
		      if (start != nil)
			{
			  [a insertObject: start atIndex: l++];
			}
		      [a insertObject: @"<var>" atIndex: l++];
		      if (sub != nil)
			{
			  [a replaceObjectAtIndex: l withObject: sub];
			}
		      l++;
		      [a insertObject: @"</var>" atIndex: l];
		      if (end != nil)
			{
			  [a insertObject: end atIndex: ++l];
			}
		    }
		}
	    }
	}

      /*
       * Ensure that methods are rendered as references.
       * First look for format with class name in square brackets.
       */
      r = [tmp rangeOfString: @"["];
      if (r.length > 0)
	{
	  unsigned	sPos = NSMaxRange(r);

	  r = NSMakeRange(pos, [tmp length] - pos);
	  r = [tmp rangeOfString: @"]" options: NSLiteralSearch range: r];
	  if (r.length > 0)
	    {
	      unsigned	ePos = r.location;
	      NSString	*cName = nil;
	      NSString	*mName = nil;
	      unichar	c;

	      if (pos < ePos
		&& [identStart characterIsMember:
		  (c = [tmp characterAtIndex: pos])] == YES)
		{
		  pos++;
		  while (pos < ePos)
		    {
		      c = [tmp characterAtIndex: pos];
		      if ([identifier characterIsMember: c] == NO)
			{
			  break;
			}
		      pos++;
		    }
		  if (c == '(')
		    {
		      pos++;
		      if (pos < ePos
			&& [identStart characterIsMember:
			  (c = [tmp characterAtIndex: pos])] == YES)
			{
			  while (pos < ePos)
			    {
			      c = [tmp characterAtIndex: pos];
			      if ([identifier characterIsMember: c] == NO)
				{
				  break;
				}
			      pos++;
			    }
			  if (c == ')')
			    {
			      pos++;
			      r = NSMakeRange(sPos, pos - sPos);
			      cName = [tmp substringWithRange: r];
			      if (pos < ePos)
				{
				  c = [tmp characterAtIndex: pos];
				}
			    }
			}
		      if (cName == nil)
			{
			  pos = ePos;	// Bad class name!
			}
		    }
		  else
		    {
		      r = NSMakeRange(sPos, pos - sPos);
		      cName = [tmp substringWithRange: r];
		    }
		}

	      if (pos < ePos && (c == '+' || c == '-'))
		{ 
		  unsigned	mStart = pos;

		  pos++;
		  if (pos < ePos
		    && [identStart characterIsMember:
		      (c = [tmp characterAtIndex: pos])] == YES)
		    {
		      while (pos < ePos)
			{
			  c = [tmp characterAtIndex: pos];
			  if (c != ':'
			    && [identifier characterIsMember: c] == NO)
			    {
			      break;
			    }
			  pos++;
			}
		      /*
		       * The end of the method name should be immediately
		       * before the closing square bracket at 'ePos'
		       */
		      if (pos == ePos && pos - mStart > 1)
			{
			  r = NSMakeRange(mStart, pos - mStart);
			  mName = [tmp substringWithRange: r];
			}
		    }
		}
	      if (mName != nil)
		{
		  NSString	*start;
		  NSString	*end;
		  NSString	*sub;
		  NSString	*ref;

		  if (sPos > 0)
		    {
		      start = [tmp substringToIndex: sPos];
		    }
		  else
		    {
		      start = nil;
		    }
		  if (ePos < [tmp length])
		    {
		      end = [tmp substringFromIndex: ePos];
		    }
		  else
		    {
		      end = nil;
		    }

		  if (start != nil || end != nil)
		    {
		      sub = [tmp substringWithRange:
			NSMakeRange(sPos, ePos - sPos)];
		    }
		  else
		    {
		      sub = nil;
		    }
		  if (start != nil)
		    {
		      [a insertObject: start atIndex: l++];
		    }
		  if (cName == nil)
		    {
		      ref = [NSString stringWithFormat:
			@"<ref type=\"method\" id=\"%@\">", mName];
		    }
		  else
		    {
		      ref = [NSString stringWithFormat:
			@"<ref type=\"method\" id=\"%@\" class=\"%@\">",
			mName, cName];
		    }
		  [a insertObject: ref atIndex: l++];
		  if (sub != nil)
		    {
		      [a replaceObjectAtIndex: l withObject: sub];
		    }
		
		  l++;
		  [a insertObject: @"</ref>" atIndex: l];
		  if (end != nil)
		    {
		      [a insertObject: end atIndex: ++l];
		    }
		  hadMethod = YES;
		}
	    }
	}
      
      /*
       * Now handle bare method names for current class ... outside brackets.
       */
      if (hadMethod == NO && ([tmp hasPrefix: @"-"] || [tmp hasPrefix: @"+"]))
	{
	  unsigned	ePos = [tmp length];
	  NSString	*mName = nil;
	  unsigned	c;

	  pos = 1;
	  if (pos < ePos
	    && [identStart characterIsMember:
	      (c = [tmp characterAtIndex: pos])] == YES)
	    {
	      while (pos < ePos)
		{
		  c = [tmp characterAtIndex: pos];
		  if (c != ':'
		    && [identifier characterIsMember: c] == NO)
		    {
		      break;
		    }
		  pos++;
		}
	      if (pos > 1 && (pos == ePos || c == ',' || c == '.' || c == ';'))
		{
		  NSString	*end;
		  NSString	*sub;
		  NSString	*ref;

		  mName = [tmp substringWithRange: NSMakeRange(0, pos)];

		  if (pos < [tmp length])
		    {
		      end = [tmp substringFromIndex: pos];
		      sub = [tmp substringToIndex: pos];
		    }
		  else
		    {
		      end = nil;
		      sub = nil;
		    }

		  ref = [NSString stringWithFormat:
		    @"<ref type=\"method\" id=\"%@\">", mName];
		  [a insertObject: ref atIndex: l++];
		  if (sub != nil)
		    {
		      [a replaceObjectAtIndex: l withObject: sub];
		    }
		  l++;
		  [a insertObject: @"</ref>" atIndex: l];
		  if (end != nil)
		    {
		      [a insertObject: end atIndex: ++l];
		    }
		  hadMethod = YES;
		}
	    }
	}
    }

  return a;
}

@end


