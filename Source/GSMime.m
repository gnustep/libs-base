
/* Implementation for GSMIME

   Copyright (C) 2000 Free Software Foundation, Inc.

   Written by: Richard frith-Macdonald <rfm@gnu.org>
   Date: October 2000
   
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

#include	<Foundation/NSArray.h>
#include	<Foundation/NSAutoreleasePool.h>
#include	<Foundation/NSData.h>
#include	<Foundation/NSDictionary.h>
#include	<Foundation/NSScanner.h>
#include	<Foundation/NSString.h>
#include	<Foundation/NSUserDefaults.h>
#include	<Foundation/NSException.h>
#include	<Foundation/GSMime.h>
#include	<string.h>

static	NSCharacterSet	*specials = nil;

/*
 *	Name -		decodebase64()
 *	Purpose -	Convert 4 bytes in base64 encoding to 3 bytes raw data.
 */
static void
decodebase64(unsigned char *dst, const char *src)
{
  dst[0] =  (src[0]         << 2) | ((src[1] & 0x30) >> 4);
  dst[1] = ((src[1] & 0x0F) << 4) | ((src[2] & 0x3C) >> 2);
  dst[2] = ((src[2] & 0x03) << 6) |  (src[3] & 0x3F);
}

typedef	enum {
  WE_QUOTED,
  WE_BASE64
} WE;

/*
 *	Name -		decodeWord()
 *	Params -	dst destination
 *			src where to start decoding from
 *			end where to stop decoding (or NULL if end of buffer).
 *			enc content-transfer-encoding
 *	Purpose -	Decode text with BASE64 or QUOTED-PRINTABLE codes.
 */
unsigned char*
decodeWord(unsigned char *dst, unsigned char *src, unsigned char *end, WE enc)
{
  int	c;

  if (enc == WE_QUOTED)
    {
      while (*src && (src != end))
	{
	  if (*src == '=')
	    {
	      src++;
	      if (*src == '\0')
		{
		  break;
		}
	      if (('\n' == *src) || ('\r' == *src))
		{
		  break;
		}
	      c = isdigit(*src) ? (*src - '0') : (*src - 55);
	      c <<= 4;
	      src++;
	      if (*src == '\0')
		{
		  break;
		}
	      c += isdigit(*src) ? (*src - '0') : (*src - 55);
	      *dst = c;
	    }
	  else if (*src == '_')
	    {
	      *dst = '\040';
	    }
	  else
	    {
	      *dst = *src;
	    }
	  dst++;
	  src++;
	}
      *dst = '\0';
      return dst;
    }
  else if (enc == WE_BASE64)
    {
      unsigned char	buf[4];
      unsigned		pos = 0;

      while (*src && (src != end))
	{
	  c = *src++;
	  if (isupper(c))
	    {
	      c -= 'A';
	    }
	  else if (islower(c))
	    {
	      c = c - 'a' + 26;
	    }
	  else if (isdigit(c))
	    {
	      c = c - '0' + 52;
	    }
	  else if (c == '/')
	    {
	      c = 63;
	    }
	  else if (c == '+')
	    {
	      c = 62;
	    }
	  else if  (c == '=')
	    {
	      c = -1;
	    }
	  else if (c == '-')
	    {
	      break;		/* end    */
	    }
	  else
	    {
	      c = -1;		/* ignore */
	    }

	  if (c >= 0)
	    {
	      buf[pos++] = c;
	      if (pos == 4)
		{
		  pos = 0;
		  decodebase64(dst, buf);
		  dst += 3;
		}
	    }
	}

      if (pos > 0)
	{
	  unsigned	i;

	  for (i = pos; i < 4; i++)
	    buf[i] = '\0';
	  pos--;
	}
      decodebase64(dst, buf);
      dst += pos;
      *dst = '\0';
      return dst;
    }
  else
    {
      NSLog(@"Unsupported encoding type");
      return end;
    }
}

static NSStringEncoding
parseCharacterSet(NSString *token)
{
  if ([token compare: @"us-ascii"] == NSOrderedSame)
    return NSASCIIStringEncoding;
  if ([token compare: @"iso-8859-1"] == NSOrderedSame)
    return NSISOLatin1StringEncoding;

  return NSASCIIStringEncoding;
}

@implementation	GSMimeCodingContext
- (BOOL) atEnd
{
  return atEnd;
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (void) setAtEnd: (BOOL)flag
{
  atEnd = flag;
}
@end

@interface	GSMimeBase64DecoderContext : GSMimeCodingContext
{
@public
  unsigned char	buf[4];
  unsigned	pos;
}
@end
@implementation	GSMimeBase64DecoderContext
@end

@interface	GSMimeQuotedDecoderContext : GSMimeCodingContext
{
@public
  unsigned char	buf[4];
  unsigned	pos;
}
@end
@implementation	GSMimeQuotedDecoderContext
@end

@interface	GSMimeChunkedDecoderContext : GSMimeCodingContext
{
@public
  unsigned char	buf[8];
  unsigned	pos;
  enum {
    ChunkSize,		// Reading chunk size
    ChunkExt,		// Reading cjhunk extensions
    ChunkEol1,		// Reading end of line after size;ext
    ChunkData,		// Reading chunk data
    ChunkEol2,		// Reading end of line after data
    ChunkFoot,		// Reading chunk footer after newline
    ChunkFootA		// Reading chunk footer
  } state;
  NSMutableData	*data;
}
@end
@implementation	GSMimeChunkedDecoderContext
- (void) dealloc
{
  RELEASE(data);
  [super dealloc];
}
- (id) init
{
  self = [super init];
  if (self != nil)
    {
      data = [NSMutableData new];
    }
  return self;
}
@end



@interface	GSMimeBinaryDecoderContext : GSMimeCodingContext
@end
@implementation	GSMimeBinaryDecoderContext
- (id) autorelease
{
  return self;
}
- (id) copyWithZone: (NSZone*)z
{
  return self;
}
- (void) dealloc
{
  NSLog(@"Error - attempt to deallocate GSMimeBinaryDecoderContext");
}
- (id) retain
{
  return self;
}
- (void) release
{
}
@end




@interface GSMimeParser (Private)
- (BOOL) _decodeBody: (NSData*)data;
- (NSString*) _decodeHeader;
- (BOOL) _unfoldHeader;
@end

@implementation	GSMimeParser

+ (GSMimeParser*) mimeParser
{
  return AUTORELEASE([[self alloc] init]);
}

- (void) dealloc
{
  RELEASE(data);
  RELEASE(child);
  RELEASE(context);
  RELEASE(boundary);
  RELEASE(document);
  [super dealloc];
}

- (GSMimeCodingContext*) contextFor: (NSDictionary*)info
{
  NSString	*name;
  NSString	*value;
  static	GSMimeCodingContext	*defaultContext = nil;

  if (defaultContext == nil)
    {
      defaultContext = [GSMimeBinaryDecoderContext new];
    }
  if (info == nil)
    {
      NSLog(@"contextFor: - nil header ... assumed binary encoding");
      return defaultContext;
    }

  name = [info objectForKey: @"Name"];
  if ([name isEqualToString: @"content-transfer-encoding"] == YES
   || [name isEqualToString: @"transfer-encoding"] == YES)
    {
      value = [info objectForKey: @"Value"];
      if ([value length] == 0)
	{
	  NSLog(@"Bad value for %@ header - assume binary encoding", name);
	  return defaultContext;
	}
      if ([value isEqualToString: @"base64"] == YES)
	{
	  return AUTORELEASE([GSMimeBase64DecoderContext new]);
	}
      else if ([value isEqualToString: @"quoted-printable"] == YES)
	{
	  return AUTORELEASE([GSMimeQuotedDecoderContext new]);
	}
      else if ([value isEqualToString: @"binary"] == YES)
	{
	  return defaultContext;
	}
      else if ([value characterAtIndex: 0] == '7')
	{
	  return defaultContext;
	}
      else if ([value characterAtIndex: 0] == '8')
	{
	  return defaultContext;
	}
      else if ([value isEqualToString: @"chunked"] == YES)
	{
	  return AUTORELEASE([GSMimeChunkedDecoderContext new]);
	}
    }

  NSLog(@"contextFor: - unknown header (%@) ... assumed binary encoding", name);
  return defaultContext;
}

- (BOOL) decodeData: (NSData*)sData
	  fromRange: (NSRange)aRange
	   intoData: (NSMutableData*)dData
	withContext: (GSMimeCodingContext*)con
{
  unsigned		size = [dData length];
  unsigned		len = [sData length];
  unsigned char		*beg;
  unsigned char		*dst;
  const char		*src;
  const char		*end;
  Class			ccls;

  if (dData == nil || [con isKindOfClass: [GSMimeCodingContext class]] == NO)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"Bad destination data for decode"];
    }
  GS_RANGE_CHECK(aRange, len);

  /*
   * Get pointers into source data buffer.
   */
  src = (const char *)[sData bytes];
  src += aRange.location;
  end = src + aRange.length;
  
  ccls = [con class];
  if (ccls == [GSMimeBase64DecoderContext class])
    {
      GSMimeBase64DecoderContext	*ctxt;

      ctxt = (GSMimeBase64DecoderContext*)con;

      /*
       * Expand destination data buffer to have capacity to handle info.
       */
      [dData setLength: size + (3 * (end + 8 - src))/4];
      dst = (unsigned char*)[dData mutableBytes];
      beg = dst;

      /*
       * Now decode data into buffer, keeping count and temporary
       * data in context.
       */
      while (src < end)
	{
	  int	cc = *src++;

	  if (isupper(cc))
	    {
	      cc -= 'A';
	    }
	  else if (islower(cc))
	    {
	      cc = cc - 'a' + 26;
	    }
	  else if (isdigit(cc))
	    {
	      cc = cc - '0' + 52;
	    }
	  else if (cc == '+')
	    {
	      cc = 62;
	    }
	  else if (cc == '/')
	    {
	      cc = 63;
	    }
	  else if  (cc == '=')
	    {
	      [ctxt setAtEnd: YES];
	      cc = -1;
	    }
	  else if (cc == '-')
	    {
	      [ctxt setAtEnd: YES];
	      break;
	    }
	  else
	    {
	      cc = -1;		/* ignore */
	    }

	  if (cc >= 0)
	    {
	      ctxt->buf[ctxt->pos++] = cc;
	      if (ctxt->pos == 4)
		{
		  ctxt->pos = 0;
		  decodebase64(dst, ctxt->buf);
		  dst += 3;
		}
	    }
	}

      /*
       * Odd characters at end of decoded data need to be added separately.
       */
      if ([ctxt atEnd] == YES && ctxt->pos > 0)
	{
	  unsigned	len = ctxt->pos - 1;;

	  while (ctxt->pos < 4)
	    {
	      ctxt->buf[ctxt->pos++] = '\0';
	    }
	  ctxt->pos = 0;
	  decodebase64(dst, ctxt->buf);
	  size += len;
	}
      [dData setLength: size + dst - beg];
    }
  else if (ccls == [GSMimeQuotedDecoderContext class])
    {
      GSMimeQuotedDecoderContext	*ctxt;

      ctxt = (GSMimeQuotedDecoderContext*)con;

      /*
       * Expand destination data buffer to have capacity to handle info.
       */
      [dData setLength: size + (end - src)];
      dst = (unsigned char*)[dData mutableBytes];
      beg = dst;

      while (src < end)
	{
	  if (ctxt->pos > 0)
	    {
	      if ((*src == '\n') || (*src == '\r'))
		{
		  ctxt->pos = 0;
		}
	      else
		{
		  ctxt->buf[ctxt->pos++] = '=';
		  if (ctxt->pos == 3)
		    {
		      int	c;
		      int	val;

		      ctxt->pos = 0;
		      c = ctxt->buf[1];
		      val = isdigit(c) ? (c - '0') : (c - 55);
		      val *= 0x10;
		      c = ctxt->buf[2];
		      val += isdigit(c) ? (c - '0') : (c - 55);
		      *dst++ = val;
		    }
		}
	    }
	  else if (*src == '=')
	    {
	      ctxt->buf[ctxt->pos++] = '=';
	    }
	  else
	    {
	      *dst++ = *src;
	    }
	  src++;
	}
      [dData setLength: size + dst - beg];
    }
  else if (ccls == [GSMimeChunkedDecoderContext class])
    {
      GSMimeChunkedDecoderContext	*ctxt;
      const char			*footers = src;

      ctxt = (GSMimeChunkedDecoderContext*)con;

      dst = beg = 0;
      while ([ctxt atEnd] == NO && src < end)
	{
	  switch (ctxt->state)
	    {
	      case ChunkSize:
		if (isxdigit(*src) && ctxt->pos < sizeof(ctxt->buf))
		  {
		    ctxt->buf[ctxt->pos++] = *src;
		  }
		else if (*src == ';')
		  {
		    ctxt->state = ChunkExt;
		  }
		else if (*src == '\r')
		  {
		    ctxt->state = ChunkEol1;
		  }
		else if (*src == '\n')
		  {
		    ctxt->state = ChunkData;
		  }
		src++;
		if (ctxt->state != ChunkSize)
		  {
		    int	val = 0;
		    int	index;

		    for (index = 0; index < ctxt->pos; index++)
		      {
			val *= 16;
			if (isdigit(ctxt->buf[index]))
			  {
			    val += ctxt->buf[index] - '0';
			  }
			else if (isupper(ctxt->buf[index]))
			  {
			    val += ctxt->buf[index] - 'A' + 10;
			  }
			else
			  {
			    val += ctxt->buf[index] - 'a' + 10;
			  }
		      }
		    ctxt->pos = val;
		    /*
		     * If we have read a chunk already, make sure that our
		     * destination size is updated correctly before growing
		     * the buffer for another chunk.
		     */
		    size += (dst - beg);
		    [dData setLength: size + val];
		    dst = (unsigned char*)[dData mutableBytes];
		    dst += size;
		    beg = dst;
		  }
		break;

	    case ChunkExt:
	      if (*src == '\r')
		{
		  ctxt->state = ChunkEol1;
		}
	      else if (*src == '\n')
		{
		  ctxt->state = ChunkData;
		}
	      src++;
	      break;

	    case ChunkEol1:
	      if (*src == '\n')
		{
		  ctxt->state = ChunkData;
		}
	      src++;
	      break;

	    case ChunkData:
	      /*
	       * If the pos is non-zero, we have a data chunk to read.
	       * otherwise, what we actually want it to read footers.
	       */
	      if (ctxt->pos > 0)
		{
		  *dst++ = *src++;
		  if (--ctxt->pos == 0)
		    {
		      ctxt->state = ChunkEol2;
		    }
		}
	      else
		{
		  footers = src;		// Record start position.
		  ctxt->state = ChunkFoot;
		}
	      break;

	    case ChunkEol2:
	      if (*src == '\n')
		{
		  ctxt->state = ChunkSize;
		}
	      src++;
	      break;

	    case ChunkFoot:
	      if (*src == '\r')
		{
		  src++;
		}
	      else if (*src == '\n')
		{
		  [ctxt setAtEnd: YES];
		}
	      else
		{
		  ctxt->state = ChunkFootA;
		}
	      break;

	    case ChunkFootA:
	      if (*src == '\n')
		{
		  ctxt->state = ChunkFootA;
		}
	      src++;
	      break;
	    }
	}
      if (ctxt->state == ChunkFoot || ctxt->state == ChunkFootA)
	{
	  [ctxt->data appendBytes: footers length: src - footers];
	  if ([ctxt atEnd] == YES)
	    {
	      NSMutableData	*old;

	      /*
	       * Pretend we are back parsing the original headers ...
	       */
	      old = data;
	      data = ctxt->data;
	      bytes = (unsigned char*)[data mutableBytes];
	      dataEnd = [data length];
	      inBody = NO;

	      /*
	       * Duplicate the normal header parsing process for our footers.
	       */
	      while (inBody == NO)
		{
		  if ([self _unfoldHeader] == NO)
		    {
		      break;
		    }
		  if (inBody == NO)
		    {
		      NSString		*header;

		      header = [self _decodeHeader];
		      if (header == nil)
			{
			  break;
			}
		      if ([self parseHeader: header] == NO)
			{
			  break;
			}
		    }
		}

	      /*
	       * restore original data.
	       */
	      ctxt->data = data;
	      data = old;
	      bytes = (unsigned char*)[data mutableBytes];
	      dataEnd = [data length];
	      inBody = YES;
	    }
	}
      /*
       * Append any data.
       */	
      [dData setLength: size + dst - beg];
    }
  else
    {
      /*
       * Assume binary (no) decoding required.
       */
      [dData setLength: size + (end - src)];
      dst = (unsigned char*)[dData mutableBytes];
      memcpy(&dst[size], src, (end - src));
      [dData setLength: size + end - src];
    }

  /*
   * A nil data item as input represents end of data.
   */
  if (sData == nil)
    {
      [con setAtEnd: YES];
    }

  return YES;
}

- (NSString*) description
{
  NSMutableString	*desc;

  desc = [NSMutableString stringWithFormat: @"GSMimeParser <%0x> -\n", self];
  [desc appendString: [document description]];
  return desc;
}

- (GSMimeDocument*) document
{
  return document;
}

- (id) init
{
  self = [super init];
  if (self != nil)
    {
      data = [[NSMutableData alloc] init];
      document = [[GSMimeDocument alloc] init];
      context = [[GSMimeCodingContext alloc] init];
    }
  return self;
}

- (BOOL) parse: (NSData*)d
{
  if (data == nil)
    {
      return NO;	/* Already completely parsed! */
    }
  if ([d length] > 0)
    {
      if (inBody == NO)
	{
	  [data appendBytes: [d bytes] length: [d length]];
	  bytes = (unsigned char*)[data mutableBytes];
	  dataEnd = [data length];

	  while (inBody == NO)
	    {
	      if ([self _unfoldHeader] == NO)
		{
		  return YES;	/* Needs more data to fill line.	*/
		}
	      if (inBody == NO)
		{
		  NSString		*header;

		  header = [self _decodeHeader];
		  if (header == nil)
		    {
		      return NO;	/* Couldn't handle words.	*/
		    }
		  if ([self parseHeader: header] == NO)
		    {
		      return NO;	/* Header not parsed properly.	*/
		    }
		}
	    }
	  /*
	   * All headers have been parsed, so we empty our internal buffer
	   * (which we will now use to store decoded data) and place unused
	   * information back in the incoming data object to act as input.
	   */
	  d = AUTORELEASE([data copy]);
	  [data setLength: 0];
	}

      if ([d length] > 0)
	{
	  [self _decodeBody: d];
	}
      return YES;	/* Want more data for body */
    }
  else
    {
      BOOL	result;

      if (inBody == YES)
	{
	  result = [self _decodeBody: d];
	}
      else
	{
	  /*
	   * If still parsing headers, add CR-LF sequences to terminate
	   * the headers.
           */
	  result = [self parse: [NSData dataWithBytes: @"\r\n\r\n" length: 4]];
	}
      DESTROY(data);
      return result;
    }
}

- (BOOL) parseHeader: (NSString*)aHeader
{
  NSScanner		*scanner = [NSScanner scannerWithString: aHeader];
  NSString		*name;
  NSString		*value;
  NSMutableDictionary	*info;
  NSCharacterSet	*skip;
  unsigned		count;

  info = [NSMutableDictionary dictionary];

  /*
   * Store the raw header string in the info dictionary.
   */
  [info setObject: [scanner string] forKey: @"RawHeader"];

  /*
   * Special case - permit web response status line to act like a header.
   */
  if ([scanner scanString: @"HTTP" intoString: &name] == NO
    || [scanner scanString: @"/" intoString: 0] == NO)
    {
      if ([scanner scanUpToString: @":" intoString: &name] == NO)
	{
	  NSLog(@"Not a valid header (%@)", [scanner string]);
	  return NO;
	}
      /*
       * Position scanner after colon and any white space.
       */
      if ([scanner scanString: @":" intoString: 0] == NO)
	{
	  NSLog(@"No colon terminating name in header (%@)", [scanner string]);
	  return NO;
	}
    }

  /*
   * Store the Raw header name and a lowercase version too.
   */
  name = [name stringByTrimmingTailSpaces];
  [info setObject: name forKey: @"BaseName"];
  name = [name lowercaseString];
  [info setObject: name forKey: @"Name"];

  skip = RETAIN([scanner charactersToBeSkipped]);
  [scanner setCharactersToBeSkipped: nil];
  [scanner scanCharactersFromSet: skip intoString: 0];
  [scanner setCharactersToBeSkipped: skip];
  RELEASE(skip);

  /*
   * Set remainder of header as a base value.
   */
  [info setObject: [[scanner string] substringFromIndex: [scanner scanLocation]]
	   forKey: @"BaseValue"];

  /*
   * Break header fields out into info dictionary.
   */
  if ([self scanHeader: scanner named: name inTo: info] == NO)
    {
      return NO;
    }

  /*
   * Check validity of broken-out header fields.
   */
  if ([name isEqualToString: @"mime-version"] == YES)
    {
      int	majv = 0;
      int	minv = 0;

      value = [info objectForKey: @"BaseValue"];
      if ([value length] == 0)
	{
	  NSLog(@"Missing value for mime-version header");
	  return NO;
	}
      if (sscanf([value lossyCString], "%d.%d", &majv, &minv) != 2)
	{
	  NSLog(@"Bad value for mime-version header");
	  return NO;
	}
      [document deleteHeaderNamed: name];	// Should be unique
    }
  else if ([name isEqualToString: @"content-type"] == YES)
    {
      NSString	*type;
      NSString	*subtype;
      BOOL	supported = NO;

      DESTROY(boundary);
      type = [info objectForKey: @"Type"];
      if ([type length] == 0)
	{
	  NSLog(@"Missing Mime content-type");
	  return NO;
	}
      subtype = [info objectForKey: @"SubType"];
	
      if ([type isEqualToString: @"text"] == YES)
	{
	  if (subtype == nil)
	    subtype = @"plain";
	}
      else if ([type isEqualToString: @"application"] == YES)
	{
	  if (subtype == nil)
	    subtype = @"octet-stream";
	}
      else if ([type isEqualToString: @"multipart"] == YES)
	{
	  NSDictionary	*par = [info objectForKey: @"Parameters"];
	  NSString	*tmp = [par objectForKey: @"boundary"];

	  supported = YES;
	  if (tmp != nil)
	    {
	      unsigned int	l = [tmp cStringLength] + 2;
	      unsigned char	*b = NSZoneMalloc(NSDefaultMallocZone(), l + 1);

	      b[0] = '-';
	      b[1] = '-';
	      [tmp getCString: &b[2]];
	      ASSIGN(boundary, [NSData dataWithBytesNoCopy: b length: l]);
	    }
	  else
	    {
	      NSLog(@"multipart message without boundary");
	      return NO;
	    }
	}

      [document deleteHeaderNamed: name];	// Should be unique
    }

  /*
   * Ensure that info dictionary is immutable by making a copy
   * of all keys and objects and placing them in a new dictionary.
   */
  count = [info count];
  {
    id		keys[count];
    id		objects[count];
    unsigned	index;

    [[info allKeys] getObjects: keys];
    for (index = 0; index < count; index++)
      {
	keys[index] = [keys[index] copy];
	objects[index] = [[info objectForKey: keys[index]] copy];
      }
    info = [NSDictionary dictionaryWithObjects: objects
				       forKeys: keys
					 count: count];
    for (index = 0; index < count; index++)
      {
	RELEASE(objects[index]);
	RELEASE(keys[index]);
      }
  }

  return [document addHeader: info];
}

- (BOOL) parsedHeaders
{
  return inBody;
}

/*
 * Parse an unloaded and decoded header line, splitting information
 * into an 'info' dictionary.
 */
- (BOOL) scanHeader: (NSScanner*)scanner
	      named: (NSString*)name
	       inTo: (NSMutableDictionary*)info
{
  NSString		*value = nil;
  NSMutableDictionary	*parameters = nil;

  /*
   *	Now see if we are interested in any of it.
   */
  if ([name isEqualToString: @"http"] == YES)
    {
      int	major;
      int	minor;
      int	status;

      if ([scanner scanInt: &major] == NO || major < 0)
	{
	  NSLog(@"Bad value for http major version");
	  return NO;
	}
      if ([scanner scanString: @"." intoString: 0] == NO)
	{
	  NSLog(@"Bad format for http version");
	  return NO;
	}
      if ([scanner scanInt: &minor] == NO || minor < 0)
	{
	  NSLog(@"Bad value for http minor version");
	  return NO;
	}
      if ([scanner scanInt: &status] == NO || status < 0)
	{
	  NSLog(@"Bad value for http status");
	  return NO;
	}
      [info setObject: [NSString stringWithFormat: @"%d", major]
	       forKey: @"HttpMajorVersion"];
      [info setObject: [NSString stringWithFormat: @"%d", minor]
	       forKey: @"HttpMinorVersion"];
      [info setObject: [NSString stringWithFormat: @"%d.%d", major, minor]
	       forKey: @"HttpVersion"];
      [info setObject: [NSString stringWithFormat: @"%d", status]
	       forKey: @"HttpStatus"];
      [self scanPastSpace: scanner];
      value = [[scanner string] substringFromIndex: [scanner scanLocation]];
    }
  else if ([name isEqualToString: @"content-transfer-encoding"] == YES
    || [name isEqualToString: @"transfer-encoding"] == YES)
    {
      value = [self scanToken: scanner];
      if ([value length] == 0)
	{
	  NSLog(@"Bad value for content-transfer-encoding header");
	  return NO;
	}
      value = [value lowercaseString];
    }
  else if ([name isEqualToString: @"content-type"] == YES)
    {
      NSString	*type;
      NSString	*subtype = nil;

      type = [self scanToken: scanner];
      if ([type length] == 0)
	{
	  NSLog(@"Invalid Mime content-type");
	  return NO;
	}
      type = [type lowercaseString];
      [info setObject: type forKey: @"Type"];
      if ([scanner scanString: @"/" intoString: 0] == YES)
	{
	  subtype = [self scanToken: scanner];
	  if ([subtype length] == 0)
	    {
	      NSLog(@"Invalid Mime content-type (subtype)");
	      return NO;
	    }
	  subtype = [subtype lowercaseString];
	  [info setObject: subtype forKey: @"SubType"];
	  value = [NSString stringWithFormat: @"%@/%@", type, subtype];
	}
      else
	{
	  value = type;
	}

      while ([scanner scanString: @";" intoString: 0] == YES)
	{
	  NSString	*paramName;

	  paramName = [self scanToken: scanner];
	  if ([paramName length] == 0)
	    {
	      NSLog(@"Invalid Mime content-type (parameter name)");
	      return NO;
	    }
	  if ([scanner scanString: @"=" intoString: 0] == YES)
	    {
	      NSString	*paramValue;

	      paramValue = [self scanToken: scanner];
	      if (paramValue == nil)
		{
		  paramValue = @"";
		}
	      if (parameters == nil)
		{
		  parameters = [NSMutableDictionary dictionary];
		}
	      paramName = [paramName lowercaseString];
	      [parameters setObject: paramValue forKey: paramName];
	    }
	  else
	    {
	      NSLog(@"Ignoring Mime content-type parameter (%@)", paramName);
	    }
	}
    }
  else if ([name isEqualToString: @"content-disposition"] == YES)
    {
      value = [self scanToken: scanner];
      value = [value lowercaseString];
      /*
       *	Concatenate slash separated parts of field.
       */
      while ([scanner scanString: @"/" intoString: 0] == YES)
	{
	  NSString	*sub = [self scanToken: scanner];

	  if ([sub length] > 0)
	    {
	      sub = [sub lowercaseString];
	      value = [NSString stringWithFormat: @"%@/%@", value, sub];
	    }
	}

      /*
       *	Expect anything else to be 'name=value' parameters.
       */
      while ([scanner scanString: @";" intoString: 0] == YES)
	{
	  NSString	*paramName;

	  paramName = [self scanToken: scanner];
	  if ([paramName length] == 0)
	    {
	      NSLog(@"Invalid Mime content-type (parameter name)");
	      return NO;
	    }
	  if ([scanner scanString: @"=" intoString: 0] == YES)
	    {
	      NSString	*paramValue;

	      paramValue = [self scanToken: scanner];
	      if (paramValue == nil)
		{
		  paramValue = @"";
		}
	      if (parameters == nil)
		{
		  parameters = [NSMutableDictionary dictionary];
		}
	      paramName = [paramName lowercaseString];
	      [parameters setObject: paramValue forKey: paramName];
	    }
	  else
	    {
	      NSLog(@"Ignoring Mime content-disposition parameter (%@)",
		paramName);
	    }
	}
    }

  if (value != nil)
    {
      [info setObject: value forKey: @"Value"];
    }
  if (parameters != nil)
    {
      [info setObject: parameters forKey: @"Parameters"];
    }
  return YES;
}

- (BOOL) scanPastSpace: (NSScanner*)scanner
{
  NSCharacterSet	*skip;
  BOOL			scanned;

  skip = RETAIN([scanner charactersToBeSkipped]);
  [scanner setCharactersToBeSkipped: nil];
  scanned = [scanner scanCharactersFromSet: skip intoString: 0];
  [scanner setCharactersToBeSkipped: skip];
  RELEASE(skip);
  return scanned;
}

- (NSString*) scanSpecial: (NSScanner*)scanner
{
  unsigned		location;
  unichar		c;

  [self scanPastSpace: scanner];

  /*
   * Now return token delimiter (may be whitespace)
   */
  location = [scanner scanLocation];
  c = [[scanner string] characterAtIndex: location];

  if ([specials characterIsMember: c] == YES)
    {
      [scanner setScanLocation: location + 1];
      return [NSString stringWithCharacters: &c length: 1];
    }
  else
    {
      return @" ";
    }
}

/*
 *	Get a mime field value - token or quoted string.
 */
- (NSString*) scanToken: (NSScanner*)scanner
{
  if ([scanner scanString: @"\"" intoString: 0] == YES)		// Quoted
    {
      NSString	*string = [scanner string];
      unsigned	length = [string length];
      unsigned	start = [scanner scanLocation];
      NSRange	r = NSMakeRange(start, length - start);
      BOOL	done = NO;

      while (done == NO)
	{
	  r = [string rangeOfString: @"\""
			    options: NSLiteralSearch
			      range: r];
	  if (r.length == 0)
	    {
	      NSLog(@"Parsing header value - found unterminated quoted string");
	      return nil;
	    }
	  if ([string characterAtIndex: r.location - 1] == '\\')
	    {
	      r.location++;
	      r.length = length - r.location;
	    }
	  else
	    {
	      done = YES;
	    }
	}
      [scanner setScanLocation: r.length + 1];
      length = r.location - start;
      if (length == 0)
	{
	  return nil;
	}
      else
	{
	  unichar	buf[length];
	  unichar	*src = buf;
	  unichar	*dst = buf;

	  [string getCharacters: buf range: NSMakeRange(start, length)];
	  while (src < &buf[length])
	    {
	      if (*src == '\\')
		{
		  src++;
		}
	      *dst++ = *src++;
	    }
	  return [NSString stringWithCharacters: buf length: dst - buf];
	}
    }
  else							// Token
    {
      NSCharacterSet		*skip;
      NSString			*value;

      /*
       * Move past white space.
       */
      skip = RETAIN([scanner charactersToBeSkipped]);
      [scanner setCharactersToBeSkipped: nil];
      [scanner scanCharactersFromSet: skip intoString: 0];
      [scanner setCharactersToBeSkipped: skip];
      RELEASE(skip);

      /*
       * Scan value terminated by any special character.
       */
      if ([scanner scanUpToCharactersFromSet: specials
				  intoString: &value] == NO)
	{
	  return nil;
	}
      return value;
    }
}

@end

@implementation	GSMimeParser (Private)
/*
 * This method takes the raw data of an unfolded header line, and handles
 * RFC2047 word encoding in the header by creating a string containing the
 * decoded words.
 */
- (NSString*) _decodeHeader
{
  NSStringEncoding	charset;
  WE			encoding;
  unsigned char		c;
  unsigned char		*src, *dst, *beg;
  NSMutableString	*hdr = [NSMutableString string];
  CREATE_AUTORELEASE_POOL(arp);

  /*
   * Remove any leading or trailing space - there shouldn't be any.
   */
  while (lineStart < lineEnd && isspace(bytes[lineStart]))
    {
      lineStart++;
    }
  while (lineEnd > lineStart && isspace(bytes[lineEnd-1]))
    {
      lineEnd--;
    }

  /*
   * Perform quoted text substitution.
   */
  bytes[lineEnd] = '\0';
  dst = src = beg = &bytes[lineStart];
  while (*src != 0)
    {
      if ((src[0] == '=') && (src[1] == '?'))
	{
	  unsigned char	*tmp;

	  if (dst > beg)
	    {
	      NSData	*d = [NSData dataWithBytes: beg length: dst - beg];
	      NSString	*s;

	      s = [[NSString alloc] initWithData: d
					encoding: NSASCIIStringEncoding];
	      [hdr appendString: s];
	      RELEASE(s);
	      dst = beg;
	    }

	  if (src[3] == '\0')
	    {
	      dst[0] = '=';
	      dst[1] = '?';
	      dst[2] = '\0';
	      NSLog(@"Bad encoded word - character set missing");
	      break;
	    }

	  src += 2;
	  tmp = src;
	  src = (unsigned char*)strchr((char*)src, '?'); 
	  if (src == 0)
	    {
	      NSLog(@"Bad encoded word - character set terminator missing");
	      break;
	    }
	  *src = '\0';
	  charset = parseCharacterSet([NSString stringWithCString: tmp]);
	  src++;
	  if (*src == 0)
	    {
	      NSLog(@"Bad encoded word - content type missing");
	      break;
	    }
	  c = tolower(*src);
	  if (c == 'b')
	    {
	      encoding = WE_BASE64;
	    }
	  else if (c == 'q')
	    {
	      encoding = WE_QUOTED;
	    }
	  else
	    {
	      NSLog(@"Bad encoded word - content type unknown");
	      break;
	    }
	  src = (unsigned char*)strchr((char*)src, '?');
	  if (src == 0)
	    {
	      NSLog(@"Bad encoded word - content type terminator missing");
	      break;
	    }
	  src++;
	  if (*src == 0)
	    {
	      NSLog(@"Bad encoded word - data missing");
	      break;
	    }
	  tmp = (unsigned char*)strchr((char*)src, '?');
	  if (tmp == 0)
	    {
	      NSLog(@"Bad encoded word - data terminator missing");
	      break;
	    }
	  dst = decodeWord(dst, src, tmp, encoding);
	  tmp++;
	  if (*tmp != '=')
	    {
	      NSLog(@"Bad encoded word - encoded word terminator missing");
	      break;
	    }
	  src = tmp;
	  if (dst > beg)
	    {
	      NSData	*d = [NSData dataWithBytes: beg length: dst - beg];
	      NSString	*s;

	      s = [[NSString alloc] initWithData: d
					encoding: charset];
	      [hdr appendString: s];
	      RELEASE(s);
	      dst = beg;
	    }
	}
      else
	{
	  *dst++ = *src;
	}
      src++;
    }
  if (dst > beg)
    {
      NSData	*d = [NSData dataWithBytes: beg length: dst - beg];
      NSString	*s;

      s = [[NSString alloc] initWithData: d
				encoding: NSASCIIStringEncoding];
      [hdr appendString: s];
      RELEASE(s);
      dst = beg;
    }
  RELEASE(arp);
  return hdr;
}

- (BOOL) _decodeBody: (NSData*)d
{
  if (boundary == nil)
    {
      NSDictionary	*typeInfo;
      NSString		*type;

      typeInfo = [document headerNamed: @"content-type"];
      type = [typeInfo objectForKey: @"Type"];
      if ([type isEqualToString: @"multipart"] == YES)
	{
	  NSLog(@"multipart decode attempt without boundary");
	  return NO;
	}
      else
	{
	  if ([context atEnd] == YES)
	    {
	      if ([d length] > 0)
		{
		  NSLog(@"Additional data ignored after parse complete");
		}
	      return YES;	/* Nothing more to do	*/
	    }

	  [self decodeData: d
		 fromRange: NSMakeRange(0, [d length])
		  intoData: data
	       withContext: context];

	  if ([context atEnd] == YES)
	    {
	      /*
	       * If no content type is supplied, we assume text.
	       */
	      if (type == nil || [type isEqualToString: @"text"] == YES)
		{
		  NSDictionary		*params;
		  NSString		*charset;
		  NSStringEncoding	stringEncoding;
		  NSString		*string;

		  /*
		   * Assume that content type is best represented as NSString.
		   */
		  params = [typeInfo objectForKey: @"Parameters"];
		  charset = [params objectForKey: @"charset"];
		  stringEncoding = parseCharacterSet(charset);
		  string = [[NSString alloc] initWithData: data
						 encoding: stringEncoding];
		  [document setContent: string];
		  RELEASE(string);
		}
	      else
		{
		  /*
		   * Assume that any non-text content type is best
		   * represented as NSData.
		   */
		  [document setContent: AUTORELEASE([data copy])];
		}
	    }
	  return YES;
	}
    }
  else
    {
      unsigned	int	bLength = [boundary length];
      unsigned char	*bBytes = (unsigned char*)[boundary bytes];
      unsigned char	bInit = bBytes[0];
      BOOL		done = NO;

      [data appendBytes: [d bytes] length: [d length]];
      bytes = (unsigned char*)[data mutableBytes];
      dataEnd = [data length];

      while (done == NO)
	{
	  /*
	   * Search our data for the next boundary.
	   */
	  while (dataEnd - lineStart >= bLength)
	    {
	      if (bytes[lineStart] == bInit
		&& memcmp(&bytes[lineStart], bBytes, bLength) == 0)
		{
		  if (lineStart == 0 || bytes[lineStart-1] == '\r'
		    || bytes[lineStart-1] == '\n')
		    {
		      lineEnd = lineStart + bLength;
		      break;
		    }
		}
	      lineStart++;
	    }
	  if (dataEnd - lineStart < bLength)
	    {
	      done = YES;	/* Needs more data.	*/
	    } 
	  else if (child == nil)
	    {
	      /*
	       * Found boundary at the start of the first section.
	       * Set sectionStart to point immediately after boundary.
	       */
	      lineStart += bLength;
	      sectionStart = lineStart;
	      child = [GSMimeParser new];
	    }
	  else
	    {
	      NSData	*d;
	      BOOL	endedFinalPart = NO;

	      /*
	       * Found boundary at the end of a section.
	       * Skip past line terminator for boundary at start of section
	       * or past marker for end of multipart document.
	       */
	      if (bytes[sectionStart] == '-' && sectionStart < dataEnd
		&& bytes[sectionStart+1] == '-')
		{
		  sectionStart += 2;
		  endedFinalPart = YES;
		}
	      if (bytes[sectionStart] == '\r')
		sectionStart++;
	      if (bytes[sectionStart] == '\n')
		sectionStart++;

	      /*
	       * Create data object for this section and pass it to the
	       * child parser to deal with.
	       */
	      d = [NSData dataWithBytes: &bytes[sectionStart]
				 length: lineStart - sectionStart];
	      if ([child parse: d] == YES && [child parse: nil] == YES)
		{
		  NSMutableArray	*a;
		  GSMimeDocument	*doc;

		  /*
		   * Store the document produced by the child, and
		   * create a new parser for the next section.
	           */
		  a = [document content];
		  if (a == nil)
		    {
		      a = [NSMutableArray new];
		      [document setContent: a];
		      RELEASE(a);
		    }
		  doc = [child document];
		  if (doc != nil)
		    {
		      [a addObject: doc];
		    }
		  RELEASE(child);
		  child = [GSMimeParser new];
		}
	      else
		{
		  /*
		   * Section failed to decode properly!
		   */
		  NSLog(@"Failed to decode section of multipart");
		  RELEASE(child);
		  child = [GSMimeParser new];
		}

	      /*
	       * Update parser data.
	       */
	      lineStart += bLength;
	      sectionStart = lineStart;
	      memcpy(bytes, &bytes[sectionStart], dataEnd - sectionStart);
	      dataEnd -= sectionStart;
	      [data setLength: dataEnd];
	      bytes = (unsigned char*)[data mutableBytes];
	      lineStart -= sectionStart;
	      sectionStart = 0;
	    }
	}
      return YES;
    }
  return NO;
}

- (BOOL) _unfoldHeader
{
  char	c;
  BOOL	unwrappingComplete = NO;

  lineStart = lineEnd;
  /*
   * RFC822 lets header fields break across lines, with continuation
   * lines beginning with whitespace.  This is called folding - and the
   * first thing we need to do is unfold any folded lines into a single
   * unfolded line (lineStart to lineEnd).
   */
  while (input < dataEnd && unwrappingComplete == NO)
    {
      /*
       * Copy data up to end of line, and skip past end.
       */
      while (input < dataEnd && (c = bytes[input]) != '\r' && c != '\n')
	{
	  bytes[lineEnd++] = bytes[input++];
	}
      input++;
      if (c == '\r' && input < dataEnd && bytes[input] == '\n')
	{
	  input++;
	}

      /*
       * See if we have a wrapped line.
       */
      if (input >= dataEnd || (c = bytes[input]) == '\r' || c == '\n'
	|| isspace(c) == 0)
	{
	  unwrappingComplete = YES;
	  bytes[lineEnd] = '\0';
	  /*
	   * If this is a zero-length line, we have reached the end of
	   * the headers.
	   */
	  if (lineEnd == lineStart)
	    {
	      unsigned		lengthRemaining;
	      NSDictionary	*hdr;

	      /*
	       * Overwrite the header data with the body, ready to start
	       * parsing the body data.
	       */
	      lengthRemaining = dataEnd - input;
	      if (lengthRemaining > 0)
		{
		  memcpy(bytes, &bytes[input], lengthRemaining);
		}
	      dataEnd = lengthRemaining;
	      [data setLength: lengthRemaining];
	      bytes = (unsigned char*)[data mutableBytes];
	      sectionStart = 0;
	      lineStart = 0;
	      lineEnd = 0;
	      input = 0;

	      /*
	       * At end of headers - set up context for decoding data.
	       */
	      inBody = YES;
	      DESTROY(context);
	      hdr = [document headerNamed: @"content-transfer-encoding"];
	      if (hdr == nil)
		{
		  hdr = [document headerNamed: @"transfer-encoding"];
		}
	      context = [self contextFor: hdr];
	      RETAIN(context);
	    }
	}
    }
  return unwrappingComplete;
}

@end



@implementation	GSMimeDocument

+ (void) initialize
{
  if (self == [GSMimeDocument class])
    {
      NSMutableCharacterSet	*m = [[NSMutableCharacterSet alloc] init];

      [m formUnionWithCharacterSet:
	[NSCharacterSet characterSetWithCharactersInString:
	@"()<>@,;:/[]?=\"\\"]];
      [m formUnionWithCharacterSet:
	[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      [m formUnionWithCharacterSet:
	[NSCharacterSet controlCharacterSet]];
      [m formUnionWithCharacterSet:
	[NSCharacterSet illegalCharacterSet]];
      specials = [m copy];
    }
}

+ (GSMimeDocument*) mimeDocument
{
  return AUTORELEASE([[self alloc] init]);
}

- (BOOL) addHeader: (NSDictionary*)info
{
  NSString	*name = [info objectForKey: @"Name"];

  if (name == nil)
    {
      NSLog(@"addHeader: supplied with header info without 'Name' field");
      return NO;
    }

  info = [info copy];
  [headers addObject: info];
  RELEASE(info);
  return YES;
}

- (NSArray*) allHeaders
{
  return [NSArray arrayWithArray: headers];
}

- (id) content
{
  return content;
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (void) dealloc
{
  RELEASE(headers);
  RELEASE(content);
  [super dealloc];
}

- (void) deleteHeader: (NSString*)aHeader
{
  unsigned	count = [headers count];

  while (count-- > 0)
    {
      NSDictionary	*info = [headers objectAtIndex: count];

      if ([aHeader isEqualToString: [info objectForKey: @"RawHeader"]] == YES)
	{
	  [headers removeObjectAtIndex: count];
	}
    }
}

- (void) deleteHeaderNamed: (NSString*)name
{
  unsigned	count = [headers count];

  name = [name lowercaseString];
  while (count-- > 0)
    {
      NSDictionary	*info = [headers objectAtIndex: count];

      if ([name isEqualToString: [info objectForKey: @"Name"]] == YES)
	{
	  [headers removeObjectAtIndex: count];
	}
    }
}

- (NSString*) description
{
  NSMutableString	*desc;
  NSDictionary		*locale;

  desc = [NSMutableString stringWithFormat: @"GSMimeDocument <%0x> -\n", self];
  locale = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
  [desc appendString: [headers descriptionWithLocale: locale]];
  [desc appendFormat: @"\nDocument content -\n%@", content];
  return desc;
}

- (NSDictionary*) headerNamed: (NSString*)name
{
  unsigned		count = [headers count];
  unsigned		index;

  name = [name lowercaseString];
  for (index = 0; index < count; index++)
    {
      NSDictionary	*info = [headers objectAtIndex: index];
      NSString		*other = [info objectForKey: @"Name"];

      if ([name isEqualToString: other] == YES)
	{
	  return info;
	}
    } 
  return nil;
}

- (NSArray*) headersNamed: (NSString*)name
{
  unsigned		count = [headers count];
  unsigned		index;
  NSMutableArray	*array;

  name = [name lowercaseString];
  array = [NSMutableArray array];
  for (index = 0; index < count; index++)
    {
      NSDictionary	*info = [headers objectAtIndex: index];
      NSString		*other = [info objectForKey: @"Name"];

      if ([name isEqualToString: other] == YES)
	{
	  [array addObject: info];
	}
    } 
  return array;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      headers = [NSMutableArray new];
    }
  return self;
}

- (BOOL) setContent: (id)newContent
{
  ASSIGN(content, newContent);
  return YES;
}

- (BOOL) setHeader: (NSDictionary*)info
{
  NSString	*name = [info objectForKey: @"Name"];
  unsigned	count = [headers count];

  if (name == nil)
    {
      NSLog(@"setHeader: supplied with header info without 'Name' field");
      return NO;
    }

  /*
   * Remove any existing headers with this name.
   */
  while (count-- > 0)
    {
      NSDictionary	*tmp = [headers objectAtIndex: count];

      if ([name isEqualToString: [tmp objectForKey: @"Name"]] == YES)
	{
	  [headers removeObjectAtIndex: count];
	}
    }

  return [self addHeader: info];
}

@end

