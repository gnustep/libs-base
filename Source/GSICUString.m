#import "GSICUString.h"

/**
 * The number of characters that we use per chunk when fetching a block of
 * characters at once for iteration.  Making this value larger will make UText
 * iteration faster, at the cost of more memory.  Making it larger than the
 * size of a typical string will make it no faster but will still cost memory.
 */
static const NSUInteger chunkSize = 32;

/**
 * Returns the number of UTF16 characters in a UText backed by an NSString.
 */
static int64_t UTextNSStringNativeLength(UText *ut)
{
	return [(NSString*)ut->p length];
}

/**
 * Replaces characters in an NSString-backed UText.
 */
static int32_t UTextNSMutableStringReplace(UText *ut,
                                           int64_t nativeStart,
                                           int64_t nativeLimit,
                                           const UChar *replacementText,
                                           int32_t replacmentLength,
                                           UErrorCode *status)
{
	NSMutableString *str = (NSMutableString*)ut->p;
	NSRange r = NSMakeRange(nativeStart, nativeLimit-nativeStart);
	NSString *replacement = [NSString alloc];
	if (replacmentLength < 0)
	{
		replacement = [replacement initWithCString: (const char*)replacementText
		                                  encoding: NSUTF16StringEncoding];
	}
	else
	{
		replacement = [replacement initWithCharactersNoCopy: (unichar*)replacementText
		                                             length: replacmentLength 
		                                       freeWhenDone: NO];
	}
	[str replaceCharactersInRange: r withString: replacement];
	[replacement release];
	// Update the chunk to reflect the internal changes.
	r = NSMakeRange(ut->chunkNativeStart, ut->chunkLength);
	[str getCharacters: ut->pExtra range: r];
	if (NULL != status)
	{
		*status = 0;
	}
	return 0;
}

/**
 * Loads a group of characters into the buffer that can be directly accessed by
 * users of the UText.  This is used for iteration but UText users.
 */
UBool UTextNSStringAccess(UText *ut, int64_t nativeIndex, UBool forward)
{
	// Special case if the chunk already contains this index
	if (nativeIndex > ut->chunkNativeStart
	    && nativeIndex < (ut->chunkNativeStart + ut->chunkLength))
	{
		ut->chunkOffset = nativeIndex - ut->chunkNativeStart;
		return TRUE;
	}
	NSString *str = ut->p;
	NSUInteger length = [str length];
	if (nativeIndex > length) { return FALSE; }
	NSRange r = {nativeIndex, chunkSize};
	forward = TRUE;
	if (forward)
	{
		if (nativeIndex + chunkSize > length)
		{
			r.length = length - nativeIndex;
		}
	}
	else
	{
		if (nativeIndex - chunkSize > 0)
		{
			r.location = nativeIndex - chunkSize;
			r.length = chunkSize;
		}
		else
		{
			r.location = 0;
			r.length = chunkSize - nativeIndex;
		}
	}
	[str getCharacters: ut->pExtra range: r];
	ut->chunkNativeStart = r.location;
	ut->chunkLength = r.length;
	ut->chunkOffset = 0;
	return TRUE;
}

/**
 * Reads some characters.  This is roughly analogous to NSString's
 * -getCharacters:range:.
 */
static int32_t UTextNSStringExtract(UText *ut,
                                    int64_t nativeStart,
                                    int64_t nativeLimit,
                                    UChar *dest,
                                    int32_t destCapacity,
                                    UErrorCode *status)
{
	// If we're loading no characters, we are expected to return the number of
	// characters that we could load if requested.
	if (destCapacity == 0)
	{
		return nativeLimit - nativeStart;
	}
	NSString *str = ut->p;
	NSUInteger length = [str length];
	if (nativeLimit > length)
	{
		nativeLimit = length;
	}
	NSRange r = NSMakeRange(nativeStart, nativeLimit - nativeStart );
	if (destCapacity < r.length)
	{
		r.length = destCapacity;
	}
	[str getCharacters: dest range: r];
	if (destCapacity > r.length)
	{
		dest[r.length] = 0;
	}
	return r.length;
}

/**
 * Copy or move some characters within a UText.
 */
void UTextNSStringCopy(UText *ut,
                       int64_t nativeStart,
                       int64_t nativeLimit,
                       int64_t nativeDest,
                       UBool move,
                       UErrorCode *status)
{
	NSMutableString *str = ut->p;
	NSUInteger length = [str length];
	if (nativeLimit > length)
	{
		nativeLimit = length;
	}
	NSRange r = NSMakeRange(nativeStart, nativeLimit - nativeStart);
	NSString *substr = [str substringWithRange: r];
	[str insertString: substr atIndex: nativeDest];
	if (move)
	{
		if (nativeDest < r.location)
		{
			r.location += r.length;
		}
		[str deleteCharactersInRange: r];
	}
	if (NULL != status) { *status = 0; }
}


/**
 * Destructor for the NSString-specific parts of the UText.  Because UTexts can
 * be allocated on the stack, or reused by different storage implementations,
 * this does not destroy the UText itself.
 */
static void UTextNStringClose(UText *ut)
{
	ut->chunkContents = NULL;
	[(NSString*)ut->p release];
	ut->p = NULL;
}

/**
 * Copies the UText object, optionally copying the NSString.  This version is
 * for NSString-backed UTexts, so uses -copy to copy the string if required.
 * Typically, this should not actually copy the underlying storage, because it
 * is immutable.
 */
UText* UTextNSStringClone(UText *dest,
                          const UText *src,
                          UBool deep,
                          UErrorCode *status)
{
	NSString *str = src->p;
	if (deep)
	{
		str = [[str copy] autorelease];
	}
	return UTextInitWithNSString(dest, str);
}

/**
 * Copies the UText object, optionally copying the NSMutableString.
 */
UText* UTextNSMutableStringClone(UText *dest,
                                 const UText *src,
                                 UBool deep,
                                 UErrorCode *status)
{
	NSMutableString *str = src->p;
	if (deep)
	{
		str = [str mutableCopy];
	}
	return UTextInitWithNSMutableString(dest, str);
}

/**
 * Returns the index of the current character in the temporary buffer.
 */
int64_t UTextNSStringMapOffsetToNative(const UText *ut)
{
	return ut->chunkNativeLimit + ut->chunkOffset;
}

/**
 * Vtable for NSString-backed UTexts.
 */
static const UTextFuncs NSStringFuncs = 
{
	sizeof(UTextFuncs), // Table size
	0, 0, 0,            // Reserved
	UTextNSStringClone,
	UTextNSStringNativeLength,
	UTextNSStringAccess,
	UTextNSStringExtract,
	0,                  // Replace
	UTextNSStringCopy,
	UTextNSStringMapOffsetToNative,
	0,                // Map to UTF16
	UTextNStringClose,
	0, 0, 0             // Spare
};

/**
 * Vtable for NSMutableString-backed UTexts.
 */
static const UTextFuncs NSMutableStringFuncs = 
{
	sizeof(UTextFuncs), // Table size
	0, 0, 0,            // Reserved
	UTextNSMutableStringClone,
	UTextNSStringNativeLength,
	UTextNSStringAccess,
	UTextNSStringExtract,
	UTextNSMutableStringReplace,
	UTextNSStringCopy,
	UTextNSStringMapOffsetToNative,
	0,                // Map to UTF16
	UTextNStringClose,
	0, 0, 0             // Spare
};

UText* UTextInitWithNSMutableString(UText *txt, NSMutableString *str)
{
	UErrorCode status = 0;
	txt = utext_setup(txt, chunkSize * sizeof(unichar), &status);

	if (0 != status)  { return NULL; }

	txt->p = str;
	txt->pFuncs = &NSMutableStringFuncs;
	txt->chunkContents = txt->pExtra;

	txt->providerProperties = 1<<UTEXT_PROVIDER_WRITABLE;

	return txt;
}

UText* UTextInitWithNSString(UText *txt, NSString *str)
{
	UErrorCode status = 0;
	txt = utext_setup(txt, 64, &status);

	if (0 != status)  { return NULL; }

	txt->p = str;
	txt->pFuncs = &NSStringFuncs;
	txt->chunkContents = txt->pExtra;

	return txt;
}


@implementation GSUTextString
- (NSUInteger)length
{
	return utext_nativeLength(&txt);
}
- (unichar)characterAtIndex: (NSUInteger)idx
{
	unichar c;
	[self getCharacters: &c range: NSMakeRange(idx, 1)];
	return c;
}
- (void)getCharacters: (unichar*)buffer range: (NSRange)r
{
	UErrorCode status;
	utext_extract(&txt, r.location, r.location+r.length, buffer, r.length,
			&status);
	if (0 != status)
	{
		_NSRangeExceptionRaise();
	}
}
- (void)dealloc
{
	utext_close(&txt);
	[super dealloc];
}
@end

@implementation GSUTextMutableString
- (NSUInteger)length
{
	return utext_nativeLength(&txt);
}
- (unichar)characterAtIndex: (NSUInteger)idx
{
	unichar c;
	[self getCharacters: &c range: NSMakeRange(idx, 1)];
	return c;
}
- (void)getCharacters: (unichar*)buffer range: (NSRange)r
{
	UErrorCode status;
	utext_extract(&txt, r.location, r.location+r.length, buffer, r.length,
			&status);
	if (0 != status)
	{
		_NSRangeExceptionRaise();
	}
}
- (void)replaceCharactersInRange: (NSRange)r
                      withString: (NSString*)aString
{
	NSUInteger size = [aString length];
	UErrorCode status;
	TEMP_BUFFER(buffer, size);
	[aString getCharacters: buffer range: NSMakeRange(0, size)];

	utext_replace(&txt, r.location, r.location + r.length, buffer, size,
			&status);
}

- (void)dealloc
{
	utext_close(&txt);
	[super dealloc];
}
@end
