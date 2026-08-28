//#if __has_include("Testing.h")
#import "Testing.h"
/*#else
#include <stdio.h>
#include <stdlib.h>
#define PASS(cond, msg) do { if (cond) { printf("PASS: %s\n", msg); } else { printf("FAIL: %s\n", msg); exit(1); } } while (0)
#define PASS_EXCEPTION(expr, exc, msg) do { BOOL __caught = NO; @try { expr; } @catch (id localException) { __caught = YES; } PASS(__caught, msg); } while (0)
#endif*/
// #import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSUserActivity.h>
#import <Foundation/NSDate.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSKeyedArchiver.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSURL.h>

static NSString *activityType = @"com.example.activity";

int main(void)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  NSUserActivity *activity;
  NSUserActivity *roundtrip;
  NSData *archived;
  NSURL *webUrl;
  NSURL *refUrl;
  NSDate *expiry;
  NSDictionary *initialInfo;

  /* Constants should match their documented string values. */
  PASS([NSUserActivityTypeBrowsingWeb isEqual: @"NSUserActivityTypeBrowsingWeb"],
       "NSUserActivityTypeBrowsingWeb has expected value");
  PASS([NSUserActivityDocumentURLKey isEqual: @"NSUserActivityDocumentURLKey"],
       "NSUserActivityDocumentURLKey has expected value");
  PASS([NSUserActivityPersistentIdentifierKey isEqual: @"NSUserActivityPersistentIdentifierKey"],
       "NSUserActivityPersistentIdentifierKey has expected value");
  PASS([NSUserActivityReferrerURLKey isEqual: @"NSUserActivityReferrerURLKey"],
       "NSUserActivityReferrerURLKey has expected value");
  PASS([NSUserActivitySuggestedInvocationPhraseKey isEqual: @"NSUserActivitySuggestedInvocationPhraseKey"],
       "NSUserActivitySuggestedInvocationPhraseKey has expected value");
  PASS([NSUserActivityExternalRecordURLKey isEqual: @"NSUserActivityExternalRecordURLKey"],
       "NSUserActivityExternalRecordURLKey has expected value");

  /* Basic creation and defaults. */
  activity = [[NSUserActivity alloc] initWithActivityType: activityType];
  PASS(activity != nil, "Can create NSUserActivity with activity type");
  PASS([[activity activityType] isEqual: activityType], "activityType is stored");
  PASS([activity eligibleForHandoff] == YES, "eligibleForHandoff defaults to YES");
  PASS([activity eligibleForSearch] == NO, "eligibleForSearch defaults to NO");
  PASS([activity eligibleForPublicIndexing] == NO, "eligibleForPublicIndexing defaults to NO");
  PASS([activity supportsContinuationOnPhone] == NO, "supportsContinuationOnPhone defaults to NO");
  PASS([activity needsSave] == NO, "needsSave defaults to NO");
  PASS([activity isValid], "Activity starts valid");

  /* Property assignment and mutation. */
  [activity setTitle: @"Title"];
  initialInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  @"v1", @"k1",
                                  nil];
  [activity setUserInfo: initialInfo];
  [activity addUserInfoEntriesFromDictionary:
                [NSDictionary dictionaryWithObjectsAndKeys:
                                    @"v2", @"k2",
                                    nil]];
  PASS([[activity userInfo] count] == 2,
       "User info accepts initial and added entries");
  PASS([[[activity userInfo] objectForKey: @"k2"] isEqual: @"v2"],
       "User info addUserInfoEntriesFromDictionary merges values");

  [activity setRequiredUserInfoKeys: [NSSet setWithObjects: @"k1", @"k2", nil]];
  PASS([[activity requiredUserInfoKeys] count] == 2,
       "requiredUserInfoKeys is stored");

  webUrl = [NSURL URLWithString: @"https://example.com/doc"];
  refUrl = [NSURL URLWithString: @"https://example.com/ref"];
  expiry = [NSDate dateWithTimeIntervalSinceNow: 60];
  [activity setWebpageURL: webUrl];
  [activity setReferrerURL: refUrl];
  [activity setExpirationDate: expiry];
  [activity setKeywords: [NSSet setWithObjects: @"one", @"two", nil]];
  [activity setEligibleForSearch: YES];
  [activity setEligibleForPublicIndexing: YES];
  [activity setSupportsContinuationOnPhone: YES];
  [activity setNeedsSave: YES];

  PASS([[activity webpageURL] isEqual: webUrl], "webpageURL is stored");
  PASS([[activity referrerURL] isEqual: refUrl], "referrerURL is stored");
  PASS([[activity expirationDate] timeIntervalSinceDate: expiry] == 0,
       "expirationDate is stored");
  PASS([activity eligibleForSearch] == YES, "eligibleForSearch updates");
  PASS([activity eligibleForPublicIndexing] == YES, "eligibleForPublicIndexing updates");
  PASS([activity supportsContinuationOnPhone] == YES, "supportsContinuationOnPhone updates");
  PASS([activity needsSave] == YES, "needsSave updates");

  /* Archive/unarchive round-trip retains keys and flags. */
  archived = [NSKeyedArchiver archivedDataWithRootObject: activity];
  roundtrip = [NSKeyedUnarchiver unarchiveObjectWithData: archived];
  PASS(roundtrip != nil, "Round-trip decoding returns an object");
  PASS([[roundtrip activityType] isEqual: activityType], "activityType survives coding");
  PASS([[roundtrip title] isEqual: @"Title"], "title survives coding");
  PASS([[[roundtrip userInfo] objectForKey: @"k1"] isEqual: @"v1"],
       "userInfo survives coding");
  PASS(([[roundtrip requiredUserInfoKeys] isEqual:
       [NSSet setWithObjects: @"k1", @"k2", nil]]),
       "requiredUserInfoKeys survives coding");
  PASS([roundtrip eligibleForSearch] == YES &&
       [roundtrip eligibleForPublicIndexing] == YES &&
       [roundtrip supportsContinuationOnPhone] == YES,
       "boolean flags survive coding");

  /* Invalid initializers should raise. */
  PASS_EXCEPTION([[NSUserActivity alloc] initWithActivityType: nil], NSInvalidArgumentException,
                 "initWithActivityType: rejects nil");
  PASS_EXCEPTION([[NSUserActivity alloc] initWithActivityType: @""], NSInvalidArgumentException,
                 "initWithActivityType: rejects empty string");

     RELEASE(activity);
  [arp release];
  return 0;
}
