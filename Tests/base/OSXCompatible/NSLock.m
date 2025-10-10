#import <Foundation/Foundation.h>
#import "Testing.h"
#import "ObjectTesting.h"

int main()
{
  START_SET("NSLock GSMacOSXCompatible")

  NSLock		*lock = AUTORELEASE([NSLock new]);
  NSUserDefaults	*defs = [NSUserDefaults standardUserDefaults];
  BOOL			mode = [defs boolForKey: @"GSMacOSXCompatible"]; 

  [defs setBool: NO forKey: @"GSMacOSXCompatible"];
  PASS_EXCEPTION([lock unlock], @"NSLockException",
    "unlocking an unlocked lock raises NSLockException")

  [defs setBool: YES forKey: @"GSMacOSXCompatible"];
  PASS_RUNS([lock unlock],
    "unlocking an unlocked lock does not raise in MacOSX compatibility mode")

  [defs setBool: mode forKey: @"GSMacOSXCompatible"];

  END_SET("NSLock GSMacOSXCompatible")
  return 0;
}
