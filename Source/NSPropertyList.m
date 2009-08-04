/** Interface for NSPropertyList for GNUstep
   Copyright (C) 2003,2004 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   		Fred Kiefer <FredKiefer@gmx.de>

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */

#import "config.h"
#include <string.h>
#include <limits.h>
#import "GNUstepBase/preface.h"
#import "GNUstepBase/GSMime.h"

#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSByteOrder.h"
#import "Foundation/NSCalendarDate.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSPropertyList.h"
#import "Foundation/NSSerialization.h"
#import "Foundation/NSString.h"
#import "Foundation/NSTimeZone.h"
#import "Foundation/NSUserDefaults.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSDebug.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSXMLParser.h"
#import "GNUstepBase/Unicode.h"

#import "GSPrivate.h"

@class  GSSloppyXMLParser;

/*
 * Cache classes.
 */
static Class	NSArrayClass;
static Class	NSDataClass;
static Class	NSDateClass;
static Class	NSDictionaryClass;
static Class	NSNumberClass;
static Class	NSStringClass;
static Class	NSMutableStringClass;
static Class	GSStringClass;
static Class	GSMutableStringClass;

extern BOOL GSScanDouble(unichar*, unsigned, double*);

@class	GSMutableDictionary;
@interface GSMutableDictionary : NSObject	// Help the compiler
@end


@interface GSXMLPListParser : NSObject
{
  NSXMLParser				*theParser;
  NSMutableString			*value;
  NSMutableArray			*stack;
  NSString				*key;
  BOOL					inArray;
  BOOL					inDictionary;
  id					plist;
  NSPropertyListMutabilityOptions	opts;
}

- (id) initWithData: (NSData*)data
	 mutability: (NSPropertyListMutabilityOptions)options;
- (BOOL) parse;
- (void) parser: (NSXMLParser *)parser
  foundCharacters: (NSString *)string;
- (void) parser: (NSXMLParser *)parser
  didStartElement: (NSString *)elementName
  namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qualifiedName
  attributes: (NSDictionary *)attributeDict;
- (void) parser: (NSXMLParser *)parser
  didEndElement: (NSString *)elementName
  namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName;
- (id) result;
@end

@implementation GSXMLPListParser

- (void) dealloc
{
  RELEASE(key);
  RELEASE(stack);
  RELEASE(plist);
  RELEASE(value);
  RELEASE(theParser);
  [super dealloc];
}

- (id) initWithData: (NSData*)data
	 mutability: (NSPropertyListMutabilityOptions)options
{
  if ((self = [super init]) != nil)
    {
      stack = [[NSMutableArray alloc] initWithCapacity: 10];
      theParser = [[GSSloppyXMLParser alloc] initWithData: data];
      [theParser setDelegate: self];
      opts = options;
    }
  return self;
}

- (void) parser: (NSXMLParser *)parser
  foundCharacters: (NSString *)string
{
  string = [string stringByTrimmingSpaces];
  if ([string length] > 0)
    {
      if (value == nil)
        {
          value = [[NSMutableString alloc] initWithCapacity: 50];
        }
      [value appendString: string];
    }
}

- (void) parser: (NSXMLParser *)parser
  didStartElement: (NSString *)elementName
  namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qualifiedName
  attributes: (NSDictionary *)attributeDict
{
  if ([elementName isEqualToString: @"dict"] == YES)
    {
      NSMutableDictionary	*d;

      if (key == nil)
        {
          key = RETAIN([NSNull null]);
        }
      [stack addObject: key];
      DESTROY(key);
      d = [[NSMutableDictionary alloc] initWithCapacity: 10];
      [stack addObject: d];
      RELEASE(d);
      inDictionary = YES;
      inArray = NO;
    }
  else if ([elementName isEqualToString: @"array"] == YES)
    {
      NSMutableArray	*a;

      if (key == nil)
        {
          key = RETAIN([NSNull null]);
        }
      [stack addObject: key];
      DESTROY(key);
      a = [[NSMutableArray alloc] initWithCapacity: 10];
      [stack addObject: a];
      RELEASE(a);
      inArray = YES;
      inDictionary = NO;
    }
}

- (void) parser: (NSXMLParser *)parser
  didEndElement: (NSString *)elementName
  namespaceURI: (NSString *)namespaceURI
  qualifiedName: (NSString *)qName
{
  BOOL	inContainer = NO;

  if ([elementName isEqualToString: @"dict"] == YES)
    {
      inContainer = YES;
    }
  if ([elementName isEqualToString: @"array"] == YES)
    {
      inContainer = YES;
    }

  if (inContainer)
    {
      if (opts != NSPropertyListImmutable)
	{
	  ASSIGN(plist, [stack lastObject]);
	}
      else
        {
	  ASSIGN(plist, [[stack lastObject] makeImmutableCopyOnFail: NO]);
	}
      [stack removeLastObject];
      inArray = NO;
      inDictionary = NO;
      ASSIGN(key, [stack lastObject]);
      [stack removeLastObject];
      if ((id)key == (id)[NSNull null])
        {
          DESTROY(key);
        }
      if ([stack count] > 0)
        {
	  id	last;

	  last = [stack lastObject];
	  if ([last isKindOfClass: NSArrayClass] == YES)
	    {
	      inArray = YES;
	    }
	  else if ([last isKindOfClass: NSDictionaryClass] == YES)
	    {
	      inDictionary = YES;
	    }
	}
    }
  else if ([elementName isEqualToString: @"key"] == YES)
    {
      if (value == nil)
	{
	  ASSIGN(key, @"");	// Empty key.
	}
      else
	{
          ASSIGN(key, [value makeImmutableCopyOnFail: NO]);
          DESTROY(value);
	}
      return;
    }
  else if ([elementName isEqualToString: @"data"])
    {
      NSData	*d;

      d = [GSMimeDocument decodeBase64:
	     [value dataUsingEncoding: NSASCIIStringEncoding]];
      if (opts == NSPropertyListMutableContainersAndLeaves)
	{
	  d = AUTORELEASE([d mutableCopy]);
	}
      ASSIGN(plist, d);
      if (d == nil)
	{
	  [parser abortParsing];
	  return;
	}
    }
  else if ([elementName isEqualToString: @"date"])
    {
      id	result;

      if ([value hasSuffix: @"Z"] == YES && [value length] == 20)
	{
	  result = [NSCalendarDate dateWithString: value
				   calendarFormat: @"%Y-%m-%dT%H:%M:%SZ"];
	}
      else
	{
	  result = [NSCalendarDate dateWithString: value
				   calendarFormat: @"%Y-%m-%d %H:%M:%S %z"];
	}
      ASSIGN(plist, result);
    }
  else if ([elementName isEqualToString: @"string"])
    {
      id	o;

      if (opts == NSPropertyListMutableContainersAndLeaves)
        {
	  if (value == nil)
	    {
	      o = [NSMutableString string];
	    }
	  else
	    {
	      o = value;
	    }
	}
      else
        {
	  if (value == nil)
	    {
	      o = @"";
	    }
	  else
	    {
	      o = [value makeImmutableCopyOnFail: NO];
	    }
	}
      ASSIGN(plist, o);
    }
  else if ([elementName isEqualToString: @"integer"])
    {
      ASSIGN(plist, [NSNumber numberWithInt: [value intValue]]);
    }
  else if ([elementName isEqualToString: @"real"])
    {
      ASSIGN(plist, [NSNumber numberWithDouble: [value doubleValue]]);
    }
  else if ([elementName isEqualToString: @"true"])
    {
      ASSIGN(plist, [NSNumber numberWithBool: YES]);
    }
  else if ([elementName isEqualToString: @"false"])
    {
      ASSIGN(plist, [NSNumber numberWithBool: NO]);
    }
  else if ([elementName isEqualToString: @"plist"])
    {
      DESTROY(value);
      return;
    }
  else // invalid tag
    {
      NSLog(@"unrecognized tag <%@>", elementName);
      [parser abortParsing];
      return;
    }

  if (inArray == YES)
    {
      [[stack lastObject] addObject: plist];
    }
  else if (inDictionary == YES)
    {
      if (key == nil)
        {
	  [parser abortParsing];
	  return;
	}
      [(NSMutableDictionary*)[stack lastObject] setObject: plist forKey: key];
      DESTROY(key);
    }
  DESTROY(value);
}

- (BOOL) parse
{
  return [theParser parse];
}

- (id) result
{
  return plist;
}

@end




@interface GSBinaryPLParser : NSObject
{
  NSPropertyListMutabilityOptions	mutability;
  const unsigned char	*_bytes;
  NSData		*data;
  unsigned		offset_size;	// Number of bytes per table entry
  unsigned		index_size;	// Number of bytes per table entry
  unsigned		table_start;	// Start address of object table
  unsigned		table_len;	// Length of object table
}

- (id) initWithData: (NSData*)plData
	 mutability: (NSPropertyListMutabilityOptions)m;
- (id) rootObject;
- (id) objectAtIndex: (NSUInteger)index;

@end

@interface BinaryPLGenerator : NSObject
{
  NSMutableData *dest;
  NSMutableArray *objectList;
  NSMutableArray *objectsToDoList;
  id root;

  // Number of bytes per object table index
  unsigned int index_size;
  // Number of bytes per object table entry
  unsigned int offset_size;

  unsigned int table_start;
  unsigned int table_size;
  unsigned int *table;
}

+ (void) serializePropertyList: (id)aPropertyList intoData: (NSMutableData *)destination;
- (id) initWithPropertyList: (id)aPropertyList intoData: (NSMutableData *)destination;
- (void) generate;
- (void) storeObject: (id)object;
- (void) cleanup;

@end


static Class	plArray;
static id	(*plAdd)(id, SEL, id) = 0;

static Class	plDictionary;
static id	(*plSet)(id, SEL, id, id) = 0;

/* Bitmap of 'quotable' characters ... those characters which must be
 * inside a quoted string if written to an old style property list.
 */
static const unsigned char quotables[32] = {
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\x85',
  '\x13',
  '\x00',
  '\x78',
  '\x00',
  '\x00',
  '\x00',
  '\x38',
  '\x01',
  '\x00',
  '\x00',
  '\xa8',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
  '\xff',
};

/* Bitmap of characters considered white space if in an old style property
 * list. This is the same as the set given by the isspace() function in the
 * POSIX locale, but (for cross-locale portability of property list files)
 * is fixed, rather than locale dependent.
 */
static const unsigned char whitespace[32] = {
  '\x00',
  '\x3f',
  '\x00',
  '\x00',
  '\x01',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
  '\x00',
};

#define IS_BIT_SET(a,i) ((((a) & (1<<(i)))) > 0)

#define GS_IS_QUOTABLE(X) IS_BIT_SET(quotables[(X)/8], (X) % 8)

#define GS_IS_WHITESPACE(X) IS_BIT_SET(whitespace[(X)/8], (X) % 8)

static NSCharacterSet *oldQuotables = nil;
static NSCharacterSet *xmlQuotables = nil;

static void setupQuotables(void)
{
  if (oldQuotables == nil)
    {
      NSMutableCharacterSet	*s;

      s = [[NSCharacterSet characterSetWithCharactersInString:
	@"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
	@"abcdefghijklmnopqrstuvwxyz$./_"]
	mutableCopy];
      [s invert];
      oldQuotables = [s copy];
      RELEASE(s);

      s = [[NSCharacterSet characterSetWithCharactersInString:
	@"&<>'\\\""] mutableCopy];
      [s addCharactersInRange: NSMakeRange(0x0001, 0x001f)];
      [s removeCharactersInRange: NSMakeRange(0x0009, 0x0002)];
      [s removeCharactersInRange: NSMakeRange(0x000D, 0x0001)];
      [s addCharactersInRange: NSMakeRange(0xD800, 0x07FF)];
      [s addCharactersInRange: NSMakeRange(0xFFFE, 0x0002)];
      xmlQuotables = [s copy];
      RELEASE(s);
    }
}

#define inrange(ch,min,max) ((ch)>=(min) && (ch)<=(max))
#define char2num(ch) \
inrange(ch,'0','9') \
? ((ch)-0x30) \
: (inrange(ch,'a','f') \
? ((ch)-0x57) : ((ch)-0x37))

typedef	struct	{
  const unsigned char	*ptr;
  unsigned	end;
  unsigned	pos;
  unsigned	lin;
  NSString	*err;
  NSPropertyListMutabilityOptions opt;
  BOOL		key;
  BOOL		old;
} pldata;

/*
 *	Property list parsing - skip whitespace keeping count of lines and
 *	regarding objective-c style comments as whitespace.
 *	Returns YES if there is any non-whitespace text remaining.
 */
static BOOL skipSpace(pldata *pld)
{
  unsigned char	c;

  while (pld->pos < pld->end)
    {
      c = pld->ptr[pld->pos];

      if (GS_IS_WHITESPACE(c) == NO)
	{
	  if (c == '/' && pld->pos < pld->end - 1)
	    {
	      /*
	       * Check for comments beginning '/' followed by '/' or '*'
	       */
	      if (pld->ptr[pld->pos + 1] == '/')
		{
		  pld->pos += 2;
		  while (pld->pos < pld->end)
		    {
		      c = pld->ptr[pld->pos];
		      if (c == '\n')
			{
			  break;
			}
		      pld->pos++;
		    }
		  if (pld->pos >= pld->end)
		    {
		      pld->err = @"reached end of string in comment";
		      return NO;
		    }
		}
	      else if (pld->ptr[pld->pos + 1] == '*')
		{
		  pld->pos += 2;
		  while (pld->pos < pld->end)
		    {
		      c = pld->ptr[pld->pos];
		      if (c == '\n')
			{
			  pld->lin++;
			}
		      else if (c == '*' && pld->pos < pld->end - 1
			&& pld->ptr[pld->pos+1] == '/')
			{
			  pld->pos++; /* Skip past '*'	*/
			  break;
			}
		      pld->pos++;
		    }
		  if (pld->pos >= pld->end)
		    {
		      pld->err = @"reached end of string in comment";
		      return NO;
		    }
		}
	      else
		{
		  return YES;
		}
	    }
	  else
	    {
	      return YES;
	    }
	}
      if (c == '\n')
	{
	  pld->lin++;
	}
      pld->pos++;
    }
  pld->err = @"reached end of string";
  return NO;
}

static inline id parseQuotedString(pldata* pld)
{
  unsigned	start = ++pld->pos;
  unsigned	escaped = 0;
  unsigned	shrink = 0;
  BOOL		hex = NO;
  NSString	*obj;

  while (pld->pos < pld->end)
    {
      unsigned char	c = pld->ptr[pld->pos];

      if (escaped)
	{
	  if (escaped == 1 && c >= '0' && c <= '7')
	    {
	      escaped = 2;
	      hex = NO;
	    }
	  else if (escaped == 1 && (c == 'u' || c == 'U'))
	    {
	      escaped = 2;
	      hex = YES;
	    }
	  else if (escaped > 1)
	    {
	      if (hex && isxdigit(c))
		{
		  shrink++;
		  escaped++;
		  if (escaped == 6)
		    {
		      escaped = 0;
		    }
		}
	      else if (c >= '0' && c <= '7')
		{
		  shrink++;
		  escaped++;
		  if (escaped == 4)
		    {
		      escaped = 0;
		    }
		}
	      else
		{
		  pld->pos--;
		  escaped = 0;
		}
	    }
	  else
	    {
	      escaped = 0;
	    }
	}
      else
	{
	  if (c == '\\')
	    {
	      escaped = 1;
	      shrink++;
	    }
	  else if (c == '"')
	    {
	      break;
	    }
	}
      if (c == '\n')
	pld->lin++;
      pld->pos++;
    }
  if (pld->pos >= pld->end)
    {
      pld->err = @"reached end of string while parsing quoted string";
      return nil;
    }
  if (pld->pos - start - shrink == 0)
    {
      obj = @"";
    }
  else
    {
      unsigned	length;
      unichar	*chars;
      unichar	*temp = NULL;
      unsigned	int temp_length = 0;
      unsigned	j;
      unsigned	k;

      if (!GSToUnicode(&temp, &temp_length, &pld->ptr[start],
		       pld->pos - start, NSUTF8StringEncoding,
		       NSDefaultMallocZone(), 0))
	{
	  pld->err = @"invalid utf8 data while parsing quoted string";
	  return nil;
	}
      length = temp_length - shrink;
      chars = NSAllocateCollectable(sizeof(unichar) * length, 0);
      escaped = 0;
      hex = NO;
      for (j = 0, k = 0; j < temp_length; j++)
	{
	  unichar c = temp[j];

	  if (escaped)
	    {
	      if (escaped == 1 && c >= '0' && c <= '7')
		{
		  chars[k] = c - '0';
		  hex = NO;
		  escaped++;
		}
	      else if (escaped == 1 && (c == 'u' || c == 'U'))
		{
		  chars[k] = 0;
		  hex = YES;
		  escaped++;
		}
	      else if (escaped > 1)
		{
		  if (hex && isxdigit(c))
		    {
		      chars[k] <<= 4;
		      chars[k] |= char2num(c);
		      escaped++;
		      if (escaped == 6)
			{
			  escaped = 0;
			  k++;
			}
		    }
		  else if (c >= '0' && c <= '7')
		    {
		      chars[k] <<= 3;
		      chars[k] |= (c - '0');
		      escaped++;
		      if (escaped == 4)
			{
			  escaped = 0;
			  k++;
			}
		    }
		  else
		    {
		      escaped = 0;
		      j--;
		      k++;
		    }
		}
	      else
		{
		  escaped = 0;
		  switch (c)
		    {
		      case 'a' : chars[k] = '\a'; break;
		      case 'b' : chars[k] = '\b'; break;
		      case 't' : chars[k] = '\t'; break;
		      case 'r' : chars[k] = '\r'; break;
		      case 'n' : chars[k] = '\n'; break;
		      case 'v' : chars[k] = '\v'; break;
		      case 'f' : chars[k] = '\f'; break;
		      default  : chars[k] = c; break;
		    }
		  k++;
		}
	    }
	  else
	    {
	      chars[k] = c;
	      if (c == '\\')
		{
		  escaped = 1;
		}
	      else
		{
		  k++;
		}
	    }
	}

      NSZoneFree(NSDefaultMallocZone(), temp);
      length = k;

      if (pld->key ==
	NO && pld->opt == NSPropertyListMutableContainersAndLeaves)
	{
	  obj = [GSMutableString alloc];
	  obj = [obj initWithCharactersNoCopy: chars
				       length: length
				 freeWhenDone: YES];
	}
      else
	{
	  obj = [GSMutableString alloc];
	  obj = [obj initWithCharactersNoCopy: chars
				       length: length
				 freeWhenDone: YES];
	}
    }
  pld->pos++;
  return obj;
}

static inline id parseUnquotedString(pldata *pld)
{
  unsigned	start = pld->pos;
  unsigned	i;
  unsigned	length;
  id		obj;
  unichar	*chars;

  while (pld->pos < pld->end)
    {
      if (GS_IS_QUOTABLE(pld->ptr[pld->pos]) == YES)
	break;
      pld->pos++;
    }

  length = pld->pos - start;
  chars = NSAllocateCollectable(sizeof(unichar) * length, 0);
  for (i = 0; i < length; i++)
    {
      chars[i] = pld->ptr[start + i];
    }

  if (pld->key == NO && pld->opt == NSPropertyListMutableContainersAndLeaves)
    {
      obj = [GSMutableString alloc];
      obj = [obj initWithCharactersNoCopy: chars
				   length: length
			     freeWhenDone: YES];
    }
  else
    {
      obj = [GSMutableString alloc];
      obj = [obj initWithCharactersNoCopy: chars
				   length: length
			     freeWhenDone: YES];
    }
  return obj;
}

static id parsePlItem(pldata* pld)
{
  id	result = nil;
  BOOL	start = (pld->pos == 0 ? YES : NO);

  if (skipSpace(pld) == NO)
    {
      return nil;
    }
  switch (pld->ptr[pld->pos])
    {
      case '{':
	{
	  NSMutableDictionary	*dict;

	  dict = [[plDictionary allocWithZone: NSDefaultMallocZone()]
	    initWithCapacity: 0];
	  pld->pos++;
	  while (skipSpace(pld) == YES && pld->ptr[pld->pos] != '}')
	    {
	      id	key;
	      id	val;

	      pld->key = YES;
	      key = parsePlItem(pld);
	      pld->key = NO;
	      if (key == nil)
		{
		  return nil;
		}
	      if (skipSpace(pld) == NO)
		{
		  RELEASE(key);
		  RELEASE(dict);
		  return nil;
		}
	      if (pld->ptr[pld->pos] != '=')
		{
		  pld->err = @"unexpected character (wanted '=')";
		  RELEASE(key);
		  RELEASE(dict);
		  return nil;
		}
	      pld->pos++;
	      val = parsePlItem(pld);
	      if (val == nil)
		{
		  RELEASE(key);
		  RELEASE(dict);
		  return nil;
		}
	      if (skipSpace(pld) == NO)
		{
		  RELEASE(key);
		  RELEASE(val);
		  RELEASE(dict);
		  return nil;
		}
	      if (pld->ptr[pld->pos] == ';')
		{
		  pld->pos++;
		}
	      else if (pld->ptr[pld->pos] != '}')
		{
		  pld->err = @"unexpected character (wanted ';' or '}')";
		  RELEASE(key);
		  RELEASE(val);
		  RELEASE(dict);
		  return nil;
		}
	      (*plSet)(dict, @selector(setObject:forKey:), val, key);
	      RELEASE(key);
	      RELEASE(val);
	    }
	  if (pld->pos >= pld->end)
	    {
	      pld->err = @"unexpected end of string when parsing dictionary";
	      RELEASE(dict);
	      return nil;
	    }
	  pld->pos++;
	  result = dict;
	  if (pld->opt == NSPropertyListImmutable)
	    {
	      [result makeImmutableCopyOnFail: NO];
	    }
	}
	break;

      case '(':
	{
	  NSMutableArray	*array;

	  array = [[plArray allocWithZone: NSDefaultMallocZone()]
	    initWithCapacity: 0];
	  pld->pos++;
	  while (skipSpace(pld) == YES && pld->ptr[pld->pos] != ')')
	    {
	      id	val;

	      val = parsePlItem(pld);
	      if (val == nil)
		{
		  RELEASE(array);
		  return nil;
		}
	      if (skipSpace(pld) == NO)
		{
		  RELEASE(val);
		  RELEASE(array);
		  return nil;
		}
	      if (pld->ptr[pld->pos] == ',')
		{
		  pld->pos++;
		}
	      else if (pld->ptr[pld->pos] != ')')
		{
		  pld->err = @"unexpected character (wanted ',' or ')')";
		  RELEASE(val);
		  RELEASE(array);
		  return nil;
		}
	      (*plAdd)(array, @selector(addObject:), val);
	      RELEASE(val);
	    }
	  if (pld->pos >= pld->end)
	    {
	      pld->err = @"unexpected end of string when parsing array";
	      RELEASE(array);
	      return nil;
	    }
	  pld->pos++;
	  result = array;
	  if (pld->opt == NSPropertyListImmutable)
	    {
	      [result makeImmutableCopyOnFail: NO];
	    }
	}
	break;

      case '<':
	pld->pos++;
	if (pld->pos < pld->end && pld->ptr[pld->pos] == '*')
	  {
	    const unsigned char	*ptr;
	    unsigned		min;
	    unsigned		len = 0;
	    unsigned		i;

	    pld->old = NO;
	    pld->pos++;
	    min = pld->pos;
	    ptr = &(pld->ptr[min]);
	    while (pld->pos < pld->end && pld->ptr[pld->pos] != '>')
	      {
		pld->pos++;
	      }
	    len = pld->pos - min;
	    if (len > 1)
	      {
		unsigned char	type = *ptr++;

		len--;
		// Allow for quoted values.
		if (ptr[0] == '"' && len > 1)
		  {
		    len--;
		    ptr++;
		    if (ptr[len - 1] == '"')
		      {
			len--;
		      }
		  }
		if (type == 'I')
		  {
		    char	buf[len+1];

		    for (i = 0; i < len; i++) buf[i] = (char)ptr[i];
		    buf[len] = '\0';
		    result = [[NSNumber alloc] initWithLong: atol(buf)];
		  }
		else if (type == 'B')
		  {
		    if (ptr[0] == 'Y')
		      {
			result = [[NSNumber alloc] initWithBool: YES];
		      }
		    else if (ptr[0] == 'N')
		      {
			result = [[NSNumber alloc] initWithBool: NO];
		      }
		    else
		      {
			pld->err = @"bad value for bool";
			return nil;
		      }
		  }
		else if (type == 'D')
		  {
		    unichar	buf[len];
		    unsigned	i;
		    NSString	*str;

		    for (i = 0; i < len; i++) buf[i] = ptr[i];
		    str = [[NSString alloc] initWithCharacters: buf
							length: len];
		    result = [[NSCalendarDate alloc] initWithString: str
		      calendarFormat: @"%Y-%m-%d %H:%M:%S %z"];
		    RELEASE(str);
		  }
		else if (type == 'R')
		  {
		    unichar	buf[len];
		    double	d = 0.0;

		    for (i = 0; i < len; i++) buf[i] = ptr[i];
		    GSScanDouble(buf, len, &d);
		    result = [[NSNumber alloc] initWithDouble: d];
		  }
		else
		  {
		    pld->err = @"unrecognized type code after '<*'";
		    return nil;
		  }
	      }
	    else
	      {
		pld->err = @"missing type code after '<*'";
		return nil;
	      }
	    if (pld->pos >= pld->end)
	      {
		pld->err = @"unexpected end of string when parsing data";
		return nil;
	      }
	    if (pld->ptr[pld->pos] != '>')
	      {
		pld->err = @"unexpected character (wanted '>')";
		return nil;
	      }
	    pld->pos++;
	  }
	else
	  {
	    NSMutableData	*data;
	    unsigned	max = pld->end - 1;
	    unsigned	char	buf[BUFSIZ];
	    unsigned	len = 0;

	    data = [[NSMutableData alloc] initWithCapacity: 0];
	    skipSpace(pld);
	    while (pld->pos < max
	      && isxdigit(pld->ptr[pld->pos])
	      && isxdigit(pld->ptr[pld->pos+1]))
	      {
		unsigned char	byte;

		byte = (char2num(pld->ptr[pld->pos])) << 4;
		pld->pos++;
		byte |= char2num(pld->ptr[pld->pos]);
		pld->pos++;
		buf[len++] = byte;
		if (len == sizeof(buf))
		  {
		    [data appendBytes: buf length: len];
		    len = 0;
		  }
		skipSpace(pld);
	      }
	    if (pld->pos >= pld->end)
	      {
		pld->err = @"unexpected end of string when parsing data";
		RELEASE(data);
		return nil;
	      }
	    if (pld->ptr[pld->pos] != '>')
	      {
		pld->err = @"unexpected character (wanted '>')";
		RELEASE(data);
		return nil;
	      }
	    if (len > 0)
	      {
		[data appendBytes: buf length: len];
	      }
	    pld->pos++;
	    // FIXME ... should be immutable sometimes.
	    result = data;
	  }
	break;

      case '"':
	result = parseQuotedString(pld);
	break;

      default:
	result = parseUnquotedString(pld);
	break;
    }
  if (start == YES && result != nil)
    {
      if (skipSpace(pld) == YES)
	{
	  pld->err = @"extra data after parsed string";
	  result = nil;		// Not at end of string.
	}
    }
  return result;
}

id
GSPropertyListFromStringsFormat(NSString *string)
{
  NSMutableDictionary	*dict;
  pldata		_pld;
  pldata		*pld = &_pld;
  NSData		*d;

  /*
   * An empty string is a nil property list.
   */
  if ([string length] == 0)
    {
      return nil;
    }

  d = [string dataUsingEncoding: NSUTF8StringEncoding];
  NSCAssert(d, @"Couldn't get utf8 data from string.");
  _pld.ptr = (unsigned char*)[d bytes];
  _pld.pos = 0;
  _pld.end = [d length];
  _pld.err = nil;
  _pld.lin = 0;
  _pld.opt = NSPropertyListImmutable;
  _pld.key = NO;
  _pld.old = YES;	// OpenStep style
  [NSPropertyListSerialization class];	// initialise

  dict = [[plDictionary allocWithZone: NSDefaultMallocZone()]
    initWithCapacity: 0];
  while (skipSpace(pld) == YES)
    {
      id	key;
      id	val;

      if (pld->ptr[pld->pos] == '"')
	{
	  key = parseQuotedString(pld);
	}
      else
	{
	  key = parseUnquotedString(pld);
	}
      if (key == nil)
	{
	  DESTROY(dict);
	  break;
	}
      if (skipSpace(pld) == NO)
	{
	  pld->err = @"incomplete final entry (no semicolon?)";
	  RELEASE(key);
	  DESTROY(dict);
	  break;
	}
      if (pld->ptr[pld->pos] == ';')
	{
	  pld->pos++;
	  (*plSet)(dict, @selector(setObject:forKey:), @"", key);
	  RELEASE(key);
	}
      else if (pld->ptr[pld->pos] == '=')
	{
	  pld->pos++;
	  if (skipSpace(pld) == NO)
	    {
	      RELEASE(key);
	      DESTROY(dict);
	      break;
	    }
	  if (pld->ptr[pld->pos] == '"')
	    {
	      val = parseQuotedString(pld);
	    }
	  else
	    {
	      val = parseUnquotedString(pld);
	    }
	  if (val == nil)
	    {
	      RELEASE(key);
	      DESTROY(dict);
	      break;
	    }
	  if (skipSpace(pld) == NO)
	    {
	      pld->err = @"missing final semicolon";
	      RELEASE(key);
	      RELEASE(val);
	      DESTROY(dict);
	      break;
	    }
	  (*plSet)(dict, @selector(setObject:forKey:), val, key);
	  RELEASE(key);
	  RELEASE(val);
	  if (pld->ptr[pld->pos] == ';')
	    {
	      pld->pos++;
	    }
	  else
	    {
	      pld->err = @"unexpected character (wanted ';')";
	      DESTROY(dict);
	      break;
	    }
	}
      else
	{
	  pld->err = @"unexpected character (wanted '=' or ';')";
	  RELEASE(key);
	  DESTROY(dict);
	  break;
	}
    }
  if (dict == nil && _pld.err != nil)
    {
      RELEASE(dict);
      [NSException raise: NSGenericException
		  format: @"Parse failed at line %d (char %d) - %@",
	_pld.lin + 1, _pld.pos + 1, _pld.err];
    }
  return AUTORELEASE(dict);
}



#include <math.h>

static char base64[]
  = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

static void
encodeBase64(NSData *source, NSMutableData *dest)
{
  int		length = [source length];
  int		enclen = length / 3;
  int		remlen = length - 3 * enclen;
  int		destlen = 4 * ((length + 2) / 3);
  unsigned char *sBuf;
  unsigned char *dBuf;
  int		sIndex = 0;
  int		dIndex = [dest length];

  [dest setLength: dIndex + destlen];

  if (length == 0)
    {
      return;
    }
  sBuf = (unsigned char*)[source bytes];
  dBuf = [dest mutableBytes];

  for (sIndex = 0; sIndex < length - 2; sIndex += 3, dIndex += 4)
    {
      dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
      dBuf[dIndex + 1]
	= base64[((sBuf[sIndex] << 4) | (sBuf[sIndex + 1] >> 4)) & 0x3f];
      dBuf[dIndex + 2]
	= base64[((sBuf[sIndex + 1] << 2) | (sBuf[sIndex + 2] >> 6)) & 0x3f];
      dBuf[dIndex + 3] = base64[sBuf[sIndex + 2] & 0x3f];
    }

  if (remlen == 1)
    {
      dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
      dBuf[dIndex + 1] = (sBuf[sIndex] << 4) & 0x30;
      dBuf[dIndex + 1] = base64[dBuf[dIndex + 1]];
      dBuf[dIndex + 2] = '=';
      dBuf[dIndex + 3] = '=';
    }
  else if (remlen == 2)
    {
      dBuf[dIndex] = base64[sBuf[sIndex] >> 2];
      dBuf[dIndex + 1] = (sBuf[sIndex] << 4) & 0x30;
      dBuf[dIndex + 1] |= sBuf[sIndex + 1] >> 4;
      dBuf[dIndex + 1] = base64[dBuf[dIndex + 1]];
      dBuf[dIndex + 2] = (sBuf[sIndex + 1] << 2) & 0x3c;
      dBuf[dIndex + 2] = base64[dBuf[dIndex + 2]];
      dBuf[dIndex + 3] = '=';
    }
}

static inline void Append(void *bytes, unsigned length, NSMutableData *dst)
{
  [dst appendBytes: bytes length: length];
}

/*
 * Output a string escaped for OpenStep style property lists.
 * The result is ascii data.
 */
static void
PString(NSString *obj, NSMutableData *output)
{
  unsigned	length;

  if ((length = [obj length]) == 0)
    {
      [output appendBytes: "\"\"" length: 2];
    }
  else if ([obj rangeOfCharacterFromSet: oldQuotables].length > 0
    || [obj characterAtIndex: 0] == '/')
    {
      unichar		tmp[length <= 1024 ? length : 0];
      unichar		*ustring;
      unichar		*from;
      unichar		*end;
      unsigned char	*ptr;
      int		base = [output length];
      int		len = 0;

      if (length <= 1024)
	{
	  ustring = tmp;
	}
      else
	{
	  ustring = NSAllocateCollectable(sizeof(unichar) * length, 0);
	}
      end = &ustring[length];
      [obj getCharacters: ustring];
      for (from = ustring; from < end; from++)
	{
	  switch (*from)
	    {
	      case '\t':
	      case '\r':
	      case '\n':
		len++;
		break;

	      case '\a':
	      case '\b':
	      case '\v':
	      case '\f':
	      case '\\':
	      case '"' :
		len += 2;
		break;

	      default:
		if (*from < 128)
		  {
		    if (isprint(*from) || *from == ' ')
		      {
			len++;
		      }
		    else
		      {
			len += 4;
		      }
		  }
		else
		  {
		    len += 6;
		  }
		break;
	    }
	}

      [output setLength: base + len + 2];
      ptr = [output mutableBytes] + base;
      *ptr++ = '"';
      for (from = ustring; from < end; from++)
	{
	  switch (*from)
	    {
	      case '\t':
	      case '\r':
	      case '\n':
		*ptr++ = *from;
		break;

	      case '\a': 	*ptr++ = '\\'; *ptr++ = 'a';  break;
	      case '\b': 	*ptr++ = '\\'; *ptr++ = 'b';  break;
	      case '\v': 	*ptr++ = '\\'; *ptr++ = 'v';  break;
	      case '\f': 	*ptr++ = '\\'; *ptr++ = 'f';  break;
	      case '\\': 	*ptr++ = '\\'; *ptr++ = '\\'; break;
	      case '"' : 	*ptr++ = '\\'; *ptr++ = '"';  break;

	      default:
		if (*from < 128)
		  {
		    if (isprint(*from) || *from == ' ')
		      {
			*ptr++ = *from;
		      }
		    else
		      {
			unichar	c = *from;

			*ptr++ = '\\';
			ptr[2] = (c & 7) + '0';
			c >>= 3;
			ptr[1] = (c & 7) + '0';
			c >>= 3;
			ptr[0] = (c & 7) + '0';
			ptr += 3;
		      }
		  }
		else
		  {
		    unichar	c = *from;

		    *ptr++ = '\\';
		    *ptr++ = 'U';
		    ptr[3] = (c & 15) > 9 ? (c & 15) + 55 : (c & 15) + 48;
		    c >>= 4;
		    ptr[2] = (c & 15) > 9 ? (c & 15) + 55 : (c & 15) + 48;
		    c >>= 4;
		    ptr[1] = (c & 15) > 9 ? (c & 15) + 55 : (c & 15) + 48;
		    c >>= 4;
		    ptr[0] = (c & 15) > 9 ? (c & 15) + 55 : (c & 15) + 48;
		    ptr += 4;
		  }
		break;
	    }
	}
      *ptr++ = '"';

      if (ustring != tmp)
	{
	  NSZoneFree(NSDefaultMallocZone(), ustring);
	}
    }
  else
    {
      NSData	*d = [obj dataUsingEncoding: NSASCIIStringEncoding];

      [output appendData: d];
    }
}

/*
 * Output a string escaped for use in xml.
 * Result is utf8 data.
 */
static void
XString(NSString* obj, NSMutableData *output)
{
  static const char	*hexdigits = "0123456789ABCDEF";
  unsigned	end;

  end = [obj length];
  if (end == 0)
    {
      return;
    }

  if ([obj rangeOfCharacterFromSet: xmlQuotables].length > 0)
    {
      unichar	*base;
      unichar	*map;
      unichar	c;
      unsigned	len;
      unsigned	rpos;
      unsigned	wpos;

      base = NSAllocateCollectable(sizeof(unichar) * end, 0);
      [obj getCharacters: base];
      for (len = rpos = 0; rpos < end; rpos++)
	{
	  c = base[rpos];
	  switch (c)
	    {
	      case '&':
		len += 5;
		break;
	      case '<':
	      case '>':
		len += 4;
		break;
	      case '\'':
	      case '"':
		len += 6;
		break;

	      default:
		if ((c < 0x20 && (c != 0x09 && c != 0x0A && c != 0x0D))
		  || (c > 0xD7FF && c < 0xE000) || c > 0xFFFD)
		  {
		    len += 6;
		  }
		else
		  {
		    len++;
		  }
		break;
	    }
	}
      map = NSAllocateCollectable(sizeof(unichar) * len, 0);
      for (wpos = rpos = 0; rpos < end; rpos++)
	{
	  c = base[rpos];
	  switch (c)
	    {
	      case '&':
		map[wpos++] = '&';
		map[wpos++] = 'a';
		map[wpos++] = 'm';
		map[wpos++] = 'p';
		map[wpos++] = ';';
		break;
	      case '<':
		map[wpos++] = '&';
		map[wpos++] = 'l';
		map[wpos++] = 't';
		map[wpos++] = ';';
		break;
	      case '>':
		map[wpos++] = '&';
		map[wpos++] = 'g';
		map[wpos++] = 't';
		map[wpos++] = ';';
		break;
	      case '\'':
		map[wpos++] = '&';
		map[wpos++] = 'a';
		map[wpos++] = 'p';
		map[wpos++] = 'o';
		map[wpos++] = 's';
		map[wpos++] = ';';
		break;
	      case '"':
		map[wpos++] = '&';
		map[wpos++] = 'q';
		map[wpos++] = 'u';
		map[wpos++] = 'o';
		map[wpos++] = 't';
		map[wpos++] = ';';
		break;

	      default:
		if ((c < 0x20 && (c != 0x09 && c != 0x0A && c != 0x0D))
		  || (c > 0xD7FF && c < 0xE000) || c > 0xFFFD)
		  {
		    map[wpos++] = '\\';
		    map[wpos++] = 'U';
		    map[wpos++] = hexdigits[(c>>12) & 0xf];
		    map[wpos++] = hexdigits[(c>>8) & 0xf];
		    map[wpos++] = hexdigits[(c>>4) & 0xf];
		    map[wpos++] = hexdigits[c & 0xf];
		  }
		else
		  {
		    map[wpos++] = c;
		  }
		break;
	    }
	}
      NSZoneFree(NSDefaultMallocZone(), base);
      obj = [[NSString alloc] initWithCharacters: map length: len];
      [output appendData: [obj dataUsingEncoding: NSUTF8StringEncoding]];
      RELEASE(obj);
    }
  else
    {
      [output appendData: [obj dataUsingEncoding: NSUTF8StringEncoding]];
    }
}


static const char	*indentStrings[] = {
  "",
  "  ",
  "    ",
  "      ",
  "\t",
  "\t  ",
  "\t    ",
  "\t      ",
  "\t\t",
  "\t\t  ",
  "\t\t    ",
  "\t\t      ",
  "\t\t\t",
  "\t\t\t  ",
  "\t\t\t    ",
  "\t\t\t      ",
  "\t\t\t\t",
  "\t\t\t\t  ",
  "\t\t\t\t    ",
  "\t\t\t\t      ",
  "\t\t\t\t\t",
  "\t\t\t\t\t  ",
  "\t\t\t\t\t    ",
  "\t\t\t\t\t      ",
  "\t\t\t\t\t\t"
};

/**
 * obj is the object to be written out<br />
 * loc is the locale for formatting (or nil to indicate no formatting)<br />
 * lev is the level of indentation to use<br />
 * step is the indentation step (0 == 0, 1 = 2, 2 = 4, 3 = 8)<br />
 * x is an indicator for xml or old/new openstep property list format<br />
 * dest is the output buffer.
 */
static void
OAppend(id obj, NSDictionary *loc, unsigned lev, unsigned step,
  NSPropertyListFormat x, NSMutableData *dest)
{
  if (NSStringClass == 0)
    {
      [NSPropertyListSerialization class];      // Force initialisation
    }
  if ([obj isKindOfClass: NSStringClass])
    {
      if (x == NSPropertyListXMLFormat_v1_0)
	{
	  [dest appendBytes: "<string>" length: 8];
	  XString(obj, dest);
	  [dest appendBytes: "</string>\n" length: 10];
	}
      else
	{
	  PString(obj, dest);
	}
    }
  else if ([obj isKindOfClass: NSNumberClass])
    {
      const char	*t = [obj objCType];

      if (*t ==  'c' || *t == 'C')
	{
	  BOOL	val = [obj boolValue];

	  if (val == YES)
	    {
	      if (x == NSPropertyListXMLFormat_v1_0)
		{
		  [dest appendBytes: "<true/>\n" length: 8];
		}
	      else if (x == NSPropertyListGNUstepFormat)
		{
		  [dest appendBytes: "<*BY>" length: 5];
		}
	      else
		{
		  PString([obj description], dest);
		}
	    }
	  else
	    {
	      if (x == NSPropertyListXMLFormat_v1_0)
		{
		  [dest appendBytes: "<false/>\n" length: 9];
		}
	      else if (x == NSPropertyListGNUstepFormat)
		{
		  [dest appendBytes: "<*BN>" length: 5];
		}
	      else
		{
		  PString([obj description], dest);
		}
	    }
	}
      else if (strchr("sSiIlLqQ", *t) != 0)
	{
	  if (x == NSPropertyListXMLFormat_v1_0)
	    {
	      [dest appendBytes: "<integer>" length: 9];
	      XString([obj stringValue], dest);
	      [dest appendBytes: "</integer>\n" length: 11];
	    }
	  else if (x == NSPropertyListGNUstepFormat)
	    {
	      [dest appendBytes: "<*I" length: 3];
	      [dest appendData:
	        [[obj stringValue] dataUsingEncoding: NSASCIIStringEncoding]];
	      [dest appendBytes: ">" length: 1];
	    }
	  else
	    {
	      PString([obj description], dest);
	    }
	}
      else
	{
	  if (x == NSPropertyListXMLFormat_v1_0)
	    {
	      [dest appendBytes: "<real>" length: 6];
	      XString([obj stringValue], dest);
	      [dest appendBytes: "</real>\n" length: 8];
	    }
	  else if (x == NSPropertyListGNUstepFormat)
	    {
	      [dest appendBytes: "<*R" length: 3];
	      [dest appendData:
	        [[obj stringValue] dataUsingEncoding: NSASCIIStringEncoding]];
	      [dest appendBytes: ">" length: 1];
	    }
	  else
	    {
	      PString([obj description], dest);
	    }
	}
    }
  else if ([obj isKindOfClass: NSDataClass])
    {
      if (x == NSPropertyListXMLFormat_v1_0)
	{
	  [dest appendBytes: "<data>\n" length: 7];
	  encodeBase64(obj, dest);
	  [dest appendBytes: "</data>\n" length: 8];
	}
      else
	{
	  const unsigned char	*src;
	  unsigned char		*dst;
	  int		length;
	  int		i;
	  int		j;

	  src = [obj bytes];
	  length = [obj length];
	  #define num2char(num) ((num) < 0xa ? ((num)+'0') : ((num)+0x57))

	  j = [dest length];
	  [dest setLength: j + 2*length+(length > 4 ? (length-1)/4+2 : 2)];
	  dst = [dest mutableBytes];
	  dst[j++] = '<';
	  for (i = 0; i < length; i++, j++)
	    {
	      dst[j++] = num2char((src[i]>>4) & 0x0f);
	      dst[j] = num2char(src[i] & 0x0f);
	      if ((i & 3) == 3 && i < length-1)
		{
		  /* if we've just finished a 32-bit int, print a space */
		  dst[++j] = ' ';
		}
	    }
	  dst[j++] = '>';
	}
    }
  else if ([obj isKindOfClass: NSDateClass])
    {
      static NSTimeZone	*z = nil;

      if (z == nil)
	{
	  z = RETAIN([NSTimeZone timeZoneForSecondsFromGMT: 0]);
	}
      if (x == NSPropertyListXMLFormat_v1_0)
	{
	  [dest appendBytes: "<date>" length: 6];
	  obj = [obj descriptionWithCalendarFormat: @"%Y-%m-%dT%H:%M:%SZ"
	    timeZone: z locale: nil];
	  obj = [obj dataUsingEncoding: NSASCIIStringEncoding];
	  [dest appendData: obj];
	  [dest appendBytes: "</date>\n" length: 8];
	}
      else if (x == NSPropertyListGNUstepFormat)
	{
	  [dest appendBytes: "<*D" length: 3];
	  obj = [obj descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S %z"
	    timeZone: z locale: nil];
	  obj = [obj dataUsingEncoding: NSASCIIStringEncoding];
	  [dest appendData: obj];
	  [dest appendBytes: ">" length: 1];
	}
      else
	{
	  obj = [obj descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S %z"
	    timeZone: z locale: nil];
	  PString(obj, dest);
	}
    }
  else if ([obj isKindOfClass: NSArrayClass])
    {
      const char	*iBaseString;
      const char	*iSizeString;
      unsigned	level = lev;

      if (level*step < sizeof(indentStrings)/sizeof(id))
	{
	  iBaseString = indentStrings[level*step];
	}
      else
	{
	  iBaseString
	    = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}
      level++;
      if (level*step < sizeof(indentStrings)/sizeof(id))
	{
	  iSizeString = indentStrings[level*step];
	}
      else
	{
	  iSizeString
	    = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}

      if (x == NSPropertyListXMLFormat_v1_0)
	{
	  NSEnumerator	*e;

	  [dest appendBytes: "<array>\n" length: 8];
	  e = [obj objectEnumerator];
	  while ((obj = [e nextObject]))
	    {
	      [dest appendBytes: iSizeString length: strlen(iSizeString)];
	      OAppend(obj, loc, level, step, x, dest);
	    }
	  [dest appendBytes: iBaseString length: strlen(iBaseString)];
	  [dest appendBytes: "</array>\n" length: 9];
	}
      else
	{
	  unsigned		count = [obj count];
	  unsigned		last = count - 1;
	  NSString		*plists[count];
	  unsigned		i;

	  if ([obj isProxy] == YES)
	    {
	      for (i = 0; i < count; i++)
		{
		  plists[i] = [obj objectAtIndex: i];
		}
	    }
	  else
	    {
	      [obj getObjects: plists];
	    }

	  if (loc == nil)
	    {
	      [dest appendBytes: "(" length: 1];
	      for (i = 0; i < count; i++)
		{
		  id	item = plists[i];

		  OAppend(item, nil, 0, step, x, dest);
		  if (i != last)
		    {
		      [dest appendBytes: ", " length: 2];
		    }
		}
	      [dest appendBytes: ")" length: 1];
	    }
	  else
	    {
	      [dest appendBytes: "(\n" length: 2];
	      for (i = 0; i < count; i++)
		{
		  id	item = plists[i];

		  [dest appendBytes: iSizeString length: strlen(iSizeString)];
		  OAppend(item, loc, level, step, x, dest);
		  if (i == last)
		    {
		      [dest appendBytes: "\n" length: 1];
		    }
		  else
		    {
		      [dest appendBytes: ",\n" length: 2];
		    }
		}
	      [dest appendBytes: iBaseString length: strlen(iBaseString)];
	      [dest appendBytes: ")" length: 1];
	    }
	}
    }
  else if ([obj isKindOfClass: NSDictionaryClass])
    {
      const char	*iBaseString;
      const char	*iSizeString;
      SEL		objSel = @selector(objectForKey:);
      IMP		myObj = [obj methodForSelector: objSel];
      unsigned		i;
      NSArray		*keyArray = [obj allKeys];
      unsigned		numKeys = [keyArray count];
      NSString		*plists[numKeys];
      NSString		*keys[numKeys];
      BOOL		canCompare = YES;
      Class		lastClass = 0;
      unsigned		level = lev;
      BOOL		isProxy = [obj isProxy];

      if (level*step < sizeof(indentStrings)/sizeof(id))
	{
	  iBaseString = indentStrings[level*step];
	}
      else
	{
	  iBaseString
	    = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}
      level++;
      if (level*step < sizeof(indentStrings)/sizeof(id))
	{
	  iSizeString = indentStrings[level*step];
	}
      else
	{
	  iSizeString
	    = indentStrings[sizeof(indentStrings)/sizeof(id)-1];
	}

      if (isProxy == YES)
	{
	  for (i = 0; i < numKeys; i++)
	    {
	      keys[i] = [keyArray objectAtIndex: i];
	    }
	}
      else
	{
	  [keyArray getObjects: keys];
	}

      if (x == NSPropertyListXMLFormat_v1_0)
        {
	  /* This format can only use strings as keys.
	   */
	  for (i = 0; i < numKeys; i++)
	    {
	      if ([keys[i] isKindOfClass: NSStringClass] == NO)
	        {
	          if ([keys[i] isKindOfClass: NSNumberClass] == YES)
		    {
		      keys[i] = [keys[i] description];
		    }
		  else
		    {
		      [NSException raise: NSInvalidArgumentException
		        format: @"Bad key in property list: '%@'", keys[i]];
		    }
		}
	    }
	}
      else
	{
	  /* All keys must respond to -compare: for sorting.
	   */
	  lastClass = NSStringClass;
	  for (i = 0; i < numKeys; i++)
	    {
	      if (GSObjCClass(keys[i]) == lastClass)
		continue;
	      if ([keys[i] isKindOfClass: NSStringClass] == NO)
		{
		  canCompare = NO;
		  break;
		}
	      lastClass = GSObjCClass(keys[i]);
	    }
	}

      if (canCompare == YES)
	{
	  #define STRIDE_FACTOR 3
	  unsigned	c,d, stride;
	  BOOL		found;
	  NSComparisonResult	(*comp)(id, SEL, id) = 0;
	  unsigned int	count = numKeys;
	  #ifdef	GSWARN
	  BOOL		badComparison = NO;
	  #endif

	  stride = 1;
	  while (stride <= count)
	    {
	      stride = stride * STRIDE_FACTOR + 1;
	    }
	  lastClass = 0;
	  while (stride > (STRIDE_FACTOR - 1))
	    {
	      // loop to sort for each value of stride
	      stride = stride / STRIDE_FACTOR;
	      for (c = stride; c < count; c++)
		{
		  found = NO;
		  if (stride > c)
		    {
		      break;
		    }
		  d = c - stride;
		  while (!found)
		    {
		      id			a = keys[d + stride];
		      id			b = keys[d];
		      Class			x;
		      NSComparisonResult	r;

		      x = GSObjCClass(a);
		      if (x != lastClass)
			{
			  lastClass = x;
			  comp = (NSComparisonResult (*)(id, SEL, id))
			    [a methodForSelector: @selector(compare:)];
			}
		      r = (*comp)(a, @selector(compare:), b);
		      if (r < 0)
			{
			  #ifdef	GSWARN
			  if (r != NSOrderedAscending)
			    {
			      badComparison = YES;
			    }
			  #endif
			  keys[d + stride] = b;
			  keys[d] = a;
			  if (stride > d)
			    {
			      break;
			    }
			  d -= stride;
			}
		      else
			{
			  #ifdef	GSWARN
			  if (r != NSOrderedDescending
			    && r != NSOrderedSame)
			    {
			      badComparison = YES;
			    }
			  #endif
			  found = YES;
			}
		    }
		}
	    }
	  #ifdef	GSWARN
	  if (badComparison == YES)
	    {
	      NSWarnFLog(@"Detected bad return value from comparison");
	    }
	  #endif
	}

      if (isProxy == YES)
	{
	  for (i = 0; i < numKeys; i++)
	    {
	      plists[i] = [(NSDictionary*)obj objectForKey: keys[i]];
	    }
	}
      else
	{
	  for (i = 0; i < numKeys; i++)
	    {
	      plists[i] = (*myObj)(obj, objSel, keys[i]);
	    }
	}

      if (x == NSPropertyListXMLFormat_v1_0)
	{
	  [dest appendBytes: "<dict>\n" length: 7];
	  for (i = 0; i < numKeys; i++)
	    {
	      [dest appendBytes: iSizeString length: strlen(iSizeString)];
	      [dest appendBytes: "<key>" length: 5];
	      XString(keys[i], dest);
	      [dest appendBytes: "</key>\n" length: 7];
	      [dest appendBytes: iSizeString length: strlen(iSizeString)];
	      OAppend(plists[i], loc, level, step, x, dest);
	    }
	  [dest appendBytes: iBaseString length: strlen(iBaseString)];
	  [dest appendBytes: "</dict>\n" length: 8];
	}
      else if (loc == nil)
	{
	  [dest appendBytes: "{" length: 1];
	  for (i = 0; i < numKeys; i++)
	    {
	      OAppend(keys[i], nil, 0, step, x, dest);
	      [dest appendBytes: " = " length: 3];
	      OAppend(plists[i], nil, 0, step, x, dest);
	      [dest appendBytes: "; " length: 2];
	    }
	  [dest appendBytes: "}" length: 1];
	}
      else
	{
	  [dest appendBytes: "{\n" length: 2];
	  for (i = 0; i < numKeys; i++)
	    {
	      [dest appendBytes: iSizeString length: strlen(iSizeString)];
	      OAppend(keys[i], loc, level, step, x, dest);
	      [dest appendBytes: " = " length: 3];
	      OAppend(plists[i], loc, level, step, x, dest);
	      [dest appendBytes: ";\n" length: 2];
	    }
	  [dest appendBytes: iBaseString length: strlen(iBaseString)];
	  [dest appendBytes: "}" length: 1];
	}
    }
  else
    {
      NSString	*cls;

      if (obj == nil)
	{
	  obj = @"(nil)";
	  cls = @"(nil)";
	}
      else
	{
	  cls = NSStringFromClass([obj class]);
	}

      if (x == NSPropertyListXMLFormat_v1_0)
	{
	  NSDebugLog(@"Non-property-list class (%@) encoded as string", cls);
	  [dest appendBytes: "<string>" length: 8];
	  XString([obj description], dest);
	  [dest appendBytes: "</string>" length: 9];
	}
      else
	{
	  NSDebugLog(@"Non-property-list class (%@) encoded as string", cls);
	  PString([obj description], dest);
	}
    }
}




@implementation	NSPropertyListSerialization

static BOOL	classInitialized = NO;

+ (void) initialize
{
  if (classInitialized == NO)
    {
      classInitialized = YES;

      NSStringClass = [NSString class];
      NSMutableStringClass = [NSMutableString class];
      NSDataClass = [NSData class];
      NSDateClass = [NSDate class];
      NSNumberClass = [NSNumber class];
      NSArrayClass = [NSArray class];
      NSDictionaryClass = [NSDictionary class];
      GSStringClass = [GSString class];
      GSMutableStringClass = [GSMutableString class];

      plArray = [GSMutableArray class];
      plAdd = (id (*)(id, SEL, id))
	[plArray instanceMethodForSelector: @selector(addObject:)];

      plDictionary = [GSMutableDictionary class];
      plSet = (id (*)(id, SEL, id, id))
	[plDictionary instanceMethodForSelector: @selector(setObject:forKey:)];

      setupQuotables();
    }
}

+ (NSData*) dataFromPropertyList: (id)aPropertyList
			  format: (NSPropertyListFormat)aFormat
		errorDescription: (NSString**)anErrorString
{
  NSMutableData	*dest;
  NSDictionary	*loc;
  int		step = 2;

  loc = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
  dest = [NSMutableData dataWithCapacity: 1024];

  if (aFormat == NSPropertyListXMLFormat_v1_0)
    {
      const char	*prefix =
	"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist "
	"PUBLIC \"-//GNUstep//DTD plist 0.9//EN\" "
	"\"http://www.gnustep.org/plist-0_9.xml\">\n"
	"<plist version=\"0.9\">\n";

      [dest appendBytes: prefix length: strlen(prefix)];
      OAppend(aPropertyList, loc, 0, step > 3 ? 3 : step, aFormat, dest);
      [dest appendBytes: "</plist>" length: 8];
    }
  else if (aFormat == NSPropertyListGNUstepBinaryFormat)
    {
      [NSSerializer serializePropertyList: aPropertyList intoData: dest];
    }
  else if (aFormat == NSPropertyListBinaryFormat_v1_0)
    {
      [BinaryPLGenerator serializePropertyList: aPropertyList intoData: dest];
    }
  else
    {
      OAppend(aPropertyList, loc, 0, step > 3 ? 3 : step, aFormat, dest);
    }
  return dest;
}

void
GSPropertyListMake(id obj, NSDictionary *loc, BOOL xml,
  BOOL forDescription, unsigned step, id *str)
{
  NSString		*tmp;
  NSPropertyListFormat	style;
  NSMutableData		*dest;

  if (classInitialized == NO)
    {
      [NSPropertyListSerialization class];
    }

  if (*str == nil)
    {
      *str = AUTORELEASE([GSMutableString new]);
    }
  else if (GSObjCClass(*str) != [GSMutableString class])
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Illegal object (%@) at argument 0", *str];
    }

  if (forDescription)
    {
      style = NSPropertyListOpenStepFormat;
    }
  else if (xml == YES)
    {
      style = NSPropertyListXMLFormat_v1_0;
    }
  else if (GSPrivateDefaultsFlag(NSWriteOldStylePropertyLists) == YES)
    {
      style = NSPropertyListOpenStepFormat;
    }
  else
    {
      style = NSPropertyListGNUstepFormat;
    }

  dest = [NSMutableData dataWithCapacity: 1024];

  if (style == NSPropertyListXMLFormat_v1_0)
    {
      const char	*prefix =
	"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!DOCTYPE plist "
	"PUBLIC \"-//GNUstep//DTD plist 0.9//EN\" "
	"\"http://www.gnustep.org/plist-0_9.xml\">\n"
	"<plist version=\"0.9\">\n";

      [dest appendBytes: prefix length: strlen(prefix)];
      OAppend(obj, loc, 0, step > 3 ? 3 : step, style, dest);
      [dest appendBytes: "</plist>" length: 8];
    }
  else
    {
      OAppend(obj, loc, 0, step > 3 ? 3 : step, style, dest);
    }
  tmp = [[NSString alloc] initWithData: dest encoding: NSASCIIStringEncoding];
  [*str appendString: tmp];
  RELEASE(tmp);
}

+ (BOOL) propertyList: (id)aPropertyList
     isValidForFormat: (NSPropertyListFormat)aFormat
{
// FIXME ... need to check properly.
  switch (aFormat)
    {
      case NSPropertyListGNUstepFormat:
	return YES;

      case NSPropertyListGNUstepBinaryFormat:
	return YES;

      case NSPropertyListOpenStepFormat:
	return YES;

      case NSPropertyListXMLFormat_v1_0:
	return YES;

      case NSPropertyListBinaryFormat_v1_0:
	return YES;

      default:
	[NSException raise: NSInvalidArgumentException
		    format: @"[%@ +%@]: unsupported format",
	  NSStringFromClass(self), NSStringFromSelector(_cmd)];
	return NO;
    }
}

+ (id) propertyListFromData: (NSData*)data
	   mutabilityOption: (NSPropertyListMutabilityOptions)anOption
		     format: (NSPropertyListFormat*)aFormat
	   errorDescription: (NSString**)anErrorString
{
  NSPropertyListFormat	format = 0;
  NSString		*error = nil;
  id			result = nil;
  const unsigned char	*bytes = 0;
  unsigned int		length = 0;

  if (data == nil)
    {
      error = @"nil data argument passed to method";
    }
  else if ([data isKindOfClass: NSDataClass] == NO)
    {
      error = @"non-NSData data argument passed to method";
    }
  else if ([data length] == 0)
    {
      error = @"empty data argument passed to method";
    }
  else
    {
      bytes = [data bytes];
      length = [data length];
      if (length >= 8 && memcmp(bytes, "bplist00", 8) == 0)
	{
	  format = NSPropertyListBinaryFormat_v1_0;
	}
      else if (bytes[0] == 0 || bytes[0] == 1)
	{
	  format = NSPropertyListGNUstepBinaryFormat;
	}
      else
	{
	  unsigned int		index = 0;

	  // Skip any leading white space.
	  while (index < length && GS_IS_WHITESPACE(bytes[index]) == YES)
	    {
	      index++;
	    }

	  if (length - index > 2
	    && bytes[index] == '<' && bytes[index+1] == '?')
	    {
	      // It begins with '<?' so it is xml
	      format = NSPropertyListXMLFormat_v1_0;
	    }
	  else
	    {
	      // Assume openstep format unless we find otherwise.
	      format = NSPropertyListOpenStepFormat;
	    }
	}
    }

  if (error == nil)
    {
      switch (format)
	{
	  case NSPropertyListXMLFormat_v1_0:
	    {
	      GSXMLPListParser *parser;

	      parser = [GSXMLPListParser alloc];
	      parser = AUTORELEASE([parser initWithData: data
					     mutability: anOption]);
	      if ([parser parse] == YES)
		{
		  result = AUTORELEASE(RETAIN([parser result]));
		}
	      else if (error == nil)
		{
		  error = @"failed to parse as XML property list";
		}
	    }
	    break;

	  case NSPropertyListOpenStepFormat:
	    {
	      pldata	_pld;

	      _pld.ptr = bytes;
	      _pld.pos = 0;
	      _pld.end = length;
	      _pld.err = nil;
	      _pld.lin = 0;
	      _pld.opt = anOption;
	      _pld.key = NO;
	      _pld.old = YES;	// OpenStep style

	      result = AUTORELEASE(parsePlItem(&_pld));
	      if (_pld.old == NO)
		{
		  // Found some modern GNUstep extension in data.
		  format = NSPropertyListGNUstepFormat;
		}
	      if (_pld.err != nil)
		{
		  error = [NSString stringWithFormat:
		    @"Parse failed at line %d (char %d) - %@",
		    _pld.lin + 1, _pld.pos + 1, _pld.err];
		}
	    }
	    break;

	  case NSPropertyListGNUstepBinaryFormat:
	    if (anOption == NSPropertyListImmutable)
	      {
		result = [NSDeserializer deserializePropertyListFromData: data
						       mutableContainers: NO];
	      }
	    else
	      {
		result = [NSDeserializer deserializePropertyListFromData: data
						       mutableContainers: YES];
	      }
	    break;

	  case NSPropertyListBinaryFormat_v1_0:
	    {
	      GSBinaryPLParser	*p = [GSBinaryPLParser alloc];

	      p = [p initWithData: data mutability: anOption];
	      result = [p rootObject];
	      RELEASE(p);
	    }
	    break;

	  default:
	    error = @"format not supported";
	    break;
	}
    }

  /*
   * Done ... return all values.
   */
  if (anErrorString != 0)
    {
      *anErrorString = error;
    }
  if (aFormat != 0)
    {
      *aFormat = format;
    }
  return result;
}

@end



@interface NSPropertyListSerialization (JavaCompatibility)
+ (NSData*) dataFromPropertyList: (id)anObject;
+ (id) propertyListFromData: (NSData*)aData;
+ (id) propertyListFromString: (NSString*)aString;
+ (NSString*) stringFromPropertyList: (id)anObject;
@end

@implementation NSPropertyListSerialization (JavaCompatibility)
+ (NSData*) dataFromPropertyList: (id)anObject
{
  NSString	*dummy;

  if (anObject == nil)
    {
      return nil;
    }
  return [self dataFromPropertyList: anObject
                             format: NSPropertyListGNUstepBinaryFormat
		   errorDescription: &dummy];
}
+ (id) propertyListFromData: (NSData*)aData
{
  NSPropertyListFormat	format;
  NSString		*dummy;

  if (aData == nil)
    {
      return nil;
    }
  return [self propertyListFromData: aData
		   mutabilityOption: NSPropertyListImmutable
			     format: &format
		   errorDescription: &dummy];
}
+ (id) propertyListFromString: (NSString*)aString
{
  NSData		*aData;
  NSPropertyListFormat	format;
  NSString		*dummy;

  aData = [aString dataUsingEncoding: NSUTF8StringEncoding];
  if (aData == nil)
    {
      return nil;
    }
  return [self propertyListFromData: aData
		   mutabilityOption: NSPropertyListImmutable
			     format: &format
		   errorDescription: &dummy];
}
+ (NSString*) stringFromPropertyList: (id)anObject
{
  NSString	*string;
  NSData	*aData;

  if (anObject == nil)
    {
      return nil;
    }
  aData = [self dataFromPropertyList: anObject
			      format: NSPropertyListGNUstepFormat
		    errorDescription: &string];
  string = [NSString alloc];
  string = [string initWithData: aData encoding: NSASCIIStringEncoding];
  return AUTORELEASE(string);
}
@end





@implementation GSBinaryPLParser

- (void) dealloc
{
  DESTROY(data);
  [super dealloc];
}

- (id) initWithData: (NSData*)plData
	 mutability: (NSPropertyListMutabilityOptions)m;
{
  unsigned	length;

  length = [plData length];
  if (length < 32)
    {
      DESTROY(self);
    }
  else
    {
      unsigned char	postfix[32];

      // FIXME: Get more of the details
      [plData getBytes: postfix range: NSMakeRange(length-32, 32)];
      offset_size = postfix[6];
      index_size = postfix[7];
      table_start = (postfix[28] << 24) + (postfix[29] << 16)
	+ (postfix[30] << 8) + postfix[31];
      if (offset_size < 1 || offset_size > 4)
	{
	  [NSException raise: NSGenericException
		      format: @"Unknown table size %d", offset_size];
	  DESTROY(self);	// Bad format
	}
      else if (index_size < 1 || index_size > 4)
	{
	  unsigned	saved = offset_size;

	  DESTROY(self);	// Bad format
	  [NSException raise: NSGenericException
		      format: @"Unknown table size %d", saved];
	}
      else if (table_start > length - 32)
	{
	  DESTROY(self);	// Bad format
	}
      else
	{
	  table_len = length - table_start - 32;
	  ASSIGN(data, plData);
	  _bytes = (const unsigned char*)[data bytes];
	  mutability = m;
	}
    }

  return self;
}

- (unsigned long) offsetForIndex: (unsigned)index
{
  if (index > table_len)
    {
      [NSException raise: NSRangeException
		   format: @"Object table index out of bounds %d.", index];
    }

  if (offset_size == 1)
    {
      unsigned char offset;

      [data getBytes: &offset range: NSMakeRange(table_start + index, 1)];

      return offset;
    }
  else if (offset_size == 2)
    {
      unsigned short offset;

      [data getBytes: &offset range: NSMakeRange(table_start + 2*index, 2)];

      return NSSwapBigShortToHost(offset);
    }
  else
    {
      unsigned char buffer[offset_size];
      int i;
      unsigned long num = 0;
      NSRange	r;

      r = NSMakeRange(table_start + offset_size*index, offset_size);
      [data getBytes: &buffer range: r];
      for (i = 0; i < offset_size; i++)
        {
	  num = (num << 8) + buffer[i];
	}
      return num;
    }
  return 0;
}

- (unsigned) readObjectIndexAt: (unsigned*)counter
{
  if (index_size == 1)
    {
      unsigned char oid;

      [data getBytes: &oid range: NSMakeRange(*counter,1)];
      *counter += 1;
      return oid;
    }
  else if (index_size == 2)
    {
      unsigned short oid;

      [data getBytes: &oid range: NSMakeRange(*counter, 2)];
      *counter += 2;

      return NSSwapBigShortToHost(oid);
    }
  else
    {
      unsigned char buffer[index_size];
      int i;
      unsigned num = 0;

      [data getBytes: &buffer range: NSMakeRange(*counter, index_size)];
      *counter += index_size;
      for (i = 0; i < index_size; i++)
        {
	  num = (num << 8) + buffer[i];
	}
      return num;
    }
  return 0;
}

- (unsigned long) readCountAt: (unsigned*) counter
{
  unsigned char c;

  [data getBytes: &c range: NSMakeRange(*counter,1)];
  *counter += 1;

  if (c == 0x10)
    {
      unsigned char count;

      [data getBytes: &count range: NSMakeRange(*counter,1)];
      *counter += 1;
      return count;
    }
  else if (c == 0x11)
    {
      unsigned short count;

      [data getBytes: &count range: NSMakeRange(*counter,2)];
      *counter += 2;
      return NSSwapBigShortToHost(count);
    }
  else if ((c > 0x11) && (c <= 0x13))
    {
      unsigned len = c - 0x0f;
      unsigned char buffer[len];
      int i;
      unsigned long num = 0;

      [data getBytes: &buffer range: NSMakeRange(*counter, len)];
      *counter += len;
      for (i = 0; i < len; i++)
        {
	  num = (num << 8) + buffer[i];
	}
      return num;
    }
  else
    {
      //FIXME
      [NSException raise: NSGenericException
		   format: @"Unknown count type %d", c];
    }

  return 0;
}

- (id) rootObject
{
  return [self objectAtIndex: 0];
}

- (id) objectAtIndex: (NSUInteger)index
{
  unsigned char	next;
  unsigned counter = [self offsetForIndex: index];
  id		result = nil;

  [data getBytes: &next range: NSMakeRange(counter,1)];
  //NSLog(@"read object %d at index %d type %d", index, counter, next);
  counter += 1;

  if (next == 0x08)
    {
      // NO
      result = [NSNumber numberWithBool: NO];
    }
  else if (next == 0x09)
    {
      // YES
      result = [NSNumber numberWithBool: YES];
    }
  else if ((next >= 0x10) && (next < 0x17))
    {
      // integer number
      unsigned		len = 1 << (next - 0x10);
      unsigned long long num = 0;
      unsigned		i;
      unsigned char	buffer[16];

      [data getBytes: buffer range: NSMakeRange(counter, len)];
      for (i = 0; i < len; i++)
        {
	  num = (num << 8) + buffer[i];
	}

      if (next == 0x10)
        {
	  result = [NSNumber numberWithUnsignedChar: (unsigned char)num];
	}
      else if (next == 0x11)
        {
	  result = [NSNumber numberWithUnsignedShort: (unsigned short)num];
	}
      else if ((next == 0x12) || (next == 13))
        {
	  result = [NSNumber numberWithUnsignedInt: (unsigned int)num];
	}
      else
        {
	  result = [NSNumber numberWithUnsignedLongLong: num];
	}
    }
  else if (next == 0x22)
    {
      // float number
      NSSwappedFloat in;

      [data getBytes: &in range: NSMakeRange(counter, sizeof(float))];
      result = [NSNumber numberWithFloat: NSSwapBigFloatToHost(in)];
    }
  else if (next == 0x23)
    {
      // double number
      NSSwappedDouble in;

      [data getBytes: &in range: NSMakeRange(counter, sizeof(double))];
      result = [NSNumber numberWithDouble: NSSwapBigDoubleToHost(in)];
    }
  else if (next == 0x33)
    {
      double in;
      // Date
      NSDate *date;
      [data getBytes: &in range: NSMakeRange(counter, sizeof(double))];
      date = [NSDate dateWithTimeIntervalSinceReferenceDate:
	NSSwapBigDoubleToHost(in)];
      result = date;
    }
  else if ((next >= 0x40) && (next < 0x4F))
    {
      // short data
      unsigned len = next - 0x40;

      if (mutability == NSPropertyListMutableContainersAndLeaves)
	{
	  result = [NSMutableData dataWithBytes: _bytes + counter
					 length: len];
	}
      else
	{
	  result = [data subdataWithRange: NSMakeRange(counter, len)];
	}
    }
  else if (next == 0x4F)
    {
      // long data
      unsigned long len;

      len = [self readCountAt: &counter];
      if (mutability == NSPropertyListMutableContainersAndLeaves)
	{
	  result = [NSMutableData dataWithBytes: _bytes + counter
					 length: len];
	}
      else
	{
	  result = [data subdataWithRange: NSMakeRange(counter, len)];
	}
    }
  else if ((next >= 0x50) && (next < 0x5F))
    {
      // Short string
      unsigned	len = next - 0x50;
      char 	buffer[len+1];

      [data getBytes: buffer range: NSMakeRange(counter, len)];
      buffer[len] = '\0';
      if (mutability == NSPropertyListMutableContainersAndLeaves)
	{
	  result = [NSMutableString stringWithUTF8String: buffer];
	}
      else
	{
	  result = [NSString stringWithUTF8String: buffer];
	}
    }
  else if (next == 0x5F)
    {
      // long string
      unsigned long len;
      char *buffer;

      len = [self readCountAt: &counter];
      buffer = NSAllocateCollectable(len + 1, 0);
      [data getBytes: buffer range: NSMakeRange(counter, len)];
      buffer[len] = '\0';
      if (mutability == NSPropertyListMutableContainersAndLeaves)
	{
	  result = [NSMutableString stringWithUTF8String: buffer];
	}
      else
	{
	  result = [NSString stringWithUTF8String: buffer];
	}
      NSZoneFree(NSDefaultMallocZone(), buffer);
    }
  else if ((next >= 0x60) && (next < 0x6F))
    {
      // Short unicode string
      unsigned	len = next - 0x60;
      unsigned 	i;
      unichar	buffer[len];

      [data getBytes: buffer
	       range: NSMakeRange(counter, sizeof(unichar)*len)];

      for (i = 0; i < len; i++)
        {
	  buffer[i] = NSSwapBigShortToHost(buffer[i]);
	}

      if (mutability == NSPropertyListMutableContainersAndLeaves)
	{
	  result = [NSMutableString stringWithCharacters: buffer length: len];
	}
      else
	{
	  result = [NSString stringWithCharacters: buffer length: len];
	}
    }
  else if (next == 0x6F)
    {
      // long unicode string
      unsigned	long len;
      unsigned	i;
      unichar	*buffer;

      len = [self readCountAt: &counter];
      buffer = NSAllocateCollectable(sizeof(unichar) * len, 0);
      [data getBytes: buffer range: NSMakeRange(counter, sizeof(unichar)*len)];

      for (i = 0; i < len; i++)
        {
	  buffer[i] = NSSwapBigShortToHost(buffer[i]);
	}

      if (mutability == NSPropertyListMutableContainersAndLeaves)
	{
	  result = [NSMutableString stringWithCharacters: buffer length: len];
	}
      else
	{
	  result = [NSString stringWithCharacters: buffer length: len];
	}
      NSZoneFree(NSDefaultMallocZone(), buffer);
    }
  else if (next == 0x80)
    {
      unsigned char	index;

      [data getBytes: &index range: NSMakeRange(counter,1)];
      result = [NSDictionary dictionaryWithObject:
				 [NSNumber numberWithInt: index]
			     forKey: @"CF$UID"];
    }
  else if (next == 0x81)
    {
      unsigned short	index;

      [data getBytes: &index range: NSMakeRange(counter,2)];
      index = NSSwapBigShortToHost(index);
      result = [NSDictionary dictionaryWithObject:
				 [NSNumber numberWithInt: index]
			     forKey: @"CF$UID"];
    }
  else if ((next >= 0xA0) && (next < 0xAF))
    {
      // short array
      unsigned	len = next - 0xA0;
      unsigned	i;
      id	objects[len];

      for (i = 0; i < len; i++)
        {
	  int oid = [self readObjectIndexAt: &counter];

	  objects[i] = [self objectAtIndex: oid];
	}

      if (mutability == NSPropertyListMutableContainersAndLeaves
	|| mutability == NSPropertyListMutableContainers)
	{
	  result = [NSMutableArray arrayWithObjects: objects count: len];
	}
      else
	{
	  result = [NSArray arrayWithObjects: objects count: len];
	}
    }
  else if (next == 0xAF)
    {
      // big array
      unsigned	long len;
      unsigned	i;
      id	*objects;

      len = [self readCountAt: &counter];
      objects = NSAllocateCollectable(sizeof(id) * len, NSScannedOption);

      for (i = 0; i < len; i++)
        {
	  int oid = [self readObjectIndexAt: &counter];

	  objects[i] = [self objectAtIndex: oid];
	}

      if (mutability == NSPropertyListMutableContainersAndLeaves
	|| mutability == NSPropertyListMutableContainers)
	{
	  result =[NSMutableArray arrayWithObjects: objects count: len];
	}
      else
	{
	  result =[NSArray arrayWithObjects: objects count: len];
	}
      NSZoneFree(NSDefaultMallocZone(), objects);
    }
  else if ((next >= 0xD0) && (next < 0xDF))
    {
      // dictionary
      unsigned	len = next - 0xD0;
      unsigned	i;
      id	keys[len];
      id	values[len];

      for (i = 0; i < len; i++)
        {
	  int oid = [self readObjectIndexAt: &counter];

	  keys[i] = [self objectAtIndex: oid];
	}

      for (i = 0; i < len; i++)
        {
	  int oid = [self readObjectIndexAt: &counter];

	  values[i] = [self objectAtIndex: oid];
	}

      if (mutability == NSPropertyListMutableContainersAndLeaves
	|| mutability == NSPropertyListMutableContainers)
	{
	  result = [NSMutableDictionary dictionaryWithObjects: values
						      forKeys: keys
							count: len];
	}
      else
	{
	  result = [NSDictionary dictionaryWithObjects: values
					       forKeys: keys
						 count: len];
	}
    }
  else if (next == 0xDF)
    {
      // big dictionary
      unsigned	long len;
      unsigned	i;
      id	*keys;
      id	*values;

      len = [self readCountAt: &counter];
      keys = NSAllocateCollectable(sizeof(id) * len * 2, NSScannedOption);
      values = keys + len;
      for (i = 0; i < len; i++)
        {
	  int oid = [self readObjectIndexAt: &counter];

	  keys[i] = [self objectAtIndex: oid];
	}

      for (i = 0; i < len; i++)
        {
	  int oid = [self readObjectIndexAt: &counter];

	  values[i] = [self objectAtIndex: oid];
	}

      if (mutability == NSPropertyListMutableContainersAndLeaves
	|| mutability == NSPropertyListMutableContainers)
	{
	  result = [NSMutableDictionary dictionaryWithObjects: values
						      forKeys: keys
							count: len];
	}
      else
	{
	  result = [NSDictionary dictionaryWithObjects: values
					       forKeys: keys
						 count: len];
	}
      NSZoneFree(NSDefaultMallocZone(), keys);
    }
  else
    {
      [NSException raise: NSGenericException
		   format: @"Unknown control byte = %d", next];
    }

  return result;
}

@end


@implementation BinaryPLGenerator

+ (void) serializePropertyList: (id)aPropertyList
		      intoData: (NSMutableData *)destination
{
  BinaryPLGenerator *gen;

  gen = [[BinaryPLGenerator alloc]
    initWithPropertyList: aPropertyList intoData: destination];
  [gen generate];
  RELEASE(gen);
}

- (id) initWithPropertyList: (id) aPropertyList
		   intoData: (NSMutableData *)destination
{
  ASSIGN(root, aPropertyList);
  ASSIGN(dest, destination);
  [dest setLength: 0];

  return self;
}

- (void) dealloc
{
  DESTROY(root);
  [self cleanup];
  DESTROY(dest);
  [super dealloc];
}

- (NSData*) data
{
  return dest;
}

- (void) setup
{
  [dest setLength: 0];
  if (index_size == 1)
    {
      table_size = 256;
    }
  else if (index_size == 2)
    {
      table_size = 256 * 256;
    }
  else if (index_size == 3)
    {
      table_size = 256 * 256 * 256;
    }
  else if (index_size == 4)
    {
      table_size = UINT_MAX;
    }

  table = objc_malloc(table_size * sizeof(int));

  objectsToDoList = [[NSMutableArray alloc] init];
  objectList = [[NSMutableArray alloc] init];

  [objectsToDoList addObject: root];
  [objectList addObject: root];
}

- (void) cleanup
{
  DESTROY(objectsToDoList);
  DESTROY(objectList);
  if (table != NULL)
    {
      objc_free(table);
      table = NULL;
    }
}

- (void) writeObjects
{
  id object;
  const char *prefix = "bplist00";

  [dest appendBytes: prefix length: strlen(prefix)];

  while ([objectsToDoList count] != 0)
    {
      object = [objectsToDoList objectAtIndex: 0];
      [self storeObject: object];
      [objectsToDoList removeObjectAtIndex: 0];
    }
}

- (void) markOffset: (unsigned int) offset for: (id)object
{
  unsigned int oid;

  oid = [objectList indexOfObject: object];
  if (oid == NSNotFound)
    {
      [NSException raise: NSGenericException
		   format: @"Unknown object %@.", object];
    }
  if (oid >= table_size)
    {
      [NSException raise: NSRangeException
		   format: @"Object table index out of bounds %d.", oid];
    }

  table[oid] = offset;
}

- (void) writeObjectTable
{
  unsigned int size;
  unsigned int len;
  unsigned int i;
  unsigned char *buffer;
  unsigned int last_offset;

  table_start = [dest length];
  // This is a bit too much, as the length
  // of the last object is added.
  last_offset = table_start;

  if (last_offset < 256)
    {
      offset_size = 1;
    }
  else if (last_offset < 256 * 256)
    {
      offset_size = 2;
    }
  else if (last_offset < 256 * 256 * 256)
    {
      offset_size = 3;
    }
  else if (last_offset <= UINT_MAX)
    {
      offset_size = 4;
    }
  else
    {
      [NSException raise: NSRangeException
	format: @"Object table offset out of bounds %d.", last_offset];
    }

  len = [objectList count];
  size = offset_size * len;

  buffer = objc_malloc(size);

  if (offset_size == 1)
    {
      for (i = 0; i < len; i++)
        {
	  unsigned char ci;

	  ci = table[i];
	  buffer[i] = ci;
	}
    }
  else if (offset_size == 2)
    {
      for (i = 0; i < len; i++)
        {
	  unsigned short si;

	  si = table[i];
	  buffer[2 * i] = (si >> 8);
	  buffer[2 * i + 1] = si % 256;
	}
    }
  else if (offset_size == 3)
    {
      for (i = 0; i < len; i++)
        {
	  unsigned int si;

	  si = table[i];
	  buffer[3 * i] = (si >> 16);
	  buffer[3 * i + 1] = (si >> 8) % 256;
	  buffer[3 * i + 2] = si % 256;
	}
    }
  else if (offset_size == 4)
    {
      for (i = 0; i < len; i++)
        {
	  unsigned int si;

	  si = table[i];
	  buffer[4 * i] = (si >> 24);
	  buffer[4 * i + 1] = (si >> 16) % 256;
	  buffer[4 * i + 2] = (si >> 8) % 256;
	  buffer[4 * i + 3] = si % 256;
	}
    }

  [dest appendBytes: buffer length: size];
  objc_free(buffer);
}

- (void) writeMetaData
{
  unsigned char meta[32];
  unsigned int i;
  unsigned int len;

  for (i = 0; i < 32; i++)
    {
      meta[i] = 0;
    }

  meta[6] = offset_size;
  meta[7] = index_size;

  len = [objectList count];
  meta[12] = (len >> 24);
  meta[13] = (len >> 16) % 256;
  meta[14] = (len >> 8) % 256;
  meta[15] = len % 256;
  meta[28] = (table_start >> 24);
  meta[29] = (table_start >> 16) % 256;
  meta[30] = (table_start >> 8) % 256;
  meta[31] = table_start % 256;

  [dest appendBytes: meta length: 32];
}

- (unsigned int) indexForObject: (id)object
{
  unsigned int index;

  index = [objectList indexOfObject: object];
  if (index == NSNotFound)
    {
      index = [objectList count];
      [objectList addObject: object];
      [objectsToDoList addObject: object];
    }

  return index;
}

- (void) storeIndex: (unsigned int)index
{
  if (index_size == 1)
    {
      unsigned char oid;

      oid = index;
      [dest appendBytes: &oid length: 1];
    }
  else if (index_size == 2)
    {
      unsigned short oid;

      oid = NSSwapHostShortToBig(index);
      [dest appendBytes: &oid length: 2];
    }
  else if (index_size == 4)
    {
      unsigned int oid;

      oid = NSSwapHostIntToBig(index);
      [dest appendBytes: &oid length: 4];
    }
  else
    {
      [NSException raise: NSGenericException
		   format: @"Unknown table size %d", index_size];
    }
}

- (void) storeCount: (unsigned int)count
{
  unsigned char code;

  if (count < 256)
    {
      unsigned char c;

      code = 0x10;
      [dest appendBytes: &code length: 1];
      c = count;
      [dest appendBytes: &c length: 1];
    }
  else if (count < 256 * 256)
    {
      unsigned short c;

      code = 0x11;
      [dest appendBytes: &code length: 1];
      c = count;
      c = NSSwapHostShortToBig(c);
      [dest appendBytes: &c length: 2];
    }
  else
    {
      code = 0x13;
      [dest appendBytes: &code length: 1];
      count = NSSwapHostIntToBig(count);
      [dest appendBytes: &count length: 4];
    }
}

- (void) storeData: (NSData*) data
{
  unsigned int len;
  unsigned char code;

  len = [data length];

  if (len < 0x0F)
    {
      code = 0x40 + len;
      [dest appendBytes: &code length: 1];
      [dest appendData: data];
    }
  else
    {
      code = 0x4F;
      [dest appendBytes: &code length: 1];
      [self storeCount: len];
      [dest appendData: data];
    }
}

- (void) storeString: (NSString*) string
{
  unsigned int len;
  BOOL ascii = YES;
  unsigned char code;
  unsigned int i;
  unichar uchar;

  len = [string length];

  for (i = 0; i < len; i++)
    {
      uchar = [string characterAtIndex: i];
      if (uchar > 127)
        {
	  ascii = NO;
	  break;
	}
    }

  if (ascii)
    {
      if (len < 0x0F)
	{
	  code = 0x50 + len;
	  [dest appendBytes: &code length: 1];
	  [dest appendBytes: [string cString] length: len];
	}
      else
	{
	  code = 0x5F;
	  [dest appendBytes: &code length: 1];
	  [self storeCount: len];
	  [dest appendBytes: [string cString] length: len];
	}
    }
  else
    {
      if (len < 0x0F)
	{
	  unichar buffer[len + 1];
	  int i;

	  code = 0x60 + len;
	  [dest appendBytes: &code length: 1];
	  [string getCharacters: buffer];
	  for (i = 0; i < len; i++)
	    {
	      buffer[i] = NSSwapHostShortToBig(buffer[i]);
	    }
	  [dest appendBytes: buffer length: len * sizeof(unichar)];
	}
      else
        {
	  unichar *buffer;

	  code = 0x6F;
	  [dest appendBytes: &code length: 1];
	  buffer = objc_malloc(sizeof(unichar)*(len + 1));
	  [self storeCount: len];
	  [string getCharacters: buffer];
	  for (i = 0; i < len; i++)
	    {
	      buffer[i] = NSSwapHostShortToBig(buffer[i]);
	    }
	  [dest appendBytes: buffer length: sizeof(unichar)*len];
	  objc_free(buffer);
	}
    }
}

- (void) storeNumber: (NSNumber*) number
{
  const char *type;
  unsigned char code;

  type = [number objCType];

  switch (*type)
    {
      case 'c':
      case 'C':
      case 's':
      case 'S':
      case 'i':
      case 'I':
      case 'l':
      case 'L':
      case 'q':
      case 'Q':
        {
	  unsigned long long val;

	  val = [number unsignedLongLongValue];

	  // FIXME: We need a better way to determine boolean values!
	  if ((val == 0) && ((*type == 'c') || (*type == 'C')))
	    {
	      code = 0x08;
	      [dest appendBytes: &code length: 1];
	    }
	  else if ((val == 1) && ((*type == 'c') || (*type == 'C')))
	    {
	      code = 0x09;
	      [dest appendBytes: &code length: 1];
	    }
	  else if (val < 256)
	    {
	      unsigned char cval;

	      code = 0x10;
	      [dest appendBytes: &code length: 1];
	      cval = (unsigned char) val;
	      [dest appendBytes: &cval length: 1];
	    }
	  else if (val < 256 * 256)
	    {
	      unsigned short sval;

	      code = 0x11;
	      [dest appendBytes: &code length: 1];
	      sval = NSSwapHostShortToBig([number unsignedShortValue]);
	      [dest appendBytes: &sval length: 2];
	    }
	  else if (val <= UINT_MAX)
	    {
	      unsigned int ival;

	      code = 0x12;
	      [dest appendBytes: &code length: 1];
	      ival = NSSwapHostIntToBig([number unsignedIntValue]);
	      [dest appendBytes: &ival length: 4];
	    }
	  else
	    {
	      unsigned long long lval;

	      code = 0x13;
	      [dest appendBytes: &code length: 1];
	      lval = NSSwapHostLongLongToBig([number unsignedLongLongValue]);
	      [dest appendBytes: &lval length: 8];
	    }
	  break;
	}
      case 'f':
        {
	  NSSwappedFloat val = NSSwapHostFloatToBig([number floatValue]);

	  code = 0x22;
	  [dest appendBytes: &code length: 1];
	  [dest appendBytes: &val length: sizeof(float)];
	  break;
	}
      case 'd':
        {
	  NSSwappedDouble val = NSSwapHostDoubleToBig([number doubleValue]);

	  code = 0x23;
	  [dest appendBytes: &code length: 1];
	  [dest appendBytes: &val length: sizeof(double)];
	  break;
	}
      default:
	[NSException raise: NSGenericException
		    format: @"Attempt to store number with unknown ObjC type"];
    }
}

- (void) storeDate: (NSDate*) date
{
  unsigned char code;
  double out;

  code = 0x33;
  [dest appendBytes: &code length: 1];
  out = NSSwapHostDoubleToBig([date timeIntervalSinceReferenceDate]);
  [dest appendBytes: &out length: sizeof(double)];
}

- (void) storeArray: (NSArray*) array
{
  unsigned char code;
  unsigned int len;
  unsigned int i;

  len = [array count];

  if (len < 0x0F)
    {
      code = 0xA0 + len;
      [dest appendBytes: &code length: 1];
    }
  else
    {
      code = 0xAF;
      [dest appendBytes: &code length: 1];
      [self storeCount: len];
    }

  for (i = 0; i < len; i++)
    {
      id obj;
      unsigned int oid;

      obj = [array objectAtIndex: i];
      oid = [self indexForObject: obj];
      [self storeIndex: oid];
    }
}

- (void) storeDictionary: (NSDictionary*) dict
{
  unsigned char code;
  NSNumber *num;
  unsigned int i;

  num = [dict objectForKey: @"CF$UID"];
  if (num != nil)
    {
      // Special dictionary from keyed encoding
      unsigned int index;

      index = [num intValue];
      if (index < 256)
        {
	  unsigned char ci;

	  code = 0x80;
	  [dest appendBytes: &code length: 1];
	  ci = (unsigned char)index;
	  [dest appendBytes: &ci length: 1];
	}
      else
        {
	  unsigned short si;

	  code = 0x81;
	  [dest appendBytes: &code length: 1];
	  si = NSSwapHostShortToBig((unsigned short)index);
	  [dest appendBytes: &si length: 2];
	}
    }
  else
    {
      unsigned int len = [dict count];
      NSArray *keys = [dict allKeys];
      NSMutableArray *objects = [NSMutableArray arrayWithCapacity: len];
      id key;

      for (i = 0; i < len; i++)
        {
	  key = [keys objectAtIndex: i];
	  [objects addObject: [dict objectForKey: key]];
	}

      if (len < 0x0F)
        {
	  code = 0xD0 + len;
	  [dest appendBytes: &code length: 1];
	}
      else
        {
	  code = 0xDF;
	  [dest appendBytes: &code length: 1];
	  [self storeCount: len];
	}

      for (i = 0; i < len; i++)
        {
	  id obj;
	  unsigned int oid;

	  obj = [keys objectAtIndex: i];
	  oid = [self indexForObject: obj];
	  [self storeIndex: oid];
	}

      for (i = 0; i < len; i++)
        {
	  id obj;
	  unsigned int oid;

	  obj = [objects objectAtIndex: i];
	  oid = [self indexForObject: obj];
	  [self storeIndex: oid];
	}
    }
}

- (void) storeObject: (id)object
{
  [self markOffset: [dest length] for: object];

  if ([object isKindOfClass: NSStringClass])
    {
      [self storeString: object];
    }
  else if ([object isKindOfClass: NSDataClass])
    {
      [self storeData: object];
    }
  else if ([object isKindOfClass: NSNumberClass])
    {
      [self storeNumber: object];
    }
  else if ([object isKindOfClass: NSDateClass])
    {
      [self storeDate: object];
    }
  else if ([object isKindOfClass: NSArrayClass])
    {
      [self storeArray: object];
    }
  else if ([object isKindOfClass: NSDictionaryClass])
    {
      [self storeDictionary: object];
    }
  else
    {
      NSLog(@"Unknown object class %@", object);
    }
}

- (void) generate
{
  BOOL done = NO;

  index_size = 1;

  while (!done && (index_size <= 4))
    {
      NS_DURING
	{
	  [self setup];
	  [self writeObjects];
	  done = YES;
	}
      NS_HANDLER
	{
	  [self cleanup];
	  index_size += 1;
	}
      NS_ENDHANDLER
    }

  [self writeObjectTable];
  [self writeMetaData];
}

@end
