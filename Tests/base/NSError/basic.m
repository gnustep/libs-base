/*
 * basic.m - tests for NSError: construction and accessors (domain, code,
 * userInfo), the localized-value accessors driven by the userInfo keys
 * (localizedDescription and its fallbacks, localizedFailureReason,
 * localizedRecoverySuggestion, localizedRecoveryOptions), copying and
 * NSCoding.  Portable, deterministic value-semantic behaviour.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSError construction and accessors")
    NSDictionary	*info;
    NSError		*e;

    info = [NSDictionary dictionaryWithObject: @"boom"
				       forKey: NSLocalizedDescriptionKey];
    e = [NSError errorWithDomain: @"MyDomain" code: 42 userInfo: info];
    PASS(e != nil, "+errorWithDomain:code:userInfo: creates an error");
    PASS_EQUAL([e domain], @"MyDomain", "domain returns the domain");
    PASS([e code] == 42, "code returns the code");
    PASS_EQUAL([e userInfo], info, "userInfo returns the dictionary");

    e = [[NSError alloc] initWithDomain: @"Other" code: -1 userInfo: nil];
    PASS_EQUAL([e domain], @"Other", "initWithDomain:code:userInfo: sets the domain");
    PASS([e code] == -1, "a negative code is accepted");
    [e release];
  END_SET("NSError construction and accessors")

  START_SET("NSError localized values")
    NSDictionary	*info;
    NSArray		*opts;
    NSError		*e;

    info = [NSDictionary dictionaryWithObject: @"It broke"
				       forKey: NSLocalizedDescriptionKey];
    e = [NSError errorWithDomain: @"D" code: 1 userInfo: info];
    PASS_EQUAL([e localizedDescription], @"It broke",
      "localizedDescription returns NSLocalizedDescriptionKey when present");

    info = [NSDictionary dictionaryWithObject: @"disk full"
				       forKey: NSLocalizedFailureReasonErrorKey];
    e = [NSError errorWithDomain: @"D" code: 1 userInfo: info];
    PASS_EQUAL([e localizedFailureReason], @"disk full",
      "localizedFailureReason returns the failure reason");
    PASS_EQUAL([e localizedDescription], @"Operation failed disk full",
      "localizedDescription is derived from the failure reason");

    info = [NSDictionary dictionaryWithObject: @"Try again"
				       forKey: NSLocalizedRecoverySuggestionErrorKey];
    e = [NSError errorWithDomain: @"D" code: 1 userInfo: info];
    PASS_EQUAL([e localizedRecoverySuggestion], @"Try again",
      "localizedRecoverySuggestion returns the suggestion");

    opts = [NSArray arrayWithObjects: @"OK", @"Cancel", nil];
    info = [NSDictionary dictionaryWithObject: opts
				       forKey: NSLocalizedRecoveryOptionsErrorKey];
    e = [NSError errorWithDomain: @"D" code: 1 userInfo: info];
    PASS_EQUAL([e localizedRecoveryOptions], opts,
      "localizedRecoveryOptions returns the options array");

    e = [NSError errorWithDomain: @"MyDomain" code: 42 userInfo: nil];
    PASS_EQUAL([e localizedDescription], @"Error Domain=MyDomain Code=42",
      "localizedDescription falls back to the domain and code");
    PASS([e localizedFailureReason] == nil,
      "localizedFailureReason is nil when the key is absent");
  END_SET("NSError localized values")

  START_SET("NSError copying and coding")
    NSDictionary	*info;
    NSError		*e, *c, *u;
    NSData		*d;

    info = [NSDictionary dictionaryWithObject: @"x"
				       forKey: NSLocalizedDescriptionKey];
    e = [NSError errorWithDomain: @"D" code: 7 userInfo: info];

    c = [e copy];
    PASS([[c domain] isEqual: @"D"] && [c code] == 7
      && [[c userInfo] isEqual: info],
      "a copy preserves domain, code and userInfo");
    [c release];

    d = [NSKeyedArchiver archivedDataWithRootObject: e];
    u = [NSKeyedUnarchiver unarchiveObjectWithData: d];
    PASS([[u domain] isEqual: @"D"] && [u code] == 7
      && [[u userInfo] isEqual: info],
      "an archived and unarchived error is preserved");
  END_SET("NSError copying and coding")

  return 0;
}
