/* Implementation for NSURLResponse for GNUstep
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

#include "Foundation/NSCoder.h"
#include "Foundation/NSMapTable.h"
#include "Foundation/NSScanner.h"
#include "NSCallBacks.h"
#include "GNUstepBase/GSMime.h"


// Internal data storage
typedef struct {
  long long			expectedContentLength;
  NSURL				*URL;
  NSString			*MIMEType;
  NSString			*textEncodingName;
  NSString			*statusText;
  NSMapTable			*headers;
  int				statusCode;
} Internal;
 
typedef struct {
  @defs(NSURLResponse)
} priv;
#define	this	((Internal*)(((priv*)self)->_NSURLResponseInternal))
#define	inst	((Internal*)(((priv*)o)->_NSURLResponseInternal))


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

@interface	NSURLResponse (Internal)
- (void) setStatusCode: (int)code text: (NSString*)text;
- (void) setValue: (NSString *)value forHTTPHeaderField: (NSString *)field;
- (NSString *) valueForHTTPHeaderField: (NSString *)field;
@end

@implementation	NSURLResponse (Internal)
- (void) setStatusCode: (int)code text: (NSString*)text
{
  this->statusCode = code;
  ASSIGNCOPY(this->statusText, text);
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


@implementation	NSURLResponse

+ (id) allocWithZone: (NSZone*)z
{
  NSURLResponse	*o = [super allocWithZone: z];

  if (o != nil)
    {
      o->_NSURLResponseInternal = NSZoneCalloc(z, 1, sizeof(Internal));
    }
  return o;
}

- (id) copyWithZone: (NSZone*)z
{
  NSURLResponse	*o;

  if (NSShouldRetainWithZone(self, z) == YES)
    {
      o = RETAIN(self);
    }
  else
    {
      o = [[self class] allocWithZone: z];
      o = [o initWithURL: [self URL]
	MIMEType: [self MIMEType]
	expectedContentLength: [self expectedContentLength]
	textEncodingName: [self textEncodingName]];
      if (o != nil)
	{
	  ASSIGN(inst->statusText, this->statusText);
	  inst->statusCode = this->statusCode;
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
      RELEASE(this->URL);
      RELEASE(this->MIMEType);
      RELEASE(this->textEncodingName);
      RELEASE(this->statusText);
      if (this->headers != 0)
        {
	  NSFreeMapTable(this->headers);
	}
      NSZoneFree([self zone], this);
    }
  [super dealloc];
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

- (long long) expectedContentLength
{
  return this->expectedContentLength;
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

/**
 * Initialises the receiver with the URL, MIMEType, expected length and
 * text encoding name provided.
 */
- (id) initWithURL: (NSURL *)URL
  MIMEType: (NSString *)MIMEType
  expectedContentLength: (int)length
  textEncodingName: (NSString *)name
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(this->URL, URL);
      ASSIGNCOPY(this->MIMEType, MIMEType);
      ASSIGNCOPY(this->textEncodingName, name);
      this->expectedContentLength = length;
    }
  return self;
}

- (NSString *) MIMEType
{
  return this->MIMEType;
}

/**
 * Returns a suggested file name for storing the response data, with
 * suggested names being found in the following order:<br />
 * <list>
 *   <item>content-disposition header</item>
 *   <item>last path component of URL</item>
 *   <item>host name from URL</item>
 *   <item>'unknown'</item>
 * </list>
 * If possible, an extension based on the MIME type of the response
 * is also appended.<br />
 * The result should always be a valid file name.
 */
- (NSString *) suggestedFilename
{
  NSString	*disp = [self valueForHTTPHeaderField: @"content-disposition"];
  NSString	*name = nil;

  if (disp != nil)
    {
      GSMimeParser	*p;
      GSMimeHeader	*h;
      NSScanner		*sc;

      // Try to get name from content disposition header.
      p = AUTORELEASE([GSMimeParser new]);
      h = [[GSMimeHeader alloc] initWithName: @"content-displosition"
				       value: disp];
      AUTORELEASE(h);
      sc = [NSScanner scannerWithString: [h value]];
      if ([p scanHeaderBody: sc into: h] == YES)
        {
	  name = [h parameterForKey: @"filename"];
	  name = [name stringByDeletingPathExtension];
	}
    }

  if ([name length] == 0)
    {
      name = [[[self URL] absoluteString] lastPathComponent];
      name = [name stringByDeletingPathExtension];
    }
  if ([name length] == 0)
    {
      name = [[self URL] host];
    }
  if ([name length] == 0)
    {
      name = @"unknown";
    }
// FIXME ... add type specific extension
  return name;
}

- (NSString *) textEncodingName
{
  return this->textEncodingName;
}

- (NSURL *) URL
{
  return this->URL;
}

@end


@implementation NSHTTPURLResponse

+ (NSString *) localizedStringForStatusCode: (int)statusCode
{
// FIXME ... put real responses in here
  return [NSString stringWithFormat: @"%d", statusCode];
}

- (NSDictionary *) allHeaderFields
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

- (int) statusCode
{
  return this->statusCode;
}

@end

