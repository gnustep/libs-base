/* Implementation of extension methods to standard classes

   Copyright (C) 2003 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <rfm@gnu.org>

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
#include "config.h"
#include <string.h>
#include "Foundation/Foundation.h"
#include "GNUstepBase/GSCategories.h"
#include "GNUstepBase/GSLock.h"
#include "GSPrivate.h"

/* Test for ASCII whitespace which is safe for unicode characters */
#define	space(C)	((C) > 127 ? NO : isspace(C))

@implementation NSArray (GSCategories)

- (unsigned) insertionPosition: (id)item
		 usingFunction: (NSComparisonResult (*)(id, id, void *))sorter
		       context: (void *)context
{
  unsigned	count = [self count];
  unsigned	upper = count;
  unsigned	lower = 0;
  unsigned	index;
  SEL		oaiSel;
  IMP		oai;

  if (item == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position for nil object in array"];
    }
  if (sorter == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with null comparator"];
    }

  oaiSel = @selector(objectAtIndex:);
  oai = [self methodForSelector: oaiSel];
  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      NSComparisonResult comparison;

      comparison = (*sorter)(item, (*oai)(self, oaiSel, index), context);
      if (comparison == NSOrderedAscending)
        {
          upper = index;
        }
      else if (comparison == NSOrderedDescending)
        {
          lower = index + 1;
        }
      else
        {
          break;
        }
    }
  /*
   *	Now skip past any equal items so the insertion point is AFTER any
   *	items that are equal to the new one.
   */
  while (index < count && (*sorter)(item, (*oai)(self, oaiSel, index), context)
    != NSOrderedAscending)
    {
      index++;
    }
  return index;
}

- (unsigned) insertionPosition: (id)item
		 usingSelector: (SEL)comp
{
  unsigned	count = [self count];
  unsigned	upper = count;
  unsigned	lower = 0;
  unsigned	index;
  NSComparisonResult	(*imp)(id, SEL, id);
  SEL		oaiSel;
  IMP		oai;

  if (item == nil)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position for nil object in array"];
    }
  if (comp == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with null comparator"];
    }
  imp = (NSComparisonResult (*)(id, SEL, id))[item methodForSelector: comp];
  if (imp == 0)
    {
      [NSException raise: NSGenericException
		  format: @"Attempt to find position with unknown method"];
    }

  oaiSel = @selector(objectAtIndex:);
  oai = [self methodForSelector: oaiSel];
  /*
   *	Binary search for an item equal to the one to be inserted.
   */
  for (index = upper/2; upper != lower; index = lower+(upper-lower)/2)
    {
      NSComparisonResult comparison;

      comparison = (*imp)(item, comp, (*oai)(self, oaiSel, index));
      if (comparison == NSOrderedAscending)
        {
          upper = index;
        }
      else if (comparison == NSOrderedDescending)
        {
          lower = index + 1;
        }
      else
        {
          break;
        }
    }
  /*
   *	Now skip past any equal items so the insertion point is AFTER any
   *	items that are equal to the new one.
   */
  while (index < count
    && (*imp)(item, comp, (*oai)(self, oaiSel, index)) != NSOrderedAscending)
    {
      index++;
    }
  return index;
}
@end

@implementation	NSAttributedString (GSCategories)
- (NSAttributedString*) attributedSubstringWithRange: (NSRange)aRange
{
  GSOnceMLog(@"This method is deprecated, use -attributedSubstringFromRange:");
  return [self attributedSubstringFromRange: aRange];
}
@end

/**
 * Extension methods for the NSCalendarDate class
 */
@implementation NSCalendarDate (GSCategories)

/**
 * The ISO standard week of the year is based on the first week of the
 * year being that week (starting on monday) for which the thursday
 * is on or after the first of january.<br />
 * This has the effect that, if january first is a friday, saturday or
 * sunday, the days of that week (up to and including the sunday) are
 * considered to be in week 53 of the preceding year. Similarly if the
 * last day of the year is a monday tuesday or wednesday, these days are
 * part of week 1 of the next year.
 */
- (int) weekOfYear
{
  int	dayOfWeek = [self dayOfWeek];
  int	dayOfYear;

  /*
   * Whether a week is considered to be in a year or not depends on its
   * thursday ... so find thursday for the receivers week.
   * NB. this may result in a date which is not in the same year as the
   * receiver.
   */
  if (dayOfWeek != 4)
    {
      CREATE_AUTORELEASE_POOL(arp);
      NSCalendarDate	*thursday;

      /*
       * A week starts on monday ... so adjust from 0 to 7 so that a
       * sunday is counted as the last day of the week.
       */
      if (dayOfWeek == 0)
	{
	  dayOfWeek = 7;
	}
      thursday = [self dateByAddingYears: 0
				  months: 0
				    days: 4 - dayOfWeek
				   hours: 0
				 minutes: 0
				 seconds: 0];
      dayOfYear = [thursday dayOfYear];
      RELEASE(arp);
    }
  else
    {
      dayOfYear = [self dayOfYear];
    }

  /*
   * Round up to a week boundary, so that when we divide by seven we
   * get a result in the range 1 to 53 as mandated by the ISO standard.
   */
  dayOfYear += (7 - dayOfYear % 7);
  return dayOfYear / 7;
}

@end



/**
 * Extension methods for the NSData class.
 */
@implementation NSData (GSCategories)

/**
 * Returns an NSString object containing an ASCII hexadecimal representation
 * of the receiver.  This means that the returned object will contain
 * exactly twice as many characters as there are bytes as the receiver,
 * as each byte in the receiver is represented by two hexadecimal digits.<br />
 * The high order four bits of each byte is encoded before the low
 * order four bits.  Capital letters 'A' to 'F' are used to represent
 * values from 10 to 15.<br />
 * If you need the hexadecimal representation as raw byte data, use code
 * like -
 * <example>
 *   hexData = [[sourceData hexadecimalRepresentation]
 *     dataUsingEncoding: NSASCIIStringEncoding];
 * </example>
 */
- (NSString*) hexadecimalRepresentation
{
  static const char	*hexChars = "0123456789ABCDEF";
  unsigned		slen = [self length];
  unsigned		dlen = slen * 2;
  const unsigned char	*src = (const unsigned char *)[self bytes];
  char			*dst = (char*)NSZoneMalloc(NSDefaultMallocZone(), dlen);
  unsigned		spos = 0;
  unsigned		dpos = 0;
  NSData		*data;
  NSString		*string;

  while (spos < slen)
    {
      unsigned char	c = src[spos++];

      dst[dpos++] = hexChars[(c >> 4) & 0x0f];
      dst[dpos++] = hexChars[c & 0x0f];
    }
  data = [NSData allocWithZone: NSDefaultMallocZone()];
  data = [data initWithBytesNoCopy: dst length: dlen];
  string = [[NSString alloc] initWithData: data
				 encoding: NSASCIIStringEncoding];
  RELEASE(data);
  return AUTORELEASE(string);
}

/**
 * Initialises the receiver with the supplied string data which contains
 * a hexadecimal coding of the bytes.  The parsing of the string is
 * fairly tolerant, ignoring whitespace and permitting both upper and
 * lower case hexadecimal digits (the -hexadecimalRepresentation method
 * produces a string using only uppercase digits with no white space).<br />
 * If the string does not contain one or more pairs of hexadecimal digits
 * then an exception is raised.
 */
- (id) initWithHexadecimalRepresentation: (NSString*)string
{
  CREATE_AUTORELEASE_POOL(arp);
  NSData	*d;
  const char	*src;
  const char	*end;
  unsigned char	*dst;
  unsigned int	pos = 0;
  unsigned char	byte = 0;
  BOOL		high = NO;

  d = [string dataUsingEncoding: NSASCIIStringEncoding
	   allowLossyConversion: YES];
  src = (const char*)[d bytes];
  end = src + [d length];
  dst = NSZoneMalloc(NSDefaultMallocZone(), [d length]/2 + 1);

  while (src < end)
    {
      char		c = *src++;
      unsigned char	v;

      if (isspace(c))
	{
	  continue;
	}
      if (c >= '0' && c <= '9')
	{
	  v = c - '0';
	}
      else if (c >= 'A' && c <= 'F')
	{
	  v = c - 'A' + 10;
	}
      else if (c >= 'a' && c <= 'f')
	{
	  v = c - 'a' + 10;
	}
      else
	{
	  pos = 0;
	  break;
	}
      if (high == NO)
	{
	  byte = v << 4;
	  high = YES;
	}
      else
	{
	  byte |= v;
	  high = NO;
	  dst[pos++] = byte;
	}
    }
  if (pos > 0 && high == NO)
    {
      self = [self initWithBytes: dst length: pos];
    }
  else
    {
      DESTROY(self);
    }
  NSZoneFree(NSDefaultMallocZone(), dst);
  RELEASE(arp);
  if (self == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"%@: invalid hexadeciaml string data",
	NSStringFromSelector(_cmd)];
    }
  return self;
}

struct MD5Context
{
  uint32_t	buf[4];
  uint32_t	bits[2];
  uint8_t	in[64];
};
static void MD5Init (struct MD5Context *context);
static void MD5Update (struct MD5Context *context, unsigned char const *buf,
unsigned len);
static void MD5Final (unsigned char digest[16], struct MD5Context *context);
static void MD5Transform (uint32_t buf[4], uint32_t const in[16]);

/*
 * This code implements the MD5 message-digest algorithm.
 * The algorithm is due to Ron Rivest.  This code was
 * written by Colin Plumb in 1993, no copyright is claimed.
 * This code is in the public domain; do with it what you wish.
 *
 * Equivalent code is available from RSA Data Security, Inc.
 * This code has been tested against that, and is equivalent,
 * except that you don't need to include two pages of legalese
 * with every copy.
 *
 * To compute the message digest of a chunk of bytes, declare an
 * MD5Context structure, pass it to MD5Init, call MD5Update as
 * needed on buffers full of bytes, and then call MD5Final, which
 * will fill a supplied 16-byte array with the digest.
 */

/*
 * Ensure data is little-endian
 */
static void littleEndian (void *buf, unsigned words)
{
  if (NSHostByteOrder() == NS_BigEndian)
    {
      while (words-- > 0)
        {
          union swap {
            uint32_t    num;
            uint8_t     byt[4];
          } tmp;
          uint8_t       b0;
          uint8_t       b1;

          tmp.num = ((uint32_t*)buf)[words];
          b0 = tmp.byt[0];
          b1 = tmp.byt[1];
          tmp.byt[0] = tmp.byt[3];
          tmp.byt[1] = tmp.byt[2];
          tmp.byt[2] = b1;
          tmp.byt[3] = b0;
          ((uint32_t*)buf)[words] = tmp.num;
        }
    }
}

/*
 * Start MD5 accumulation.  Set bit count to 0 and buffer to mysterious
 * initialization constants.
 */
static void MD5Init (struct MD5Context *ctx)
{
  ctx->buf[0] = 0x67452301;
  ctx->buf[1] = 0xefcdab89;
  ctx->buf[2] = 0x98badcfe;
  ctx->buf[3] = 0x10325476;

  ctx->bits[0] = 0;
  ctx->bits[1] = 0;
}

/*
 * Update context to reflect the concatenation of another buffer full
 * of bytes.
 */
static void MD5Update (struct MD5Context *ctx, unsigned char const *buf,
  unsigned len)
{
  uint32_t t;

  /* Update bitcount */

  t = ctx->bits[0];
  if ((ctx->bits[0] = t + ((uint32_t) len << 3)) < t)
    ctx->bits[1]++;		/* Carry from low to high */
  ctx->bits[1] += len >> 29;

  t = (t >> 3) & 0x3f;	/* Bytes already in shsInfo->data */

  /* Handle any leading odd-sized chunks */

  if (t)
    {
      unsigned char *p = (unsigned char *) ctx->in + t;

      t = 64 - t;
      if (len < t)
	{
	  memcpy (p, buf, len);
	  return;
	}
      memcpy (p, buf, t);
      littleEndian (ctx->in, 16);
      MD5Transform (ctx->buf, (uint32_t *) ctx->in);
      buf += t;
      len -= t;
    }
  /* Process data in 64-byte chunks */

  while (len >= 64)
    {
      memcpy (ctx->in, buf, 64);
      littleEndian (ctx->in, 16);
      MD5Transform (ctx->buf, (uint32_t *) ctx->in);
      buf += 64;
      len -= 64;
    }

  /* Handle any remaining bytes of data. */

  memcpy (ctx->in, buf, len);
}

/*
 * Final wrapup - pad to 64-byte boundary with the bit pattern
 * 1 0* (64-bit count of bits processed, MSB-first)
 */
static void MD5Final (unsigned char digest[16], struct MD5Context *ctx)
{
  unsigned count;
  unsigned char *p;

  /* Compute number of bytes mod 64 */
  count = (ctx->bits[0] >> 3) & 0x3F;

  /* Set the first char of padding to 0x80.  This is safe since there is
     always at least one byte free */
  p = ctx->in + count;
  *p++ = 0x80;

  /* Bytes of padding needed to make 64 bytes */
  count = 64 - 1 - count;

  /* Pad out to 56 mod 64 */
  if (count < 8)
    {
      /* Two lots of padding:  Pad the first block to 64 bytes */
      memset (p, 0, count);
      littleEndian (ctx->in, 16);
      MD5Transform (ctx->buf, (uint32_t *) ctx->in);

      /* Now fill the next block with 56 bytes */
      memset (ctx->in, 0, 56);
    }
  else
    {
      /* Pad block to 56 bytes */
      memset (p, 0, count - 8);
    }
  littleEndian (ctx->in, 14);

  /* Append length in bits and transform */
  ((uint32_t *) ctx->in)[14] = ctx->bits[0];
  ((uint32_t *) ctx->in)[15] = ctx->bits[1];

  MD5Transform (ctx->buf, (uint32_t *) ctx->in);
  littleEndian ((unsigned char *) ctx->buf, 4);
  memcpy (digest, ctx->buf, 16);
  memset (ctx, 0, sizeof (ctx));	/* In case it's sensitive */
}

/* The four core functions - F1 is optimized somewhat */

/* #define F1(x, y, z) (x & y | ~x & z) */
#define F1(x, y, z) (z ^ (x & (y ^ z)))
#define F2(x, y, z) F1(z, x, y)
#define F3(x, y, z) (x ^ y ^ z)
#define F4(x, y, z) (y ^ (x | ~z))

/* This is the central step in the MD5 algorithm. */
#define MD5STEP(f, w, x, y, z, data, s) \
  (w += f(x, y, z) + data,  w = w<<s | w>>(32-s),  w += x)

/*
 * The core of the MD5 algorithm, this alters an existing MD5 hash to
 * reflect the addition of 16 43bit words of new data.  MD5Update blocks
 * the data and converts bytes into 43bit words for this routine.
 */
static void MD5Transform (uint32_t buf[4], uint32_t const in[16])
{
  register uint32_t a, b, c, d;

  a = buf[0];
  b = buf[1];
  c = buf[2];
  d = buf[3];

  MD5STEP (F1, a, b, c, d, in[0] + 0xd76aa478, 7);
  MD5STEP (F1, d, a, b, c, in[1] + 0xe8c7b756, 12);
  MD5STEP (F1, c, d, a, b, in[2] + 0x242070db, 17);
  MD5STEP (F1, b, c, d, a, in[3] + 0xc1bdceee, 22);
  MD5STEP (F1, a, b, c, d, in[4] + 0xf57c0faf, 7);
  MD5STEP (F1, d, a, b, c, in[5] + 0x4787c62a, 12);
  MD5STEP (F1, c, d, a, b, in[6] + 0xa8304613, 17);
  MD5STEP (F1, b, c, d, a, in[7] + 0xfd469501, 22);
  MD5STEP (F1, a, b, c, d, in[8] + 0x698098d8, 7);
  MD5STEP (F1, d, a, b, c, in[9] + 0x8b44f7af, 12);
  MD5STEP (F1, c, d, a, b, in[10] + 0xffff5bb1, 17);
  MD5STEP (F1, b, c, d, a, in[11] + 0x895cd7be, 22);
  MD5STEP (F1, a, b, c, d, in[12] + 0x6b901122, 7);
  MD5STEP (F1, d, a, b, c, in[13] + 0xfd987193, 12);
  MD5STEP (F1, c, d, a, b, in[14] + 0xa679438e, 17);
  MD5STEP (F1, b, c, d, a, in[15] + 0x49b40821, 22);

  MD5STEP (F2, a, b, c, d, in[1] + 0xf61e2562, 5);
  MD5STEP (F2, d, a, b, c, in[6] + 0xc040b340, 9);
  MD5STEP (F2, c, d, a, b, in[11] + 0x265e5a51, 14);
  MD5STEP (F2, b, c, d, a, in[0] + 0xe9b6c7aa, 20);
  MD5STEP (F2, a, b, c, d, in[5] + 0xd62f105d, 5);
  MD5STEP (F2, d, a, b, c, in[10] + 0x02441453, 9);
  MD5STEP (F2, c, d, a, b, in[15] + 0xd8a1e681, 14);
  MD5STEP (F2, b, c, d, a, in[4] + 0xe7d3fbc8, 20);
  MD5STEP (F2, a, b, c, d, in[9] + 0x21e1cde6, 5);
  MD5STEP (F2, d, a, b, c, in[14] + 0xc33707d6, 9);
  MD5STEP (F2, c, d, a, b, in[3] + 0xf4d50d87, 14);
  MD5STEP (F2, b, c, d, a, in[8] + 0x455a14ed, 20);
  MD5STEP (F2, a, b, c, d, in[13] + 0xa9e3e905, 5);
  MD5STEP (F2, d, a, b, c, in[2] + 0xfcefa3f8, 9);
  MD5STEP (F2, c, d, a, b, in[7] + 0x676f02d9, 14);
  MD5STEP (F2, b, c, d, a, in[12] + 0x8d2a4c8a, 20);

  MD5STEP (F3, a, b, c, d, in[5] + 0xfffa3942, 4);
  MD5STEP (F3, d, a, b, c, in[8] + 0x8771f681, 11);
  MD5STEP (F3, c, d, a, b, in[11] + 0x6d9d6122, 16);
  MD5STEP (F3, b, c, d, a, in[14] + 0xfde5380c, 23);
  MD5STEP (F3, a, b, c, d, in[1] + 0xa4beea44, 4);
  MD5STEP (F3, d, a, b, c, in[4] + 0x4bdecfa9, 11);
  MD5STEP (F3, c, d, a, b, in[7] + 0xf6bb4b60, 16);
  MD5STEP (F3, b, c, d, a, in[10] + 0xbebfbc70, 23);
  MD5STEP (F3, a, b, c, d, in[13] + 0x289b7ec6, 4);
  MD5STEP (F3, d, a, b, c, in[0] + 0xeaa127fa, 11);
  MD5STEP (F3, c, d, a, b, in[3] + 0xd4ef3085, 16);
  MD5STEP (F3, b, c, d, a, in[6] + 0x04881d05, 23);
  MD5STEP (F3, a, b, c, d, in[9] + 0xd9d4d039, 4);
  MD5STEP (F3, d, a, b, c, in[12] + 0xe6db99e5, 11);
  MD5STEP (F3, c, d, a, b, in[15] + 0x1fa27cf8, 16);
  MD5STEP (F3, b, c, d, a, in[2] + 0xc4ac5665, 23);

  MD5STEP (F4, a, b, c, d, in[0] + 0xf4292244, 6);
  MD5STEP (F4, d, a, b, c, in[7] + 0x432aff97, 10);
  MD5STEP (F4, c, d, a, b, in[14] + 0xab9423a7, 15);
  MD5STEP (F4, b, c, d, a, in[5] + 0xfc93a039, 21);
  MD5STEP (F4, a, b, c, d, in[12] + 0x655b59c3, 6);
  MD5STEP (F4, d, a, b, c, in[3] + 0x8f0ccc92, 10);
  MD5STEP (F4, c, d, a, b, in[10] + 0xffeff47d, 15);
  MD5STEP (F4, b, c, d, a, in[1] + 0x85845dd1, 21);
  MD5STEP (F4, a, b, c, d, in[8] + 0x6fa87e4f, 6);
  MD5STEP (F4, d, a, b, c, in[15] + 0xfe2ce6e0, 10);
  MD5STEP (F4, c, d, a, b, in[6] + 0xa3014314, 15);
  MD5STEP (F4, b, c, d, a, in[13] + 0x4e0811a1, 21);
  MD5STEP (F4, a, b, c, d, in[4] + 0xf7537e82, 6);
  MD5STEP (F4, d, a, b, c, in[11] + 0xbd3af235, 10);
  MD5STEP (F4, c, d, a, b, in[2] + 0x2ad7d2bb, 15);
  MD5STEP (F4, b, c, d, a, in[9] + 0xeb86d391, 21);

  buf[0] += a;
  buf[1] += b;
  buf[2] += c;
  buf[3] += d;
}

/**
 * Creates an MD5 digest of the information stored in the receiver and
 * returns it as an autoreleased 16 byte NSData object.<br />
 * If you need to produce a digest of string information, you need to
 * decide what character encoding is to be used and convert your string
 * to a data object of that encoding type first using the
 * [NSString-dataUsingEncoding:] method -
 * <example>
 *   myDigest = [[myString dataUsingEncoding: NSUTF8StringEncoding] md5Digest];
 * </example>
 * If you need to use the digest in a human readable form, you will
 * probably want it to be seen as 32 hexadecimal digits, and can do that
 * using the -hexadecimalRepresentation method.
 */
- (NSData*) md5Digest
{
  struct MD5Context	ctx;
  unsigned char		digest[16];

  MD5Init(&ctx);
  MD5Update(&ctx, [self bytes], [self length]);
  MD5Final(digest, &ctx);
  return [NSData dataWithBytes: digest length: 16];
}

/**
 * Decodes the source data from uuencoded and return the result.<br />
 * Returns the encoded file name in namePtr if it is not null.
 * Returns the encoded file mode in modePtr if it is not null.
 */
- (BOOL) uudecodeInto: (NSMutableData*)decoded
		 name: (NSString**)namePtr
		 mode: (int*)modePtr
{
  const unsigned char	*bytes = (const unsigned char*)[self bytes];
  unsigned		length = [self length];
  unsigned		decLength = [decoded length];
  unsigned		pos = 0;
  NSString		*name = nil;

  if (namePtr != 0)
    {
      *namePtr = nil;
    }
  if (modePtr != 0)
    {
      *modePtr = 0;
    }

#define DEC(c)	(((c) - ' ') & 077)

  for (pos = 0; pos < length; pos++)
    {
      if (bytes[pos] == '\n')
	{
	  if (name != nil)
	    {
	      unsigned		i = 0;
	      int		lineLength;
	      unsigned char	*decPtr;

	      lineLength = DEC(bytes[i++]);
	      if (lineLength <= 0)
		{
		  break;	// Got line length zero or less.
		}

	      [decoded setLength: decLength + lineLength];
	      decPtr = [decoded mutableBytes];

	      while (lineLength > 0)
		{
		  unsigned char	tmp[4];
		  int	c;

		  /*
		   * In case the data is corrupt, we need to copy into
		   * a temporary buffer avoiding buffer overrun in the
		   * main buffer.
		   */
		  tmp[0] = bytes[i++];
		  if (i < pos)
		    {
		      tmp[1] = bytes[i++];
		      if (i < pos)
			{
			  tmp[2] = bytes[i++];
			  if (i < pos)
			    {
			      tmp[3] = bytes[i++];
			    }
			  else
			    {
			      tmp[3] = 0;
			    }
			}
		      else
			{
			  tmp[2] = 0;
			  tmp[3] = 0;
			}
		    }
		  else
		    {
		      tmp[1] = 0;
		      tmp[2] = 0;
		      tmp[3] = 0;
		    }
		  if (lineLength >= 1)
		    {
		      c = DEC(tmp[0]) << 2 | DEC(tmp[1]) >> 4;
		      decPtr[decLength++] = (unsigned char)c;
		    }
		  if (lineLength >= 2)
		    {
		      c = DEC(tmp[1]) << 4 | DEC(tmp[2]) >> 2;
		      decPtr[decLength++] = (unsigned char)c;
		    }
		  if (lineLength >= 3)
		    {
		      c = DEC(tmp[2]) << 6 | DEC(tmp[3]);
		      decPtr[decLength++] = (unsigned char)c;
		    }
		  lineLength -= 3;
		}
	    }
	  else if (pos > 6 && strncmp((const char*)bytes, "begin ", 6) == 0)
	    {
	      unsigned	off = 6;
	      unsigned	end = pos;
	      int	mode = 0;
	      NSData	*d;

	      if (end > off && bytes[end-1] == '\r')
		{
		  end--;
		}
	      while (off < end && bytes[off] >= '0' && bytes[off] <= '7')
		{
		  mode *= 8;
		  mode += bytes[off] - '0';
		  off++;
		}
	      if (modePtr != 0)
		{
		  *modePtr = mode;
		}
	      while (off < end && bytes[off] == ' ')
		{
		  off++;
		}
	      d = [NSData dataWithBytes: &bytes[off] length: end - off];
	      name = [[NSString alloc] initWithData: d
					   encoding: NSASCIIStringEncoding];
	      IF_NO_GC(AUTORELEASE(name);)
	      if (namePtr != 0)
		{
		  *namePtr = name;
		}
	    }
	  pos++;
	  bytes += pos;
	  length -= pos;
	}
    }
  if (name == nil)
    {
      return NO;
    }
  return YES;
}

/**
 * Encode the source data to uuencoded.<br />
 * Uses the supplied name as the filename in the encoded data,
 * and says that the file mode is as specified.<br />
 * If no name is supplied, uses <code>untitled</code> as the name.
 */
- (BOOL) uuencodeInto: (NSMutableData*)encoded
		 name: (NSString*)name
		 mode: (int)mode
{
  const unsigned char	*bytes = (const unsigned char*)[self bytes];
  int			length = [self length];
  unsigned char		buf[64];
  unsigned		i;

  name = [name stringByTrimmingSpaces];
  if ([name length] == 0)
    {
      name = @"untitled";
    }
  /*
   * The header is a line of the form 'begin mode filename'
   */
  sprintf((char*)buf, "begin %03o ", mode);
  [encoded appendBytes: buf length: strlen((const char*)buf)];
  [encoded appendData: [name dataUsingEncoding: NSASCIIStringEncoding]];
  [encoded appendBytes: "\n" length: 1];

#define ENC(c) ((c) > 0 ? ((c) & 077) + ' ': '`')

  while (length > 0)
    {
      int	count;
      unsigned	pos;

      /*
       * We want up to 45 bytes in a line ... and we record the
       * number of bytes as the initial output character.
       */
      count = length;
      if (count > 45)
	{
	  count = 45;
	}
      i = 0;
      buf[i++] = ENC(count);

      /*
       * Now we encode the actual data for the line.
       */
      for (pos = 0; count > 0; count -= 3)
	{
	  unsigned char	tmp[3];
	  int		c;

	  /*
	   * Copy data into a temporary buffer ensuring we don't
	   * overrun the end of the original buffer risking access
	   * violation.
	   */
	  tmp[0] = bytes[pos++];
	  if (pos < length)
	    {
	      tmp[1] = bytes[pos++];
	      if (pos < length)
		{
		  tmp[2] = bytes[pos++];
		}
	      else
		{
		  tmp[2] = 0;
		}
	    }
	  else
	    {
	      tmp[1] = 0;
	      tmp[2] = 0;
	    }

	  c = tmp[0] >> 2;
	  buf[i++] = ENC(c);
	  c = ((tmp[0] << 4) & 060) | ((tmp[1] >> 4) & 017);
	  buf[i++] = ENC(c);
	  c = ((tmp[1] << 2) & 074) | ((tmp[2] >> 6) & 03);
	  buf[i++] = ENC(c);
	  c = tmp[2] & 077;
	  buf[i++] = ENC(c);
	}
      bytes += pos;
      length -= pos;
      buf[i++] = '\n';
      [encoded appendBytes: buf length: i];
    }

  /*
   * Encode a line of length zero followed by 'end' as the terminator.
   */
  [encoded appendBytes: "`\nend\n" length: 6];
  return YES;
}
@end



/**
 * GNUstep specific (non-standard) additions to the NSError class.
 * Possibly to be made public
 */
@implementation NSError(GSCategories)


#if !defined(__MINGW32__)
#if !defined(HAVE_STRERROR_R)
#if defined(HAVE_STRERROR)
static int
strerror_r(int eno, char *buf, int len)
{
  const char *ptr;
  int   result;

  [gnustep_global_lock lock];
  ptr = strerror(eno);
  if (ptr == 0)
    {
      strncpy(buf, "unknown error number", len);
      result = -1;
    }
  else
    {
      strncpy(buf, strerror(eno), len);
      result = 0;
    }
  [gnustep_global_lock unlock];
  return result;
}
#else
static int
strerror_r(int eno, char *buf, int len)
{
  extern char  *sys_errlist[];
  extern int    sys_nerr;

  if (eno < 0 || eno >= sys_nerr)
    {
      strncpy(buf, "unknown error number", len);
      return -1;
    }
  strncpy(buf, sys_errlist[eno], len);
  return 0;
}
#endif
#endif
#endif

/*
 * Returns an NSError instance encapsulating the last system error.
 * The user info dictionary of this object will be mutable, so that
 * additional information can be placed in it by higher level code.
 */
+ (NSError*) _last
{
#if defined(__MINGW32__)
  return [self _systemError: GetLastError()];
#else
  extern int	errno;

  return [self _systemError: errno];
#endif
}

+ (NSError*) _systemError: (long)code
{
  NSError	*error;
  NSString	*domain;
  NSDictionary	*info;
#if defined(__MINGW32__)
  LPVOID	lpMsgBuf;
  NSString	*message;

  domain = NSOSStatusErrorDomain;
  FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM,
    NULL, code, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
    (LPWSTR) &lpMsgBuf, 0, NULL );
  message = [NSString stringWithCharacters: lpMsgBuf length: wcslen(lpMsgBuf)];
  LocalFree(lpMsgBuf);
  info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    message, NSLocalizedDescriptionKey,
    nil];
#else
  NSString	*message;
  char          buf[BUFSIZ];

  /* FIXME ... not all are POSIX, should we use NSMachErrorDomain for some? */
  domain = NSPOSIXErrorDomain;
  if (strerror_r(code, buf, BUFSIZ) < 0)
    {
      sprintf(buf, "%ld", code);
    }
  message = [NSString stringWithCString: buf
			       encoding: [NSString defaultCStringEncoding]];
  /* FIXME ... can we do better localisation? */
  info = [NSMutableDictionary dictionaryWithObjectsAndKeys:
    message, NSLocalizedDescriptionKey,
    nil];
#endif

  /* NB we use a mutable dictionary so that calling code can add extra
   * information to the dictionary before passing it up to higher level
   * code.
   */
  error = [self errorWithDomain: domain code: code userInfo: info];
  return error;
}
@end



/**
 * GNUstep specific (non-standard) additions to the NSNumber class.
 */
@implementation NSNumber(GSCategories)

+ (NSValue*) valueFromString: (NSString*)string
{
  /* FIXME: implement this better */
  const char *str;

  str = [string cString];
  if (strchr(str, '.') >= 0 || strchr(str, 'e') >= 0
      || strchr(str, 'E') >= 0)
    return [NSNumber numberWithDouble: atof(str)];
  else if (strchr(str, '-') >= 0)
    return [NSNumber numberWithInt: atoi(str)];
  else
    return [NSNumber numberWithUnsignedInt: atoi(str)];
  return [NSNumber numberWithInt: 0];
}

@end



/**
 * Extension methods for the NSObject class
 */
@implementation NSObject (GSCategories)

- (id) notImplemented: (SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"method %s not implemented in %s(%s)",
    aSel ? GSNameFromSelector(aSel) : "(null)",
    GSClassNameFromObject(self),
    GSObjCIsInstance(self) ? "instance" : "class"];
  return nil;
}

- (id) shouldNotImplement: (SEL)aSel
{
  [NSException
    raise: NSGenericException
    format: @"%s(%s) should not implement %s",
    GSClassNameFromObject(self),
    GSObjCIsInstance(self) ? "instance" : "class",
    aSel ? GSNameFromSelector(aSel) : "(null)"];
  return nil;
}

- (id) subclassResponsibility: (SEL)aSel
{
  [NSException raise: NSInvalidArgumentException
    format: @"subclass %s(%s) should override %s",
	       GSClassNameFromObject(self),
	       GSObjCIsInstance(self) ? "instance" : "class",
	       aSel ? GSNameFromSelector(aSel) : "(null)"];
  return nil;
}

/**
 * WARNING: The -compare: method for NSObject is deprecated
 *          due to subclasses declaring the same selector with
 *          conflicting signatures.
 *          Comparison of arbitrary objects is not just meaningless
 *          but also dangerous as most concrete implementations
 *          expect comparable objects as arguments often accessing
 *          instance variables directly.
 *          This method will be removed in a future release.
 */
- (NSComparisonResult) compare: (id)anObject
{
  NSLog(@"WARNING: The -compare: method for NSObject is deprecated.");

  if (anObject == self)
    {
      return NSOrderedSame;
    }
  if (anObject == nil)
    {
      [NSException raise: NSInvalidArgumentException
		   format: @"nil argument for compare:"];
    }
  if ([self isEqual: anObject])
    {
      return NSOrderedSame;
    }
  /*
   * Ordering objects by their address is pretty useless,
   * so subclasses should override this is some useful way.
   */
  if ((id)self > anObject)
    {
      return NSOrderedDescending;
    }
  else
    {
      return NSOrderedAscending;
    }
}

@end

/**
 * GNUstep specific (non-standard) additions to the NSString class.
 */
@implementation NSString (GSCategories)

/**
 * Returns an autoreleased string initialized with -initWithFormat:arguments:.
 */
+ (id) stringWithFormat: (NSString*)format
	      arguments: (va_list)argList
{
  return AUTORELEASE([[self allocWithZone: NSDefaultMallocZone()]
    initWithFormat: format arguments: argList]);
}

/**
 * Returns a string formed by removing the prefix string from the
 * receiver.  Raises an exception if the prefix is not present.
 */
- (NSString*) stringByDeletingPrefix: (NSString*)prefix
{
  NSCAssert2([self hasPrefix: prefix],
    @"'%@' does not have the prefix '%@'", self, prefix);
  return [self substringFromIndex: [prefix length]];
}

/**
 * Returns a string formed by removing the suffix string from the
 * receiver.  Raises an exception if the suffix is not present.
 */
- (NSString*) stringByDeletingSuffix: (NSString*)suffix
{
  NSCAssert2([self hasSuffix: suffix],
    @"'%@' does not have the suffix '%@'", self, suffix);
  return [self substringToIndex: ([self length] - [suffix length])];
}

/**
 * Returns a string formed by removing leading white space from the
 * receiver.
 */
- (NSString*) stringByTrimmingLeadSpaces
{
  unsigned	length = [self length];

  if (length > 0)
    {
      unsigned	start = 0;
      unichar	(*caiImp)(NSString*, SEL, unsigned int);
      SEL caiSel = @selector(characterAtIndex:);

      caiImp = (unichar (*)())[self methodForSelector: caiSel];
      while (start < length && space((*caiImp)(self, caiSel, start)))
	{
	  start++;
	}
      if (start > 0)
	{
	  return [self substringFromIndex: start];
	}
    }
  return self;
}

/**
 * Returns a string formed by removing trailing white space from the
 * receiver.
 */
- (NSString*) stringByTrimmingTailSpaces
{
  unsigned	length = [self length];

  if (length > 0)
    {
      unsigned	end = length;
      unichar	(*caiImp)(NSString*, SEL, unsigned int);
      SEL caiSel = @selector(characterAtIndex:);

      caiImp = (unichar (*)())[self methodForSelector: caiSel];
      while (end > 0)
	{
	  if (!space((*caiImp)(self, caiSel, end - 1)))
	    {
	      break;
	    }
	  end--;
	}
      if (end < length)
	{
	  return [self substringToIndex: end];
	}
    }
  return self;
}

/**
 * Returns a string formed by removing both leading and trailing
 * white space from the receiver.
 */
- (NSString*) stringByTrimmingSpaces
{
  unsigned	length = [self length];

  if (length > 0)
    {
      unsigned	start = 0;
      unsigned	end = length;
      unichar	(*caiImp)(NSString*, SEL, unsigned int);
      SEL caiSel = @selector(characterAtIndex:);

      caiImp = (unichar (*)())[self methodForSelector: caiSel];
      while (start < length && space((*caiImp)(self, caiSel, start)))
	{
	  start++;
	}
      while (end > start)
	{
	  if (!space((*caiImp)(self, caiSel, end - 1)))
	    {
	      break;
	    }
	  end--;
	}
      if (start > 0 || end < length)
	{
          if (start < end)
	    {
	      return [self substringFromRange:
		NSMakeRange(start, end - start)];
	    }
          else
	    {
	      return [NSString string];
	    }
	}
    }
  return self;
}

/**
 * Returns a string in which any (and all) occurrences of
 * replace in the receiver have been replaced with by.
 * Returns the receiver if replace
 * does not occur within the receiver.  NB. an empty string is
 * not considered to exist within the receiver.
 */
- (NSString*) stringByReplacingString: (NSString*)replace
			   withString: (NSString*)by
{
  NSRange range = [self rangeOfString: replace];

  if (range.length > 0)
    {
      NSMutableString	*tmp = [self mutableCopy];
      NSString		*str;

      [tmp replaceString: replace withString: by];
      str = AUTORELEASE([tmp copy]);
      RELEASE(tmp);
      return str;
    }
  else
    return self;
}

@end

/**
 * GNUstep specific (non-standard) additions to the NSMutableString class.
 */
@implementation NSMutableString (GSCategories)

/**
 * Removes the specified suffix from the string.  Raises an exception
 * if the suffix is not present.
 */
- (void) deleteSuffix: (NSString*)suffix
{
  NSCAssert2([self hasSuffix: suffix],
    @"'%@' does not have the suffix '%@'", self, suffix);
  [self deleteCharactersInRange:
    NSMakeRange([self length] - [suffix length], [suffix length])];
}

/**
 * Removes the specified prefix from the string.  Raises an exception
 * if the prefix is not present.
 */
- (void) deletePrefix: (NSString*)prefix
{
  NSCAssert2([self hasPrefix: prefix],
    @"'%@' does not have the prefix '%@'", self, prefix);
  [self deleteCharactersInRange: NSMakeRange(0, [prefix length])];
}

/**
 * Replaces all occurrences of the string replace with the string by
 * in the receiver.<br />
 * Has no effect if replace does not occur within the
 * receiver.  NB. an empty string is not considered to exist within
 * the receiver.<br />
 * Calls - replaceOccurrencesOfString:withString:options:range: passing
 * zero for the options and a range from 0 with the length of the receiver.
 *
 * Note that is has to work for
 * [tmp replaceString: @"&amp;" withString: @"&amp;amp;"];
 */
- (void) replaceString: (NSString*)replace
	    withString: (NSString*)by
{
  NSRange       range;
  unsigned int  count = 0;
  unsigned int	newEnd;
  NSRange	searchRange;

  if (replace == nil)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"%@ nil search string", NSStringFromSelector(_cmd)];
    }
  if (by == nil)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"%@ nil replace string", NSStringFromSelector(_cmd)];
    }

  searchRange = NSMakeRange(0, [self length]);
  range = [self rangeOfString: replace options: 0 range: searchRange];

  if (range.length > 0)
    {
      unsigned  byLen = [by length];

      do
        {
          count++;
          [self replaceCharactersInRange: range
                              withString: by];

	  newEnd = NSMaxRange(searchRange) + byLen - range.length;
	  searchRange.location = range.location + byLen;
	  searchRange.length = newEnd - searchRange.location;

          range = [self rangeOfString: replace
                              options: 0
                                range: searchRange];
        }
      while (range.length > 0);
    }
}

/**
 * Removes all leading white space from the receiver.
 */
- (void) trimLeadSpaces
{
  unsigned	length = [self length];

  if (length > 0)
    {
      unsigned	start = 0;
      unichar	(*caiImp)(NSString*, SEL, unsigned int);
      SEL caiSel = @selector(characterAtIndex:);

      caiImp = (unichar (*)())[self methodForSelector: caiSel];
      while (start < length && space((*caiImp)(self, caiSel, start)))
	{
	  start++;
	}
      if (start > 0)
	{
	  [self deleteCharactersInRange: NSMakeRange(0, start)];
	}
    }
}

/**
 * Removes all trailing white space from the receiver.
 */
- (void) trimTailSpaces
{
  unsigned	length = [self length];

  if (length > 0)
    {
      unsigned	end = length;
      unichar	(*caiImp)(NSString*, SEL, unsigned int);
      SEL caiSel = @selector(characterAtIndex:);

      caiImp = (unichar (*)())[self methodForSelector: caiSel];
      while (end > 0 && space((*caiImp)(self, caiSel, end - 1)))
	{
	  end--;
	}
      if (end < length)
	{
	  [self deleteCharactersInRange: NSMakeRange(end, length - end)];
	}
    }
}

/**
 * Removes all leading or trailing white space from the receiver.
 */
- (void) trimSpaces
{
  [self trimTailSpaces];
  [self trimLeadSpaces];
}

@end

/**
 * GNUstep specific (non-standard) additions to the NSLock class.
 */

static GSLazyRecursiveLock *local_lock = nil;

/*
   This class only exists to provide
   a thread safe mechanism to initialize local_lock
   as +initialize is called under a lock in ObjC runtimes.
   User code should resort to GS_INITIALIZED_LOCK(),
   which uses the +newLockAt: extension.
*/

@interface _GSLockInitializer : NSObject
@end
@implementation _GSLockInitializer
+ (void) initialize
{
  if (local_lock == nil)
    {
      /* As we do not know whether creating custom locks
	 may implicitly create other locks,
	 we use a recursive lock.  */
      local_lock = [GSLazyRecursiveLock new];
    }
}

@end

GS_STATIC_INLINE id
newLockAt(Class self, SEL _cmd, id *location)
{
  if (location == 0)
    {
      [NSException raise: NSInvalidArgumentException
                   format: @"'%@' called with nil location",
		   NSStringFromSelector(_cmd)];
    }

  if (*location == nil)
    {
      if (local_lock == nil)
	{
	  [_GSLockInitializer class];
	}

      [local_lock lock];

      if (*location == nil)
	{
	  *location = [[self alloc] init];
	}

      [local_lock unlock];
    }

  return *location;
}


@implementation NSLock (GSCategories)
+ (id) newLockAt: (id *)location
{
  return newLockAt(self, _cmd, location);
}
@end

@implementation NSRecursiveLock (GSCategories)
+ (id) newLockAt: (id *)location
{
  return newLockAt(self, _cmd, location);
}
@end

@implementation	NSTask (GSCategories)

static	NSString*
executablePath(NSFileManager *mgr, NSString *path)
{
#if defined(__MINGW32__)
  NSString	*tmp;

  if ([mgr isExecutableFileAtPath: path])
    {
      return path;
    }
  tmp = [path stringByAppendingPathExtension: @"exe"];
  if ([mgr isExecutableFileAtPath: tmp])
    {
      return tmp;
    }
  tmp = [path stringByAppendingPathExtension: @"com"];
  if ([mgr isExecutableFileAtPath: tmp])
    {
      return tmp;
    }
  tmp = [path stringByAppendingPathExtension: @"cmd"];
  if ([mgr isExecutableFileAtPath: tmp])
    {
      return tmp;
    }
#else
  if ([mgr isExecutableFileAtPath: path])
    {
      return path;
    }
#endif
  return nil;
}

+ (NSString*) launchPathForTool: (NSString*)name
{
  NSEnumerator	*enumerator;
  NSDictionary	*env;
  NSString	*pathlist;
  NSString	*path;
  NSFileManager	*mgr;

  mgr = [NSFileManager defaultManager];

#if	defined(GNUSTEP)
  enumerator = [NSSearchPathForDirectoriesInDomains(
    GSToolsDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((path = [enumerator nextObject]) != nil)
    {
      path = [path stringByAppendingPathComponent: name];
      if ((path = executablePath(mgr, path)) != nil)
	{
	  return path;
	}
    }
  enumerator = [NSSearchPathForDirectoriesInDomains(
    GSAdminToolsDirectory, NSAllDomainsMask, YES) objectEnumerator];
  while ((path = [enumerator nextObject]) != nil)
    {
      path = [path stringByAppendingPathComponent: name];
      if ((path = executablePath(mgr, path)) != nil)
	{
	  return path;
	}
    }
#endif

  env = [[NSProcessInfo processInfo] environment];
  pathlist = [env objectForKey:@"PATH"];
#if defined(__MINGW32__)
/* Windows 2000 and perhaps others have "Path" not "PATH" */
  if (pathlist == nil)
    {
      pathlist = [env objectForKey: @"Path"];
    }
  enumerator = [[pathlist componentsSeparatedByString: @";"] objectEnumerator];
#else
  enumerator = [[pathlist componentsSeparatedByString: @":"] objectEnumerator];
#endif
  while ((path = [enumerator nextObject]) != nil)
    {
      path = [path stringByAppendingPathComponent: name];
      if ((path = executablePath(mgr, path)) != nil)
	{
	  return path;
	}
    }
  return nil;
}
@end

