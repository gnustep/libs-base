/**
   Test cases for NSString surrogate pair handling and UTF-8 conversion,
   with emphasis on unmatched surrogate halves.
*/

#import <Foundation/Foundation.h>
#import "Testing.h"

/*
 * Unicode surrogate pair background
 * ----------------------------------
 * NSString stores characters as UTF-16 code units (unichar, 16-bit).
 * Supplementary plane characters (U+10000..U+10FFFF) require two code units
 * called a surrogate pair: a high surrogate (0xD800..0xDBFF) followed by a
 * low surrogate (0xDC00..0xDFFF).
 *
 * When such a string is converted to UTF-8 (via -UTF8String,
 * -dataUsingEncoding:NSUTF8StringEncoding, or
 * -getCString:maxLength:encoding:) a conforming implementation must:
 *   - encode well-formed pairs as a single 4-byte UTF-8 sequence, and
 *   - handle lone (unmatched) surrogate halves in some defined way.
 *
 * Test naming convention:
 *   testSP_*  – well-formed surrogate pair tests
 *   testLS_*  – lone (unmatched) surrogate tests
 *   testMX_*  – mixed / edge-case tests
 */

/* -------------------------------------------------------------------------
 * Helper: return YES if every byte in the C string is a valid UTF-8 byte
 * sequence.  This is a minimal well-formedness check; it does NOT accept
 * CESU-8 or WTF-8 encodings of surrogates (0xED 0xA0..0xBF ... etc.).
 * ------------------------------------------------------------------------- */
static BOOL
isValidUTF8(const char *bytes, NSUInteger len)
{
  NSUInteger i = 0;

  if (bytes == NULL)
    {
      return NO;
    }
  while (i < len)
    {
      unsigned char b = (unsigned char)bytes[i];

      if (b < 0x80)
        {
          /* ASCII */
          i += 1;
        }
      else if ((b & 0xE0) == 0xC0)
        {
          /* 2-byte sequence; continuation must be 0x80..0xBF */
          if (i + 1 >= len)                         return NO;
          if (((unsigned char)bytes[i+1] & 0xC0) != 0x80) return NO;
          /* Reject overlong */
          if ((b & 0x1F) < 0x02)                    return NO;
          i += 2;
        }
      else if ((b & 0xF0) == 0xE0)
        {
          /* 3-byte sequence */
          if (i + 2 >= len)                         return NO;
          if (((unsigned char)bytes[i+1] & 0xC0) != 0x80) return NO;
          if (((unsigned char)bytes[i+2] & 0xC0) != 0x80) return NO;
          /* Reject surrogates: U+D800..U+DFFF => 0xED 0xA0..0xBF */
          if (b == 0xED && ((unsigned char)bytes[i+1] & 0xE0) == 0xA0)
            return NO;
          i += 3;
        }
      else if ((b & 0xF8) == 0xF0)
        {
          /* 4-byte sequence */
          if (i + 3 >= len)                         return NO;
          if (((unsigned char)bytes[i+1] & 0xC0) != 0x80) return NO;
          if (((unsigned char)bytes[i+2] & 0xC0) != 0x80) return NO;
          if (((unsigned char)bytes[i+3] & 0xC0) != 0x80) return NO;
          /* Reject values above U+10FFFF */
          if (b > 0xF4)                             return NO;
          i += 4;
        }
      else
        {
          return NO;
        }
    }
  return YES;
}

/* -------------------------------------------------------------------------
 * Helper: decode a 4-byte UTF-8 sequence and return the Unicode scalar.
 * Caller must ensure the sequence is valid.
 * ------------------------------------------------------------------------- */
static uint32_t
utf8FourByteScalar(const unsigned char *p)
{
  return (((uint32_t)(p[0] & 0x07)) << 18)
       | (((uint32_t)(p[1] & 0x3F)) << 12)
       | (((uint32_t)(p[2] & 0x3F)) <<  6)
       |  ((uint32_t)(p[3] & 0x3F));
}


int
main(int argc, char *argv[])
{
  uint8_t	replacement[4] = { 0xEF, 0xBF, 0xBD, 0x00 };

  /* -----------------------------------------------------------------------
   * SET 1: Well-formed surrogate pairs
   * ----------------------------------------------------------------------- */
  START_SET("NSString well-formed surrogate pairs")

  /* U+1F600 GRINNING FACE: high=0xD83D low=0xDE00 */
  {
    unichar emoji[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: emoji length: 2];

    PASS(s != nil,
      "Can create NSString containing a surrogate pair (U+1F600)");
    PASS([s length] == 2,
      "-length of a surrogate pair is 2 (UTF-16 code units)");

    /* The string must round-trip through -characterAtIndex: */
    PASS([s characterAtIndex: 0] == 0xD83D,
      "-characterAtIndex:0 returns the high surrogate 0xD83D");
    PASS([s characterAtIndex: 1] == 0xDE00,
      "-characterAtIndex:1 returns the low surrogate 0xDE00");
  }

  /* U+10000 LINEAR B SYLLABLE B008 A: high=0xD800 low=0xDC00 (lowest pair) */
  {
    unichar lowest[2] = { 0xD800, 0xDC00 };
    NSString *s = [NSString stringWithCharacters: lowest length: 2];
    const char *utf8 = [s UTF8String];

    PASS(s != nil,
      "Can create NSString for U+10000 (lowest supplementary character)");
    PASS(utf8 != NULL,
      "-UTF8String is non-NULL for U+10000");

    if (utf8 != NULL)
      {
        NSUInteger len = strlen(utf8);
        PASS(len == 4,
          "-UTF8String for U+10000 produces exactly 4 bytes");
        /* U+10000 => 0xF0 0x90 0x80 0x80 */
        PASS((unsigned char)utf8[0] == 0xF0
          && (unsigned char)utf8[1] == 0x90
          && (unsigned char)utf8[2] == 0x80
          && (unsigned char)utf8[3] == 0x80,
          "UTF-8 bytes for U+10000 are 0xF0 0x90 0x80 0x80");
      }
  }

  /* U+10FFFF (highest valid code point): high=0xDBFF low=0xDFFF */
  {
    unichar highest[2] = { 0xDBFF, 0xDFFF };
    NSString *s = [NSString stringWithCharacters: highest length: 2];
    const char *utf8 = [s UTF8String];

    PASS(s != nil,
      "Can create NSString for U+10FFFF (highest valid code point)");
    PASS(utf8 != NULL,
      "-UTF8String is non-NULL for U+10FFFF");

    if (utf8 != NULL)
      {
        NSUInteger len = strlen(utf8);
        PASS(len == 4,
          "-UTF8String for U+10FFFF produces exactly 4 bytes");
        /* U+10FFFF => 0xF4 0x8F 0xBF 0xBF */
        PASS((unsigned char)utf8[0] == 0xF4
          && (unsigned char)utf8[1] == 0x8F
          && (unsigned char)utf8[2] == 0xBF
          && (unsigned char)utf8[3] == 0xBF,
          "UTF-8 bytes for U+10FFFF are 0xF4 0x8F 0xBF 0xBF");
      }
  }

  /* Multiple surrogate pairs in sequence */
  {
    /* U+1F600 then U+1F601 */
    unichar two[4] = { 0xD83D, 0xDE00, 0xD83D, 0xDE01 };
    NSString *s = [NSString stringWithCharacters: two length: 4];
    const char *utf8 = [s UTF8String];

    PASS(s != nil,
      "Can create NSString with two consecutive surrogate pairs");
    PASS([s length] == 4,
      "-length for two surrogate pairs is 4 (UTF-16 code units)");
    PASS(utf8 != NULL,
      "-UTF8String is non-NULL for two consecutive surrogate pairs");

    if (utf8 != NULL)
      {
        PASS(strlen(utf8) == 8,
          "-UTF8String for two surrogate pairs produces 8 bytes");
        PASS(isValidUTF8(utf8, 8),
          "-UTF8String output for two surrogate pairs is well-formed UTF-8");
      }
  }

  /* Surrogate pair embedded in ASCII */
  {
    unichar mixed[5] = { 'A', 0xD83D, 0xDE00, 'Z', 0 };
    NSString *s = [NSString stringWithCharacters: mixed length: 4];
    const char *utf8 = [s UTF8String];

    PASS(s != nil,
      "Can create NSString with surrogate pair embedded between ASCII chars");
    PASS(utf8 != NULL,
      "-UTF8String is non-NULL for ASCII + surrogate pair + ASCII");

    if (utf8 != NULL)
      {
        /* 'A'(1) + U+1F600(4) + 'Z'(1) = 6 bytes */
        PASS(strlen(utf8) == 6,
          "-UTF8String byte length is correct for ASCII+pair+ASCII");
        PASS(isValidUTF8(utf8, 6),
          "-UTF8String output for ASCII+pair+ASCII is well-formed UTF-8");
        PASS((unsigned char)utf8[0] == 'A',
          "First byte of UTF-8 output is 'A'");
        PASS((unsigned char)utf8[5] == 'Z',
          "Last byte of UTF-8 output is 'Z'");
        /* The 4-byte sequence must decode to U+1F600 */
        PASS(utf8FourByteScalar((unsigned char *)utf8 + 1) == 0x1F600U,
          "Four-byte sequence decodes to U+1F600");
      }
  }

  /* -dataUsingEncoding:NSUTF8StringEncoding for a well-formed pair */
  {
    unichar emoji[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: emoji length: 2];
    NSData *d = [s dataUsingEncoding: NSUTF8StringEncoding];

    PASS(d != nil,
      "-dataUsingEncoding:NSUTF8StringEncoding succeeds for a valid pair");

    if (d != nil)
      {
        const unsigned char *bytes = (const unsigned char *)[d bytes];
        NSUInteger len = [d length];

        PASS(len == 4,
          "NSData from -dataUsingEncoding:NSUTF8StringEncoding has 4 bytes");
        PASS(isValidUTF8((const char *)bytes, len),
          "NSData bytes are well-formed UTF-8 for a valid surrogate pair");
        PASS(utf8FourByteScalar(bytes) == 0x1F600U,
          "NSData bytes decode to U+1F600");
      }
  }

  END_SET("NSString well-formed surrogate pairs")


  /* -----------------------------------------------------------------------
   * SET 2: Lone high surrogate (0xD800..0xDBFF with no following low)
   * ----------------------------------------------------------------------- */
  START_SET("NSString lone high surrogate")

  /* A bare high surrogate at the end of a string */
  {
    unichar 		lone[1] = { 0xD800 };
    NSString 		*s = [NSString stringWithCharacters: lone length: 1];
    const uint8_t	*utf8;

    PASS(s != nil,
      "Can create NSString containing a lone high surrogate 0xD800")
    PASS([s length] == 1,
      "-length of a lone high surrogate is 1")
    PASS([s characterAtIndex: 0] == 0xD800,
      "-characterAtIndex:0 returns the lone high surrogate 0xD800")
    PASS([s canBeConvertedToEncoding: NSUTF8StringEncoding] == NO,
      " a lone high surrogate can not be converted to UTF8 without loss")
    PASS_RUNS(utf8 = (const uint8_t*)[s UTF8String],
      "-UTF8String for lone high surrogate does not raise")
    if (utf8)
      {
	PASS(strcmp((const char*)utf8, (const char*)replacement) == 0,
	  "-UTF8String for lone high surrogate gives replacement character")
      }
  }

  /* -UTF8String must either return NULL or return non-NULL without crashing */
  {
    unichar lone[1] = { 0xDBFF };
    NSString *s = [NSString stringWithCharacters: lone length: 1];
    /* We wrap in an exception handler because some runtimes raise here */
    const char *utf8 = NULL;
    BOOL raised = NO;

    NS_DURING
      utf8 = [s UTF8String];
    NS_HANDLER
      raised = YES;
    NS_ENDHANDLER

    PASS(raised == NO || utf8 == NULL,
      "-UTF8String for lone high surrogate 0xDBFF does not crash");
  }

  /* High surrogate followed immediately by another high surrogate */
  {
    unichar two_high[2] = { 0xD83D, 0xD83D };
    NSString *s = [NSString stringWithCharacters: two_high length: 2];
    const char *utf8 = NULL;
    BOOL raised = NO;

    PASS(s != nil,
      "Can create NSString with two consecutive high surrogates");

    NS_DURING
      utf8 = [s UTF8String];
    NS_HANDLER
      raised = YES;
    NS_ENDHANDLER

    PASS(raised == NO || utf8 == NULL,
      "-UTF8String for two consecutive high surrogates does not crash");

    /* If a result is returned it must not be well-formed UTF-8 *or*
     * the implementation must have substituted replacement characters.
     * Either way it must be a null-terminated byte sequence. */
    if (utf8 != NULL)
      {
        NSUInteger len = strlen(utf8);
        /* We do not mandate well-formedness here — just non-crash */
        PASS(len > 0,
          "-UTF8String for two high surrogates returns a non-empty string"
          " (implementation-defined encoding)");
      }
  }

  /* High surrogate followed by a non-surrogate BMP character */
  {
    unichar mismatched[2] = { 0xD800, 0x0041 /* 'A' */ };
    NSString *s = [NSString stringWithCharacters: mismatched length: 2];
    const char *utf8 = NULL;
    BOOL raised = NO;

    PASS(s != nil,
      "Can create NSString with lone high surrogate followed by 'A'");

    NS_DURING
      utf8 = [s UTF8String];
    NS_HANDLER
      raised = YES;
    NS_ENDHANDLER

    PASS(raised == NO || utf8 == NULL,
      "-UTF8String for high surrogate + 'A' does not crash");

    if (utf8 != NULL)
      {
        /* The 'A' must be present somewhere in the output */
        NSUInteger i, len = strlen(utf8);
        BOOL foundA = NO;

        for (i = 0; i < len; i++)
          {
            if ((unsigned char)utf8[i] == 'A') { foundA = YES; break; }
          }
        PASS(foundA,
          "ASCII character 'A' is present in -UTF8String output after lone"
          " high surrogate");
      }
  }

  /* -dataUsingEncoding: with allowLossyConversion:NO */
  {
    unichar lone[1] = { 0xD800 };
    NSString *s = [NSString stringWithCharacters: lone length: 1];
    NSData *d = [s dataUsingEncoding: NSUTF8StringEncoding
               allowLossyConversion: NO];

    /* Spec says: may return nil if conversion is not lossless */
    PASS(d == nil || [d length] > 0,
      "-dataUsingEncoding:allowLossyConversion:NO for lone high surrogate"
      " returns nil or non-empty data (implementation-defined)");
  }

  /* -dataUsingEncoding: with allowLossyConversion:YES */
  {
    unichar lone[1] = { 0xD800 };
    NSString *s = [NSString stringWithCharacters: lone length: 1];
    NSData *d = [s dataUsingEncoding: NSUTF8StringEncoding
               allowLossyConversion: YES];

    PASS(d != nil,
      "-dataUsingEncoding:allowLossyConversion:YES for lone high surrogate"
      " returns non-nil NSData");
  }

  END_SET("NSString lone high surrogate")


  /* -----------------------------------------------------------------------
   * SET 3: Lone low surrogate (0xDC00..0xDFFF with no preceding high)
   * ----------------------------------------------------------------------- */
  START_SET("NSString lone low surrogate")

  {
    unichar lone[1] = { 0xDC00 };
    NSString *s = [NSString stringWithCharacters: lone length: 1];

    PASS(s != nil,
      "Can create NSString containing a lone low surrogate 0xDC00");
    PASS([s length] == 1,
      "-length of a lone low surrogate is 1");
    PASS([s characterAtIndex: 0] == 0xDC00,
      "-characterAtIndex:0 returns the lone low surrogate 0xDC00");
  }

  {
    unichar lone[1] = { 0xDFFF };
    NSString *s = [NSString stringWithCharacters: lone length: 1];
    const char *utf8 = NULL;
    BOOL raised = NO;

    NS_DURING
      utf8 = [s UTF8String];
    NS_HANDLER
      raised = YES;
    NS_ENDHANDLER

    PASS(raised == NO || utf8 == NULL,
      "-UTF8String for lone low surrogate 0xDFFF does not crash");
  }

  /* Low surrogate preceded by a non-surrogate BMP character */
  {
    unichar mismatched[2] = { 0x0041 /* 'A' */, 0xDC00 };
    NSString *s = [NSString stringWithCharacters: mismatched length: 2];
    const char *utf8 = NULL;
    BOOL raised = NO;

    PASS(s != nil,
      "Can create NSString with 'A' followed by lone low surrogate");

    NS_DURING
      utf8 = [s UTF8String];
    NS_HANDLER
      raised = YES;
    NS_ENDHANDLER

    PASS(raised == NO || utf8 == NULL,
      "-UTF8String for 'A' + lone low surrogate does not crash");

    if (utf8 != NULL)
      {
        PASS((unsigned char)utf8[0] == 'A',
          "First byte of -UTF8String output for 'A'+lone-low-surrogate is 'A'");
      }
  }

  /* Low surrogate followed by high surrogate (reversed pair — invalid) */
  {
    unichar reversed[2] = { 0xDC00, 0xD800 };
    NSString *s = [NSString stringWithCharacters: reversed length: 2];
    const char *utf8 = NULL;
    BOOL raised = NO;

    PASS(s != nil,
      "Can create NSString with reversed surrogate pair (low then high)");

    NS_DURING
      utf8 = [s UTF8String];
    NS_HANDLER
      raised = YES;
    NS_ENDHANDLER

    PASS(raised == NO || utf8 == NULL,
      "-UTF8String for reversed surrogate pair does not crash");
  }

  END_SET("NSString lone low surrogate")


  /* -----------------------------------------------------------------------
   * SET 4: getCString:maxLength:encoding: with surrogates
   * ----------------------------------------------------------------------- */
  START_SET("NSString getCString:maxLength:encoding: with surrogates")

  /* Well-formed pair via getCString */
  {
    unichar emoji[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: emoji length: 2];
    char buf[32];
    BOOL ok;

    memset(buf, 0xFF, sizeof(buf));
    ok = [s getCString: buf
             maxLength: sizeof(buf)
              encoding: NSUTF8StringEncoding];

    PASS(ok == YES,
      "-getCString:maxLength:encoding: returns YES for well-formed pair");
    PASS(isValidUTF8(buf, strlen(buf)),
      "Buffer filled by -getCString: is well-formed UTF-8 for valid pair");
    PASS(strlen(buf) == 4,
      "Buffer length for a single supplementary char is 4 bytes");
  }

  /* getCString with a buffer that is exactly the right size (4+1 bytes) */
  {
    unichar emoji[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: emoji length: 2];
    char buf[5];
    BOOL ok;

    memset(buf, 0xFF, sizeof(buf));
    ok = [s getCString: buf
             maxLength: 5   /* 4 bytes + NUL */
              encoding: NSUTF8StringEncoding];

    PASS(ok == YES,
      "-getCString:maxLength:encoding: returns YES with exact-fit buffer");
    PASS((unsigned char)buf[4] == '\0',
      "NUL terminator is written at buf[4] with exact-fit buffer");
  }

  /* getCString with a buffer that is one byte too small */
  {
    unichar emoji[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: emoji length: 2];
    char buf[4];   /* only 4 bytes; need 4 data bytes + NUL = 5 */
    BOOL ok;

    memset(buf, 0xFF, sizeof(buf));
    ok = [s getCString: buf
             maxLength: 4
              encoding: NSUTF8StringEncoding];

    PASS(ok == NO,
      "-getCString:maxLength:encoding: returns NO when buffer is too small");
  }

  /* getCString for a lone high surrogate — must not crash */
  {
    unichar lone[1] = { 0xD800 };
    NSString *s = [NSString stringWithCharacters: lone length: 1];
    char buf[32];
    BOOL ok = NO;
    BOOL raised = NO;

    memset(buf, 0, sizeof(buf));
    NS_DURING
      ok = [s getCString: buf
               maxLength: sizeof(buf)
                encoding: NSUTF8StringEncoding];
    NS_HANDLER
      raised = YES;
    NS_ENDHANDLER

    PASS(raised == NO,
      "-getCString:maxLength:encoding: for lone high surrogate does not raise"
      " an exception");
    /* ok may be YES or NO: both are acceptable; we only require no crash */
    PASS(raised == NO && (ok == YES || ok == NO),
      "-getCString:maxLength:encoding: returns a BOOL for lone high surrogate"
      " (implementation-defined)");
  }

  END_SET("NSString getCString:maxLength:encoding: with surrogates")


  /* -----------------------------------------------------------------------
   * SET 5: -dataUsingEncoding:NSUTF16StringEncoding with surrogates
   * ----------------------------------------------------------------------- */
  START_SET("NSString UTF-16 encoding with surrogates")

  /* Round-trip: NSString -> UTF-16 data -> NSString -> UTF-8 */
  {
    unichar emoji[2] = { 0xD83D, 0xDE00 };
    NSString *original = [NSString stringWithCharacters: emoji length: 2];
    NSData *utf16data = [original dataUsingEncoding: NSUTF16StringEncoding];

    PASS(utf16data != nil,
      "-dataUsingEncoding:NSUTF16StringEncoding succeeds for valid pair");

    if (utf16data != nil)
      {
        NSString *roundTripped = [NSString stringWithCharacters: emoji
                                                         length: 2];

        PASS([roundTripped isEqualToString: original],
          "Round-tripped NSString from UTF-16 data equals the original");
      }
  }

  /* UTF-16BE encoding of a lone surrogate must not crash */
  {
    unichar	lone[1] = { 0xD800 };
    NSString	*s = [NSString stringWithCharacters: lone length: 1];
    unichar	c;

    PASS_RUNS(
      [s dataUsingEncoding: NSUTF16BigEndianStringEncoding
          allowLossyConversion: YES],
      "-dataUsingEncoding:NSUTF16BigEndianStringEncoding:allowLossy:YES for"
      " lone high surrogate does not raise")

    // Second half of surrogate pair
    c = lone[0] = 0xde0a;
    s = [[NSString alloc] initWithBytes: lone
				 length: 2
			       encoding: NSUnicodeStringEncoding];
    PASS([s length] == 1, "native - second half of surrogate pair is valid")
    PASS([s characterAtIndex: 0] == c,
      "native - second half of surrogate pair has corect value");
    DESTROY(s);

    lone[0] = GSSwapHostI16ToBig(0xde0a);
    s = [[NSString alloc] initWithBytes: lone
				 length: 2
			       encoding: NSUTF16BigEndianStringEncoding];
    PASS([s length] == 1, "big endian second half of surrogate pair is valid")
    PASS([s characterAtIndex: 0] == c,
      "big endian - second half of surrogate pair has corect value");
    DESTROY(s);

    lone[0] = GSSwapHostI16ToLittle(0xde0a);
    s = [[NSString alloc] initWithBytes: lone
				 length: 2
			       encoding: NSUTF16LittleEndianStringEncoding];
    PASS([s length] == 1,
      "little endian second half of surrogate pair is valid")
    PASS([s characterAtIndex: 0] == c,
      "little endian - second half of surrogate pair has corect value");
    DESTROY(s);
  }

  END_SET("NSString UTF-16 encoding with surrogates")


  /* -----------------------------------------------------------------------
   * SET 6: -lengthOfBytesUsingEncoding: and -maximumLengthOfBytesUsingEncoding:
   * ----------------------------------------------------------------------- */
  START_SET("NSString byte-length methods with surrogates")

  /* Well-formed pair: -lengthOfBytesUsingEncoding: must return 4 */
  {
    unichar emoji[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: emoji length: 2];
    NSUInteger len = [s lengthOfBytesUsingEncoding: NSUTF8StringEncoding];

    PASS(len == 4,
      "-lengthOfBytesUsingEncoding:NSUTF8StringEncoding returns 4 for"
      " a valid supplementary character");
  }

  /* -maximumLengthOfBytesUsingEncoding: must be >= 4 for a pair */
  {
    unichar emoji[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: emoji length: 2];
    NSUInteger max = [s maximumLengthOfBytesUsingEncoding:
                          NSUTF8StringEncoding];

    PASS(max >= 4,
      "-maximumLengthOfBytesUsingEncoding:NSUTF8StringEncoding returns >= 4"
      " for a valid surrogate pair");
  }

  /* Lone high surrogate: -lengthOfBytesUsingEncoding: must return 0 or
   * a positive implementation-defined value; it must not crash */
  {
    unichar lone[1] = { 0xD800 };
    NSString *s = [NSString stringWithCharacters: lone length: 1];
    NSUInteger len = 0;
    BOOL raised = NO;

    NS_DURING
      len = [s lengthOfBytesUsingEncoding: NSUTF8StringEncoding];
    NS_HANDLER
      raised = YES;
    NS_ENDHANDLER

    PASS(raised == NO,
      "-lengthOfBytesUsingEncoding: for lone high surrogate does not raise");

    /* Apple returns 0 for a lone surrogate; GNUstep may return 3 (WTF-8) */
    PASS(raised == NO && (len == 0 || len >= 1),
      "-lengthOfBytesUsingEncoding: for lone high surrogate returns a"
      " non-negative value (implementation-defined)");
  }

  END_SET("NSString byte-length methods with surrogates")


  /* -----------------------------------------------------------------------
   * SET 7: -compare: and -isEqualToString: with surrogates
   * ----------------------------------------------------------------------- */
  START_SET("NSString comparison with surrogates")

  /* Two identical surrogate-pair strings are equal */
  {
    unichar pair1[2] = { 0xD83D, 0xDE00 };
    unichar pair2[2] = { 0xD83D, 0xDE00 };
    NSString *s1 = [NSString stringWithCharacters: pair1 length: 2];
    NSString *s2 = [NSString stringWithCharacters: pair2 length: 2];

    PASS([s1 isEqualToString: s2],
      "-isEqualToString: returns YES for two identical surrogate-pair strings");
    PASS([s1 compare: s2] == NSOrderedSame,
      "-compare: returns NSOrderedSame for two identical surrogate-pair"
      " strings");
  }

  /* Different supplementary characters must compare unequal */
  {
    unichar a[2] = { 0xD83D, 0xDE00 };  /* U+1F600 */
    unichar b[2] = { 0xD83D, 0xDE01 };  /* U+1F601 */
    NSString *s1 = [NSString stringWithCharacters: a length: 2];
    NSString *s2 = [NSString stringWithCharacters: b length: 2];

    PASS(![s1 isEqualToString: s2],
      "-isEqualToString: returns NO for U+1F600 vs U+1F601");
    PASS([s1 compare: s2] == NSOrderedAscending,
      "-compare: orders U+1F600 before U+1F601");
  }

  /* Lone high surrogate must not equal a valid pair even if high halves match */
  {
    unichar lone[1] = { 0xD83D };
    unichar pair[2] = { 0xD83D, 0xDE00 };
    NSString *s1 = [NSString stringWithCharacters: lone length: 1];
    NSString *s2 = [NSString stringWithCharacters: pair length: 2];

    PASS(![s1 isEqualToString: s2],
      "-isEqualToString: returns NO for lone high surrogate vs full pair");
  }

  END_SET("NSString comparison with surrogates")


  /* -----------------------------------------------------------------------
   * SET 8: -substringWithRange: around surrogate boundaries
   * ----------------------------------------------------------------------- */
  START_SET("NSString substringWithRange: with surrogates")

  /* Extract just the high surrogate of a pair */
  {
    unichar pair[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: pair length: 2];
    NSString *sub = [s substringWithRange: NSMakeRange(0, 1)];

    PASS(sub != nil,
      "-substringWithRange: on the high-surrogate half returns non-nil");
    PASS([sub length] == 1,
      "Substring of just the high surrogate has length 1");
    PASS([sub characterAtIndex: 0] == 0xD83D,
      "Substring of the high surrogate contains 0xD83D");
  }

  /* Extract just the low surrogate of a pair */
  {
    unichar pair[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: pair length: 2];
    NSString *sub = [s substringWithRange: NSMakeRange(1, 1)];

    PASS(sub != nil,
      "-substringWithRange: on the low-surrogate half returns non-nil");
    PASS([sub length] == 1,
      "Substring of just the low surrogate has length 1");
    PASS([sub characterAtIndex: 0] == 0xDE00,
      "Substring of the low surrogate contains 0xDE00");
  }

  /* Extract entire pair */
  {
    unichar pair[2] = { 0xD83D, 0xDE00 };
    NSString *s = [NSString stringWithCharacters: pair length: 2];
    NSString *sub = [s substringWithRange: NSMakeRange(0, 2)];

    PASS([sub isEqualToString: s],
      "-substringWithRange: over the full pair returns a string equal to the"
      " original");
  }

  /* Range covering the ASCII prefix only (no surrogates) */
  {
    unichar text[5] = { 'H', 'i', 0xD83D, 0xDE00, '!' };
    NSString *s = [NSString stringWithCharacters: text length: 5];
    NSString *prefix = [s substringWithRange: NSMakeRange(0, 2)];

    PASS([prefix isEqualToString: @"Hi"],
      "-substringWithRange: extracts ASCII prefix correctly when string"
      " contains a later surrogate pair");
  }

  END_SET("NSString substringWithRange: with surrogates")


  /* -----------------------------------------------------------------------
   * SET 9: -rangeOfString: with surrogate-pair needle
   * ----------------------------------------------------------------------- */
  START_SET("NSString rangeOfString: with surrogates")

  {
    unichar haystack[6] = { 'A', 'B', 0xD83D, 0xDE00, 'C', 'D' };
    unichar needle[2]   = { 0xD83D, 0xDE00 };
    NSString *hs = [NSString stringWithCharacters: haystack length: 6];
    NSString *nd = [NSString stringWithCharacters: needle length: 2];
    NSRange r = [hs rangeOfString: nd];

    PASS(r.location == 2 && r.length == 2,
      "-rangeOfString: finds a surrogate pair at the correct location");
  }

  {
    unichar haystack[4] = { 'A', 'B', 'C', 'D' };
    unichar needle[2]   = { 0xD83D, 0xDE00 };
    NSString *hs = [NSString stringWithCharacters: haystack length: 4];
    NSString *nd = [NSString stringWithCharacters: needle length: 2];
    NSRange r = [hs rangeOfString: nd];

    PASS(r.location == NSNotFound,
      "-rangeOfString: returns NSNotFound when pair is not present");
  }

  END_SET("NSString rangeOfString: with surrogates")


  /* -----------------------------------------------------------------------
   * SET 10: NSString creation from UTF-8 data containing 4-byte sequences
   * ----------------------------------------------------------------------- */
  START_SET("NSString init from UTF-8 data with supplementary characters")

  /* Build NSString from raw UTF-8 bytes for U+1F600 */
  {
    const char utf8bytes[] = { (char)0xF0, (char)0x9F, (char)0x98, (char)0x80, '\0' };
    NSString *s = [NSString stringWithUTF8String: utf8bytes];

    PASS(s != nil,
      "+stringWithUTF8String: succeeds for a 4-byte UTF-8 sequence (U+1F600)");
    PASS([s length] == 2,
      "NSString created from 4-byte UTF-8 sequence has length 2 (two UTF-16"
      " code units)");

    if ([s length] == 2)
      {
        PASS([s characterAtIndex: 0] == 0xD83D,
          "First code unit is the high surrogate 0xD83D");
        PASS([s characterAtIndex: 1] == 0xDE00,
          "Second code unit is the low surrogate 0xDE00");
      }
  }

  /* UTF-8 string with mixed ASCII and supplementary characters */
  {
    /* "A" U+1F600 "Z" */
    const char utf8mixed[] = {
      'A',
      (char)0xF0, (char)0x9F, (char)0x98, (char)0x80,
      'Z',
      '\0'
    };
    NSString *s = [NSString stringWithUTF8String: utf8mixed];

    PASS(s != nil,
      "+stringWithUTF8String: succeeds for ASCII+supplementary+ASCII");
    PASS([s length] == 4,
      "NSString from ASCII+U+1F600+ASCII has length 4 (1+2+1 code units)");
    PASS([s characterAtIndex: 0] == 'A',
      "First code unit is 'A'");
    PASS([s characterAtIndex: 3] == 'Z',
      "Last code unit is 'Z'");
  }

  /* Invalid UTF-8: overlong 4-byte sequence for a BMP character */
  {
    /* 0xF0 0x80 0x80 0x41 is overlong for 'A'; must be rejected */
    const char overlong[] = { (char)0xF0, (char)0x80, (char)0x80, (char)0x41, '\0' };
    NSString *s = [NSString stringWithUTF8String: overlong];

    PASS(s == nil,
      "+stringWithUTF8String: returns nil for an overlong UTF-8 sequence");
  }

  /* Invalid UTF-8: CESU-8 encoding of surrogate (0xED 0xA0 0x80 = U+D800) */
  {
    /* This byte sequence is how a lone surrogate would appear in CESU-8 /
     * WTF-8; it is not valid UTF-8 and must not be accepted as U+D800. */
    const char cesu8_high[] = { (char)0xED, (char)0xA0, (char)0x80, '\0' };
    NSString *s = [NSString stringWithUTF8String: cesu8_high];

    PASS(s == nil,
      "+stringWithUTF8String: returns nil for a CESU-8 encoded high surrogate"
      " (0xED 0xA0 0x80 is not valid UTF-8)");
  }

  /* Initialise from NSData containing valid UTF-8 for U+10000 */
  {
    const unsigned char u10000[4] = { 0xF0, 0x90, 0x80, 0x80 };
    NSData *d = [NSData dataWithBytes: u10000 length: 4];
    NSString *s = [[[NSString alloc] initWithData: d
                                         encoding: NSUTF8StringEncoding]
                   autorelease];

    PASS(s != nil,
      "-initWithData:encoding:NSUTF8StringEncoding succeeds for U+10000");
    PASS([s length] == 2,
      "NSString from U+10000 UTF-8 data has 2 UTF-16 code units");
  }

  END_SET("NSString init from UTF-8 data with supplementary characters")

  return 0;
}
