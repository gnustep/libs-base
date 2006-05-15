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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   <title>NSKeyValueCoding informal protocol reference</title>
   $Date$ $Revision$
   */

#include "config.h"
#include "Foundation/NSObject.h"
#include "Foundation/NSMethodSignature.h"
#include "Foundation/NSAutoreleasePool.h"
#include "Foundation/NSString.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSException.h"
#include "Foundation/NSZone.h"
#include "Foundation/NSDebug.h"
#include "Foundation/NSObjCRuntime.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSKeyValueCoding.h"
#include "Foundation/NSNull.h"

NSString* const NSUndefinedKeyException = @"NSUndefinedKeyException";


static void
SetValueForKey(NSObject *self, id anObject, const char *key, unsigned size)
{
  SEL		sel = 0;
  const char	*type = 0;
  int		off;

  if (size > 0)
    {
      const char	*name;
      char		buf[size+6];
      char		lo;
      char		hi;

      strcpy(buf, "_set");
      strcpy(&buf[4], key);
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;
      buf[size+4] = ':';
      buf[size+5] = '\0';

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
		  if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		    {
		      buf[4] = hi;
		      buf[3] = 's';
		      buf[2] = 'i';
		      buf[1] = '_';
		      name = &buf[1];	// _isKey
		      if (GSObjCFindVariable(self,
			name, &type, &size, &off) == NO)
			{
			  buf[4] = lo;
			  name = &buf[4];	// key
			  if (GSObjCFindVariable(self,
			    name, &type, &size, &off) == NO)
			    {
			      buf[4] = hi;
			      buf[3] = 's';
			      buf[2] = 'i';
			      name = &buf[2];	// isKey
			      GSObjCFindVariable(self,
				name, &type, &size, &off);
			    }
			}
		    }
		}
	    }
	  else
	    {
	      GSOnceFLog(@"Key-value access using _setKey: isdeprecated:");
	    }
	}
    }
  GSObjCSetVal(self, key, anObject, sel, type, size, off);
}

static id ValueForKey(NSObject *self, const char *key, unsigned size)
{
  SEL		sel = 0;
  int		off;
  const char	*type = NULL;

  if (size > 0)
    {
      const char	*name;
      char		buf[size+5];
      char		lo;
      char		hi;

      strcpy(buf, "_get");
      strcpy(&buf[4], key);
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
	      sel = 0;
	    }
	}

      if (sel == 0 && [[self class] accessInstanceVariablesDirectly] == YES)
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
	  if (sel == 0)
	    {
	      buf[4] = lo;
	      buf[3] = '_';
	      name = &buf[4];	// key
	      if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		{
		  name = &buf[3];	// _key
		  GSObjCFindVariable(self, name, &type, &size, &off);
		}
	    }
	}
    }
  return GSObjCGetVal(self, key, sel, type, size, off);
}


@implementation NSObject(KeyValueCoding)

+ (BOOL) accessInstanceVariablesDirectly
{
  return YES;
}


+ (BOOL) useStoredAccessor
{
  return YES;
}


- (NSDictionary*) dictionaryWithValuesForKeys: (NSArray*)keys
{
  NSMutableDictionary	*dictionary;
  NSEnumerator		*enumerator;
  id			key;

  dictionary = [NSMutableDictionary dictionaryWithCapacity: [keys count]];
  enumerator = [keys objectEnumerator];
  while ((key = [enumerator nextObject]) != nil)
    {
      id	value = [self valueForKey: key];

      if (value == nil)
	{
	  value = [NSNull null];
	}
      [dictionary setObject: value forKey: key];
    }
  return dictionary;
}

- (id) handleQueryWithUnboundKey: (NSString*)aKey
{
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
    self, @"NSTargetObjectUserInfoKey",
    (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
    nil];
  NSException *exp = [NSException exceptionWithName: NSUndefinedKeyException
				  reason: @"Unable to find value for key"
				  userInfo: dict];

  GSOnceMLog(@"This method is deprecated, use -valueForUndefinedKey:");
  [exp raise];
  return nil;
}


- (void) handleTakeValue: (id)anObject forUnboundKey: (NSString*)aKey
{
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
    (anObject ? (id)anObject : (id)@"(nil)"), @"NSTargetObjectUserInfoKey",
    (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
    nil];
  NSException *exp = [NSException exceptionWithName: NSUndefinedKeyException
				  reason: @"Unable to set value for key"
				  userInfo: dict];
  GSOnceMLog(@"This method is deprecated, use -setValue:forUndefinedKey:");
  [exp raise];
}


- (NSMutableArray*) mutableArrayValueForKey: (NSString*)aKey
{
 [self notImplemented: _cmd];
 return nil;
}

- (NSMutableArray*) mutableArrayValueForKeyPath: (NSString*)aKey
{
 [self notImplemented: _cmd];
 return nil;
}

- (void) setNilValueForKey: (NSString*)aKey
{
  static IMP	o = 0;

  /* Backward compatibility hack */
  if (o == 0)
    {
      o = [NSObject instanceMethodForSelector:
	@selector(unableToSetNilForKey:)];
    }
  if ([self methodForSelector: @selector(unableToSetNilForKey:)] != o)
    {
      [self unableToSetNilForKey: aKey];
    }

  [NSException raise: NSInvalidArgumentException
	      format: @"%@ -- %@ 0x%x: Given nil value to set for key \"%@\"",
    NSStringFromSelector(_cmd), NSStringFromClass([self class]), self, aKey];
}


- (void) setValue: (id)anObject forKey: (NSString*)aKey
{
  unsigned	size = [aKey length];
  char		key[size+1];

  [aKey getCString: key
	 maxLength: size+1
	  encoding: NSASCIIStringEncoding];
  SetValueForKey(self, anObject, key, size);
}


- (void) setValue: (id)anObject forKeyPath: (NSString*)aKey
{
  unsigned	size = [aKey length];
  char		buf[size+1];
  unsigned	start = 0;
  unsigned	end = 0;
  id		o = self;

  [aKey getCString: buf
	 maxLength: size+1
	  encoding: NSASCIIStringEncoding];
  while (o != nil)
    {
      end = start;
      while (end < size && buf[end] != '.')
	{
	  end++;
	}
      aKey = [[NSString alloc] initWithBytes:  buf + start
				      length:  end - start
				    encoding: NSASCIIStringEncoding];
      AUTORELEASE(aKey);
      if (end >= size)
	{
	  [o setValue: anObject forKey: aKey];
	  return;
	}
      o = [o valueForKey: aKey];
      start = ++end;
    }
}


- (void) setValue: (id)anObject forUndefinedKey: (NSString*)aKey
{
  NSDictionary	*dict;
  NSException	*exp; 
  static IMP	o = 0;

  /* Backward compatibility hack */
  if (o == 0)
    {
      o = [NSObject instanceMethodForSelector:
	@selector(handleTakeValue:forUnboundKey:)];
    }
  if ([self methodForSelector: @selector(handleTakeValue:forUnboundKey:)] != o)
    {
      [self handleTakeValue: anObject forUnboundKey: aKey];
      return;
    }

  dict = [NSDictionary dictionaryWithObjectsAndKeys:
    (anObject ? (id)anObject : (id)@"(nil)"), @"NSTargetObjectUserInfoKey",
    (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
    nil];
  exp = [NSException exceptionWithName: NSInvalidArgumentException
				reason: @"Unable to set nil value for key"
			      userInfo: dict];
  [exp raise];
}


- (void) setValuesForKeysWithDictionary: (NSDictionary*)aDictionary
{
  NSEnumerator	*enumerator = [aDictionary keyEnumerator];
  NSString	*key;

  while ((key = [enumerator nextObject]) != nil)
    {
      [self setValue: [aDictionary objectForKey: key] forKey: key];
    }
}


- (id) storedValueForKey: (NSString*)aKey
{
  unsigned	size;

  if ([[self class] useStoredAccessor] == NO)
    {
      return [self valueForKey: aKey];
    }

  size = [aKey length];
  if (size > 0)
    {
      SEL		sel = 0;
      const char	*type = NULL;
      int		off;
      const char	*name;
      char		key[size+1];
      char		buf[size+5];
      char		lo;
      char		hi;

      strcpy(buf, "_get");
      [aKey getCString: key
	     maxLength: size+1
	      encoding: NSASCIIStringEncoding];
      strcpy(&buf[4], key);
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
	      if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		{
		  name = &buf[4]; // key
		  GSObjCFindVariable(self, name, &type, &size, &off);
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
      if (sel != 0 || type != NULL)
	{
	  return GSObjCGetVal(self, key, sel, type, size, off);
	}
    }
  [self handleTakeValue: nil forUnboundKey: aKey];
  return nil;
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
  if (size > 0)
    {
      SEL		sel;
      const char	*type;
      int		off;
      const char	*name;
      char		key[size+1];
      char		buf[size+6];
      char		lo;
      char		hi;

      strcpy(buf, "_set");
      [aKey getCString: key
	     maxLength: size+1
	      encoding: NSASCIIStringEncoding];
      strcpy(&buf[4], key);
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;
      buf[size+4] = ':';
      buf[size+5] = '\0';

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
	      if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		{
		  name = &buf[4];	// key
		  GSObjCFindVariable(self, name, &type, &size, &off);
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
      if (sel != 0 || type != NULL)
	{
	  GSObjCSetVal(self, key, anObject, sel, type, size, off);
	  return;
	}
    }
  [self handleTakeValue: anObject forUnboundKey: aKey];
}


- (void) takeStoredValuesFromDictionary: (NSDictionary*)aDictionary
{
  NSEnumerator	*enumerator = [aDictionary keyEnumerator];
  NSNull	*null = [NSNull null];
  NSString	*key;

  while ((key = [enumerator nextObject]) != nil)
    {
      id obj = [aDictionary objectForKey: key];

      if (obj == null)
	{
	  obj = nil;
	}
      [self takeStoredValue: obj forKey: key];
    }
}


- (void) takeValue: (id)anObject forKey: (NSString*)aKey
{
  SEL		sel = 0;
  const char	*type = 0;
  int		off;
  unsigned	size = [aKey length];
  char		key[size+1];

  GSOnceMLog(@"This method is deprecated, use -setValue:forKey:");
  [aKey getCString: key
	 maxLength: size+1
	  encoding: NSASCIIStringEncoding];
  if (size > 0)
    {
      const char	*name;
      char		buf[size+6];
      char		lo;
      char		hi;

      strcpy(buf, "_set");
      strcpy(&buf[4], key);
      lo = buf[4];
      hi = islower(lo) ? toupper(lo) : lo;
      buf[4] = hi;
      buf[size+4] = ':';
      buf[size+5] = '\0';

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
		  name = &buf[4];	// key
		  if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
		    {
		      name = &buf[3];	// _key
		      GSObjCFindVariable(self, name, &type, &size, &off);
		    }
		}
	    }
	}
    }
  GSObjCSetVal(self, key, anObject, sel, type, size, off);
}


- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey
{
  NSRange	r = [aKey rangeOfString: @"."];

  GSOnceMLog(@"This method is deprecated, use -setValue:forKeyPath:");
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

  GSOnceMLog(@"This method is deprecated, use -setValuesForKeysWithDictionary:");
  while ((key = [enumerator nextObject]) != nil)
    {
      id obj = [aDictionary objectForKey: key];

      if (obj == null)
	{
	  obj = nil;
	}
      [self takeValue: obj forKey: key];
    }
}


- (void) unableToSetNilForKey: (NSString*)aKey
{
  GSOnceMLog(@"This method is deprecated, use -setNilValueForKey:");
  [NSException raise: NSInvalidArgumentException
	      format: @"%@ -- %@ 0x%x: Given nil value to set for key \"%@\"",
    NSStringFromSelector(_cmd), NSStringFromClass([self class]), self, aKey];
}


- (BOOL) validateValue: (id*)aValue
                forKey: (NSString*)aKey
                 error: (NSError**)anError
{
  unsigned	size;

  if (aValue == 0 || (size = [aKey length]) == 0)
    {
      [NSException raise: NSInvalidArgumentException format: @"nil argument"];
    }
  else
    {
      char		name[size+16];
      SEL		sel;
      BOOL		(*imp)(id,SEL,id*,id*);

      strcpy(name, "validate");
      [aKey getCString: &name[8]
	     maxLength: size+1
	      encoding: NSASCIIStringEncoding];
      strcpy(&name[size+8], ":error:");
      if (islower(name[8]))
	{
	  name[8] = toupper(name[8]);
	}
      sel = GSSelectorFromName(name);
      if (sel != 0
	&& (imp = (BOOL (*)(id,SEL,id*,id*))[self methodForSelector: sel]) != 0)
	{
	  return (*imp)(self, sel, aValue, anError);
	}
    }
  return YES;
}

- (BOOL) validateValue: (id*)aValue
            forKeyPath: (NSString*)aKey
                 error: (NSError**)anError
{
  unsigned	size = [aKey length];
  char		buf[size+1];
  unsigned	start = 0;
  unsigned	end = 0;
  id		o = self;

  [aKey getCString: buf
	 maxLength: size+1
	  encoding: NSASCIIStringEncoding];
  while (o != nil)
    {
      end = start;
      while (end < size && buf[end] != '.')
	{
	  end++;
	}
      if (end >= size)
	{
	  break;
	}
      aKey = [[NSString alloc] initWithBytes:  buf + start
				      length:  end - start
				    encoding: NSASCIIStringEncoding];
      AUTORELEASE(aKey);
      o = [o valueForKey: aKey];
      start = ++end;
    }
  if (o == nil)
    {
      return NO;
    }
  else
    {
      char		name[end-start+16];
      SEL		sel;
      BOOL		(*imp)(id,SEL,id*,id*);

      size = end - start;
      strcpy(name, "validate");
      strcpy(&name[8], buf+start);
      strcpy(&name[size+8], ":error:");
      if (islower(name[8]))
	{
	  name[8] = toupper(name[8]);
	}
      sel = GSSelectorFromName(name);
      if (sel != 0
	&& (imp = (BOOL (*)(id,SEL,id*,id*))[self methodForSelector: sel]) != 0)
	{
	  return (*imp)(self, sel, aValue, anError);
	}
      return YES;
    }
}


- (id) valueForKey: (NSString*)aKey
{
  unsigned	size = [aKey length];
  char		key[size+1];

  [aKey getCString: key
	 maxLength: size+1
	  encoding: NSASCIIStringEncoding];
  return ValueForKey(self, key, size);
}


- (id) valueForKeyPath: (NSString*)aKey
{
  unsigned	size = [aKey length];
  char		buf[size+1];
  unsigned	start = 0;
  unsigned	end = 0;
  id		o = self;

  [aKey getCString: buf
	 maxLength: size+1
	  encoding: NSASCIIStringEncoding];
  while (start < size && o != nil)
    {
      end = start;
      while (end < size && buf[end] != '.')
	{
	  end++;
	}
      aKey = [[NSString alloc] initWithBytes:  buf + start
				      length:  end - start
				    encoding: NSASCIIStringEncoding];
      AUTORELEASE(aKey);
      o = [o valueForKey: aKey];
      start = ++end;
    }
  return o;
}


- (id) valueForUndefinedKey: (NSString*)aKey
{
  NSDictionary	*dict;
  NSException	*exp;
  static IMP	o = 0;

  /* Backward compatibility hack */
  if (o == 0)
    {
      o = [NSObject instanceMethodForSelector:
	@selector(handleQueryWithUnboundKey:)];
    }
  if ([self methodForSelector: @selector(handleQueryWithUnboundKey:)] != o)
    {
      return [self handleQueryWithUnboundKey: aKey];
    }
  dict = [NSDictionary dictionaryWithObjectsAndKeys:
    self, @"NSTargetObjectUserInfoKey",
    (aKey ? (id)aKey : (id)@"(nil)"), @"NSUnknownUserInfoKey",
    nil];
  exp = [NSException exceptionWithName: NSUndefinedKeyException
				reason: @"Unable to find value for key"
			      userInfo: dict];

  [exp raise];
  return nil;
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

