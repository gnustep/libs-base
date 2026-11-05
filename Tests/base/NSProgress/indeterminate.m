/* Test indeterminate progress behavior */

#include "Foundation/NSException.h"
#include "GNUstepBase/GNUstep.h"
#import <Foundation/NSProgress.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSKeyValueObserving.h>
#import "ObjectTesting.h"

@interface Observer : NSObject
{
  @public
  int observations;
}
@end

@implementation Observer
- (void) observeValueForKeyPath: (NSString *)keyPath
                       ofObject: (id)object
                         change: (NSDictionary *)change
                        context: (void *)context
{
  observations += 1;
}
@end

int main(void)
{
  ENTER_POOL

  NSProgress *zero = [NSProgress progressWithTotalUnitCount: 0];
  [zero setCompletedUnitCount: 0];
  PASS([zero totalUnitCount] == 0, "totalUnitCount is 0");
  PASS([zero completedUnitCount] == 0, "completedUnitCount is 0");
  PASS([zero isIndeterminate] == YES, "0/0 progress is indeterminate");
  PASS([zero fractionCompleted] == 0.0, "indeterminate fractionCompleted is 0.0");
  PASS([zero isFinished] == NO, "indeterminate progress is not finished");

  NSProgress *negativeTotal = [NSProgress progressWithTotalUnitCount: -1];
  PASS([negativeTotal totalUnitCount] == -1, "totalUnitCount is negative");
  PASS([negativeTotal isIndeterminate] == YES, "negative totalUnitCount is indeterminate");
  PASS([negativeTotal fractionCompleted] == 0.0, "indeterminate fractionCompleted is 0.0 (negative total)");
  PASS([negativeTotal isFinished] == NO, "indeterminate progress is not finished (negative total)");

  NSProgress *negativeCompleted = [NSProgress progressWithTotalUnitCount: 5];
  [negativeCompleted setCompletedUnitCount: -1];
  PASS([negativeCompleted completedUnitCount] == -1, "completedUnitCount is negative");
  PASS([negativeCompleted isIndeterminate] == YES, "negative completedUnitCount is indeterminate");
  PASS([negativeCompleted fractionCompleted] == 0.0, "indeterminate fractionCompleted is 0.0 (negative completed)");
  PASS([negativeCompleted isFinished] == NO, "indeterminate progress is not finished (negative completed)");

  NSProgress *wasIndeterminate = [NSProgress progressWithTotalUnitCount: 0];
  Observer *o = [[Observer alloc] init];
  [wasIndeterminate addObserver: o forKeyPath: @"finished" options: 0 context: NULL];
  [wasIndeterminate setCompletedUnitCount: 1];
  PASS([wasIndeterminate isFinished], "1/0 progress is finished");
  PASS([wasIndeterminate fractionCompleted] == 1.0, "1/0 fractionCompleted is 1.0");
  PASS(o->observations == 1, "received KVO notification for finished");
  [wasIndeterminate setCompletedUnitCount: 0];
  PASS([wasIndeterminate isFinished] == NO, "returning to 0/0 unfinishes the progress");
  PASS(o->observations == 2, "received KVO notification for unfinished");
  [wasIndeterminate setTotalUnitCount: 1];
  [wasIndeterminate setCompletedUnitCount: 1];
  PASS([wasIndeterminate isFinished], "progress finishes after being indeterminate");
  PASS([wasIndeterminate fractionCompleted] == 1.0, "fractionCompleted is 1.0 after being indeterminate");
  PASS(o->observations == 3, "received KVO notification for finished again");
  [wasIndeterminate removeObserver: o forKeyPath: @"finished"];
  [o release];

  LEAVE_POOL
  return 0;
}
