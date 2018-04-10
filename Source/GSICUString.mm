
#import "common.h"
#if GS_USE_ICU == 1
#define UNISTR_FROM_STRING_EXPLICIT explicit
#define GSICUSTRING_MM 1
#import "Foundation/Foundation.h"
#import "GSICUString.h"
extern "C" {
#import "GSPrivate.h"
}
#include "unicode/localpointer.h"
#include "unicode/ucnv_err.h"
#include "unicode/ucnv.h"
#include "unicode/uenum.h"
#include <unicode/brkiter.h>
#include <unicode/bytestream.h>
#include <unicode/coll.h>
#include <unicode/locid.h>
#include <unicode/unistr.h>
#include <memory>

using icu::BreakIterator;
using icu::Collator;

/**
 * Extra methods to access the underlying storage for an NSString object, if it
 * is storing its data in a convenient format.  These methods allow fast paths
 * when representations match, without having to encode understanding of other
 * string implementations into this code.
 *
 * All of the methods in this category return a temporary read-only pointer,
 * which is not expected to be valid across operations that mutate the string.
 */
@interface NSString (ICU)
/**
 * Return a pointer to the `icu::UnicodeString` that this string encapsulates,
 * or `nullptr` if this string does not encapsulate a `icu::UnicodeString`.
 */
- (icu::UnicodeString*)_icuInternalString;
/**
 * Returns a pointer to the internal UTF-16 buffer that this string
 * encapsulates or `nullptr` if it does not use a contiguous block of UTF-16
 * characters as the internal storage.
 */
- (unichar *)_internalUTF16Buffer;
/**
 * Returns a pointer to the internal ASCII buffer that this string
 * encapsulates or `nullptr` if it does not use a contiguous block of ASCII
 * characters as the internal storage.
 */
- (unichar *)_internalASCIIBuffer;
@end

/**
 * Abstract implementations of the internal string access methods.  These all
 * return `nullptr` if  not overridden by strings that provide a useful
 * implementation.
 */
@implementation NSString (ICU)
- (icu::UnicodeString*)_icuInternalString
{
  return nullptr;
}
- (unichar *)_internalUTF16Buffer
{
  return nullptr;
}
- (unichar *)_internalASCIIBuffer
{
  return nullptr;
}
@end


namespace {

// This code uses OpenStep's unichar type and C++11's char16_t type (which ICU
// uses for UTF-16 data) interchangeably.  Make sure that they are the same size.
static_assert(sizeof(unichar) == sizeof(char16_t),
  "Can't use ICU and GNUstep character types interchangeably!");

/**
 * Adaptor to use an `NSMutableData` as an ICU `ByteSink`.  This class wraps
 * the `NSMutableData` and appends to it.
 */
class NSDataByteSink : public icu::ByteSink
{
  /**
   * A pointer to the place within the NSMutableData that might be being used
   * as scratch space.
   */
  char *buffer;
  /**
   * The length of data written to the underlying storage.
   */
  NSUInteger length;

  /**
   * Access a temporary buffer.  This extends the mutable data object to
   * provide the requested amount of space and returns that buffer.  The caller
   * can then write directly into the mutable data object, which will be
   * truncated if required in the `Append` method.
   */
  char* GetAppendBuffer(int32_t min_capacity,
                        int32_t desired_capacity_hint,
                        char *scratch,
                        int32_t scratch_capacity,
                        int32_t *result_capacity) override
  {
    // Don't allow the buffer to grow by huge amounts if the caller asks us for
    // a multi-MB chunk.  If they ask for too much, we'll have to copy
    // everything to truncate at the end.
    desired_capacity_hint = std::min(desired_capacity_hint, 8192);
    // If a previous call asked for more space than it used then don't keep
    // expanding the underlying storage.
    NSUInteger bufferLength = [d length];
    NSInteger spaceToReserve = desired_capacity_hint - (bufferLength - length);
    if (spaceToReserve > 0)
      {
        [d increaseLengthBy: spaceToReserve];
      }
    *result_capacity = desired_capacity_hint;
    buffer = (char*)[d mutableBytes] + length;
    return buffer;
  }
  /**
   * Append a buffer to the underlying storage.  If the buffer was previously
   * returned by `GetAppendBuffer` then we just mark it as used space,
   * otherwise we copy it into the buffer.
   */
  void Append (const char *bytes, int32_t n) override
  {
    // If this is not an in-place buffer, we need to copy it.
    if (bytes != buffer)
      {
        // If we've previously reserved some space, truncate it.
        // Note: This should be very cold code, so inefficiency doesn't matter
        // much, but if profiling indicates that it does then we should resize
        // the buffer and do a single copy, because the truncation may involve
        // copying all of the data, and then the insertion copying it again.
        NSUInteger len = [d length];
        if ([d length] > length)
          {
            [d replaceBytesInRange: NSMakeRange(length, len - length)
                         withBytes: ""
                            length: 0];
          }
        [d appendBytes: bytes length: n];
      }
    length += n;
    buffer = nullptr;
  }

  public:
  /**
   * Constructor, creates a new `NSMutableData` to append int.
   */
  NSDataByteSink() : buffer(0), length(0), d([NSMutableData new]) {}
  /**
   * Destructor.  Destroys the reference to the `NSMutableData` if one is still
   * extant.  In normal use, the 
   */
  virtual ~NSDataByteSink() { RELEASE(d); }
  /**
   * The underlying storage for this sync.
   */
  NSMutableData *d;
  /**
   * Truncate the underlying storage to clip any space that was reserved and not used.
   * This returns an autoreleased reference to the data object, transferring
   * ownership to the caller.
   */
  NSData *finalise()
  {
    // Truncate the buffer to the length that we expect
    NSUInteger len = [d length];
    if (len > length)
      {
        [d replaceBytesInRange: NSMakeRange(length, len - length)
                     withBytes: ""
                        length: 0];
      }
    length = len;
    buffer = nullptr;
    NSData *data = d;
    d = nil;
    return AUTORELEASE(data);
  }

};

/**
 * Access a per-thread break iterator.  This is stored in a `thread_local`
 * `std::unique_ptr`, so will be automatically destroyed on thread exit.
 */
BreakIterator *get_thread_break_iterator()
{
  UErrorCode e = U_ZERO_ERROR;
  static thread_local std::unique_ptr<BreakIterator> thread_iterator(BreakIterator::createCharacterInstance(icu::Locale(), e));
  return thread_iterator.get();
}

/**
 * Access a per-thread default collator.  This is stored in a `thread_local`
 * `std::unique_ptr`, so will be automatically destroyed on thread exit.
 */
Collator *get_default_collator()
{
  UErrorCode e = U_ZERO_ERROR;
  static thread_local std::unique_ptr<Collator> thread_collator(Collator::createInstance(e));
  return thread_collator.get();
}

/**
 * Adaptor for accessing an NSString as an icu::UnicodeString.  If the NSString
 * wraps an icu::UnicodeString, this simply accesses it.  Otherwise it
 * constructs a new ICU string from the character data.
 w*/
class NSStringUnicodeString
{
  /**
   * A string object stored inside this structure that is used to store either
   * a copy of the string data or to directly access the string data if it is
   * stored in a way that permits direct wrapping.
   */
  icu::UnicodeString copy;
  /**
   * A pointer to the unicode string object that this class will return.  This
   * is either an internal object within the wrapped string or `copy`.
   */
  icu::UnicodeString *real;
  public:
  /**
   * Constructor.  Wraps an `NSString`.  Note that this may copy all of the
   * string data, so should not be used unless the resulting
   * `icu::UnicodeString` is definitely going to be used.
   */
  NSStringUnicodeString(NSString *aString)
  {
    // Access the string data directly.
    if (icu::UnicodeString *otherstr = [aString _icuInternalString])
      {
        real = otherstr;
      }
    // If there isn't an ICU string, but we can access the UTF-16 buffer,
    // create a very thin wrapper without copying it.
    else if (unichar *ptr = [aString _internalUTF16Buffer])
      {
        NSUInteger len = [aString length];
        copy.setTo(false, (const char16_t *)ptr, len);
        assert(copy.length() == len);
        real = &copy;
      }
    else
      {
        NSUInteger len = [aString length];
        unichar *buffer = (unichar*)copy.getBuffer(len);
        try
        {
          [aString getCharacters: buffer range: NSMakeRange(0, len)];
        }
        catch (...)
        {
          copy.releaseBuffer(0);
          throw;
        }
        copy.releaseBuffer(len);
        real = &copy;
      }
  }
  /**
   * Cast operator overload, allows this class to substitute for an
   * `icu::UnicodeString`.
   */
  operator const icu::UnicodeString&() { return *real; }
};

/**
 * Function that initialises a `UnicodeString` with the arguments from
 * `-initWithCharactersNoCopy:length:freeWhenDone:`.
 */
void SetUnicodeStringWithCharacters(UnicodeString &str,
                                    unichar *characters,
                                    NSUInteger aLength,
                                    BOOL freeWhenDone)
{
  // FIXME: We should actually take ownership of this string, but that's
  // difficult with the UnicodeString APIs.  This API isn't great anyway,
  // because it works only with malloc'd memory.  It would be nice to have a
  // version that took an explicit deleter.
  if (freeWhenDone)
    {
      // This setTo overload copies the characters.
      str.setTo((const char16_t *)characters, aLength);
      free(characters);
    }
  else
    {
      // This setTo overload will use ptr as an immutable buffer and will copy
      // on write.
      str.setTo(false, (const char16_t *)characters, aLength);
    }
}

/**
 * Function that initialises a `UnicodeString` with the arguments from
 * `-initWithBytesNoCopy:length:encoding:freeWhenDone:`
 */
BOOL SetUnicodeStringWithBytesNoCopy(UnicodeString &str,
                                     void* bytes,
                                     NSUInteger length,
                                     NSStringEncoding encoding,
                                     BOOL freeWhenDone)
{
  // FIXME: Also special case big / little endian UTF-16 encoding, depending on
  // the native endian.
  if (encoding == NSUTF16StringEncoding)
    {
      SetUnicodeStringWithCharacters(str,
                                     (unichar*)bytes,
                                     length/sizeof(unichar),
                                     freeWhenDone);
      return YES;
    }
  UErrorCode e = U_ZERO_ERROR;
  const char *converterName = GSPrivateEncodingIConvName(encoding);
  if (converterName == nullptr)
    {
      return NO;
    }
  UConverter *conv = ucnv_open(converterName, &e);
  UnicodeString tmp((const char*)bytes, length, conv, e);
  ucnv_close(conv);
  if (U_FAILURE(e))
    {
      return NO;
    }
  str = std::move(tmp);
  // Always free early here, because we're converting the text to the internal
  // representation.
  if (freeWhenDone)
    {
      free(bytes);
    }
  return YES;
}

} // Anonymous namespace

/**
 * `NSMutableString` subclass that simply wraps an ICU UnicodeString.
 */
@implementation GSMutableICUUnicodeString

#define STRING_CLASS GSMutableICUUnicodeString
#include "GSICUStringMethods.hh"

// NSMutableString methods

- (void)replaceCharactersInRange: (NSRange)aRange
                      withString: (NSString*)aString
{
  GS_RANGE_CHECK(aRange, str.length());
  NSStringUnicodeString other(aString);
  str.replace(aRange.location, aRange.length, other);
}


@end

@implementation GSICUUnicodeString

#define STRING_CLASS GSICUUnicodeString
#include "GSICUStringMethods.hh"

@end

#endif // GS_USE_ICU
