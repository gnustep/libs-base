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

/** An exception for an unknown key */
NSString* const NSUnknownKeyException = @"NSUnknownKeyException";

/**
 * This describes an informal protocol for key-value coding.
 * The basic methods are implemented as a category of the NSObject class,
 * but other classes override those default implementations to perform
 * more specific operations.
 */
@implementation NSObject (KeyValueCoding)

/**
 * Controls whether the NSKeyValueCoding methods may attempt to
 * access instance variables directly.
 * NSObject's implementation returns YES.
 */
+ (BOOL) accessInstanceVariablesDirectly
{
  return YES;
}

/**
 * Controls whether [NSObject-storedValueForKey:] and 
 * [NSObject-takeStoredValueForKey:] may use the stored accessor mechainsm.
 * If not the calls get redirected to [NSObject-valueForKey:] and 
 * [NSObject-takeValueForKey:] effectively changing the search order
 * of private/public accessor methods and instance variables.
 */
+ (BOOL) useStoredAccessor
{
  return YES;
}

/**
 * Invoked when [NSObject-valueForKey:]/[NSObject-storedValueForKey:] are
 * called with a key, which can't be associated with an accessor method or
 * instance variable.  Subclasses may override this method to add custom
 * handling.  NSObject raises an NSUnknownKeyException, with a userInfo
 * dictionary containing NSTargetObjectUserInfoKey with the receiver
 * an NSUnknownUserInfoKey with the supplied key entries.
 */
- (id) handleQueryWithUnboundKey: (NSString*)aKey
{
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
				     self, 
				     @"NSTargetObjectUserInfoKey", 
				     aKey,
				     @"NSUnknownUserInfoKey",
				     nil];
  NSException *exp = [NSException exceptionWithName: NSUnknownKeyException
				  reason: @"Unable to find value for key"
				  userInfo: dict];
  [exp raise];
  return nil;
}

/**
 * Invoked when
 * [NSObject-takeValue:forKey:]/[NSObject-takeStoredValue:forKey:] are
 * called with a key which can't be associated with an accessor method or
 * instance variable.  Subclasses may override this method to add custom
 * handling.  NSObject raises an NSUnknownKeyException, with a userInfo
 * dictionary containing NSTargetObjectUserInfoKey with the receiver
 * an NSUnknownUserInfoKey with the supplied key entries.
 */
- (void) handleTakeValue: (id)anObject forUnboundKey: (NSString*)aKey
{
  NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
				     anObject, 
				     @"NSTargetObjectUserInfoKey", 
				     aKey,
				     @"NSUnknownUserInfoKey",
				     nil];
  NSException *exp = [NSException exceptionWithName: NSUnknownKeyException
				  reason: @"Unable to set value for key"
				  userInfo: dict];
  [exp raise];
}

/**
 * Returns the value associated with the supplied key as an object.
 * Scalar attributes are converted to corresponding objects.
 * The storedValue-NSKeyValueCoding use the private accessors
 * in favor of the public ones, if the receiver's class allows
 * [NSObject+useStoredAccessor].  Otherwise this method invokes
 * [NSObject-valueForKey:].
 * The search order is:<\br>
 * Private accessor methods:
 * <list>
 *  <item>_getKey</item>
 *  <item>_key</item>
 * </list>
 * If the receiver's class allows [NSObject+accessInstanceVariablesDirectly]
 * it continues with instance variables:
 * <list>
 *  <item>_key</item>
 *  <item>key</item>
 * </list>
 * Public accessor methods:
 * <list>
 *  <item>getKey</item>
 *  <item>key</item>
 * </list>
 * Invokes [NSObject-handleQueryWithUnboundKey:]
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accesor method takes
 * any arguments or the type is unsupported (e.g. structs).
 */
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
      return GSObjCGetValue(self, aKey, sel, type, size, off);
    }
}

/**
 * Sets the value associated with the supplied in the receiver.
 * The object is converted to the scalar attribute where applicable.
 * The storedValue-NSKeyValueCoding use the private accessors
 * in favor of the public ones, if the receiver's class allows
 * [NSObject+useStoredAccessor.]
 * Otherwise this method invokes [NSObject-takeValue:forKey:].
 * The search order is:<\br>
 * Private accessor methods:
 * <list>
 *  <item>_setKey:</item>
 * </list>
 * If the receiver's class allows [NSObject+accessInstanceVariablesDirectly]
 * it continues with instance variables:
 * <list>
 *  <item>_key</item>
 *  <item>key</item>
 * </list>
 * Public accessor methods:
 * <list>
 *  <item>setKey:</item>
 * </list>
 * Invokes [NSObject-handleTakeValue:forUnboundKey:]
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accesor method doesn't take
 * exactly one argument or the type is unsupported (e.g. structs).
 * If the receiver expects a scalar value and the value supplied
 * is the NSNull instance or nil, this method invokes 
 * [NSObject-unableToSetNilForKey:].
 */
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
      GSObjCSetValue(self, aKey, anObject, sel, type, size, off);
   }
}

/**
 * Iterates over the dictionary invoking [NSObject-takeStoredValue:forKey:]
 * on the receiver for each key-value pair, converting NSNull to nil.
 */
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

/**
 * Sets the value if the attribute associated with the key in the receiver.
 * The object is converted to a scalar attribute where applicable.
 * The value-NSKeyValueCoding use the public accessors
 * in favor of the private ones.
 * The search order is:<\br>
 * Accessor methods:
 * <list>
 *  <item>setKey:</item>
 *  <item>_setKey:</item>
 * </list>
 * If the receiver's class allows [NSObject+accessInstanceVariablesDirectly]
 * it continues with instance variables:
 * <list>
 *  <item>key</item>
 *  <item>_key</item>
 * </list>
 * Invokes [NSObject-handleTakeValue:forUnboundKey:]
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accesor method doesn't take
 * exactly one argument or the type is unsupported (e.g. structs).
 * If the receiver expects a scalar value and the value supplied
 * is the NSNull instance or nil, this method invokes 
 * [NSObject-unableToSetNilForKey:].
 */
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
      GSObjCSetValue(self, aKey, anObject, sel, type, size, off);
    }
}

/**
 * Retrieves the object returned by invoking [NSObject-valueForKey:]
 * on the receiver with the first key component supplied by the key path.
 * Then invokes [NSObject-takeValue:forKeyPath:] recursively on the
 * returned object with rest of the key path.
 * The key components are delimated by '.'.
 * If the key path doesn't contain any '.', this method simply
 * invokes [NSObject-takeValue:forKey:].
 */
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

/**
 * Iterates over the dictionary invoking [NSObject-takeValue:forKey:]
 * on the receiver for each key-value pair, converting NSNull to nil.
 */
- (void) takeValuesFromDictionary: (NSDictionary*)aDictionary
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
      [self takeValue: obj forKey: key];
    }
}

/**
 * This method is invoked by the NSKeyValueCoding mechanism when an attempt
 * is made to set an null value for a scalar attribute.  This implementation
 * raises an NSInvalidArgument exception.  Subclasses my override this method
 * to do custom handling. (E.g. setting the value to the equivalent of 0.)
 */
- (void) unableToSetNilForKey: (NSString*)aKey
{
  [NSException raise: NSInvalidArgumentException
	      format: @"%@ -- %@ 0x%x: Given nil value to set for key \"%@\"",
    NSStringFromSelector(_cmd), NSStringFromClass([self class]), self, aKey];
}

/**
 * Returns the value associated with the supplied key as an object.
 * Scalar attributes are converted to corresponding objects.
 * The value-NSKeyValueCoding use the public accessors
 * in favor of the privat ones.
 * The search order is:<\br>
 * Accessor methods:
 * <list>
 *  <item>getKey</item>
 *  <item>key</item>
 *  <item>_getKey</item>
 *  <item>_key</item>
 * </list>
 * If the receiver's class allows accessInstanceVariablesDirectly
 * it continues with instance variables:
 * <list>
 *  <item>key</item>
 *  <item>_key</item>
 * </list>
 * Invokes [NSObject-handleQueryWithUnboundKey:]
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accesor method takes
 * any arguments or the type is unsupported (e.g. structs).
 */
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
	  name = &buf[4];	// key
	  if (GSObjCFindVariable(self, name, &type, &size, &off) == NO)
	    {
	      name = &buf[3];	// _key
	      GSObjCFindVariable(self, name, &type, &size, &off);
	    }
	}
      return GSObjCGetValue(self, aKey, sel, type, size, off);
    }
}

/**
 * Retuns the object returned by invoking [NSObject-valueForKeyPath:]
 * recursively on the object returned by invoking [NSObject-valueForKey:]
 * on the receiver with the first key component supplied by the key path.
 * The key components are delimated by '.'.
 * If the key path doesn't contain any '.', this method simply
 * invokes [NSObject-valueForKey:].
 */
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

/**
 * Iterates over the array sending the receiver [NSObject-valueForKey:]
 * for each object in the array and inserting the result in a dictionary.
 * All nil values returned by [NSObject-valueForKey:] are replaced by the
 * NSNull instance in the dictionary.
 */
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

