/**

   <title>AGSParser ... a tool to get documention info from ObjC source</title>
   Copyright (C) 2001 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: October 2001

   This file is part of the GNUstep Project

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   You should have received a copy of the GNU General Public
   License along with this program; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

   */

#include "AGSParser.h"

@implementation	AGSParser

- (void) dealloc
{
  DESTROY(ifStack);
  DESTROY(declared);
  DESTROY(info);
  DESTROY(comment);
  DESTROY(identifier);
  DESTROY(identStart);
  DESTROY(spaces);
  DESTROY(spacenl);
  DESTROY(source);
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
  source = [NSMutableArray new];
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

- (NSString*) parseDeclaratorInto: (NSMutableArray*)a
{
  while ([self skipWhiteSpace] < length)
    {
      while (pos < length && buffer[pos] == '*')
	{
	  [a addObject: @"*"];
	  pos++;
	}
      if (buffer[pos] == '(')
	{
	  NSString	*result;

	  [a addObject: @"("];
	  pos++;
	  result = [self parseDeclaratorInto: a];
	  if ([self skipWhiteSpace] < length && buffer[pos] == '(')
	    {
	      [self parseDeclaratorInto: a];	// parse function args.
	    }
	  if ([self skipWhiteSpace] < length && buffer[pos] == ')')
	    {
	      [a addObject: @")"];
	      pos++;
	      return result;
	    }
	  else
	    {
	      [self log: @"missing ')' in declarator."];
	      return nil;
	    }
	}
      else
	{
	  NSString	*s;

	  s = [self parseIdentifier];
	  if ([s isEqualToString: @"const"] || [s isEqualToString: @"volatile"])
	    {
	      [a addObject: s];
	    }
	  else
	    {
	      return s;	// Parsed all asterisks, consts, and volatiles
	    }
	}
    }
  return nil;
}

- (NSMutableDictionary*) parseDeclIsSource: (BOOL)isSource
{
  CREATE_AUTORELEASE_POOL(arp);
  static NSSet		*qualifiers = nil;
  NSString		*baseType = nil;
  NSString		*declName = nil;
  NSMutableArray	*a1;
  NSMutableArray	*a2;
  NSString		*s;
  BOOL			isTypedef = NO;

  if (qualifiers == nil)
    {
      qualifiers = [NSSet setWithObjects:
	@"auto",
	@"const",
	@"extern",
	@"inline",
	@"long",
	@"register",
	@"short",
	@"signed",
	@"static",
	@"typedef",
	@"unsigned",
	@"volatile",
	nil];
      RETAIN(qualifiers);
    }

  a1 = [NSMutableArray array];
  a2 = [NSMutableArray array];
  while ((s = [self parseIdentifier]) != nil)
    {
      if ([s isEqualToString: @"static"] == YES)
	{
	  /*
	   * We don't want to document static declarations.
	   */
	  [self skipStatementLine];
	  goto fail;
	}
      if ([s isEqualToString: @"GS_EXPORT"] == YES)
	{
	  s = @"extern";
	}
      if ([qualifiers member: s] == nil)
	{
	  break;
	}
      else
	{
	  if ([s isEqualToString: @"typedef"] == YES)
	    {
	      isTypedef = YES;
	    }
	  [a1 addObject: s];
	}
    }

  baseType = s;
  if (baseType == nil)
    {
      /*
       * If there is no identifier here, the line must have been
       * something like 'unsigned *length' so we must set the default
       * base type of 'int'
       */
      baseType = @"int";
    }

  /**
   * We handle struct, union, and enum declarations by skipping the
   * stuff enclosed in curly braces.  If there was an identifier
   * after the keyword we use it as the struct name, otherwise we
   * use '...' to denote a nameless type.
   */
  if ([s isEqualToString: @"struct"] == YES
    || [s isEqualToString: @"union"] == YES
    || [s isEqualToString: @"enum"] == YES)
    {
      s = [self parseIdentifier];
      if (s == nil)
	{
	  baseType = [NSString stringWithFormat: @"%@ ...", baseType];
	}
      else
	{
	  baseType = [NSString stringWithFormat: @"%@ %@", baseType, s];
	}
      if ([self skipWhiteSpace] < length && buffer[pos] == '{')
	{
	  [self skipBlock];
	}
    }

  declName = [self parseDeclaratorInto: a2];
  if (declName == nil)
    {
      /*
       * If there is no identifier here, the line must have been
       * something like 'unsigned length' and we assumed that 'length'
       * was the base type rather than the declared name.
       * The fix is to set the base type to be 'int' and use the value
       * we had as the declaration name.
       */
      declName = baseType;
      baseType = @"int";
    }

  [a1 addObject: baseType];
  [a1 addObjectsFromArray: a2];

  if ([self skipWhiteSpace] < length)
    {
      if (buffer[pos] == '[')
	{
	  while (buffer[pos] == '[')
	    {
	      unsigned	old = pos;

	      if ([self skipArray] == old)
		{
		  break;
		}
	      [a1 addObject: @"[]"];
	    }
	}
      else if (buffer[pos] == '(')
	{
	  [self log: @"parse function '%@' of type '%@'",
	    declName, [a1 componentsJoinedByString: @" "]];
	  [self skipStatement];
	  RELEASE(arp);
	  return nil;
	}
    }

  if ([self skipWhiteSpace] < length)
    {
      if (buffer[pos] == ';')
	{
	  [self skipStatement];
	}
      else if (buffer[pos] == ',')
	{
	  [self log: @"ignoring multiple comma separated declarations"];
	  [self skipStatement];
	}
      else if (buffer[pos] == '=')
	{
	  [self skipStatement];
	}
      else if (buffer[pos] == '{')
	{
	  [self skipBlock];
	}
      else
	{
	  [self log: @"unexpected char (%c) parsing declaration", buffer[pos]];
	  goto fail;
	}

      /*
       * Read in any comment on the same line in case it
       * contains documentation for the declaration.
       */
      if ([self skipSpaces] < length && buffer[pos] == '/')
	{
	  [self skipComment];
	}

      if (inInstanceVariables == YES)
	{
	  NSMutableDictionary	*d;
	  NSString		*t;

	  t = [a1 componentsJoinedByString: @" "];
	  d = [[NSMutableDictionary alloc] initWithCapacity: 4];
	  [d setObject: declName forKey: @"Name"];
	  [d setObject: t forKey: @"Type"];
	  if (comment != nil)
	    {
	      [d setObject: comment forKey: @"Comment"];
	      DESTROY(comment);
	    }
	  RELEASE(arp);
	  return AUTORELEASE(d);
	}
      else if (isTypedef == YES)
	{
	  [self log: @"parse typedef '%@' of type '%@'",
	    declName, [a1 componentsJoinedByString: @" "]];
	}
      else
	{
	  [self log: @"parse variable/constant '%@' of type '%@'",
	    declName, [a1 componentsJoinedByString: @" "]];
	}
    }
  else
    {
      [self log: @"unexpected end of data parsing declaration"];
    }
fail:
  DESTROY(comment);
  RELEASE(arp);
  return nil;
}

- (NSMutableDictionary*) parseFile: (NSString*)name isSource: (BOOL)isSource
{
  NSString	*token;

  commentsRead = NO;
  fileName = name;
  if (declared == nil)
    {
      ASSIGN(declared, [fileName lastPathComponent]);
    }
  /**
   * If this is parsing a header file (isSource == NO) then we reset the
   * list of known source files associated with the header before proceeding.
   */
  [source removeAllObjects];
  if (isSource == NO)
    {
      [source removeAllObjects];
      [source addObject:
	[[[fileName lastPathComponent] stringByDeletingPathExtension]
	  stringByAppendingPathExtension: @"m"]];
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
	    [self skipPreprocessor];
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
	     * Must be some sort of declaration ...
	     */
	    // pos--;
	    // [self parseDeclIsSource: isSource];
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
  [self setStandards: dict];

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
  NSString		*visibility = @"private";
  NSMutableDictionary	*ivars;
  BOOL			shouldDocument = documentAllInstanceVariables;

  DESTROY(comment);

  inInstanceVariables = YES;

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
	      goto fail;
	    }
	  if ([token isEqual: @"private"] == YES)
	    {
	      ASSIGN(visibility, token);
	      shouldDocument = documentAllInstanceVariables;
	    }
	  else if ([token isEqual: @"protected"] == YES)
	    {
	      ASSIGN(visibility, token);
	      shouldDocument = YES;
	    }
	  else if ([token isEqual: @"public"] == YES)
	    {
	      ASSIGN(visibility, token);
	      shouldDocument = YES;
	    }
	  else
	    {
	      [self log: @"interface with bad visibility (%@)", token];
	      goto fail;
	    }
	}
      else if (buffer[pos] == '#')
	{
	  [self skipPreprocessor];	// Ignore preprocessor directive.
	  DESTROY(comment);
	}
      else if (shouldDocument == YES)
	{
	  NSMutableDictionary	*iv = [self parseDeclIsSource: NO];

	  if (iv != nil)
	    {
	      [iv setObject: visibility forKey: @"Visibility"];
	      [ivars setObject: iv forKey: [iv objectForKey: @"Name"]];
	    }
	}
      else
	{
	  [self skipStatement];
	}
    }

  inInstanceVariables = NO;

  if (pos >= length)
    {
      [self log: @"interface with bad instance variables"];
      return nil;
    }
  pos++;	// Step past closing bracket.
  return ivars;
fail:
  DESTROY(comment);
  inInstanceVariables = NO;
  return nil;
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
	      unsigned	saved = pos;

	      /*
	       * As a special case, try to cope with a method name separated
	       * from its body by a semicolon ... a common bug since the
	       * compiler doesn't pick it up!
	       */
	      if (term == '{' && buffer[pos] == ';')
		{
		  pos++;
		  if ([self skipWhiteSpace] >= length || buffer[pos] != term)
		    {
		      pos = saved;
		    }
		}
	      if (buffer[pos] == term)
		{
		  [self log: @"error in method definition ... "
		    @"semicolon after name"];
		}
	      else
		{
		  [self log: @"error parsing method name"];
		  goto fail;
		}
	    }
	}
      else
	{
	  unsigned	saved = pos;

	  /*
	   * As a special case, try to cope with a method name separated
	   * from its body by a semicolon ... a common bug since the
	   * compiler doesn't pick it up!
	   */
	  if (term == '{' && buffer[pos] == ';')
	    {
	      pos++;
	      if ([self skipWhiteSpace] >= length || buffer[pos] != term)
		{
		  pos = saved;
		}
	    }
	  if (buffer[pos] == term)
	    {
	      [self log: @"error in method definition ... "
		@"semicolon after name"];
	    }
	  else
	    {
	      [self log: @"error parsing method name"];
	      goto fail;
	    }
	}
    }

  [method setObject: mname forKey: @"Name"];
  if (flag == YES)
    {
      [self setStandards: method];
    }
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
	    else if ([token isEqual: @"class"] == YES)
	      {
		/*
		 * Pre-declaration of one or more classes ... rather like a
		 * normal C statement, it ends with a semicolon.
		 */
		[self skipStatementLine];
		return nil;
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
	    [self skipPreprocessor];
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
	  /*
	   * Remove any whitespace before an opening bracket.
	   */
	  if (ptr > start && ptr[-1] == ' ')
	    {
	      ptr--;
	    }
	  *ptr++ = '(';
	  nest++;
	}
      else if (c == ')')
	{
	  /*
	   * Remove any whitespace before a closing bracket.
	   */
	  if (ptr > start && ptr[-1] == ' ')
	    {
	      ptr--;
	    }
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
  [self setStandards: dict];
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

  [dict setObject: declared forKey: @"Declared"];

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
  [source removeAllObjects];
  [info removeAllObjects];
  haveSource = NO;
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

/**
 * Set the name of the file in which classes are to be documented as
 * being declared.  The default value of this is the last part of the
 * path of the source file being parsed.
 */
- (void) setDeclared: (NSString*)name
{
  ASSIGN(declared, name);
}

/**
 * This method is used to enable (or disable) documentation of all
 * instance variables.  If it is turned off, only those instance
 * variables that are explicitly declared 'public' or 'protected'
 * will be documented.
 */
- (void) setDocumentAllInstanceVariables: (BOOL)flag
{
  documentAllInstanceVariables = flag;
}

/**
 * Turn on or off parsing of preprocessor conditional compilation info
 * indicating the standards complied with.  When this is turned on, we
 * assume that all standards are complied with by default.<br />
 * You should only turn this on while parsing the GNUstep source code.
 */
- (void) setGenerateStandards: (BOOL)flag
{
  if (flag == NO)
    {
      DESTROY(ifStack);
    }
  else if (ifStack == nil)
    {
      ifStack = [[NSMutableArray alloc] initWithCapacity: 4];
      [ifStack addObject: [NSSet setWithObjects:
	@"OpenStep", @"MacOS-X", @"GNUstep", nil]];
    }
}

/**
 * Store the current standards information derived from preprocessor
 * conditionals in the supplied dictionary ... this will be used by
 * the AGSOutput class to put standards markup in the gsdoc output.
 */
- (void) setStandards: (NSMutableDictionary*)dict
{
  NSSet	*set = [ifStack lastObject];

  if ([set count] > 0)
    {
      NSMutableString	*s = nil;
      NSEnumerator	*e = [set objectEnumerator];
      NSString		*name;

      s = [NSMutableString stringWithCString: "<standards>"];
      while ((name = [e nextObject]) != nil)
	{
	  [s appendFormat: @"<%@ />", name];
	}
      [s appendString: @"</standards>"];
      [dict setObject: s forKey: @"Standards"];
    }
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
 * Skip until we encounter an ']' marking the end of an array.
 * Expect the current character position to be pointing to the
 * '[' at the start of an array.
 */
- (unsigned) skipArray
{
  pos++;
  while ([self skipWhiteSpace] < length)
    {
      unichar	c = buffer[pos++];

      switch (c)
	{
	  case '#':		// preprocessor directive.
	    [self skipPreprocessor];
	    break;

	  case '\'':
	  case '"':
	    pos--;
	    [self skipLiteral];
	    break;

	  case '[':
	    pos--;
	    [self skipArray];
	    break;

	  case ']':
	    return pos;
        }
    }
  return pos;
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
	    [self skipPreprocessor];
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
 * When the data provided by a comment is appended to the data
 * stored in the 'comment' instance variable, a line break (&lt;br /&gt;)is
 * automatically forced to separate it from the proceding info.<br />
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
		  tmp = [comment stringByAppendingFormat: @"<br />\n%@", tmp];
		}
	      ASSIGN(comment, tmp);
	    }

	  if (commentsRead == NO && comment != nil)
	    {
	      unsigned		commentLength = [comment length];
	      NSMutableArray	*authors;
	      NSEnumerator	*enumerator;
	      NSArray		*keys;
	      NSString		*key;

	      authors = (NSMutableArray*)[info objectForKey: @"authors"];
	      /*
	       * Scan through for more authors
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
			  if ([authors containsObject: author] == NO)
			    {
			      [authors addObject: author];
			    }
			}
		      else
			{
			  [self log: @"unterminated <author> in comment"];
			}
		    }
		}
	      /*
	       * In addition to fully specified author elements in the
	       * comment, we look for lines of the formats -
	       * Author: name <email>
	       * Author: name
	       * By: name <email>
	       * By: name
	       */
	      r = NSMakeRange(0, commentLength);
	      while (r.length > 0)
		{
		  NSString	*term = @"\n";
		  NSRange	a;
		  NSRange	b;

		  /*
		   * Look for 'Author:' or 'By:' and use whichever we
		   * find first.
		   */
		  a = [comment rangeOfString: @"author:"
				     options: NSCaseInsensitiveSearch
				       range: r];
		  b = [comment rangeOfString: @"by:"
				     options: NSCaseInsensitiveSearch
				       range: r];
		  if (a.length > 0)
		    {
		      if (b.length > 0 && b.location < a.location)
			{
			  r = b;
			}
		      else
			{
			  r = a;
			  /*
			   * A line '$Author$' is an RCS tag and is
			   * terminated by the second dollar rather than
			   * by a newline.
			   */
			  if (r.location > 0
			    && [comment characterAtIndex: r.location-1] == '$')
			    {
			      term = @"$";
			    }
			}
		    }
		  else
		    {
		      r = b;
		    }

		  if (r.length > 0)
		    {
		      unsigned	i = NSMaxRange(r);
		      NSString	*line;
		      NSString	*author;

		      r = NSMakeRange(i, commentLength - i);
		      r = [comment rangeOfString: term
					 options: NSLiteralSearch
					   range: r];
		      if (r.length == 0)
			{
			  r.location = commentLength;
			}
		      r = NSMakeRange(i, NSMaxRange(r) - i);
		      line = [comment substringWithRange: r];
		      line = [line stringByTrimmingSpaces];
		      i = NSMaxRange(r);
		      r = [line rangeOfString: @"<"];
		      if (r.length > 0)
			{
			  NSString	*name;
			  NSString	*mail;

			  name = [line substringToIndex: r.location];
			  name = [name stringByTrimmingSpaces];
			  mail = [line substringFromIndex: r.location+1];
			  r = [mail rangeOfString: @">"];
			  if (r.length > 0)
			    {
			      mail = [mail substringToIndex: r.location];
			    }
			  author = [NSString stringWithFormat:
			    @"<author name=\"%@\"><email address=\"%@\">"
			    @"%@</email></author>", name, mail, mail];
			}
		      else
			{
			  author = [NSString stringWithFormat:
			    @"<author name=\"%@\"></author>", line];
			}
		      r = NSMakeRange(i, commentLength - i);
		      if (authors == nil)
			{
			  authors = [NSMutableArray new];
			  [info setObject: authors forKey: @"authors"];
			  RELEASE(authors);
			}
		      if ([authors containsObject: author] == NO)
			{
			  [authors addObject: author];
			}
		    }
		}

	      /*
	       * Lines of the form 'AutogsdocSource: ...' are used as the
	       * names of source files to provide documentation information.
	       * whitespace around a filename is stripped.
	       */
	      r = NSMakeRange(0, commentLength);
	      while (r.length > 0)
		{
		  /*
		   * Look for 'AtogsdocSource:' lines.
		   */
		  r = [comment rangeOfString: @"AutogsdocSource:"
				     options: NSCaseInsensitiveSearch
				       range: r];
		  if (r.length > 0)
		    {
		      unsigned	i = NSMaxRange(r);
		      NSString	*line;

		      r = NSMakeRange(i, commentLength - i);
		      r = [comment rangeOfString: @"\n"
					 options: NSLiteralSearch
					   range: r];
		      if (r.length == 0)
			{
			  r.location = commentLength;
			}
		      r = NSMakeRange(i, NSMaxRange(r) - i);
		      line = [comment substringWithRange: r];
		      line = [line stringByTrimmingSpaces];
		
		      if ([line length] > 0
			&& [source containsObject: line] == NO)
			{
			  if (haveSource == NO)
			    {
			      [source removeAllObjects]; // remove default.
			    }
			  [source addObject: line];
			  haveSource = YES;
			}
		      i = NSMaxRange(r);
		      r = NSMakeRange(i, commentLength - i);
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
	       * If no <copy> ... </copy> then try Copyright:
	       */
	      if ([info objectForKey: @"copy"] == nil)
		{
		  r = NSMakeRange(0, commentLength);
		  while (r.length > 0)
		    {
		      /*
		       * Look for 'Copyright:'
		       */
		      r = [comment rangeOfString: @"copyright (c)"
					 options: NSCaseInsensitiveSearch
					   range: r];
		      if (r.length > 0)
			{
			  unsigned	i = NSMaxRange(r);
			  NSString	*line;

			  r = NSMakeRange(i, commentLength - i);
			  r = [comment rangeOfString: @"\n"
					     options: NSLiteralSearch
					       range: r];
			  if (r.length == 0)
			    {
			      r.location = commentLength;
			    }
			  r = NSMakeRange(i, NSMaxRange(r) - i);
			  line = [comment substringWithRange: r];
			  line = [line stringByTrimmingSpaces];
			  line = [NSString stringWithFormat:
			    @"<copy>%@</copy>", line];
			  [info setObject: line forKey: @"copy"];
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

/**
 * Skip past a preprocessor statement, handling preprocessor
 * conditionals in a rudimentary way.  We keep track of the
 * level of conditional nesting, and we also track the use of
 * #ifdef and #ifndef with some well-known constants to tell
 * us which standards are currently supported.
 */
- (unsigned) skipPreprocessor
{
  /*
   * If we are not doing preprocessor handling ... just skip to end of line.
   */
  if (ifStack == nil)
    {
      return [self skipRemainderOfLine];
    }

  while (pos < length && [spaces characterIsMember: buffer[pos]] == YES)
    {
      pos++;
    }
  if (pos < length && buffer[pos] != '\n')
    {
      NSString	*directive = [self parseIdentifier];

      if ([directive isEqual: @"endif"] == YES)
	{
	  if ([ifStack count] <= 1)
	    {
	      [self log: @"Unexpected #endif (no matching #if)"];
	    }
	  else
	    {
	      [ifStack removeLastObject];
	    }
	}
      else if ([directive isEqual: @"elif"] == YES)
	{
	  if ([ifStack count] <= 1)
	    {
	      [self log: @"Unexpected #else (no matching #if)"];
	    }
	  else
	    {
	      [ifStack removeLastObject];
	      [ifStack addObject: [ifStack lastObject]];
	    }
	}
      else if ([directive isEqual: @"else"] == YES)
	{
	  if ([ifStack count] <= 1)
	    {
	      [self log: @"Unexpected #else (no matching #if)"];
	    }
	  else
	    {
	      [ifStack removeLastObject];
	      [ifStack addObject: [ifStack lastObject]];
	    }
	}
      else if ([directive isEqual: @"if"] == YES)
	{
	  [ifStack addObject: [ifStack lastObject]];
	}
      else if ([directive hasPrefix: @"if"] == YES)
	{
	  BOOL	isIfDef = [directive isEqual: @"ifdef"];

	  while (pos < length && [spaces characterIsMember: buffer[pos]] == YES)
	    {
	      pos++;
	    }
	  if (pos < length && buffer[pos] != '\n')
	    {
	      NSMutableSet	*set = [[ifStack lastObject] mutableCopy];
	      NSString		*arg = [self parseIdentifier];

	      if ([arg isEqual: @"NO_GNUSTEP"] == YES)
		{
		  if (isIfDef == YES)
		    {
		      [self log: @"Unexpected #ifdef NO_GNUSTEP (nonsense)"];
		    }
		  else
		    {
		      [set removeObject: @"MacOS-X"];
		      [set addObject: @"NotMacOS-X"];
		      [set removeObject: @"OpenStep"];
		      [set addObject: @"NotOpenStep"];
		    }
		}
	      else if ([arg isEqual: @"STRICT_MACOS_X"] == YES)
		{
		  if (isIfDef == YES)
		    {
		      [set removeObject: @"NotMacOS-X"];
		      [set addObject: @"MacOS-X"];
		    }
		  else
		    {
		      [set removeObject: @"MacOS-X"];
		      [set addObject: @"NotMacOS-X"];
		    }
		}
	      else if ([arg isEqual: @"STRICT_OPENSTEP"] == YES)
		{
		  if (isIfDef == YES)
		    {
		      [set removeObject: @"NotOpenStep"];
		      [set addObject: @"OpenStep"];
		    }
		  else
		    {
		      [set removeObject: @"OpenStep"];
		      [set addObject: @"NotOpenStep"];
		    }
		}
	      [ifStack addObject: set];
	      RELEASE(set);
	    }
	}
    }
  while (pos < length)
    {
      if (buffer[pos++] == '\n')
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
	    [self skipPreprocessor];
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
	    [self skipPreprocessor];
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

- (NSArray*) source
{
  return AUTORELEASE([source copy]);
}
@end

