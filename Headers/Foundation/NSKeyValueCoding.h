
/* Interface for NSKeyValueCoding for GNUStep
   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date:	2000
   
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
   */ 

#ifndef __NSKeyValueCoding_h_GNUSTEP_BASE_INCLUDE
#define __NSKeyValueCoding_h_GNUSTEP_BASE_INCLUDE

#include	<Foundation/NSObject.h>

@class NSArray;
@class NSDictionary;
@class NSString;

#ifndef	STRICT_OPENSTEP

/** An exception for an unknown key in [NSObject(NSKeyValueCoding)]. */
GS_EXPORT NSString* const NSUnknownKeyException;

/**
 * <p>This describes an informal protocol for <em>key-value coding</em>, a
 * mechanism whereby the fields of an object may be accessed and set using
 * generic methods in conjunction with string keys rather than field-specific
 * methods.  Key-based access loses compile-time validity checking, but can be
 * convenient in certain kinds of situations.</p>
 *
 * <p>The basic methods are implemented as a category of the [NSObject] class,
 * but other classes override those default implementations to perform more
 * specific operations.</p>
 */
@interface NSObject (NSKeyValueCoding)

/**
 * Controls whether the NSKeyValueCoding methods may attempt to
 * access instance variables directly.
 * NSObject's implementation returns YES.
 */
+ (BOOL) accessInstanceVariablesDirectly;

/**
 * Controls whether -storedValueForKey: and -takeStoredValue:forKey: may use
 * the stored accessor mechanism.  If not the calls get redirected to
 * -valueForKey: and -takeValue:forKey: effectively changing the search order
 * of private/public accessor methods and instance variables.
 * NSObject's implementation returns YES.
 */
+ (BOOL) useStoredAccessor;

/**
 * Invoked when -valueForKey: / -storedValueForKey: are called with a key,
 * which can't be associated with an accessor method or instance variable.
 * Subclasses may override this method to add custom handling.  NSObject
 * raises an NSUnknownKeyException, with a userInfo dictionary containing
 * NSTargetObjectUserInfoKey with the receiver an NSUnknownUserInfoKey with
 * the supplied key entries.
 */
- (id) handleQueryWithUnboundKey: (NSString*)aKey;

/**
 * Invoked when -takeValue:forKey: / -takeStoredValue:forKey: are called with
 * a key which can't be associated with an accessor method or instance
 * variable.  Subclasses may override this method to add custom handling.
 * NSObject raises an NSUnknownKeyException, with a userInfo dictionary
 * containing NSTargetObjectUserInfoKey with the receiver an
 * NSUnknownUserInfoKey with the supplied key entries.
 */
- (void) handleTakeValue: (id)anObject forUnboundKey: (NSString*)aKey;

/**
 * Returns the value associated with the supplied key as an object.
 * Scalar attributes are converted to corresponding objects.
 * Uses private accessors in favor of the public ones, if the receiver's
 * class allows +useStoredAccessor.  Otherwise this method invokes
 * -valueForKey:.
 * The search order is:<br/>
 * Private accessor methods:
 * <list>
 *  <item>_getKey</item>
 *  <item>_key</item>
 * </list>
 * If the receiver's class allows +accessInstanceVariablesDirectly
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
 * Invokes -handleQueryWithUnboundKey: if no accessor mechanism can be
 * found and raises NSInvalidArgumentException if the accesor method takes
 * takes any arguments or the type is unsupported (e.g. structs).
 */
- (id) storedValueForKey: (NSString*)aKey;

/**
 * Sets the value associated with the supplied in the receiver.
 * The object is converted to the scalar attribute where applicable.
 * Uses the private accessors in favor of the public ones, if the
 * receiver's class allows +useStoredAccessor .
 * Otherwise this method invokes -takeValue:forKey: .
 * The search order is:<br/>
 * Private accessor methods:
 * <list>
 *  <item>_setKey:</item>
 * </list>
 * If the receiver's class allows accessInstanceVariablesDirectly
 * it continues with instance variables:
 * <list>
 *  <item>_key</item>
 *  <item>key</item>
 * </list>
 * Public accessor methods:
 * <list>
 *  <item>setKey:</item>
 * </list>
 * Invokes -handleTakeValue:forUnboundKey:
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accesor method doesn't take
 * exactly one argument or the type is unsupported (e.g. structs).
 * If the receiver expects a scalar value and the value supplied
 * is the NSNull instance or nil, this method invokes 
 * -unableToSetNilForKey: .
 */
- (void) takeStoredValue: (id)anObject forKey: (NSString*)aKey;

/**
 * Iterates over the dictionary invoking -takeStoredValue:forKey:
 * on the receiver for each key-value pair, converting NSNull to nil.
 */
- (void) takeStoredValuesFromDictionary: (NSDictionary*)aDictionary;

/**
 * Sets the value if the attribute associated with the key in the receiver.
 * The object is converted to a scalar attribute where applicable.
 * Uses the public accessors in favor of the private ones.
 * The search order is:<br/>
 * Accessor methods:
 * <list>
 *  <item>setKey:</item>
 *  <item>_setKey:</item>
 * </list>
 * If the receiver's class allows +accessInstanceVariablesDirectly
 * it continues with instance variables:
 * <list>
 *  <item>key</item>
 *  <item>_key</item>
 * </list>
 * Invokes -handleTakeValue:forUnboundKey:
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accesor method doesn't take
 * exactly one argument or the type is unsupported (e.g. structs).
 * If the receiver expects a scalar value and the value supplied
 * is the NSNull instance or nil, this method invokes 
 * -unableToSetNilForKey: .
 */
- (void) takeValue: (id)anObject forKey: (NSString*)aKey;

/**
 * Retrieves the object returned by invoking -valueForKey:
 * on the receiver with the first key component supplied by the key path.
 * Then invokes -takeValue:forKeyPath: recursively on the
 * returned object with rest of the key path.
 * The key components are delimated by '.'.
 * If the key path doesn't contain any '.', this method simply
 * invokes -takeValue:forKey:.
 */
- (void) takeValue: (id)anObject forKeyPath: (NSString*)aKey;

/**
 * Iterates over the dictionary invoking -takeValue:forKey:
 * on the receiver for each key-value pair, converting NSNull to nil.
 */
- (void) takeValuesFromDictionary: (NSDictionary*)aDictionary;

/**
 * This method is invoked by the NSKeyValueCoding mechanism when an attempt
 * is made to set an null value for a scalar attribute.  This implementation
 * raises an NSInvalidArgument exception.  Subclasses my override this method
 * to do custom handling. (E.g. setting the value to the equivalent of 0.)
 */
- (void) unableToSetNilForKey: (NSString*)aKey;

/**
 * Returns the value associated with the supplied key as an object.
 * Scalar attributes are converted to corresponding objects.
 * The value-NSKeyValueCoding use the public accessors
 * in favor of the private ones.
 * The search order is:<br/>
 * Accessor methods:
 * <list>
 *  <item>getKey</item>
 *  <item>key</item>
 *  <item>_getKey</item>
 *  <item>_key</item>
 * </list>
 * If the receiver's class allows +accessInstanceVariablesDirectly
 * it continues with instance variables:
 * <list>
 *  <item>key</item>
 *  <item>_key</item>
 * </list>
 * Invokes -handleQueryWithUnboundKey:
 * if no accessor mechanism can be found
 * and raises NSInvalidArgumentException if the accesor method takes
 * any arguments or the type is unsupported (e.g. structs).
 */
- (id) valueForKey: (NSString*)aKey;

/**
 * Retuns the object returned by invoking -valueForKeyPath:
 * recursively on the object returned by invoking -valueForKey:
 * on the receiver with the first key component supplied by the key path.
 * The key components are delimated by '.'.
 * If the key path doesn't contain any '.', this method simply
 * invokes -valueForKey: .
 */
- (id) valueForKeyPath: (NSString*)aKey;

/**
 * Iterates over the array sending the receiver -valueForKey:
 * for each object in the array and inserting the result in a dictionary.
 * All nil values returned by -valueForKey: are replaced by the
 * NSNull instance in the dictionary.
 */
- (NSDictionary*) valuesForKeys: (NSArray*)keys;

@end

#endif
#endif

