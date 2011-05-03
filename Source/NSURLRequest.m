/* Implementation for NSURLRequest for GNUstep
   Copyright (C) 2006 Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <frm@gnu.org>
   Date: 2006
   
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
   */ 

#include "GSURLPrivate.h"

#include "Foundation/NSMapTable.h"
#include "Foundation/NSCoder.h"
#include "NSCallBacks.h"


// Internal data storage
typedef struct {
  NSData			*body;
  NSInputStream			*bodyStream;
  NSString			*method;
  NSMapTable			*headers;
  BOOL				shouldHandleCookies;
  NSURL				*URL;
  NSURL				*mainDocumentURL;
  NSURLRequestCachePolicy	cachePolicy;
  NSTimeInterval		timeoutInterval;
  NSMutableDictionary		*properties;
} Internal;
 
/* Defines to get easy access to internals from mutable/immutable
 * versions of the class and from categories.
 */
typedef struct {
  @defs(NSURLRequest)
} priv;
#define	this	((Internal*)(((priv*)self)->_NSURLRequestInternal))
#define	inst	((Internal*)(((priv*)o)->_NSURLRequestInternal))

@implementation	NSURLRequest

+ (id) allocWithZone: (NSZone*)z
{
  NSURLRequest	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLRequestInternal = NSZoneCalloc(z, 1, sizeof(Internal));
    }
  return o;
}

+ (id) requestWithURL: (NSURL *)URL
{
  return [self requestWithURL: URL
		  cachePolicy: NSURLRequestUseProtocolCachePolicy
	      timeoutInterval: 60.0];
}

+ (id) requestWithURL: (NSURL *)URL
	  cachePolicy: (NSURLRequestCachePolicy)cachePolicy
      timeoutInterval: (NSTimeInterval)timeoutInterval
{
  NSURLRequest	*o = [[self class] allocWithZone: NSDefaultMallocZone()];

  o = [o initWithURL: URL
	 cachePolicy: cachePolicy
     timeoutInterval: timeoutInterval];
  return AUTORELEASE(o);
}

- (NSURLRequestCachePolicy) cachePolicy
{
  return this->cachePolicy;
}

- (id) copyWithZone: (NSZone*)z
{
  NSURLRequest	*o;

  if (NSShouldRetainWithZone(self, z) == YES
    && [self isKindOfClass: [NSMutableURLRequest class]] == NO)
    {
      o = RETAIN(self);
    }
  else
    {
      o = [[self class] allocWithZone: z];
      o = [o initWithURL: [self URL]
	     cachePolicy: [self cachePolicy]
	 timeoutInterval: [self timeoutInterval]];
      if (o != nil)
        {
	  inst->properties = [this->properties mutableCopy];
	  ASSIGN(inst->mainDocumentURL, this->mainDocumentURL);
	  ASSIGN(inst->body, this->body);
	  ASSIGN(inst->bodyStream, this->bodyStream);
	  ASSIGN(inst->method, this->method);
	  inst->shouldHandleCookies = this->shouldHandleCookies;
	  if (this->headers == 0)
	    {
	      inst->headers = 0;
	    }
	  else
	    {
	      inst->headers = NSCopyMapTableWithZone(this->headers, z);
	    }
	}
    }
  return o;
}

- (void) dealloc
{
  if (this != 0)
    {
      RELEASE(this->body);
      RELEASE(this->bodyStream);
      RELEASE(this->method);
      RELEASE(this->URL);
      RELEASE(this->mainDocumentURL);
      RELEASE(this->properties);
      if (this->headers != 0)
        {
	  NSFreeMapTable(this->headers);
	}
      NSZoneFree([self zone], this);
    }
  [super dealloc];
}

- (NSString*) description
{
  return [NSString stringWithFormat: @"<%@ %@>",
    NSStringFromClass([self class]), [[self URL] absoluteString]];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
// FIXME
  if ([aCoder allowsKeyedCoding])
    {
    }
  else
    {
    }
}

- (id) initWithCoder: (NSCoder*)aCoder
{
// FIXME
  if ([aCoder allowsKeyedCoding])
    {
    }
  else
    {
    }
  return self;
}

- (unsigned) hash
{
  return [this->URL hash];
}

- (id) initWithURL: (NSURL *)URL
{
  return [self initWithURL: URL
	       cachePolicy: NSURLRequestUseProtocolCachePolicy
	   timeoutInterval: 60.0];
}

- (id) initWithURL: (NSURL *)URL
       cachePolicy: (NSURLRequestCachePolicy)cachePolicy
   timeoutInterval: (NSTimeInterval)timeoutInterval
{
  if ((self = [super init]) != nil)
    {
      this->URL = RETAIN(URL);
      this->cachePolicy = cachePolicy;
      this->timeoutInterval = timeoutInterval;
      this->mainDocumentURL = nil;
    }
  return self;
}

- (BOOL) isEqual: (id)o
{
  if ([o isKindOfClass: [NSURLRequest class]] == NO)
    {
      return NO;
    }
  if (this->URL != inst->URL
    && [this->URL isEqual: inst->URL] == NO)
    {
      return NO;
    }
  if (this->mainDocumentURL != inst->mainDocumentURL
    && [this->mainDocumentURL isEqual: inst->mainDocumentURL] == NO)
    {
      return NO;
    }
  if (this->method != inst->method
    && [this->method isEqual: inst->method] == NO)
    {
      return NO;
    }
  if (this->body != inst->body
    && [this->body isEqual: inst->body] == NO)
    {
      return NO;
    }
  if (this->bodyStream != inst->bodyStream
    && [this->bodyStream isEqual: inst->bodyStream] == NO)
    {
      return NO;
    }
  if (this->properties != inst->properties
    && [this->properties isEqual: inst->properties] == NO)
    {
      return NO;
    }
  if (this->headers != inst->headers)
    {
      NSMapEnumerator	enumerator;
      id		k;
      id		v;

      if (this->headers == 0 || inst->headers == 0)
	{
	  return NO;
	}
      if (NSCountMapTable(this->headers) != NSCountMapTable(inst->headers))
	{
	  return NO;
	}
      enumerator = NSEnumerateMapTable(this->headers);
      while (NSNextMapEnumeratorPair(&enumerator, (void **)(&k), (void**)&v))
	{
	  id	ov = (id)NSMapGet(inst->headers, (void*)k);

	  if ([v isEqual: ov] == NO)
	    {
	      NSEndMapTableEnumeration(&enumerator);
	      return NO;
	    }
	}
      NSEndMapTableEnumeration(&enumerator);
    }
  return YES;
}

- (NSURL *) mainDocumentURL
{
  return this->mainDocumentURL;
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  NSMutableURLRequest	*o;

  o = [NSMutableURLRequest allocWithZone: z];
  o = [o initWithURL: [self URL]
	 cachePolicy: [self cachePolicy]
     timeoutInterval: [self timeoutInterval]];
  if (o != nil)
    {
      [o setMainDocumentURL: this->mainDocumentURL];
      inst->properties = [this->properties mutableCopy];
      ASSIGN(inst->mainDocumentURL, this->mainDocumentURL);
      ASSIGN(inst->body, this->body);
      ASSIGN(inst->bodyStream, this->bodyStream);
      ASSIGN(inst->method, this->method);
      inst->shouldHandleCookies = this->shouldHandleCookies;
      if (this->headers == 0)
        {
	  inst->headers = 0;
	}
      else
	{
	  inst->headers = NSCopyMapTableWithZone(this->headers, z);
	}
    }
  return o;
}

- (NSTimeInterval) timeoutInterval
{
  return this->timeoutInterval;
}

- (NSURL *) URL
{
  return this->URL;
}

@end


@implementation NSMutableURLRequest

- (void) setCachePolicy: (NSURLRequestCachePolicy)cachePolicy
{
  this->cachePolicy = cachePolicy;
}

- (void) setMainDocumentURL: (NSURL *)URL
{
  ASSIGN(this->mainDocumentURL, URL);
}

- (void) setTimeoutInterval: (NSTimeInterval)seconds
{
  this->timeoutInterval = seconds;
}

- (void) setURL: (NSURL *)URL
{
  ASSIGN(this->URL, URL);
}

@end



/*
 * Implement map keys for strings with case insensitive comparisons,
 * so we can have case insensitive matching of http headers (correct
 * behavior), but actually preserve case of headers stored and written
 * in case the remote server is buggy and requires particular
 * captialisation of headers (some http software is faulty like that).
 */
static unsigned int
_non_retained_id_hash(void *table, NSString* o)
{
  return [[o uppercaseString] hash];
}

static BOOL
_non_retained_id_is_equal(void *table, NSString *o, NSString *p)
{
  return ([o caseInsensitiveCompare: p] == NSOrderedSame) ? YES : NO;
}

typedef unsigned int (*NSMT_hash_func_t)(NSMapTable *, const void *);
typedef BOOL (*NSMT_is_equal_func_t)(NSMapTable *, const void *, const void *);
typedef void (*NSMT_retain_func_t)(NSMapTable *, const void *);
typedef void (*NSMT_release_func_t)(NSMapTable *, void *);
typedef NSString *(*NSMT_describe_func_t)(NSMapTable *, const void *);

static const NSMapTableKeyCallBacks headerKeyCallBacks =
{
  (NSMT_hash_func_t) _non_retained_id_hash,
  (NSMT_is_equal_func_t) _non_retained_id_is_equal,
  (NSMT_retain_func_t) _NS_non_retained_id_retain,
  (NSMT_release_func_t) _NS_non_retained_id_release,
  (NSMT_describe_func_t) _NS_non_retained_id_describe,
  NSNotAPointerMapKey
};

@implementation NSURLRequest (NSHTTPURLRequest)

- (NSDictionary *) allHTTPHeaderFields
{
  NSMutableDictionary	*fields;

  fields = [NSMutableDictionary dictionaryWithCapacity: 8];
  if (this->headers != 0)
    {
      NSMapEnumerator	enumerator;
      NSString		*k;
      NSString		*v;

      enumerator = NSEnumerateMapTable(this->headers);
      while (NSNextMapEnumeratorPair(&enumerator, (void **)(&k), (void**)&v))
	{
	  [fields setObject: v forKey: k];
	}
      NSEndMapTableEnumeration(&enumerator);
    }
  return fields;
}

- (NSData *) HTTPBody
{
  return this->body;
}

- (NSInputStream *) HTTPBodyStream
{
  return this->bodyStream;
}

- (NSString *) HTTPMethod
{
  return this->method;
}

- (BOOL) HTTPShouldHandleCookies
{
  return this->shouldHandleCookies;
}

- (NSString *) valueForHTTPHeaderField: (NSString *)field
{
  NSString	*value = nil;

  if (this->headers != 0)
    {
      value = (NSString*)NSMapGet(this->headers, (void*)field);
    }
  return value;
}

@end



@implementation NSMutableURLRequest (NSMutableHTTPURLRequest)

- (void) addValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
  NSString	*old = [self valueForHTTPHeaderField: field];

  if (old != nil)
    {
      value = [old stringByAppendingFormat: @",%@", value];
    }
  [self setValue: value forHTTPHeaderField: field];
}

- (void) setAllHTTPHeaderFields: (NSDictionary *)headerFields
{
  NSEnumerator	*enumerator = [headerFields keyEnumerator];
  NSString	*field;

  while ((field = [enumerator nextObject]) != nil)
    {
      id	value = [headerFields objectForKey: field];

      if ([value isKindOfClass: [NSString class]] == YES)
        {
	  [self setValue: (NSString*)value forHTTPHeaderField: field];
	}
    }
}

- (void) setHTTPBodyStream: (NSInputStream *)inputStream
{
  DESTROY(this->body);
  ASSIGN(this->bodyStream, inputStream);
}

- (void) setHTTPBody: (NSData *)data
{
  DESTROY(this->bodyStream);
  ASSIGNCOPY(this->body, data);
}

- (void) setHTTPMethod: (NSString *)method
{
  ASSIGNCOPY(this->method, method);
}

- (void) setHTTPShouldHandleCookies: (BOOL)should
{
  this->shouldHandleCookies = should;
}

- (void) setValue: (NSString *)value forHTTPHeaderField: (NSString *)field
{
  if (this->headers == 0)
    {
      this->headers = NSCreateMapTable(headerKeyCallBacks,
	NSObjectMapValueCallBacks, 8);
    }
  NSMapInsert(this->headers, (void*)field, (void*)value);
}

@end

@implementation	NSURLRequest (Private)
- (id) _propertyForKey: (NSString*)key
{
  return [this->properties objectForKey: key];
}

- (void) _setProperty: (id)value forKey: (NSString*)key
{
  if (this->properties == nil)
    {
      this->properties = [NSMutableDictionary new];
      [this->properties setObject: value forKey: key];
    }
}
@end
