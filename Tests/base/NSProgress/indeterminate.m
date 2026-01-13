/* Test indeterminate progress behavior */

#include "Foundation/NSException.h"
#include "GNUstepBase/GNUstep.h"
#import <Foundation/NSProgress.h>
#import <Foundation/NSAutoreleasePool.h>
#import "ObjectTesting.h"

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

  LEAVE_POOL
  return 0;
}
