/* Test for unicode noncharacter codepoints
 */
#import "Testing.h"

#import <Foundation/NSString.h>

int main(int argc, char **argv)
{
  NSString *str;
  unichar u;

  u = (unichar)0xffff;
  str = [[NSString alloc] initWithCharacters: &u length: 1];
  PASS([str length] == 1, "ffff codpepoint is permitted in string");
  PASS([str characterAtIndex: 0] == 0xffff, "ffff is returned properly");
  [str release];

  return 0;
}

