#import "NSObject.h"
#import "NSGeometry.h"

@class NSArray;
@class NSDate;
@class NSDictionary;
@class NSOrthography;
@class NSRegularExpression;
@class NSString;
@class NSTimeZone;
@class NSURL;

typedef uint64_t NSTextCheckingType;
static const NSTextCheckingType NSTextCheckingTypeRegularExpression  = 1ULL<<10;

/**
 * NSTextCheckingResult is an abstract class encapsulating the result of some
 * operation that checks 
 */
@interface NSTextCheckingResult : NSObject
#if GS_HAS_DECLARED_PROPERTIES
@property(readonly) NSDictionary *addressComponents;
@property(readonly) NSDictionary *components;
@property(readonly) NSDate *date;
@property(readonly) NSTimeInterval duration;
@property(readonly) NSArray *grammarDetails;
@property(readonly) NSUInteger numberOfRanges;
@property(readonly) NSOrthography *orthography;
@property(readonly) NSString *phoneNumber;
@property(readonly) NSRange range;
@property(readonly) NSRegularExpression *regularExpression;
@property(readonly) NSString *replacementString;
@property(readonly) NSTextCheckingType resultType;
@property(readonly) NSTimeZone *timeZone;
@property(readonly) NSURL *URL;
#else
- (NSDictionary*)addressComponents;
- (NSDictionary*)components;
- (NSDate*)date;
- (NSTimeInterval) duration;
- (NSArray*)grammarDetails;
- (NSUInteger) numberOfRanges;
- (NSOrthography*)orthography;
- (NSString*)phoneNumber;
- (NSRange) range;
- (NSRegularExpression*)regularExpression;
- (NSString*)replacementString;
- (NSTextCheckingType) resultType;
- (NSTimeZone*)timeZone;
- (NSURL*)URL;
#endif
+ (NSTextCheckingResult*)regularExpressionCheckingResultWithRanges: (NSRangePointer)ranges
                                                             count: (NSUInteger)count
                                                 regularExpression: (NSRegularExpression*)regularExpression;
@end
