/** 

   <title>AGSIndex ... a class to create references for a gsdoc file</title>
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

#include	<Foundation/Foundation.h>
#include        "AGSIndex.h"

static int      XML_ELEMENT_NODE;
static int      XML_TEXT_NODE;

static void
mergeDictionaries(NSMutableDictionary *dst, NSDictionary *src, BOOL override)
{
  static NSMutableArray	*stack = nil;
  NSEnumerator	*e = [src keyEnumerator];
  NSString	*k;
  id		s;
  id		d;

  if (stack == nil)
    {
      stack = [[NSMutableArray alloc] initWithCapacity: 8];
    }
  while ((k = [e nextObject]) != nil)
    {
      if ([k isEqualToString: @"contents"] == YES)
	{
	  continue;	// Makes no sense to merge file contents.
	}
      s = [src objectForKey: k];
      d = [dst objectForKey: k];

      [stack addObject: k];
      if (d == nil)
	{
	  if ([s isKindOfClass: [NSString class]] == YES)
	    {
	      [dst setObject: s forKey: k];
	    }
	  else if ([s isKindOfClass: [NSDictionary class]] == YES)
	    {
	      d = [[NSMutableDictionary alloc] initWithCapacity: [s count]];
	      [dst setObject: d forKey: k];
	      RELEASE(d);
	    }
	  else
	    {
	      NSLog(@"Unexpected class in merge %@ ignored", stack);
	      d = nil;
	    }
	}
      if (d != nil)
	{
	  if ([d isKindOfClass: [NSString class]] == YES)
	    {
	      if ([s isKindOfClass: [NSString class]] == NO)
		{
		  NSLog(@"Class missmatch in merge for %@.", stack);
		}
	      else if ([d isEqual: s] == NO)
		{
		  if (override == YES)
		    {
		      [dst setObject: s forKey: k];
		    }
		  else
		    {
		      NSLog(@"String missmatch in merge for %@. S:%@, D:%@",
			stack, s, d);
		    }
		}
	    }
	  else if ([d isKindOfClass: [NSDictionary class]] == YES)
	    {
	      if ([s isKindOfClass: [NSDictionary class]] == NO)
		{
		  NSLog(@"Class missmatch in merge for %@.", stack);
		}
	      else
		{
		  mergeDictionaries(d, s, override);
		}
	    }
	}
      [stack removeLastObject];
    }
}

static void
setDirectory(NSMutableDictionary *dict, NSString *path)
{
  NSArray	*a = [dict allKeys];
  NSEnumerator	*e = [a objectEnumerator];
  NSString	*k;

  while ((k = [e nextObject]) != nil)
    {
      id	o = [dict objectForKey: k];

      if ([o isKindOfClass: [NSString class]] == YES)
	{
	  o = [path stringByAppendingPathComponent: [o lastPathComponent]];
	  [dict setObject: o forKey: k];
	}
      else if ([o isKindOfClass: [NSDictionary class]] == YES)
	{
	  setDirectory(o, path);
	}
    }
}

/**
 * This class is used to build and manipulate a dictionary of
 * cross-reference information.<br />
 * The references are held in a tree consisting of dictionaries
 * with strings at the leaves -<br />
 * method method-name class-name file-name<br />
 * method method-name category-name file-name<br />
 * method method-name protocol-name file-name<br />
 * ivariable variable-name class-name file-name<br />
 * class class-name file-name<br />
 * category category-name file-name<br />
 * protocol protocol-name file-name<br />
 * function function-name file-name<br />
 * type type-name file-name<br />
 * constant constant-name file-name<br />
 * variable variable-name file-name<br />
 * entry entry-name file-name ref<br />
 * label label-name file-name ref<br />
 * contents ref text<br />
 * super class-name superclass-name<br />
 * title file-name text<br />
 */
@implementation	AGSIndex

+ (void) initialize
{
  if (self == [AGSIndex class])
    {
      /*
       * Cache XML node information.
       */
      XML_ELEMENT_NODE = [GSXMLNode typeFromDescription: @"XML_ELEMENT_NODE"];
      XML_TEXT_NODE = [GSXMLNode typeFromDescription: @"XML_TEXT_NODE"];
    }
}

- (void) dealloc
{
  RELEASE(refs);
  [super dealloc];
}

- (NSString*) globalRef: (NSString*)ref type: (NSString*)type
{
  NSDictionary	*t;

  t = [refs objectForKey: type];
  return [t objectForKey: ref];
}

- (id) init
{
  refs = [[NSMutableDictionary alloc] initWithCapacity: 8];
  return self;
}

/**
 * Given the root node of a gsdoc document, we traverse the tree
 * looking for interesting nodes, and recording their names in a
 * dictionary of references.
 */
- (void) makeRefs: (GSXMLNode*)node
{
  GSXMLNode	*children = [node children];
  GSXMLNode	*next = [node next];
  BOOL		newUnit = NO;

  if ([node type] == XML_ELEMENT_NODE)
    {
      NSString		*name = [node name];
      NSDictionary	*prop = [node propertiesAsDictionary];

      if ([name isEqual: @"category"] == YES)
	{
	  newUnit = YES;
	  unit = [NSString stringWithFormat: @"%@(%@)",
	    [prop objectForKey: @"class"], [prop objectForKey: @"name"]];

	  [self setGlobalRef: unit type: @"category"];
	}
      else if ([name isEqual: @"chapter"] == YES)
	{
	  chap++;
	  sect = 0;
	  ssect = 0;
	  sssect = 0;
	}
      else if ([name isEqual: @"class"] == YES)
	{
	  NSString	*tmp;

	  newUnit = YES;
	  unit = [prop objectForKey: @"name"];
	  tmp = [prop objectForKey: @"super"];
	  if (tmp != nil)
	    {
	      NSMutableDictionary	*t;

	      t = [refs objectForKey: @"super"];
	      if (t == nil)
		{
		  t = [NSMutableDictionary new];
		  [refs setObject: t forKey: @"super"];
		  RELEASE(t);
		}
	      [t setObject: tmp forKey: unit];
	    }
	  [self setGlobalRef: unit type: @"class"];
	}
      else if ([name isEqual: @"gsdoc"] == YES)
	{
	  base = [prop objectForKey: @"base"];
	  if (base == nil)
	    {
	      NSLog(@"No 'base' document name supplied in gsdoc element");
	      return;
	    }
	}
      else if ([name isEqual: @"heading"] == YES)
	{
	  NSMutableDictionary	*d;
	  NSString		*k;

	  d = [refs objectForKey: @"contents"];
	  if (d == nil)
	    {
	      d = [[NSMutableDictionary alloc] initWithCapacity: 8];
	      [refs setObject: d forKey: @"contents"];
	      RELEASE(d);
	    }

          k = [NSString stringWithFormat: @"%03u%03u%03u%03u",
	    chap, sect, ssect, sssect];
	  [d setObject: [[children content] stringByTrimmingSpaces] forKey: k];
	  children = nil;
	}
      else if ([name isEqual: @"ivariable"] == YES)
	{
	  NSString	*tmp = [prop objectForKey: @"name"];

	  [self setUnitRef: tmp type: name];
	}
      else if ([name isEqual: @"entry"] || [name isEqual: @"label"])
	{
	  NSMutableDictionary	*all;
	  NSMutableDictionary	*byFile;
	  NSString		*text;
	  NSString		*val;

	  text = [[children content] stringByTrimmingSpaces];
	  children = nil;
	  all = [refs objectForKey: name];
	  if (all == nil)
	    {
	      all = [[NSMutableDictionary alloc] initWithCapacity: 8];
	      [refs setObject: all forKey: name];
	      RELEASE(all);
	    }
	  byFile = [all objectForKey: base];
	  if (byFile == nil)
	    {
	      byFile = [[NSMutableDictionary alloc] initWithCapacity: 2];
	      [all setObject: byFile forKey: base];
	      RELEASE(byFile);
	    }
	  val = [prop objectForKey: @"id"];
	  if (val == nil)
	    {
	      val = text;
	    }
	  [byFile setObject: val forKey: @"text"];
	}
      else if ([name isEqual: @"method"] == YES)
	{
	  NSString	*sel = @"";
	  GSXMLNode	*tmp = children;

	  sel = [prop objectForKey: @"factory"];
	  if (sel != nil && [sel boolValue] == YES)
	    {
	      sel = @"+";
	    }
	  else
	    {
	      sel = @"-";
	    }
	  children = nil;
	  while (tmp != nil)
	    {
	      if ([tmp type] == XML_ELEMENT_NODE)
		{
		  if ([[tmp name] isEqual: @"sel"] == YES)
		    {
		      GSXMLNode	*t = [tmp children];

		      while (t != nil)
			{
			  if ([t type] == XML_TEXT_NODE)
			    {
			      sel = [sel stringByAppendingString:
				[[t content] stringByTrimmingSpaces]];
			    }
			  t = [t next];
			}
		    }
		  else if ([[tmp name] isEqual: @"arg"] == NO)
		    {
		      children = tmp;
		      break;
		    }
		  else if ([[tmp name] isEqual: @"vararg"] == YES)
		    {
		      sel = [sel stringByAppendingString: @",..."];
		      children = [tmp next];
		      break;
		    }
		}
	      tmp = [tmp next];
	    }
	  if ([sel length] > 1)
	    {
	      [self setUnitRef: sel type: name];
	    }
	}
      else if ([name isEqual: @"protocol"] == YES)
	{
	  newUnit = YES;
	  unit = [NSString stringWithFormat: @"(%@)",
	    [prop objectForKey: @"name"]];
	  [self setGlobalRef: unit type: @"protocol"];
	}
      else if ([name isEqual: @"constant"] == YES
	|| [name isEqual: @"EOEntity"] == YES
	|| [name isEqual: @"EOModel"] == YES
	|| [name isEqual: @"function"] == YES
	|| [name isEqual: @"macro"] == YES
	|| [name isEqual: @"type"] == YES
	|| [name isEqual: @"variable"] == YES)
	{
	  NSString	*tmp = [prop objectForKey: @"name"];

	  [self setGlobalRef: tmp type: name];
	}
      else if ([name isEqual: @"section"] == YES)
	{
	  sect++;
	  ssect = 0;
	  sssect = 0;
	}
      else if ([name isEqual: @"subsect"] == YES)
	{
	  ssect++;
	  sssect = 0;
	}
      else if ([name isEqual: @"subsubsect"] == YES)
	{
	  sssect++;
	}
      else if ([name isEqual: @"title"] == YES)
	{
	  NSMutableDictionary	*d;

	  d = [refs objectForKey: @"title"];
	  if (d == nil)
	    {
	      d = [[NSMutableDictionary alloc] initWithCapacity: 8];
	      [refs setObject: d forKey: @"title"];
	      RELEASE(d);
	    }

	  [d setObject: [[children content] stringByTrimmingSpaces]
		forKey: base];
	  children = nil;
	}
      else
	{
	}
    }

  if (children != nil)
    {
      [self makeRefs: children];
    }
  if (newUnit == YES)
    {
      unit = nil;
    }
  if (next != nil)
    {
      [self makeRefs: next];
    }
}

/**
 * Merge a dictionary containing references into the current
 * index.   The flag may be used to specify that references
 * being merged in should override any pre-existing values.
 */ 
- (void) mergeRefs: (NSDictionary*)more override: (BOOL)flag
{
  mergeDictionaries(refs, more, flag);
}

- (NSMutableArray*) methodsInUnit: (NSString*)aUnit
{
  NSDictionary		*d = [refs objectForKey: @"method"];
  NSEnumerator		*e = [d keyEnumerator];
  NSMutableArray	*a = [NSMutableArray array];
  NSString		*k;

  while ((k = [e nextObject]) != nil)
    {
      NSDictionary	*m = [d objectForKey: k];

      if ([m objectForKey: aUnit] != nil)
	{
	  [a addObject: k];
	}
    }
  return a;
}

- (NSMutableDictionary*) refs
{
  return refs;
}

- (void) setDirectory: (NSString*)path
{
  if (path != nil)
    {
      CREATE_AUTORELEASE_POOL(pool);
      setDirectory(refs, path);
      RELEASE(pool);
    }
}

- (void) setGlobalRef: (NSString*)ref
		 type: (NSString*)type
{
  NSMutableDictionary	*t;
  NSString		*old;

  t = [refs objectForKey: type];
  if (t == nil)
    {
      t = [NSMutableDictionary new];
      [refs setObject: t forKey: type];
      RELEASE(t);
    }
  old = [t objectForKey: ref];
  if (old != nil && [old isEqual: base] == NO)
    {
      NSLog(@"Warning ... %@ %@ appears in %@ and %@ ... using the latter",
	type, ref, old, base);
    }
  [t setObject: base forKey: ref];
}

- (void) setUnitRef: (NSString*)ref
	       type: (NSString*)type
{
  NSMutableDictionary	*t;
  NSMutableDictionary	*r;
  NSString		*old;

  t = [refs objectForKey: type];
  if (t == nil)
    {
      t = [NSMutableDictionary new];
      [refs setObject: t forKey: type];
      RELEASE(t);
    }
  r = [t objectForKey: ref];
  if (r == nil)
    {
      r = [NSMutableDictionary new];
      [t setObject: r forKey: ref];
      RELEASE(r);
    }
  old = [r objectForKey: unit];
  if (old != nil && [old isEqual: base] == NO)
    {
      NSLog(@"Warning ... %@ %@ %@ appears in %@ and %@ ... using the latter",
	type, ref, unit, old, base);
    }
  [r setObject: base forKey: unit];
}

/**
 * Return a dictionary containing info on all the units containing the
 * specified method or instance variable.
 */
- (NSDictionary*) unitRef: (NSString*)ref type: (NSString*)type
{
  NSDictionary	*t;

  t = [refs objectForKey: type];
  return [t objectForKey: ref];
}

/**
 * Return the name of the file containing the ref and return
 * the unit name in which it was found.  If not found, return nil for both.
 */
- (NSString*) unitRef: (NSString*)ref type: (NSString*)type unit: (NSString**)u
{
  NSString	*s;
  NSDictionary	*t;

  /**
   * If ref does not occur in the index, this method returns nil.
   */
  t = [self unitRef: ref type: type];
  if (t == nil)
    {
      *u = nil;
      return nil;
    }

  if (*u == nil)
    {
      /**
       * If the method was given no unit to look in, then it will succeed
       * and return a value if (and only if) the required reference is
       * defined only in one unit.
       */
      if ([t count] == 1)
	{
	  *u = [[t allKeys] lastObject];
	  return [t objectForKey: *u];
	}
      return nil;
    }

  /**
   * If ref exists in the unit specified, the method will succeed and
   * return the name of the file in which the reference is located.
   */
  s = [t objectForKey: *u];
  if (s != nil)
    {
      return s;
    }

  /**
   * If the unit that the method has been asked to look in is a
   * category or protocol which is not found, the lookup must fail.
   */
  if ([t objectForKey: *u] == nil
    && ([*u length] == 0 || [*u characterAtIndex: [*u length] - 1] == ')'))
    {
      *u = nil;
      return nil;
    }

  /**
   * If the unit is a class, and ref was not found in it, then this
   * method will succeed if ref can be found in any superclass of the class.
   */
  while (*u != nil)
    {
      *u = [self globalRef: *u type: @"super"];
      if (*u != nil)
	{
	  s = [t objectForKey: *u];
	  if (s != nil)
	    {
	      return s;
	    }
	}
    }

  return nil;
}

@end

