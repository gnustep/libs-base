
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

@interface GSMimeParser (Private)
- (BOOL) _decodeBody: (NSData*)boundary;
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
  RELEASE(document);
  [super dealloc];
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
      NSData	*boundary;

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
		  return NO;	/* Couldn't handle word encodings.	*/
		}
	      if ([document addHeader: header] == NO)
		{
		  return NO;	/* Header was not in legal format.	*/
		}
	    }
	}

      /*
       * If we have a multipart document, we must feed the data to
       * a child parser to decode the subsidiary parts.
       */
      boundary = [document boundary];
      if (boundary != nil)
	{
	  [self _decodeBody: boundary];
	}
      return YES;	/* Want more data for body */
    }
  else
    {
      BOOL	result;

      if (inBody == YES)
	{
	  result = [self _decodeBody: [document boundary]];
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

- (BOOL) parsedHeaders
{
  return inBody;
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

- (BOOL) _decodeBody: (NSData*)boundary
{
  if (boundary == nil)
    {
      NSDictionary	*typeInfo;
      NSString		*type;

      typeInfo = [document infoForHeaderNamed: @"content-type"];
      type = [typeInfo objectForKey: @"Type"];
      if ([type isEqualToString: @"multipart"] == YES)
	{
	  NSLog(@"multipart decode attempt without boundary");
	  return NO;
	}
      else
	{
	  NSDictionary	*encInfo;
	  NSString	*value;
	  NSData	*decoded;

	  encInfo = [document infoForHeaderNamed: @"content-transfer-encoding"];
	  value = [encInfo objectForKey: @"Value"];

	  if ([value isEqualToString: @"quoted-printable"] == YES)
	    {
	      int		cc;
	      const char	*src;
	      const char	*end;
	      unsigned char	*dst;
	      unsigned char	*beg;

	      src = (const char*)bytes;
	      end = src + dataEnd;
	      beg = NSZoneMalloc(NSDefaultMallocZone(), dataEnd);
	      dst = beg;

	      while (src < end)
		{
		  if (*src == '=')
		    {
		      src++;
		      if (src == end)
			{
			  break;
			}
		      if ((*src == '\n') || (*src == '\r'))
			{
			  break;
			}
		      cc = isdigit(*src) ? (*src - '0') : (*src - 55);
		      cc *= 0x10;
		      src++;
		      if (src == end)
			{
			  break;
			}
		      cc += isdigit(*src) ? (*src - '0') : (*src - 55);
		      *dst = cc;
		    }
		  else
		    {
		      *dst = *src;
		    }
		  dst++;
		  src++;
		}
	      decoded = [NSData dataWithBytesNoCopy: beg length: dst - beg];
	    }
	  else if ([value isEqualToString: @"base64"] == YES)
	    {
	      int		cc;
	      const char	*src;
	      const char	*end;
	      unsigned char	*dst;
	      unsigned char	*beg;
	      char		buf[4];
	      int		pos = 0;

	      src = (const char*)bytes;
	      end = src + dataEnd;
	      beg = NSZoneMalloc(NSDefaultMallocZone(), dataEnd);
	      dst = beg;

	      while (src < end)
		{
		  cc = *src++;
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
		  else if (cc == '/')
		    {
		      cc = 63;
		    }
		  else if (cc == '+')
		    {
		      cc = 62;
		    }
		  else if (cc == '=')
		    {
		      cc = -1;
		    }
		  else if (cc == '\r')
		    {
		      cc = -1;
		    }
		  else if (cc == '\n')
		    {
		      cc = -1;
		    }
		  else if (cc == '-')
		    {
		      break;
		    }
		  else
		    {
		      cc = -1;				/* ignore */
		    }

		  if (cc >= 0)
		    {
		      buf[pos++] = cc;
		      if (pos == 4)
			{
			  decodebase64(dst, buf);
			  pos = 0;
			  dst += 3;
			}
		    }
		}

	      for (cc = pos; cc < 4; cc++)
		{
		  buf[cc] = '\0';
		}
	      if (pos > 0)
		{
		  pos--;
		}
	      decodebase64(dst, buf);
	      dst += pos;
	      decoded = [NSData dataWithBytesNoCopy: beg length: dst - beg];
	    }
	  else /* Assume no encoding used */
	    {
	      decoded = data;
	    }

	  /*
	   * If no content type is supplied, we assume text.
	   */
	  if (type == nil || [type isEqualToString: @"text"] == YES)
	    {
	      NSDictionary	*params;
	      NSString		*charset;
	      NSStringEncoding	stringEncoding;
	      NSString		*string;

	      /*
	       * Assume that content type is best represented as NSString.
	       */
	      params = [typeInfo objectForKey: @"Parameters"];
	      charset = [params objectForKey: @"charset"];
	      stringEncoding = parseCharacterSet(charset);
	      string = [[NSString alloc] initWithData: decoded
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
	      decoded = [decoded copy]; /* Ensure it's immutable */
	      [document setContent: decoded];
	      RELEASE(decoded);
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

		  /*
		   * Store the document produced by the child, and
		   * create anew parser for the next section.
	           */
		  a = [document content];
		  if (a == nil)
		    {
		      a = [NSMutableArray new];
		      [document setContent: a];
		      RELEASE(a);
		    }
		  [a addObject: [child document]];
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
	      unsigned	lengthRemaining;

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
	      sectionStart = 0;
	      lineStart = 0;
	      lineEnd = 0;
	      input = 0;
	      inBody = YES;	/* At end of headers.	*/
	    }
	}
    }
  return unwrappingComplete;
}

@end



#if 0
/*
 *	Name		decodebuf()
 *	Purpose -	Decode a line.
 */
static void
decodebuf(mstate* ptr, unsigned char *src, int enc, int *junkp, int* len)
{
  int		cc;
  int		show;
  unsigned char	*ss;
  unsigned char	*dest = src;

  if (enc == CE_QUOTEDP)
    {
      *len = 0;
      while (*src)
	{
	  if (*src == '=')
	    {
	      src++;
	      if (*src == 0)
		{
		  break;
		}
	      if ((*src == '\n') || (*src == '\r'))
		{
		  break;
		}
	      cc = isdigit(*src) ? (*src - '0') : (*src - 55);
	      cc *= 0x10;
	      src++;
	      if (*src == 0)
		{
		  break;
		}
	      cc += isdigit(*src) ? (*src - '0') : (*src - 55);
	      *dest = cc;
	    }
	  else
	    {
	      *dest = *src;
	    }
	  dest++;
	  src++;
	  (*len)++;
	}
      *dest = '\0';
    }
  else if (enc == CE_BASE064)
    {
      *len = 0;
      if (ptr->EndP)
	{
	  *junkp = 1;
	  return;
	}
      ptr->BPos = 0;
      while (*src)
	{
	  cc = *src++;
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
	  else if (cc == '/')
	    {
	      cc = 63;
	    }
	  else if (cc == '+')
	    {
	      cc = 62;
	    }
	  else if (cc == '=')
	    {
	      ptr->EndP = 1;
	      cc = -1;
	    }
	  else if (cc == '-')
	    {
	      *junkp = 1;			/* junk?  */
	      break;
	    }
	  else
	    {
	      cc = -1;				/* ignore */
	    }

	  if (cc >= 0)
	    {
	      ptr->BBuf[ptr->BPos++] = cc;
	      if (ptr->BPos == 4)
		{
		  ss = decodebase64(dest, ptr->BBuf);
		  ptr->BPos = 0;
		  dest += 3;
		  *len += 3;
		}
	    }
	}

      show = ptr->BPos;
      if (show)
	{
	  show--;
	}
      decodebase64(dest, ptr);
      ptr->BPos = 0;
      dest += show;
      *len += show;
      *dest = '\0';
    }
}



/*
 *	Name -		donehead()
 *	Purpose -	Do all sort of processing at the end of header.
 */
static void
donehead(mstate* ptr)
{
    int ctypemask;

    if (ptr->rfc822) {
	parsehead(ptr);
    }
    ptr->InHeadP = 0;
    if (ptr->MimeVers < 0) {			/* NOT MIME     */
	if (ptr->ContType != CT_UNKNOWN) {	/* RFC1049	*/
	    ptr->MimeVers = MV_R1049;
	} else {				/* no head	*/
	 /* ptr->MimeVers = MV_R0822;	default  */
	    ptr->ContType = CT_ASCTEXT;
	    ptr->CSubType = ST_PLAINTX;
	 /* ptr->Encoding = CE_UNCODED;	default  */
	 /* ptr->Charset  = NSISOLatin1StringEncoding;	default  */
	}
    }
    ptr->TempEncd = ptr->Encoding;

    if ((ptr->Charset == GSUndefinedEncoding)
	&& ((ptr->ContType != CT_ASCTEXT) || (ptr->CSubType != ST_PLAINTX))) {
	foldinit(ptr, GSUndefinedEncoding, GSUndefinedEncoding);
	ptr->FoldChP = 0;
    } else {
	foldinit(ptr, ptr->Charset,  CS_IGNOR);
    }

    if ((ptr->ActMask & AC_APPLCTN) && (ptr->nameParameter)) {
	ptr->AttFile = fopen(ptr->nameParameter, "wb");
    }

    ctypemask = 0; /* default */
    switch (ptr->ContType) {
      case CT_ASCTEXT: ctypemask = AC_ASCTEXT;	break;
      case CT_MULTIPT: ctypemask = AC_MULTIPT;	break;
      case CT_MESSAGE: ctypemask = AC_MESSAGE;	break;
      case CT_APPLCTN: ctypemask = AC_APPLCTN;	break;
    } /* switch */
    ptr->DecodeP = ctypemask & ptr->ActMask;
}


/*
 *	Name -		unmimeline()
 *	Params -	(mstate*)ptr, (unsigned char*)buf, (int*)len
 *	Purpose -	Process a line of input.
 *
 * 	buf = buffer containing line, also used to return decoded buffer.
 *      len = length of data in buffer on entry and return.
 * Ret: 0: nothing special
 *      1: line is null line separating header from body
 *      2: found junk trailing BASE64 encoding
 *      3: dumping attachement to named file
 *	4: line is multipart boundary
 *	5: line is a header line
 * Des: The mimelite library doesn't really handle RFC-1049 content types, but
 *      it assumes that somthing _with_ a content-type header, but _without_ a
 *      mime-version header must be RFC-1049 and sets MimeVers accordingly.
 *      The rest is up to you.
 */
int unmimeline(mstate* ptr, unsigned char *buf, int *len)
{
    int junkp = 0;

    buf[*len] = '\0';	/* Ensure nul termination.	*/
/*
 *	If we are in a multipart section and haven't started the header, 
 *	we check to see if the header is actually missing.
 */
    if (ptr->InHeadP == 2) {
	ptr->InHeadP = 1;
	if (strchr((char*)buf, ':') == 0) {
	    donehead(ptr);
	}
    }

    if (!ptr->InHeadP) {
        if (ptr->DecodeP) {
	    if (ptr->DecodeP == AC_MULTIPT) {
		if (strncmp((const char*)buf, ptr->Boundary, ptr->BLength)==0 &&
		    (buf[ptr->BLength] == '\0' || buf[ptr->BLength] == '-' ||
			isspace(buf[ptr->BLength]))) {
		    /*
		     *	At a boundary, we release any old subsidiary parser.
		     */
		    DESTROY(child);
		    /*
		     *	If we are not on the final boundary, we create a
		     *	subsidiary parser to handle everything in this part.
		     */
		    if (buf[ptr->BLength] != '-') {
			child = [GSMimeParser new];
			[child setHeader: 2];	/* May be no header.	*/
			[child setMimeVersion: [self mimeVersion]];
		    }
		    return(4);
		}
		else if (child != nil) {
		    /*
		     *	Parsing a multipart document, let the subsidiary
		     *	parser handle the current part.
		     */
		    return [child unmimeline: buf length: len];
		}
	    }
	    else {
		decodebuf(ptr, buf, ptr->TempEncd, &junkp, len);
	    }
	}
	if (ptr->FoldChP) {
	    foldbuff(ptr, buf, *len);
	}
	if (ptr->AttFile) {
	    fwrite(buf, *len, 1, ptr->AttFile);
	    return(3);
	}
	if (junkp) {
	    ptr->TempEncd = CE_UNCODED;
	    return(2);
	}
	return(0);
    }

    if (eohp(buf)) {				/* end of head  */
	donehead(ptr);
	return(1);
    }

    *len = decodhead(ptr, buf);
    foldbuff(ptr, buf, *len);
    junkp = fold_rfc822(ptr, (char*)buf);
    if (junkp != 0) {				/* Bad header.	*/
	donehead(ptr);
	return(-1);
    }
    return(5);
}
#endif



@interface	GSMimeDocument (Private)
- (NSDictionary*) _parseHeader: (NSString*)aHeader;
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

- (BOOL) addHeader: (NSString*)aHeader
{
  NSDictionary	*info = [self _parseHeader: aHeader];

  if (info == nil)
    {
      return NO;
    }
  else
    {
      [headers addObject: info];
      return YES;
    }
}

- (NSData*) boundary
{
  return boundary;
}

- (id) content
{
  return content;
}

- (void) dealloc
{
  RELEASE(headers);
  RELEASE(content);
  RELEASE(boundary);
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

- (NSArray*) infoForAllHeaders
{
  return [NSArray arrayWithArray: headers];
}

- (NSDictionary*) infoForHeaderNamed: (NSString*)name
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

- (NSArray*) infoForHeadersNamed: (NSString*)name
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

/*
 * Parse an unloaded and decoded header line, splitting information
 * into an 'info' dictionary.
 */
- (BOOL) parseHeader: (NSScanner*)scanner
	       named: (NSString*)name
		inTo: (NSMutableDictionary*)info
{
  NSString		*value = nil;
  NSMutableDictionary	*parameters = nil;

  /*
   *	Now see if we are interested in any of it.
   */
  if ([name isEqualToString: @"mime-version"] == YES)
    {
      value = [self scanToken: scanner];
      if ([value length] == 0)
	{
	  NSLog(@"Bad value for mime-version header");
	  return NO;
	}
    }
  else if ([name isEqualToString: @"content-transfer-encoding"] == YES)
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
	  [info setObject: type forKey: @"SubType"];
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

- (NSString*) scanSpecial: (NSScanner*)scanner
{
  NSCharacterSet	*skip;
  unsigned		location;
  unichar		c;

  /*
   * Move past white space.
   */
  skip = RETAIN([scanner charactersToBeSkipped]);
  [scanner setCharactersToBeSkipped: nil];
  [scanner scanCharactersFromSet: skip intoString: 0];
  [scanner setCharactersToBeSkipped: skip];
  RELEASE(skip);

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

- (BOOL) setContent: (id)newContent
{
  ASSIGN(content, newContent);
  return YES;
}

- (BOOL) setHeader: (NSString*)aHeader
{
  NSDictionary	*info = [self _parseHeader: aHeader];

  if (info == nil)
    {
      return NO;
    }
  else
    {
      unsigned	count = [headers count];
      NSString	*name = [info objectForKey: @"Name"];

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
      /*
       * Add the new header.
       */
      [headers addObject: info];
      return YES;
    }
}

@end

@implementation	GSMimeDocument (Private)

- (NSDictionary*) _parseHeader: (NSString*)aHeader
{
  NSScanner	*scanner = [NSScanner scannerWithString: aHeader];
  NSString	*name;
  NSString	*value;
  NSMutableDictionary	*info;
  NSCharacterSet	*skip;
  unsigned	count;

  info = [NSMutableDictionary dictionary];

  /*
   * Store the raw header string in the info dictionary.
   */
  [info setObject: [scanner string] forKey: @"RawHeader"];

  /*
   * Store the Raw header name and a lowercase version too.
   */
  if ([scanner scanUpToString: @":" intoString: &name] == NO)
    {
      NSLog(@"No colon terminated name in header (%@)", [scanner string]);
      return nil;
    }
  name = [name stringByTrimmingTailSpaces];
  [info setObject: name forKey: @"BaseName"];
  name = [name lowercaseString];
  [info setObject: name forKey: @"Name"];

  /*
   * Position scanner after colon and any white space.
   */
  if ([scanner scanString: @":" intoString: 0] == NO)
    {
      NSLog(@"No colon terminating name in header (%@)", [scanner string]);
      return nil;
    }
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
  if ([self parseHeader: scanner named: name inTo: info] == NO)
    {
      return nil;
    }

  /*
   * Check validity of broken-out header fields.
   */
  if ([name isEqualToString: @"mime-version"] == YES)
    {
      int	majv = 0;
      int	minv = 0;

      value = [info objectForKey: @"Value"];
      if ([value length] == 0)
	{
	  NSLog(@"Missing value for mime-version header");
	  return nil;
	}
      if (sscanf([value lossyCString], "%d.%d", &majv, &minv) != 2)
	{
	  NSLog(@"Bad value for mime-version header");
	  return nil;
	}
      [self deleteHeaderNamed: name];	// Should be unique
    }
  else if ([name isEqualToString: @"content-transfer-encoding"] == YES)
    {
      BOOL	supported = NO;

      value = [info objectForKey: @"Value"];
      if ([value length] == 0)
	{
	  NSLog(@"Bad value for content-transfer-encoding header");
	  return nil;
	}
      if ([value isEqualToString: @"quoted-printable"] == YES)
	{
	  supported = YES;
	}
      else if ([value isEqualToString: @"base64"] == YES)
	{
	  supported = YES;
	}
      else if ([value isEqualToString: @"binary"] == YES)
	{
	  supported = YES;
	}
      else if ([value characterAtIndex: 0] == '7')
	{
	  supported = YES;
	}
      else if ([value characterAtIndex: 0] == '8')
	{
	  supported = YES;
	}
      if (supported == NO)
	{
	  NSLog(@"Unsupported/unknown content-transfer-encoding");
	  return nil;
	}
      [self deleteHeaderNamed: name];	// Should be unique
    }
  else if ([name isEqualToString: @"content-type"] == YES)
    {
      NSString	*type;
      NSString	*subtype;
      BOOL	supported = NO;

      type = [info objectForKey: @"Type"];
      if ([type length] == 0)
	{
	  NSLog(@"Missing Mime content-type");
	  return nil;
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
	      return nil;
	    }
	}

      [self deleteHeaderNamed: name];	// Should be unique
    }

  /*
   * Ensure that info dictionary is immutable by making a copy
   * of all keys and objects and placing them in a new dictionary.
   */
  count = [info count];
  if (count > 0)
    {
      id	keys[count];
      id	objects[count];
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
  else
    {
      info = [NSDictionary dictionary];
    }

  return info;
}

@end

