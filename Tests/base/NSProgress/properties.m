/* Test the properties of NSProgress and their KVO notifications.
 * The expected behaviour was verified on macOS 26.6.2 (25G83).
 */

#import <Foundation/NSObject.h>
#import <Foundation/NSKeyValueObserving.h>
#import <Foundation/NSProgress.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSValue.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSException.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

@interface Observer : NSObject
{
    @public
    NSMutableArray *keyPaths;
}
@end

@implementation Observer

- (id) init {
    if ((self = [super init]) != nil) {
        keyPaths = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc {
    [keyPaths release];
    [super dealloc];
}

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    [keyPaths addObject: keyPath];
}

@end

void checkUnchangedValues(void) {
    NSProgress *p = [NSProgress progressWithTotalUnitCount: 10];
    Observer *o = [[Observer alloc] init];

    [p addObserver: o forKeyPath: @"kind" options: 0 context: NULL];
    [p addObserver: o forKeyPath: @"localizedDescription" options: 0 context: NULL];
    [p addObserver: o forKeyPath: @"totalUnitCount" options: 0 context: NULL];
    [p addObserver: o forKeyPath: @"completedUnitCount" options: 0 context: NULL];

    [p setKind: @"NSProgressKindFile"];
    [p setLocalizedDescription: @"a"];
    [o->keyPaths removeAllObjects];
    [p setKind: @"NSProgressKindFile"];
    [p setLocalizedDescription: @"a"];
    [p setTotalUnitCount: 10];
    [p setCompletedUnitCount: 0];
    PASS([o->keyPaths count] == 0, "setting unchanged values does not notify observers");

    [p removeObserver: o forKeyPath: @"kind"];
    [p removeObserver: o forKeyPath: @"localizedDescription"];
    [p removeObserver: o forKeyPath: @"totalUnitCount"];
    [p removeObserver: o forKeyPath: @"completedUnitCount"];
    [o release];
}

void checkUserInfo(void) {
    NSProgress *p = [NSProgress progressWithTotalUnitCount: 10];
    NSDictionary *userInfo = [p userInfo];
    NSURL *url = [NSURL fileURLWithPath: @"/tmp/x"];
    Observer *o = [[Observer alloc] init];

    [p setUserInfoObject: @"x" forKey: @"someKey"];
    PASS_EQUAL([userInfo objectForKey: @"someKey"], @"x", "userInfo shows later changes");

    [p setEstimatedTimeRemaining: [NSNumber numberWithInt: 5]];
    [p setThroughput: [NSNumber numberWithInt: 9]];
    [p setFileTotalCount: [NSNumber numberWithInt: 3]];
    [p setFileCompletedCount: [NSNumber numberWithInt: 1]];
#ifdef GNUSTEP
    [p setFileUrl: url];
#else
    [p setFileURL: url];
#endif
    [p setFileOperationKind: @"NSProgressFileOperationKindDownloading"];
    PASS_EQUAL([userInfo objectForKey: @"NSProgressEstimatedTimeRemainingKey"], [NSNumber numberWithInt: 5], "estimatedTimeRemaining is stored in userInfo");
    PASS_EQUAL([userInfo objectForKey: @"NSProgressThroughputKey"], [NSNumber numberWithInt: 9], "throughput is stored in userInfo");
    PASS_EQUAL([userInfo objectForKey: @"NSProgressFileTotalCountKey"], [NSNumber numberWithInt: 3], "fileTotalCount is stored in userInfo");
    PASS_EQUAL([userInfo objectForKey: @"NSProgressFileCompletedCountKey"], [NSNumber numberWithInt: 1], "fileCompletedCount is stored in userInfo");
    PASS_EQUAL([userInfo objectForKey: @"NSProgressFileURLKey"], url, "fileUrl is stored in userInfo");
    PASS_EQUAL([userInfo objectForKey: @"NSProgressFileOperationKindKey"], @"NSProgressFileOperationKindDownloading", "fileOperationKind is stored in userInfo");

    [p setUserInfoObject: [NSNumber numberWithInt: 7] forKey: @"NSProgressFileTotalCountKey"];
    PASS_EQUAL([p fileTotalCount], [NSNumber numberWithInt: 7], "fileTotalCount is read from userInfo");
    [p setUserInfoObject: nil forKey: @"NSProgressFileTotalCountKey"];
    PASS([p fileTotalCount] == nil, "setting nil removes the userInfo object");

    [p addObserver: o forKeyPath: @"localizedDescription" options: 0 context: NULL];
    [p addObserver: o forKeyPath: @"localizedAdditionalDescription" options: 0 context: NULL];
    [p addObserver: o forKeyPath: @"fileTotalCount" options: 0 context: NULL];
    [p setUserInfoObject: @"y" forKey: @"someKey"];
    PASS([o->keyPaths count] == 0, "changing other userInfo keys does not notify observers");
    [p setFileTotalCount: [NSNumber numberWithInt: 4]];
    PASS([o->keyPaths containsObject: @"localizedDescription"], "fileTotalCount affects localizedDescription");
    PASS([o->keyPaths containsObject: @"localizedAdditionalDescription"], "fileTotalCount affects localizedAdditionalDescription");
    PASS([o->keyPaths containsObject: @"fileTotalCount"] == NO, "fileTotalCount observers are not notified");
    [o->keyPaths removeAllObjects];
    [p setEstimatedTimeRemaining: [NSNumber numberWithInt: 6]];
    PASS([o->keyPaths isEqual: [NSArray arrayWithObject: @"localizedAdditionalDescription"]], "estimatedTimeRemaining affects localizedAdditionalDescription");
    [o->keyPaths removeAllObjects];
    [p setKind: @"NSProgressKindFile"];
    PASS([o->keyPaths containsObject: @"localizedAdditionalDescription"], "kind affects localizedAdditionalDescription");

    [p removeObserver: o forKeyPath: @"localizedDescription"];
    [p removeObserver: o forKeyPath: @"localizedAdditionalDescription"];
    [p removeObserver: o forKeyPath: @"fileTotalCount"];
    [o release];
}

void checkUserInfoCollection(void) {
    NSProgress *p = [NSProgress progressWithTotalUnitCount: 10];
    NSMutableArray *keys = [NSMutableArray array];
    NSDictionary *copy;
    NSMutableDictionary *mutableCopy;
    id key;
    NSEnumerator *e;

    [p setUserInfoObject: @"1" forKey: @"k1"];
    [p setUserInfoObject: @"2" forKey: @"k2"];
    for (key in [p userInfo]) {
        [keys addObject: key];
    }
    PASS([keys count] == 2 && [keys containsObject: @"k1"] && [keys containsObject: @"k2"], "userInfo supports fast enumeration");
    e = [[p userInfo] keyEnumerator];
    [keys removeAllObjects];
    while ((key = [e nextObject]) != nil) {
        [keys addObject: key];
    }
    PASS([keys count] == 2, "userInfo supports key enumerators");

    copy = [[[p userInfo] copy] autorelease];
    mutableCopy = [[[p userInfo] mutableCopy] autorelease];
    [p setUserInfoObject: @"3" forKey: @"k3"];
    PASS([copy count] == 2, "a copy of userInfo does not change");
    [mutableCopy setObject: @"4" forKey: @"k4"];
    PASS([mutableCopy count] == 3 && [[p userInfo] objectForKey: @"k4"] == nil, "a mutable copy of userInfo is separate");
    PASS_EXCEPTION([(NSMutableDictionary *)[p userInfo] setObject: @"5" forKey: @"k5"],
                   NSInvalidArgumentException,
                   "userInfo cannot be changed directly");
}

/* Changes the observed progress again before it changes */
@interface PriorObserver : NSObject
{
    @public
    BOOL changed;
}
@end

@implementation PriorObserver

- (void) observeValueForKeyPath:(NSString *) keyPath
                       ofObject:(id) object
                         change:(NSDictionary *) change
                        context:(void *) context {
    if (!changed && [[change objectForKey: NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
        changed = YES;
        if ([keyPath isEqual: @"kind"]) {
            [(NSProgress *)object setKind: @"nested"];
        } else if ([keyPath isEqual: @"totalUnitCount"]) {
            [(NSProgress *)object setCompletedUnitCount: 5];
        } else if (context != NULL) {
            [(NSProgress *)object setTotalUnitCount: 20];
        } else {
            [(NSProgress *)object setCompletedUnitCount: 7];
        }
    }
}

@end

void checkChangingFromPriorObserver(void) {
    NSProgress *p = [NSProgress progressWithTotalUnitCount: 10];
    NSProgress *parent = [NSProgress progressWithTotalUnitCount: 100];
    PriorObserver *o = [[PriorObserver alloc] init];

    [p addObserver: o forKeyPath: @"kind" options: NSKeyValueObservingOptionPrior context: NULL];
    [p setKind: @"outer"];
    PASS_EQUAL([p kind], @"outer", "outer change of the kind wins");
    [p removeObserver: o forKeyPath: @"kind"];

    o->changed = NO;
    [parent addChild: p withPendingUnitCount: 100];
    [p addObserver: o forKeyPath: @"completedUnitCount" options: NSKeyValueObservingOptionPrior context: NULL];
    [p setCompletedUnitCount: 5];
    PASS([p completedUnitCount] == 5, "outer change of the completed unit count wins");
    PASS([parent fractionCompleted] == 0.5, "parent follows both changes");
    [p removeObserver: o forKeyPath: @"completedUnitCount"];

    /* Changes of other properties are kept */
    p = [NSProgress progressWithTotalUnitCount: 10];
    o->changed = NO;
    [p addObserver: o forKeyPath: @"totalUnitCount" options: NSKeyValueObservingOptionPrior context: NULL];
    [p setTotalUnitCount: 20];
    PASS([p totalUnitCount] == 20 && [p completedUnitCount] == 5, "completed unit count changed before the total is kept");
    PASS([p fractionCompleted] == 0.25, "fractionCompleted follows both changes");
    [p removeObserver: o forKeyPath: @"totalUnitCount"];
    [p setCompletedUnitCount: 10];
    PASS([p completedUnitCount] == 10, "progress can still be changed");

    p = [NSProgress progressWithTotalUnitCount: 10];
    o->changed = NO;
    [p addObserver: o forKeyPath: @"completedUnitCount" options: NSKeyValueObservingOptionPrior context: (void *)1];
    [p setCompletedUnitCount: 5];
    PASS([p totalUnitCount] == 20 && [p completedUnitCount] == 5, "total changed before the completed unit count is kept");
    PASS([p fractionCompleted] == 0.25, "fractionCompleted follows both changes");
    [p removeObserver: o forKeyPath: @"completedUnitCount"];
    [o release];
}

void checkNotificationOrder(void) {
    NSProgress *p = [NSProgress progressWithTotalUnitCount: 10];
    Observer *o = [[Observer alloc] init];
    NSArray *expected;

    [p addObserver: o forKeyPath: @"fractionCompleted" options: 0 context: NULL];
    [p addObserver: o forKeyPath: @"finished" options: 0 context: NULL];
    [p addObserver: o forKeyPath: @"completedUnitCount" options: 0 context: NULL];
    [p addObserver: o forKeyPath: @"totalUnitCount" options: 0 context: NULL];

    [p setCompletedUnitCount: 10];
    expected = [NSArray arrayWithObjects: @"finished", @"completedUnitCount", @"fractionCompleted", nil];
    PASS_EQUAL(o->keyPaths, expected, "order of notifications when completing");
    [o->keyPaths removeAllObjects];
    [p setTotalUnitCount: 20];
    expected = [NSArray arrayWithObjects: @"finished", @"totalUnitCount", @"fractionCompleted", nil];
    PASS_EQUAL(o->keyPaths, expected, "order of notifications when changing the total");

    [p removeObserver: o forKeyPath: @"fractionCompleted"];
    [p removeObserver: o forKeyPath: @"finished"];
    [p removeObserver: o forKeyPath: @"completedUnitCount"];
    [p removeObserver: o forKeyPath: @"totalUnitCount"];
    [o release];
}

int main(void)
{
    ENTER_POOL

    checkUnchangedValues();
    checkUserInfo();
    checkUserInfoCollection();
    checkChangingFromPriorObserver();
    checkNotificationOrder();

    LEAVE_POOL
    return 0;
}
