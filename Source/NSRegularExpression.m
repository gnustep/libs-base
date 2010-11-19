#include "config.h"
#if HAVE_ICU
#include "unicode/uregex.h"
#define GSREGEXTYPE URegularExpression
#import "GSICUString.h"
#import "Foundation/NSRegularExpression.h"
#import "Foundation/NSTextCheckingResult.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCoder.h"


/**
 * To be helpful, Apple decided to define a set of flags that mean exactly the
 * same thing as the URegexpFlags enum in libicu, but have different values.
 * This was completely stupid, but we probably have to live with it.  We could
 * in theory use the libicu values directly (that would be sensible), but that
 * would break any code that didn't correctly use the symbolic constants.
 */
uint32_t NSRegularExpressionOptionsToURegexpFlags(NSRegularExpressionOptions opts) 
{
	uint32_t flags = 0;
	if (opts & NSRegularExpressionCaseInsensitive)
	{
		flags |= UREGEX_CASE_INSENSITIVE;
	}
	if (opts & NSRegularExpressionAllowCommentsAndWhitespace)
	{
		flags |= UREGEX_COMMENTS;
	}
	if (opts & NSRegularExpressionIgnoreMetacharacters)
	{
		flags |= UREGEX_LITERAL;
	}
	if (opts & NSRegularExpressionDotMatchesLineSeparators)
	{
		flags |= UREGEX_DOTALL;
	}
	if (opts & NSRegularExpressionAnchorsMatchLines)
	{
		flags |= UREGEX_MULTILINE;
	}
	if (opts & NSRegularExpressionUseUnixLineSeparators)
	{
		flags |= UREGEX_UNIX_LINES;
	}
	if (opts & NSRegularExpressionUseUnicodeWordBoundaries)
	{
		flags |= UREGEX_UWORD;
	}
	return flags;
}

@implementation NSRegularExpression
+ (NSRegularExpression*)regularExpressionWithPattern: (NSString*)aPattern
                                             options: (NSRegularExpressionOptions)opts
                                               error: (NSError**)e
{
	return [[[self alloc] initWithPattern: aPattern options: opts error: e] autorelease];
}
- initWithPattern: (NSString*)aPattern
          options: (NSRegularExpressionOptions)opts
            error: (NSError**)e
{
	uint32_t flags = NSRegularExpressionOptionsToURegexpFlags(opts);
	UText p = UTEXT_INITIALIZER;
	UTextInitWithNSString(&p, aPattern);
	UParseError pe = {0};
	UErrorCode s = 0;
	regex = uregex_openUText(&p, flags, &pe, &s);
	utext_close(&p);
	if (U_FAILURE(s))
	{
		// FIXME: Do something sensible with the error parameter.
		[self release];
		return nil;
	}
	options = opts;
	return self;
}
- (NSString*)pattern
{
	UErrorCode s = 0;
	UText *t = uregex_patternUText(regex, &s);
	if (U_FAILURE(s))
	{
		return nil;
	}
	GSUTextString *str = [GSUTextString new];
	utext_clone(&str->txt, t, FALSE, TRUE, &s);
	utext_close(t);
	return [str autorelease];
}

static UBool callback(const void *context, int32_t steps)
{
	if (NULL == context) { return FALSE; }
	BOOL stop = NO;
	GSRegexBlock block = (GSRegexBlock)context;
	CALL_BLOCK(block, nil, NSMatchingProgress, &stop);
	return stop;
}
/**
 * Sets up a libicu regex object for use.  Note: the documentation states that
 * NSRegularExpression must be thread safe.  To accomplish this, we store a
 * prototype URegularExpression in the object, and then clone it in each
 * method.  This is required because URegularExpression, unlike
 * NSRegularExpression, is stateful, and sharing this state between threads
 * would break concurrent calls.
 */
static URegularExpression *setupRegex(URegularExpression *regex,
                                      NSString *string,
                                      UText *txt,
                                      NSMatchingOptions options,
                                      NSRange range,
                                      GSRegexBlock block)
{
	UErrorCode s = 0;
	URegularExpression *r = uregex_clone(regex, &s);
	if (options & NSMatchingReportProgress)
	{
		uregex_setMatchCallback(r, callback, block, &s);
	}
	UTextInitWithNSString(txt, string);
	uregex_setUText(r, txt, &s);
	uregex_setRegion(r, range.location, range.location+range.length, &s);
	if (options & NSMatchingWithoutAnchoringBounds)
	{
		uregex_useAnchoringBounds(r, FALSE, &s);
	}
	if (options & NSMatchingWithTransparentBounds)
	{
		uregex_useTransparentBounds(r, TRUE, &s);
	}
	if (U_FAILURE(s))
	{
		uregex_close(r);
		return NULL;
	}
	return r;
}
static uint32_t prepareResult(NSRegularExpression *regex,
                              URegularExpression *r,
                              NSRangePointer ranges,
                              NSUInteger groups,
                              UErrorCode *s)
{
	uint32_t flags = 0;
	for (NSUInteger i=0 ; i<groups ; i++)
	{
		NSUInteger start = uregex_start(r, i, s);
		NSUInteger end = uregex_end(r, i, s);
		ranges[i] = NSMakeRange(start, end-start);
	}
	if (uregex_hitEnd(r, s))
	{
		flags |= NSMatchingHitEnd;
	}
	if (uregex_requireEnd(r, s))
	{
		flags |= NSMatchingRequiredEnd;
	}
	if (0 != *s)
	{
		flags |= NSMatchingInternalError;
	}
	return flags;
}

- (void)enumerateMatchesInString: (NSString*)string
                         options: (NSMatchingOptions)opts
                           range: (NSRange)range
                      usingBlock: (GSRegexBlock)block
{
	UErrorCode s = 0;
	UText txt = UTEXT_INITIALIZER;
	BOOL stop = NO;
	URegularExpression *r = setupRegex(regex, string, &txt, opts, range, block);
	NSUInteger groups = [self numberOfCaptureGroups] + 1;
	NSRange ranges[groups];
	// Should this throw some kind of exception?
	if (NULL == r) { return; }
	if (opts & NSMatchingAnchored)
	{
		if (uregex_lookingAt(r, -1, &s) && (0==s))
		{
			// FIXME: Factor all of this out into prepareResult()
			uint32_t flags = prepareResult(self, r, ranges, groups, &s);
			NSTextCheckingResult *result = 
				[NSTextCheckingResult regularExpressionCheckingResultWithRanges: ranges
				                                                          count: groups
				                                              regularExpression: self];
			CALL_BLOCK(block, result, flags, &stop);
		}
	}
	else
	{
		while (!stop && uregex_findNext(r, &s) && (s == 0))
		{
			uint32_t flags = prepareResult(self, r, ranges, groups, &s);
			NSTextCheckingResult *result = 
				[NSTextCheckingResult regularExpressionCheckingResultWithRanges: ranges
				                                                          count: groups
				                                              regularExpression: self];
			CALL_BLOCK(block, result, flags, &stop);
		}
	}
	if (opts & NSMatchingCompleted)
	{
		CALL_BLOCK(block, nil, NSMatchingCompleted, &stop);
	}
	utext_close(&txt);
	uregex_close(r);
}
// The remaining methods are all meant to be wrappers around the primitive
// method that takes a block argument.  Unfortunately, this is not really
// possible when compiling with a compiler that doesn't support blocks.  
#if __has_feature(blocks)
- (NSUInteger)numberOfMatchesInString: (NSString*)string
                              options: (NSMatchingOptions)opts
                                range: (NSRange)range

{
	__block NSUInteger count = 0;
	opts &= ~NSMatchingReportProgress;
	opts &= ~NSMatchingReportCompletion;
	GSRegexBlock block = 
		^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
		{
			count++;
		};
	[self enumerateMatchesInString: string
	                       options: opts
	                         range: range
	                    usingBlock: block];
	return count;
}
- (NSTextCheckingResult*)firstMatchInString: (NSString*)string
                                    options: (NSMatchingOptions)opts
                                      range: (NSRange)range
{
	__block NSTextCheckingResult *r = nil;
	opts &= ~NSMatchingReportProgress;
	opts &= ~NSMatchingReportCompletion;
	GSRegexBlock block = 
		^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
		{
			r = result;
			*stop = YES;
		};
	[self enumerateMatchesInString: string
	                       options: opts
	                         range: range
	                    usingBlock: block];
	return r;
}
- (NSArray*)matchesInString: (NSString*)string
                    options:(NSMatchingOptions)opts
                      range:(NSRange)range
{
	NSMutableArray *array = [NSMutableArray array];
	opts &= ~NSMatchingReportProgress;
	opts &= ~NSMatchingReportCompletion;
	GSRegexBlock block = 
		^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
		{
			[array addObject: result];
		};
	[self enumerateMatchesInString: string
	                       options: opts
	                         range: range
	                    usingBlock: block];
	return array;
}
- (NSRange)rangeOfFirstMatchInString: (NSString*)string
                             options: (NSMatchingOptions)opts
                               range: (NSRange)range
{
	__block NSRange r;
	opts &= ~NSMatchingReportProgress;
	opts &= ~NSMatchingReportCompletion;
	GSRegexBlock block = 
		^(NSTextCheckingResult *result, NSMatchingFlags flags, BOOL *stop)
		{
			r= [result range];
			*stop = YES;
		};
	[self enumerateMatchesInString: string
	                       options: opts
	                         range: range
	                    usingBlock: block];
	return r;
}
#else
#	warning Your compiler does not support blocks.  NSRegularExpression will deviate from the documented behaviour when subclassing and any code that subclasses NSRegularExpression may break in unexpected ways.  It is strongly recommended that you use a compiler with blocks support.
#	ifdef __clang__
#		warning Your compiler would support blocks if you added -fblocks to your OBJCFLAGS
#	endif
#define FAKE_BLOCK_HACK(failRet, code) \
	UErrorCode s = 0;\
	UText txt = UTEXT_INITIALIZER;\
	BOOL stop = NO;\
	URegularExpression *r = setupRegex(regex, string, &txt, opts, range, 0);\
	if (NULL == r) { return failRet; }\
	if (opts & NSMatchingAnchored)\
	{\
		if (uregex_lookingAt(r, -1, &s) && (0==s))\
		{\
			code\
		}\
	}\
	else\
	{\
		while (!stop && uregex_findNext(r, &s) && (s == 0))\
		{\
			code\
		}\
	}\
	utext_close(&txt);\
	uregex_close(r);
- (NSUInteger)numberOfMatchesInString: (NSString*)string
                              options: (NSMatchingOptions)opts
                                range: (NSRange)range

{
	NSUInteger count = 0;
	FAKE_BLOCK_HACK(count,
		{
			count++;
		});
	return count;
}
- (NSTextCheckingResult*)firstMatchInString: (NSString*)string
                                    options: (NSMatchingOptions)opts
                                      range: (NSRange)range
{
	NSTextCheckingResult *result = nil;
	NSUInteger groups = [self numberOfCaptureGroups] + 1;
	NSRange ranges[groups];
	FAKE_BLOCK_HACK(result,
		{
			prepareResult(self, r, ranges, groups, &s);
			result =
				[NSTextCheckingResult regularExpressionCheckingResultWithRanges: ranges
				                                                          count: groups
				                                              regularExpression: self];
			stop = YES;
		});
	return result;
}
- (NSArray*)matchesInString: (NSString*)string
                    options:(NSMatchingOptions)opts
                      range:(NSRange)range
{
	NSMutableArray *array = [NSMutableArray array];
	NSUInteger groups = [self numberOfCaptureGroups] + 1;
	NSRange ranges[groups];
	FAKE_BLOCK_HACK(array,
		{
			prepareResult(self, r, ranges, groups, &s);
			NSTextCheckingResult *result = 
				[NSTextCheckingResult regularExpressionCheckingResultWithRanges: ranges
				                                                          count: groups
				                                              regularExpression: self];
			[array addObject: result];
		});
	return array;
}
- (NSRange)rangeOfFirstMatchInString: (NSString*)string
                             options: (NSMatchingOptions)opts
                               range: (NSRange)range
{
	NSRange result = {0,0};
	FAKE_BLOCK_HACK(result,
		{
			prepareResult(self, r, &result, 1, &s);
			stop = YES;
		});
	return result;
}
#endif
- (NSUInteger)replaceMatchesInString: (NSMutableString*)string
                             options: (NSMatchingOptions)opts
                               range: (NSRange)range
                        withTemplate: (NSString*)template
{
	// FIXME: We're computing a value that is most likely ignored in an
	// expensive way.  
	NSInteger results = [self numberOfMatchesInString: string
	                                          options: opts
	                                            range: range];
	UErrorCode s = 0;
	UText txt = UTEXT_INITIALIZER;
	UText replacement = UTEXT_INITIALIZER;
	GSUTextString *ret = [GSUTextString new];
	URegularExpression *r = setupRegex(regex, string, &txt, opts, range, 0);
	UTextInitWithNSString(&replacement, template);

	UText *output = uregex_replaceAllUText(r, &replacement, NULL, &s);
	utext_clone(&ret->txt, output, TRUE, TRUE, &s);
	[string setString: ret];
	[ret release];
	uregex_close(r);

	utext_close(&txt);
	utext_close(output);
	utext_close(&replacement);
	return results;
}

- (NSString*)stringByReplacingMatchesInString: (NSString*)string
                                      options: (NSMatchingOptions)opts
                                        range: (NSRange)range
                                 withTemplate: (NSString*)template
{
	UErrorCode s = 0;
	UText txt = UTEXT_INITIALIZER;
	UText replacement = UTEXT_INITIALIZER;
	GSUTextString *ret = [GSUTextString new];
	URegularExpression *r = setupRegex(regex, string, &txt, opts, range, 0);
	UTextInitWithNSString(&replacement, template);


	UText *output = uregex_replaceAllUText(r, &replacement, NULL, &s);
	utext_clone(&ret->txt, output, TRUE, TRUE, &s);
	uregex_close(r);

	utext_close(&txt);
	utext_close(output);
	utext_close(&replacement);
	return ret;
}

- (NSString*)replacementStringForResult: (NSTextCheckingResult*)result
                               inString: (NSString*)string
                                 offset: (NSInteger)offset
                               template: (NSString*)template
{
	UErrorCode s = 0;
	UText txt = UTEXT_INITIALIZER;
	UText replacement = UTEXT_INITIALIZER;
	GSUTextString *ret = [GSUTextString new];
	NSRange range = [result range];
	URegularExpression *r = setupRegex(regex, 
	                                   [string substringWithRange: range],
	                                   &txt,
	                                   0,
	                                   NSMakeRange(0, range.length),
	                                   0);
	UTextInitWithNSString(&replacement, template);


	UText *output = uregex_replaceFirstUText(r, &replacement, NULL, &s);
	utext_clone(&ret->txt, output, TRUE, TRUE, &s);
	uregex_close(r);

	utext_close(&txt);
	utext_close(output);
	utext_close(&replacement);
	return ret;
}
- (NSRegularExpressionOptions)options
{
	return options;
}
- (NSUInteger)numberOfCaptureGroups
{
	UErrorCode s = 0;
	return uregex_groupCount(regex, &s);
}
- (void)dealloc
{
	uregex_close(regex);
	[super dealloc];
}
- (void)encodeWithCoder: (NSCoder*)aCoder
{
	if ([aCoder allowsKeyedCoding])
	{
		[aCoder encodeInteger: options forKey: @"options"];
		[aCoder encodeObject: [self pattern] forKey: @"pattern"];
	}
	else
	{
		[aCoder encodeValueOfObjCType: @encode(NSRegularExpressionOptions) at: &options];
		[aCoder encodeObject: [self pattern]];
	}
}
- initWithCoder: (NSCoder*)aCoder
{
	NSString *pattern;
	if ([aCoder allowsKeyedCoding])
	{
		options = [aCoder decodeIntegerForKey: @"options"];
		pattern = [aCoder decodeObjectForKey: @"pattern"];
	}
	else
	{
		[aCoder decodeValueOfObjCType: @encode(NSRegularExpressionOptions) at: &options];
		pattern = [aCoder decodeObject];
	}
	return [self initWithPattern: pattern options: options error: NULL];
}
- copyWithZone: (NSZone*)aZone
{
	NSRegularExpressionOptions opts = options;
	UErrorCode s = 0;
	URegularExpression *r = uregex_clone(regex, &s);
	if (0 != s) { return nil; }

	self = [[self class] allocWithZone: aZone];
	if (nil == self) { return nil; }
	options = opts;
	regex = r;
	return self;
}
@end
#endif //HAV_ICU
