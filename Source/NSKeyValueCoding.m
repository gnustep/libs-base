/** Implementation of KeyValueCoding for GNUStep
   Copyright (C) 2000,2002 Free Software Foundation, Inc.
   
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSKeyValueCoding informal protocol reference</title>
   $Date$ $Revision$
   */ 

#include <config.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSMethodSignature.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSException.h>
#include <Foundation/NSZone.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSKeyValueCoding.h>
#include <Foundation/NSNull.h>


/**
 * This describes an informal protocol for key-value coding.
 * The basic methods are implemented as a category of the NSObject class,
 * but other classes override those default implementations to perform
 * more specific operations.
 */
@implementation NSObject (KeyValueCoding)

+ (BOOL) accessInstanceVariablesDirectly
{
  return YES;
}

+ (BOOL) useStoredAccessor
{
  return YES;
}

- (id) handleQueryWithUnboundKey: (NSString*)aKey
{
  [NSException raise: NSGenericException
	      format: @"%@ -- %@ 0x%x: Unable to find value for key \"%@\"",
    NSStringFromSelector(_cmd), NSStringFromClass([self class]), self, aKey];

  return nil;
}

- (void) handleTakeValue: (id)anObject forUnboundKey: (NSString*)aKey
{
  [NSException raise: NSGenericException
	      format: @"%@ -- %@ 0x%x: Unable set value \"%@\" for key \"%@\"",
    NSStringFromSelector(_cmd), NSStringFromClass([self class]),
    self, anObject, aKey];
}

- (id) storedValueForKey: (NSString*)aKey
{
  unsigned	size;

  if ([[self class] useStoredAccessor] == NO)
    {
      return [self valueForKey: aKey];
    }

  size = [aKey cStringLength];
  if (size < 1)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"storedValueForKey: ... empty key"];
      return NO;	// avoid compiler warnings.
    }
  else
    {
      SEL		sel = 0;
      const char	*type = NULL;
      unsigned		off;
      const char	*name;
      char		buf[size+5];
      char		lo;
      char		hi;

      strcpy(buf, "_get");
      [aKey getCString: &buf[4]];
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;

      name = buf;	// _getKey
      sel = sel_get_any_uid(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  buf[3] = '_';
	  buf[4] = lo;
	  name = &buf[3]; // _key
	  sel = sel_get_any_uid(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      sel = 0;
	    }     
	}
      if (sel == 0)
	{
	  if ([[self class] accessInstanceVariablesDirectly] == YES)
	    {
	      // _key
	      if (GSFindInstanceVariable(self, name, &type, &size, &off) == NO)
		{
		  name = &buf[4]; // key
		  GSFindInstanceVariable(self, name, &type, &size, &off);
		}
	    }
	  if (type == NULL)
	    {
	      buf[3] = 't';
	      buf[4] = hi;
	      name = &buf[1]; // getKey
	      sel = sel_get_any_uid(name);
	      if (sel == 0 || [self respondsToSelector: sel] == NO)
		{
		  buf[4] = lo;
		  name = &buf[4];	// key
		  sel = sel_get_any_uid(name);
		  if (sel == 0 || [self respondsToSelector: sel] == NO)
		    {
		      sel = 0;
		    }
		}
	    }
	}
      return GSGetValue(self, aKey, sel, type, size, off);
    }
}

- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey
{
  unsigned	size;

  if ([[self class] useStoredAccessor] == NO)
    {
      [self takeValue: anObject forKey: aKey];
      return;
    }

  size = [aKey length];
  if (size < 1)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"takeStoredValue:forKey: ... empty key"];
    }
  else
    {
      SEL		sel;
      const char	*type;
      int		off;
      const char	*name;
      char		buf[size+6];
      char		lo;
      char		hi;

      strcpy(buf, "_set");
      [aKey getCString: &buf[4]];
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;
      buf[size+4] = ':';

      name = buf;	// _setKey:
      type = NULL;
      sel = GSSelectorFromName(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  sel = 0;
	  if ([[self class] accessInstanceVariablesDirectly] == YES)
	    {
	      buf[size+4] = '\0';
	      buf[4] = lo;
	      buf[3] = '_';
	      name = &buf[3];		// _key
	      if (GSFindInstanceVariable(self, name, &type, &size, &off) == NO)
		{
		  name = &buf[4];	// key
		  GSFindInstanceVariable(self, name, &type, &size, &off);
		}
	    }
	  if (type == NULL)
	    {
	      buf[size+4] = ':';
	      buf[4] = hi;
	      buf[3] = 't';
	      name = &buf[1];		// setKey:
	      sel = GSSelectorFromName(name);
	      if (sel == 0 || [self respondsToSelector: sel] == NO)
		{
		  sel = 0;
		}
	    }
	}
      GSSetValue(self, aKey, anObject, sel, type, size, off);
   }
}

- (void) takeValue: (id)anObject forKey: (NSString*)aKey
{
  unsigned	size;

  size = [aKey length];
  if (size < 1)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"takeValue:forKey: ... empty key"];
    }
  else
    {
      SEL		sel;
      const char	*type;
      int		off;
      const char	*name;
      char		buf[size+6];
      char		lo;
      char		hi;

      strcpy(buf, "_set");
      [aKey getCString: &buf[4]];
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;
      buf[size+4] = ':';

      name = &buf[1];	// setKey:
      type = NULL;
      sel = GSSelectorFromName(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  name = buf;	// _setKey:
	  sel = GSSelectorFromName(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      sel = 0;
	      if ([[self class] accessInstanceVariablesDirectly] == YES)
		{
		  buf[size+4] = '\0';
		  buf[3] = '_';
		  buf[4] = lo;
		  name = &buf[3];	// _key
		  if (GSFindInstanceVariable(self, name, &type, &size, &off)
		    == NO)
		    {
		      name = &buf[4];	// key
		      GSFindInstanceVariable(self, name, &type, &size, &off);
		    }
		}
	    }
	}
      GSSetValue(self, aKey, anObject, sel, type, size, off);
    }
}

- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey
{
  NSRange	r = [aKey rangeOfString: @"."];

  if (r.length == 0)
    {
      [self takeValue: anObject forKey: aKey];
    }
  else
    {
      NSString	*key = [aKey substringToIndex: r.location];
      NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];

      [[self valueForKey: key] takeValue: anObject forKeyPath: path];
    }
}

- (void) takeValuesFromDictionary: (NSDictionary*)aDictionary
{
  NSEnumerator	*enumerator = [aDictionary keyEnumerator];
  NSNull	*null = [NSNull null];
  NSString	*key;

  while ((key = [enumerator nextObject]) != nil)
    {
      id	obj = [aDictionary objectForKey: key];

      if (obj == null)
	{
	  obj = nil;
	}
      [self takeValue: obj forKey: key];
    }
}

- (void) unableToSetNilForKey: (NSString*)aKey
{
  [NSException raise: NSInvalidArgumentException
	      format: @"%@ -- %@ 0x%x: Given nil value to set for key \"%@\"",
    NSStringFromSelector(_cmd), NSStringFromClass([self class]), self, aKey];
}

- (id) valueForKey: (NSString*)aKey
{
  unsigned	size;

  size = [aKey length];
  if (size < 1)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"valueForKey: ... empty key"];
      return nil;
    }
  else
    {
      SEL		sel = 0;
      const char	*type = NULL;
      unsigned		off;
      const char	*name;
      char		buf[size+5];
      char		lo;
      char		hi;

      strcpy(buf, "_get");
      [aKey getCString: &buf[4]];
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;

      name = &buf[1];	// getKey
      sel = GSSelectorFromName(name);
      if (sel == 0 || [self respondsToSelector: sel] == NO)
	{
	  buf[4] = lo;
	  name = &buf[4];	// key
	  sel = GSSelectorFromName(name);
	  if (sel == 0 || [self respondsToSelector: sel] == NO)
	    {
	      buf[4] = hi;
	      name = buf;	// _getKey
	      sel = GSSelectorFromName(name);
	      if (sel == 0 || [self respondsToSelector: sel] == NO)
		{
		  buf[4] = lo;
		  buf[3] = '_';
		  name = &buf[3];	// _key
		  sel = GSSelectorFromName(name);
		  if (sel == 0 || [self respondsToSelector: sel] == NO)
		    {
		      sel = 0;
		    }
		}
	    }
	}

      if (sel == 0 && [[self class] accessInstanceVariablesDirectly] == YES)
	{
	  buf[4] = lo;
	  buf[3] = '_';
	  name = &buf[3];	// _key
	  if (GSFindInstanceVariable(self, name, &type, &size, &off) == NO)
	    {
	      name = &buf[4];	// key
	      GSFindInstanceVariable(self, name, &type, &size, &off);
	    }
	}
      return GSGetValue(self, aKey, sel, type, size, off);
    }
}

- (id) valueForKeyPath: (NSString*)aKey
{
  NSRange	r = [aKey rangeOfString: @"."];
  id		o;

  if (r.length == 0)
    {
      o = [self valueForKey: aKey];
    }
  else
    {
      NSString	*key = [aKey substringToIndex: r.location];
      NSString	*path = [aKey substringFromIndex: NSMaxRange(r)];

      o = [[self valueForKey: key] valueForKeyPath: path];
    }
  return o;
}

- (NSDictionary*) valuesForKeys: (NSArray*)keys
{
  NSMutableDictionary	*dict;
  NSNull		*null = [NSNull null];
  unsigned		count = [keys count];
  unsigned		pos;

  dict = [NSMutableDictionary dictionaryWithCapacity: count];
  for (pos = 0; pos < count; pos++)
    {
      NSString	*key = [keys objectAtIndex: pos];
      id 	val = [self valueForKey: key];

      if (val == nil)
	{
	  val = null;
	}
      [dict setObject: val forKey: key];
    }
  return AUTORELEASE([dict copy]);
}

@end

