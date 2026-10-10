#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#import <Foundation/NSPredicate.h>
#import "GNUstepBase/GSConfig.h"

static BOOL
found(NSString *s, NSString *t, NSUInteger mask)
{
  return [s rangeOfString: t options: mask].location != NSNotFound;
}

int main()
{
  START_SET("NSString diacritic insensitive search")
#if !(GS_USE_ICU == 1)
    SKIP("library built without ICU")
#else
  NSAutoreleasePool     *arp = [NSAutoreleasePool new];
  NSUInteger            cd = NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch;

  PASS(found(@"Green TEA", @"tea", cd),
    "case and diacritic insensitive: a different case is found");
  PASS(found(@"Cafe au lait", @"café", cd),
    "case and diacritic insensitive: a different accent is found");
  PASS(found(@"CAFÉ", @"cafe", cd),
    "case and diacritic insensitive: both at once");
  PASS(!found(@"Tea", @"coffee", cd),
    "case and diacritic insensitive: another word is not found");
  PASS(found(@"Cafe au lait", @"café", NSDiacriticInsensitiveSearch),
    "diacritic insensitive: a different accent is found");
  PASS(found(@"Crème brûlée", @"brulee", NSDiacriticInsensitiveSearch),
    "diacritic insensitive: several accents");
  PASS(([[NSPredicate predicateWithFormat: @"SELF CONTAINS[cd] %@", @"chaï"]
    evaluateWithObject: @"Chai"]), "CONTAINS[cd] finds it");
  PASS([@"café" compare: @"CAFE" options: cd] == NSOrderedSame,
    "compare: case and diacritic insensitive");
  PASS([@"café" compare: @"cafe" options: NSCaseInsensitiveSearch] != NSOrderedSame,
    "compare: case insensitive keeps the accent");
  PASS([@"café" compare: @"CAFÉ" options: NSCaseInsensitiveSearch] == NSOrderedSame,
    "compare: case insensitive ignores case");

  [arp release];
#endif
  END_SET("NSString diacritic insensitive search")
  return 0;
}
