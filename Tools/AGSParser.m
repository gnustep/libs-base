/**

   <title>AGSParser ... a tool to get documention info from ObjC source</title>
   Copyright (C) <copy>2001 Free Software Foundation, Inc.</copy>

   <author name="Richard Frith-Macdonald"></author> <richard@brainstorm.co.uk>
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

#include "AGSParser.h"

@implementation	AGSParser

- (void) dealloc
{
  DESTROY(declared);
  DESTROY(info);
  DESTROY(comment);
  DESTROY(identifier);
  DESTROY(identStart);
  DESTROY(spaces);
  DESTROY(spacenl);
  [super dealloc];
}

- (NSMutableDictionary*) info
{
  return info;
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
  info = [[NSMutableDictionary alloc] initWithCapacity: 6];
  return self;
}

- (void) log: (NSString*)fmt arguments: (va_list)args
{
  const char	*msg;
  int		where;

  /*
   * Take the current position in the character buffer and
   * step through the lines array to find which line of the
   * original document it was on.
   * NB. Each item in the array represents the position *after*
   * a newline in the original data - so the zero'th array
   * element contains the character position of the start of
   * line two in human readable numbering (ie starting from 1).
   */
  for (where = [lines count] - 1; where >= 0; where--)
    {
      NSNumber	*num = [lines objectAtIndex: where];

      if ([num intValue] <= pos)
	{
	  break;
	}
    }
  where += 2;

  if (unitName != nil)
    {
      if (itemName != nil)
	{
          fmt = [NSString stringWithFormat: @"%@:%u %@(%@): %@",
	    fileName, where, unitName, itemName, fmt];
	}
      else
	{
          fmt = [NSString stringWithFormat: @"%@:%u %@: %@",
	    fileName, where, unitName, fmt];
	}
    }
  else
    {
      fmt = [NSString stringWithFormat: @"%@:%u %@", fileName, where, fmt];
    }
  fmt = [NSString stringWithFormat: fmt arguments: args];
  if ([fmt hasSuffix: @"\n"] == NO)
    {
      fmt = [fmt stringByAppendingString: @"\n"];
    }
  msg = [fmt lossyCString];
  fwrite(msg, strlen(msg), 1, stderr); 
}

- (void) log: (NSString*)fmt, ...
{
  va_list ap;

  va_start (ap, fmt);
  [self log: fmt arguments: ap];
  va_end (ap);
}

- (NSMutableDictionary*) parseFile: (NSString*)name isSource: (BOOL)isSource
{
  NSString	*token;

  commentsRead = NO;
  fileName = name;
  if (declared == nil)
    {
      ASSIGN(declared, fileName);
    }
  unitName = nil;
  itemName = nil;
  DESTROY(comment);

  [self setupBuffer];

  while ([self skipWhiteSpace] < length)
    {
      unichar	c = buffer[pos++];

      switch (c)
	{
	  case '#':
	    /*
	     * Some preprocessor directive ... must be on one line ... skip
	     * past it and delete any comment accumulated while doing so.
	     */
	    [self skipRemainderOfLine];
	    DESTROY(comment);
	    break;

	  case '@':
	    token = [self parseIdentifier];
	    if (token != nil)
	      {
		if ([token isEqual: @"interface"] == YES)
		  {
		    if (isSource == YES)
		      {
			[self skipUnit];
		      }
		    else
		      {
			[self parseInterface];
		      }
		  }
		else if ([token isEqual: @"protocol"] == YES)
		  {
		    if (isSource == YES)
		      {
			[self skipUnit];
		      }
		    else
		      {
			[self parseProtocol];
		      }
		  }
		else if ([token isEqual: @"implementation"] == YES)
		  {
		    [self parseImplementation];
		  }
		else
		  {
		    [self skipStatementLine];
		  }
	      }
	    break;

	  default:
	    /*
	     * Must be some sort of statement ... skip and ignore comments.
	     */
	    [self skipStatementLine];
	    break;
        }
    }

  return info;
}

- (NSMutableDictionary*) parseImplementation
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString		*tmp = nil;
  NSString		*name;
  NSString		*base = nil;
  NSString		*category = nil;
  NSDictionary		*methods = nil;
  NSMutableDictionary	*d;
  NSMutableDictionary	*dict = nil;

  /*
   * Record any class documentation for this class
   */
  tmp = AUTORELEASE(comment);
  comment = nil;

  if ((name = [self parseIdentifier]) == nil
    || [self skipWhiteSpace] >= length)
    {
      [self log: @"implementation with bad name"];
      goto fail;
    }
  unitName = name;

  /*
   * After the class name, we may have a category name or
   * a base class, but not both.
   */
  if (buffer[pos] == '(')
    {
      pos++;
      if ((category = [self parseIdentifier]) == nil
	|| [self skipWhiteSpace] >= length
	|| buffer[pos++] != ')'
	|| [self skipWhiteSpace] >= length)
	{
	  [self log: @"interface with bad category"];
	  goto fail;
	}
      name = [name stringByAppendingFormat: @"(%@)", category];
      unitName = name;
    }
  else if (buffer[pos] == ':')
    {
      pos++;
      if ((base = [self parseIdentifier]) == nil
	|| [self skipWhiteSpace] >= length)
	{
	  [self log: @"@interface with bad base class"];
	  goto fail;
	}
    }

  if (category == nil)
    {
      d = [info objectForKey: @"Classes"];
    }
  else
    {
      d = [info objectForKey: @"Categories"];
    }
  dict = [d objectForKey: unitName];

  if (dict == nil)
    {
      /*
       * If the implementation found does not correspond to an
       * interface found in the header file, it should not be
       * documented, and we skip it.
       */
      [self skipUnit];
      DESTROY(comment);
      return [NSMutableDictionary dictionary];
    }
  else
    {
      /*
       * Append any comment we have for this
       */
      if (tmp != nil)
	{
	  NSString	*old = [dict objectForKey: @"Comment"];

	  if (old != nil)
	    {
	      tmp = [old stringByAppendingString: tmp];
	    }
	  [dict setObject: tmp forKey: @"Comment"];
	}
      /*
       * Update base class if necessary.
       */
      if (base != nil)
	{
	  if ([base isEqual: [dict objectForKey: @"BaseClass"]] == NO)
	    {
	      [self log: @"implementation base class differs from interface"];
	    }
	  [dict setObject: base forKey: @"BaseClass"];
	}
    }

  methods = [self parseMethodsAreDeclarations: NO];
  if (methods != nil && [methods count] > 0)
    {
      // [dict setObject: methods forKey: @"Methods"];
    }

  // [self log: @"Found implementation %@", dict];

  unitName = nil;
  DESTROY(comment);
  RELEASE(arp);
  return dict;

fail:
  unitName = nil;
  DESTROY(comment);
  RELEASE(arp);
  return nil;
}

- (NSMutableDictionary*) parseInterface
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString		*name;
  NSString		*base = nil;
  NSString		*category = nil;
  NSDictionary		*methods = nil;
  NSMutableDictionary	*d;
  NSMutableDictionary	*dict;

  dict = [NSMutableDictionary dictionaryWithCapacity: 8];

  /*
   * Record any class documentation for this class
   */
  if (comment != nil)
    {
      [dict setObject: comment forKey: @"Comment"];
      DESTROY(comment);
    }

  if ((name = [self parseIdentifier]) == nil
    || [self skipWhiteSpace] >= length)
    {
      [self log: @"interface with bad name"];
      goto fail;
    }
  unitName = name;

  [dict setObject: @"class" forKey: @"Type"];

  /*
   * After the class name, we may have a category name or
   * a base class, but not both.
   */
  if (buffer[pos] == '(')
    {
      pos++;
      if ((category = [self parseIdentifier]) == nil
	|| [self skipWhiteSpace] >= length
	|| buffer[pos++] != ')'
	|| [self skipWhiteSpace] >= length)
	{
	  [self log: @"interface with bad category"];
	  goto fail;
	}
      [dict setObject: category forKey: @"Category"];
      [dict setObject: name forKey: @"BaseClass"];
      name = [name stringByAppendingFormat: @"(%@)", category];
      unitName = name;
      [dict setObject: @"category" forKey: @"Type"];
    }
  else if (buffer[pos] == ':')
    {
      pos++;
      if ((base = [self parseIdentifier]) == nil
	|| [self skipWhiteSpace] >= length)
	{
	  [self log: @"@interface with bad base class"];
	  goto fail;
	}
      [dict setObject: base forKey: @"BaseClass"];
    }
  [dict setObject: name forKey: @"Name"];

  /*
   * Interfaces or categories may conform to protocols.
   */
  if (buffer[pos] == '<')
    {
      NSArray	*protocols = [self parseProtocolList];

      if (protocols == nil)
	{
	  goto fail;
	}
      else if ([protocols count] > 0)
	{
	  [dict setObject: protocols forKey: @"Protocols"];
	}
    }

  /*
   * Interfaces may have instance variables, but categories may not.
   */
  if (buffer[pos] == '{' && category == nil)
    {
      NSDictionary	*ivars = [self parseInstanceVariables];
      if (ivars == nil)
	{
	  goto fail;
	}
      else if ([ivars count] > 0)
	{
	  [dict setObject: ivars forKey: @"InstanceVariables"];
	}
      DESTROY(comment);		// Ignore any ivar comments.
    }

  methods = [self parseMethodsAreDeclarations: YES];
  if (methods != nil && [methods count] > 0)
    {
      [dict setObject: methods forKey: @"Methods"];
    }

  [dict setObject: declared forKey: @"Declared"];

  if (category == nil)
    {
      d = [info objectForKey: @"Classes"];
      if (d == nil)
	{
	  d = [[NSMutableDictionary alloc] initWithCapacity: 4];
	  [info setObject: d forKey: @"Classes"];
	  RELEASE(d);
	}
    }
  else
    {
      d = [info objectForKey: @"Categories"];
      if (d == nil)
	{
	  d = [[NSMutableDictionary alloc] initWithCapacity: 4];
	  [info setObject: d forKey: @"Categories"];
	  RELEASE(d);
	}
    }
  [d setObject: dict forKey: unitName];

  // [self log: @"Found interface %@", dict];

  unitName = nil;
  DESTROY(comment);
  RELEASE(arp);
  return dict;

fail:
  unitName = nil;
  DESTROY(comment);
  RELEASE(arp);
  return nil;
}

- (NSString*) parseIdentifier
{
  unsigned	start;

  [self skipWhiteSpace];
  if (pos >= length || [identStart characterIsMember: buffer[pos]] == NO)
    {
      return nil;
    }
  start = pos;
  while (pos < length)
    {
      if ([identifier characterIsMember: buffer[pos]] == NO)
	{
	  return [NSString stringWithCharacters: &buffer[start]
					 length: pos - start];
	}
      pos++;
    }
  return nil;
}

- (NSMutableDictionary*) parseInstanceVariables
{
  enum { IsPrivate, IsProtected, IsPublic } visibility = IsPrivate;
  NSMutableDictionary	*ivars;

  DESTROY(comment);

  ivars = [NSMutableDictionary dictionaryWithCapacity: 8];
  pos++;
  while ([self skipWhiteSpace] < length && buffer[pos] != '}')
    {
      if (buffer[pos] == '@')
	{
	  NSString	*token;

	  pos++;
	  if ((token = [self parseIdentifier]) == nil
	    || [self skipWhiteSpace] >= length)
	    {
	      [self log: @"interface with bad visibility directive"];
	      return nil;
	    }
	  if ([token isEqual: @"private"] == YES)
	    {
	      visibility = IsPrivate;
	    }
	  else if ([token isEqual: @"protected"] == YES)
	    {
	      visibility = IsProtected;
	    }
	  else if ([token isEqual: @"public"] == YES)
	    {
	      visibility = IsPublic;
	    }
	  else
	    {
	      [self log: @"interface with bad visibility (%@)", token];
	      return nil;
	    }
	}
      else if (buffer[pos] == '#')
	{
	  [self skipRemainderOfLine];	// Ignore preprocessor directive.
	  DESTROY(comment);
	}
      else
	{
	  [self skipStatement];	/* FIXME - currently we ignore ivars */
	}
    }
  if (pos >= length)
    {
      [self log: @"interface with bad instance variables"];
      return nil;
    }
  pos++;	// Step past closing bracket.
  return ivars;
}

- (NSMutableDictionary*) parseMethodIsDeclaration: (BOOL)flag
{
  CREATE_AUTORELEASE_POOL(arp);
  NSMutableDictionary	*method;
  NSMutableString	*mname;
  NSString		*token;
  NSMutableArray	*types = nil;
  NSMutableArray	*args = nil;
  NSMutableArray	*sels = [NSMutableArray arrayWithCapacity: 2];
  unichar		term;

  method = [[NSMutableDictionary alloc] initWithCapacity: 4];
  if (buffer[pos++] == '-')
    {
      mname = [NSMutableString stringWithCString: "-"];
    }
  else
    {
      mname = [NSMutableString stringWithCString: "+"];
    }
  [method setObject: sels forKey: @"Sels"];	// Parts of selector.

  /*
   * Parse return type ... defaults to 'id'
   */
  if ([self skipWhiteSpace] >= length)
    {
      [self log: @"error parsing method return type"];
      goto fail;
    }
  if (buffer[pos] == '(')
    {
      if ((token = [self parseMethodType]) == nil
	|| [self skipWhiteSpace] >= length)
	{
	  [self log: @"error parsing method return type"];
	  goto fail;
	}
      [method setObject: token forKey: @"ReturnType"];
    }
  else
    {
      [method setObject: @"id" forKey: @"ReturnType"];
    }

  if (flag == YES)
    {
      term = ';';
    }
  else
    {
      term = '{';
    }

  while (buffer[pos] != term)
    {
      token = [self parseIdentifier];
      if ([self skipWhiteSpace] >= length)
	{
	  [self log: @"error at method name component"];
	  goto fail;
	}
      if (buffer[pos] == ':')
	{
	  NSString	*arg;
	  NSString	*type = @"id";

	  pos++;
	  if (token == nil)
	    {
	      [sels addObject: @":"];
	    }
	  else
	    {
	      [mname appendString: token];
	      [sels addObject: [token stringByAppendingString: @":"]];
	    }
	  [mname appendString: @":"];
	  if ([self skipWhiteSpace] >= length)
	    {
	      [self log: @"error parsing method argument"];
	      goto fail;
	    }
	  if (buffer[pos] == '(')
	    {
	      if ((type = [self parseMethodType]) == nil
		|| [self skipWhiteSpace] >= length)
		{
		  [self log: @"error parsing method arguument type"];
		  goto fail;
		}
	    }
	  if ((arg = [self parseIdentifier]) == nil
	    || [self skipWhiteSpace] >= length)
	    {
	      [self log: @"error parsing method argument name"];
	      goto fail;
	    }

	  if (types == nil)
	    {
	      types = [NSMutableArray arrayWithCapacity: 2];
	      [method setObject: types forKey: @"Types"];
	    }
	  [types addObject: type];

	  if (args == nil)
	    {
	      args = [NSMutableArray arrayWithCapacity: 2];
	      [method setObject: args forKey: @"Args"];
	    }
	  [args addObject: arg];

	  if (buffer[pos] == ',')
	    {
	      [method setObject: @"YES" forKey: @"VarArgs"];
	      [mname appendString: @",..."];
	      while ([self skipWhiteSpace] < length)
		{
		  if (buffer[pos] == term)
		    {
		      break;
		    }
		  pos++;
		}
	      if (buffer[pos] != term)
		{
		  [self log: @"error skipping varargs"];
		  goto fail;
		}
	    }
	}
      else if (token != nil)
	{
	  [sels addObject: token];
	  [mname appendString: token];
	  if (buffer[pos] != term)
	    {
	      [self log: @"error parsing method name"];
	      goto fail;
	    }
	}
      else
	{
	  [self log: @"error parsing method name"];
	  goto fail;
	}
    }

  [method setObject: mname forKey: @"Name"];
  itemName = mname;

  if (term == ';')
    {
      /*
       * Skip past the closing semicolon of the method declaration,
       * and read in any comment on the same line in case it
       * contains documentation for the method.
       */
      pos++;
      if ([self skipSpaces] < length && buffer[pos] == '/')
	{
	  [self skipComment];
	}
    }
  else if (term == '{')
    {
      [self skipBlock];
    }

  /*
   * Store any available documentation information in the method.
   * If the method is already documented, append new information.
   */
  if (comment != nil)
    {
      NSString	*old;

      old = [method objectForKey: @"Comment"];
      if (old != nil)
	{
	  [method setObject: [old stringByAppendingString: comment]
		     forKey: @"Comment"];
	}
      else
	{
	  [method setObject: comment forKey: @"Comment"];
	}
      DESTROY(comment);
    }

  itemName = nil;
  DESTROY(comment);
  RELEASE(arp);
  AUTORELEASE(method);
  return method;

fail:
  itemName = nil;
  DESTROY(comment);
  RELEASE(arp);
  RELEASE(method);
  return nil;
}

- (NSMutableDictionary*) parseMethodsAreDeclarations: (BOOL)flag
{
  NSMutableDictionary	*methods;
  NSMutableDictionary	*method;
  NSMutableDictionary	*exist;
  NSString		*token;

  if (flag == YES)
    {
      exist = nil;	// Declaration ... no existing methods.
      methods = [NSMutableDictionary dictionaryWithCapacity: 8];
    }
  else
    {
      /*
       * Get a list of known methods.
       */
      if ([unitName hasPrefix: @"("])
	{
	  exist = nil;	// A protocol ... no method implementations.
	}
      else if ([unitName hasSuffix: @")"])
	{
	  exist = [info objectForKey: @"Categories"];
	}
      else
	{
	  exist = [info objectForKey: @"Classes"];
	}
      exist = [exist objectForKey: unitName];
      exist = [exist objectForKey: @"Methods"];
      /*
       * If there were no methods in the interface, we can't
       * document any now so we may as well skip to the end.
       */
      if (exist == nil)
	{
	  [self skipUnit];
	  DESTROY(comment);
	  return [NSMutableDictionary dictionary];	// Empty dictionary.
	}
      methods = exist;
    }

  while ([self skipWhiteSpace] < length)
    {
      unichar	c = buffer[pos++];

      switch (c)
	{
	  case '-':
	  case '+':
	    pos--;
	    method = [self parseMethodIsDeclaration: flag];
	    if (method == nil)
	      {
		return nil;
	      }
	    token = [method objectForKey: @"Name"];
	    if (flag == YES)
	      {
		/*
		 * Just record the method.
		 */
		[methods setObject: method forKey: token];
	      }
	    else if ((exist = [methods objectForKey: token]) != nil)
	      {
		NSArray	*a0;
		NSArray	*a1;

		/*
		 * Merge info from implementation into existing version.
		 */

		a0 = [exist objectForKey: @"Args"];
		a1 = [method objectForKey: @"Args"];
		if (a0 != nil)
		  {
		    if ([a0 isEqual: a1] == NO)
		      {
			itemName = token;
			[self log: @"method args in interface %@ don't match "
			  @"those in implementation %@", a0, a1];
			itemName = nil;
			[exist setObject: a1 forKey: @"Args"];
		      }
		  }

		a0 = [exist objectForKey: @"Types"];
		a1 = [method objectForKey: @"Types"];
		if (a0 != nil)
		  {
		    if ([a0 isEqual: a1] == NO)
		      {
			itemName = token;
			[self log: @"method types in interface %@ don't match "
			  @"those in implementation %@", a0, a1];
			itemName = nil;
			[exist setObject: a1 forKey: @"Types"];
		      }
		  }

		token = [method objectForKey: @"Comment"];
		if (token != nil)
		  {
		    NSString	*old = [exist objectForKey: @"Comment"];

		    if (old != nil)
		      {
			token = [old stringByAppendingString: token];
		      }
		    [exist setObject: token forKey: @"Comment"];
		  }
	      }
	    break;

	  case '@':
	    if ((token = [self parseIdentifier]) == nil)
	      {
		[self log: @"method list with error after '@'"];
		return nil;
	      }
	    if ([token isEqual: @"end"] == YES)
	      {
		return methods;
	      }
	    else
	      {
		[self log: @"@method list with unknown directive '%@'", token];
		return nil;
	      }
	    break;

	  case '#':
	    /*
	     * Some preprocessor directive ... must be on one line ... skip
	     * past it and delete any comment accumulated while doing so.
	     */
	    [self skipRemainderOfLine];
	    DESTROY(comment);
	    break;

	  default:
	    /*
	     * Some statement other than a method ... skip and delete comments.
	     */
	    [self skipStatementLine];
	    break;
	}
    }

  [self log: @"method list prematurely ended"];
  return nil;
}

- (NSString*) parseMethodType
{
  unichar	*start;
  unichar	*ptr;
  unsigned	nest = 0;

  pos++;
  if ([self skipWhiteSpace] >= length)
    {
      return nil;
    }
  ptr = start = &buffer[pos];
  while (pos < length)
    {
      unichar	c = buffer[pos++];

      if (c == '(')
	{
	  *ptr++ = '(';
	  nest++;
	}
      else if (c == ')')
	{
	  if (nest > 0)
	    {
	      *ptr++ = ')';
	      nest--;
	    }
	  else
	    {
	      break;
	    }
	}
      else if ([spacenl characterIsMember: c] == NO)
	{
	  /*
	   * If this character is not part of a name, and the previous
	   * character written was a space, we know we can get rid of
	   * the space to standardise the type format to use a minimal
	   * number of spaces.
	   */
	  if (ptr > start && ptr[-1] == ' ')
	    {
	      if ([identifier characterIsMember: c] == NO)
		{
		  ptr--;
		}
	    }
	  *ptr++ = c;
	}
      else
	{
	  /*
	   * Don't retain whitespace if we know we don't need it
	   * because the previous character was not part of a name.
	   */
	  if (ptr > start && [identifier characterIsMember: ptr[-1]] == YES)
	    {
	      *ptr++ = ' ';
	    }
	}
    }

  if ([self skipWhiteSpace] >= length)
    {
      return nil;
    }

  /*
   * Strip trailing sapce ... leading space we never copied in the
   * first place.
   */
  if (ptr > start && [spacenl characterIsMember: ptr[-1]] == YES)
    {
      ptr--;
    }

  if (ptr > start)
    {
      return [NSString stringWithCharacters: start length: ptr - start];
    }
  else
    {
      return nil;
    }
}

- (NSMutableDictionary*) parseProtocol
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString		*name;
  NSDictionary		*methods = nil;
  NSMutableDictionary	*dict;
  NSMutableDictionary	*d;

  dict = [[NSMutableDictionary alloc] initWithCapacity: 8];

  /*
   * Record any protocol documentation for this protocol
   */
  if (comment != nil)
    {
      [dict setObject: comment forKey: @"Comment"];
      DESTROY(comment);
    }

  if ((name = [self parseIdentifier]) == nil
    || [self skipWhiteSpace] >= length)
    {
      [self log: @"protocol with bad name"];
      goto fail;
    }
  [dict setObject: name forKey: @"Name"];
  unitName = [NSString stringWithFormat: @"(%@)", name];

  /*
   * Protocols may themselves conform to protocols.
   */
  if (buffer[pos] == '<')
    {
      NSArray	*protocols = [self parseProtocolList];

      if (protocols == nil)
	{
	  goto fail;
	}
      else if ([protocols count] > 0)
	{
	  [dict setObject: protocols forKey: @"Protocols"];
	}
    }
  [dict setObject: @"protocol" forKey: @"Type"];

  methods = [self parseMethodsAreDeclarations: YES];
  if (methods != nil && [methods count] > 0)
    {
      [dict setObject: methods forKey: @"Methods"];
    }

  d = [info objectForKey: @"Protocols"];
  if (d == nil)
    {
      d = [[NSMutableDictionary alloc] initWithCapacity: 4];
      [info setObject: d forKey: @"Protocols"];
      RELEASE(d);
    }
  [d setObject: dict forKey: unitName];

  // [self log: @"Found protocol %@", dict];

  unitName = nil;
  DESTROY(comment);
  RELEASE(arp);
  AUTORELEASE(dict);
  return dict;

fail:
  unitName = nil;
  DESTROY(comment);
  RELEASE(arp);
  RELEASE(dict);
  return nil;
}

- (NSMutableArray*) parseProtocolList
{
  NSMutableArray	*protocols;
  NSString		*p;

  protocols = [NSMutableArray arrayWithCapacity: 2];
  pos++;
  while ((p = [self parseIdentifier]) != nil
    && [self skipWhiteSpace] < length)
    {
      if ([protocols containsObject: p] == NO)
	{
	  [protocols addObject: p];
	}
      if (buffer[pos] == ',')
	{
	  pos++;
	}
      else
	{
	  break;
	}
    }
  if (pos >= length || buffer[pos] != '>' || ++pos >= length
    || [self skipWhiteSpace] >= length || [protocols count] == 0)
    {
      [self log: @"bad protocol list"];
      return nil;
    }
  return protocols;
}

- (void) reset
{
  [info removeAllObjects];
  DESTROY(declared);
  DESTROY(comment);
  fileName = nil;
  unitName = nil;
  itemName = nil;
  lines = nil;
  buffer = 0;
  length = 0;
  pos = 0;
}

- (void) setDeclared: (NSString*)name
{
  ASSIGN(declared, name);
}

/**
 * Read in the file to be parsed and store it in a temporary unicode
 * buffer.  Perform basic transformations on the buffer to simplify
 * the parsing process later - including stripping out of escaped
 * end-of-line sequences.  Create mapping information to convert
 * positions in the new character buffer to line numbers in the
 * original data (for logging purposes).
 */
- (void) setupBuffer
{
  CREATE_AUTORELEASE_POOL(arp);
  NSString		*contents;
  NSMutableData		*data;
  unichar		*end;
  unichar		*inptr;
  unichar		*outptr;
  NSMutableArray	*a;

  contents = [NSString stringWithContentsOfFile: fileName];
  length = [contents length];
  data = [[NSMutableData alloc] initWithLength: length * sizeof(unichar)];
  buffer = [data mutableBytes];
  [contents getCharacters: buffer];
  outptr = buffer;
  end = &buffer[length];

  a = [NSMutableArray arrayWithCapacity: 1024];
  for (inptr = buffer; inptr < end; outptr++, inptr++)
    {
      unichar	c = *inptr;

      *outptr = c;

      /*
       * Perform ansi trigraph substitution.
       * Don't know why I bothered ... will probably never be used.
       */
      if (c == '?' && (inptr < end - 2) && inptr[1] == '?')
	{
	  BOOL	changed = YES;

	  switch (inptr[2])
	    {
	      case '=':		*outptr = '#';	break;
	      case '/':		*outptr = '\\';	break;
	      case '\'':	*outptr = '^';	break;
	      case '(':		*outptr = '[';	break;
	      case ')':		*outptr = ']';	break;
	      case '!':		*outptr = '|';	break;
	      default:		*outptr = '?'; changed = NO; break;
	    }
	  if (changed == YES)
	    {
	      inptr += 2;
	    }
	}
      else if (c == '\\')
	{
	  /*
	   * Backslash-end-of-line sequences are removed.
           */
	  if (inptr < end - 1)
	    {
	      if (inptr[1] == '\n')
		{
		  inptr++;
		  outptr--;
		  [a addObject: [NSNumber numberWithInt: outptr - buffer]];
		}
	      else if (inptr[1] == '\r')
		{
		  inptr++;
		  outptr--;
		  if (inptr[1] == '\n')
		    {
		      inptr++;
		    }
		  [a addObject: [NSNumber numberWithInt: outptr - buffer]];
		}
	    }
	}
      else if (c == '\r')
	{
	  /*
	   * Convert cr-fl or single cr to single lf
	   */
	  if (inptr < end - 1)
	    {
	      if (inptr[1] == '\n')
		{
		  inptr++;
		}
	      *outptr = '\n';
	    }
	  else
	    {
	      outptr--;		// Ignore trailing carriage return.
	    }
	  [a addObject: [NSNumber numberWithInt: outptr - buffer]];
	}
      else if (c == '\n')
	{
	  [a addObject: [NSNumber numberWithInt: outptr - buffer]];
	}
    }
  length = outptr - buffer;
  [data setLength: length*sizeof(unichar)];
  buffer = [data mutableBytes];
  pos = 0;
  lines = [[NSArray alloc] initWithArray: a];
  RELEASE(arp);
  AUTORELEASE(lines);
  AUTORELEASE(data);
}

/**
 * Skip until we encounter an '}' marking the end of a block.
 * Expect the current character position to be pointing to the
 * '{' at the start of a block.
 */
- (unsigned) skipBlock
{
  pos++;
  while ([self skipWhiteSpace] < length)
    {
      unichar	c = buffer[pos++];

      switch (c)
	{
	  case '#':		// preprocessor directive.
	    [self skipRemainderOfLine];
	    break;

	  case '\'':
	  case '"':
	    pos--;
	    [self skipLiteral];
	    break;

	  case '{':
	    pos--;
	    [self skipBlock];
	    break;

	  case '}':
	    return pos;
        }
    }
  return pos;
}

/**
 * In spite of it's trivial name, this is one of the key methods -
 * it parses and skips past comments, but it also recognizes special
 * comments (with an additional asterisk after the start of the block
 * comment) and extracts their contents, accumulating them into the
 * 'comment' instance variable.<br />
 * In addition, the first extracted documentation is checked for the
 * prsence of file header markup, which is extracted into the 'info'
 * dictionary.
 */
- (unsigned) skipComment
{
  if (buffer[pos + 1] == '/')
    {
      return [self skipRemainderOfLine];
    }
  else if (buffer[pos + 1] == '*')
    {
      unichar	*start = 0;
      BOOL	isDocumentation = NO;
      NSRange	r;

      pos += 2;	/* Skip opening part */

      /*
       * Only comments starting with slash and TWO asterisks are special.
       */
      if (pos < length - 2 && buffer[pos] == '*' && buffer[pos + 1] != '*')
	{
	  isDocumentation = YES;
	  pos++;

	  /*
	   * Ignore first line of comment if it is empty.
	   */
	  if ([self skipSpaces] < length && buffer[pos] == '\n')
	    {
	      pos++;
	    }
	}

      /*
       * Find end of comment.
       */
      start = &buffer[pos];
      while (pos < length)
	{
	  unichar	c = buffer[pos++];

	  if (c == '*' && pos < length && buffer[pos] == '/')
	    {
	      pos++;	// Position after trailing slash.
	      break;
	    }
	}

      if (isDocumentation == YES)
	{
	  unichar	*end = &buffer[pos - 1];
	  unichar	*ptr = start;
	  unichar	*newLine = ptr;

	  /*
	   * Remove any asterisks immediately before end of comment.
	   */
	  while (end > start && end[-1] == '*')
	    {
	      end--;
	    }
	  /*
	   * Remove any trailing whitespace in the comment, but ensure that
	   * there is a final newline.
	   */
	  while (end > start && [spacenl characterIsMember: end[-1]] == YES)
	    {
	      end--;
	    }
	  *end++ = '\n';

	  /*
	   * Strip parts of lines up to leading asterisks.
	   */
	  while (ptr < end)
	    {
	      unichar	c = *ptr++;

	      if (c == '\n')
		{
		  newLine = ptr;
		}
	      else if (c == '*' && newLine != 0)
		{
		  unichar	*out = newLine;

		  while (ptr < end)
		    {
		      *out++ = *ptr++;
		    }
		  end = out;
		  ptr = newLine;
		  newLine = 0;
		}
	      else if ([spaces characterIsMember: c] == NO)
		{
		  newLine = 0;
		}
	    }

	  /*
	   * If we have something for documentation, accumulate it in the
	   * 'comment' ivar.
	   */
	  if (end > start)
	    {
	      NSString	*tmp;

	      tmp = [NSString stringWithCharacters: start length: end - start];
	      if (comment != nil)
		{
		  tmp = [comment stringByAppendingString: tmp];
		}
	      ASSIGN(comment, tmp);
	    }

	  if (commentsRead == NO && comment != nil)
	    {
	      unsigned		commentLength = [comment length];
	      NSMutableArray	*authors = nil;
	      NSEnumerator	*enumerator;
	      NSArray		*keys;
	      NSString		*key;

	      /*
	       * Scan through for authors unless we got them from
	       * the interface.
	       */
	      r = NSMakeRange(0, commentLength);
	      while (r.length > 0)
		{
		  r = [comment rangeOfString: @"<author "
				     options: NSLiteralSearch
				       range: r];
		  if (r.length > 0)
		    {
		      unsigned	i = r.location;

		      r = NSMakeRange(i, commentLength - i);
		      r = [comment rangeOfString: @"</author>"
					 options: NSLiteralSearch
					   range: r];
		      if (r.length > 0)
			{
			  NSString		*author;

			  r = NSMakeRange(i, NSMaxRange(r) - i);
			  author = [comment substringWithRange: r];
			  i = NSMaxRange(r);
			  r = NSMakeRange(i, commentLength - i);
			  /*
			   * There may be more than one author
			   * of a document.
			   */
			  if (authors == nil)
			    {
			      authors = [NSMutableArray new];
			      [info setObject: authors forKey: @"authors"];
			      RELEASE(authors);
			    }
			  [authors addObject: author];
			}
		      else
			{
			  [self log: @"unterminated <author> in comment"];
			}
		    }
		}
	      if (authors == nil)
		{
		  /*
		   * Extract RCS keyword information for author
		   * if it is available.
		   */
		  r = [comment rangeOfString: @"$Author:"];
		  if (r.length > 0)
		    {
		      unsigned	i = NSMaxRange(r);
		      NSString	*author;

		      r = NSMakeRange(i, commentLength - i);
		      r = [comment rangeOfString: @"$"
					 options: NSLiteralSearch
					   range: r];
		      if (r.length > 0)
			{
			  r = NSMakeRange(i, r.location - i);
			  author = [comment substringWithRange: r];
			  author = [author stringByTrimmingSpaces];
			  authors = [NSMutableArray arrayWithObject: author];
			  [info setObject: authors forKey: @"authors"];
			}
		    }
		}

	      /**
	       * There are various sections we can extract from the
	       * document - at most one of each.
	       * If date and version are not supplied RCS Date and Revision
	       * tags will be extracted where available.
	       */
	      keys = [NSArray arrayWithObjects:
		@"abstract",	// Abstract for document head
		@"back",	// Appendix for document body
		@"chapter",	// Chapter at start of document
		@"copy",	// Copyright for document head
		@"date",	// date for document head
		@"front",	// Forward for document body
		@"title",	// Title for document head
		@"version",	// Version for document head
		nil];
	      enumerator = [keys objectEnumerator];

	      while ((key = [enumerator nextObject]) != nil)
		{
		  NSString	*s = [NSString stringWithFormat: @"<%@>", key];
		  NSString	*e = [NSString stringWithFormat: @"</%@>", key];
	      
		  /*
		   * Read date information if available
		   */
		  r = [comment rangeOfString: s];
		  if (r.length > 0)
		    {
		      unsigned	i = r.location;

		      r = NSMakeRange(i, commentLength - i);
		      r = [comment rangeOfString: e
					 options: NSLiteralSearch
					   range: r];
		      if (r.length > 0)
			{
			  NSString	*val;

			  r = NSMakeRange(i, NSMaxRange(r) - i);
			  val = [comment substringWithRange: r];
			  [info setObject: val forKey: key];
			}
		      else
			{
			  [self log: @"unterminated %@ in comment", s];
			}
		    }
		}

	      /*
	       * If no <date> ... </date> then try RCS info.
	       */
	      if ([info objectForKey: @"date"] == nil)
		{
		  r = [comment rangeOfString: @"$Date:"];
		  if (r.length > 0)
		    {
		      unsigned	i = NSMaxRange(r);
		      NSString	*date;

		      r = NSMakeRange(i, commentLength - i);
		      r = [comment rangeOfString: @"$"
					 options: NSLiteralSearch
					   range: r];
		      if (r.length > 0)
			{
			  r = NSMakeRange(i, r.location - i);
			  date = [comment substringWithRange: r];
			  date = [date stringByTrimmingSpaces];
			  date = [NSString stringWithFormat:
			    @"<date>%@</date>", date];
			  [info setObject: date forKey: @"date"];
			}
		    }
		}

	      /*
	       * If no <version> ... </version> then try RCS info.
	       */
	      if ([info objectForKey: @"version"] == nil)
		{
		  r = [comment rangeOfString: @"$Revision:"];
		  if (r.length > 0)
		    {
		      unsigned	i = NSMaxRange(r);
		      NSString	*version;

		      r = NSMakeRange(i, commentLength - i);
		      r = [comment rangeOfString: @"$"
					 options: NSLiteralSearch
					   range: r];
		      if (r.length > 0)
			{
			  r = NSMakeRange(i, r.location - i);
			  version = [comment substringWithRange: r];
			  version = [version stringByTrimmingSpaces];
			  version = [NSString stringWithFormat:
			    @"<version>%@</version>", version];
			  [info setObject: version forKey: @"version"];
			}
		    }
		}
	    }
	  commentsRead = YES;
	}
    }
  return pos;
}

- (unsigned) skipLiteral
{
  unichar	term = buffer[pos++];

  while (pos < length)
    {
      unichar	c = buffer[pos++];

      if (c == '\\')
	{
	  pos++;
	}
      else if (c == term)
	{
	  break;
	}
    }
  return pos;
}

- (unsigned) skipRemainderOfLine
{
  while (pos < length)
    {
      if (buffer[pos++] == '\n')
	{
	  break;
	}
    }
  return pos;
}

- (unsigned) skipSpaces
{
  while (pos < length)
    {
      unichar	c = buffer[pos];

      if ([spaces characterIsMember: c] == NO)
	{
	  break;
	}
      pos++;
    }
  return pos;
}

/**
 * Skip until we encounter a semicolon or closing brace.
 * Strictly speaking, we don't skip all statements that way,
 * since we only skip part of an if...else statement.
 */
- (unsigned) skipStatement
{
  while ([self skipWhiteSpace] < length)
    {
      unichar	c = buffer[pos++];

      switch (c)
	{
	  case '#':		// preprocessor directive.
	    [self skipRemainderOfLine];
	    break;

	  case '\'':
	  case '"':
	    pos--;
	    [self skipLiteral];
	    break;

	  case '{':
	    [self skipBlock];
	    return pos;

	  case ';':
	    return pos;		// At end of statement

	  case '}':
	    [self log: @"Argh ... read '}' when looking for ';'"];
	    return --pos;	// No statement to skip.
	    break;
        }
    }
  return pos;
}

/**
 * Special method to skip a statement and up to the end of the last
 * line it was on, discarding any comments so they don't get used by
 * the next construct that actually needs documenting.
 */ 
- (unsigned) skipStatementLine
{
  [self skipStatement];
  if (buffer[pos-1] == ';' || buffer[pos-1] == '}')
    {
      [self skipRemainderOfLine];
    }
  DESTROY(comment);
  return pos;
}

/**
 * Skip until we encounter an '@end' marking the end of an interface,
 * implementation, or protocol.
 */
- (unsigned) skipUnit
{
  while ([self skipWhiteSpace] < length)
    {
      unichar	c = buffer[pos++];

      switch (c)
	{
	  case '#':		// preprocessor directive.
	    [self skipRemainderOfLine];
	    break;

	  case '\'':
	  case '"':
	    pos--;
	    [self skipLiteral];
	    break;

	  case '@':
	    [self skipWhiteSpace];
	    if (pos < length - 3)
	      {
		if (buffer[pos] == 'e' && buffer[pos+1] == 'n'
		  && buffer[pos+2] == 'd')
		  {
		    pos += 3;
		    return pos;
		  }
	      }
	    break;
        }
    }
  return pos;
}

/**
 * Skip past any whitespace characters ... including comments.
 * Calls skipComment if necesary, ensuring that any documentation
 * in comments is appended to our 'comment' ivar.
 */
- (unsigned) skipWhiteSpace
{
  while (pos < length)
    {
      unichar	c = buffer[pos];

      if (c == '/')
	{
	  unsigned	old = pos;

	  if ([self skipComment] > old)
	    {
	      continue;	// Found a comment ... go on as if it was a space.
	    }
	}
      if ([spacenl characterIsMember: c] == NO)
	{
	  break;	// Not whitespace ... done.
	}
      pos++;		// Step past space character.
    }
  return pos;
}

@end

