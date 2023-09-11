#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  START_SET("Unbalanced unlocking")

  NSLock		*lock;

  lock = [NSLock new];

  PASS_EXCEPTION([lock unlock], @"NSLockException",
    "unlocking an unlocked lock raises NSLockException")

  [[NSUserDefaults standardUserDefaults] setBool: YES
					  forKey: @"GSMacOSXCompatible"];

  PASS_RUNS([lock unlock],
    "unlocking an unlocked lock does not raise in MacOSX compatibility mode")

  END_SET("Unbalanced unlocking")
  return 0;
}
