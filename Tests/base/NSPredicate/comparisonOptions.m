#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSPredicate.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"

/* The [c] and [d] options apply to equality as well as to ordering and
 * matching.
 */
int main(void)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSDictionary		*ada;
  NSDictionary		*aged;

  ada = [NSDictionary dictionaryWithObject: @"Ada" forKey: @"name"];
  aged = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 41]
				     forKey: @"age"];

  PASS(([[NSPredicate predicateWithFormat: @"name ==[c] %@", @"ada"]
    evaluateWithObject: ada]),
    "== honours the [c] option");

  PASS((![[NSPredicate predicateWithFormat: @"name !=[c] %@", @"ada"]
    evaluateWithObject: ada]),
    "!= honours the [c] option");

  PASS((![[NSPredicate predicateWithFormat: @"name == %@", @"ada"]
    evaluateWithObject: ada]),
    "== without an option is still case sensitive");

  PASS(([[NSPredicate predicateWithFormat: @"name == %@", @"Ada"]
    evaluateWithObject: ada]),
    "== matches a string that is the same");

  PASS(([[NSPredicate predicateWithFormat: @"name !=[c] %@", @"grace"]
    evaluateWithObject: ada]),
    "!=[c] is true for a string that differs by more than case");

  /* An option on a comparison of two things that are not strings changes
   * nothing: they are still compared with -isEqual:.
   */
  PASS(([[NSPredicate predicateWithFormat: @"age ==[c] %d", 41]
    evaluateWithObject: aged]),
    "an option leaves a comparison of numbers alone");

  PASS((![[NSPredicate predicateWithFormat: @"age ==[c] %d", 42]
    evaluateWithObject: aged]),
    "an option does not make unequal numbers equal");

  /* The operators that already honoured the options still do. */
  PASS(([[NSPredicate predicateWithFormat: @"name <[c] %@", @"b"]
    evaluateWithObject: ada]),
    "< honours the [c] option");

  PASS(([[NSPredicate predicateWithFormat: @"name BEGINSWITH[c] %@", @"a"]
    evaluateWithObject: ada]),
    "BEGINSWITH honours the [c] option");

  [arp release];
  return 0;
}
