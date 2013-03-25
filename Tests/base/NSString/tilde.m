#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSPathUtilities.h>
#import <Foundation/NSString.h>

int main()
{
  START_SET("tilde")
  NSString      *home = NSHomeDirectory();
  NSString      *tmp;

  PASS_EQUAL([home stringByAbbreviatingWithTildeInPath], @"~",
   "home directory becomes tilde");

  tmp = [home stringByAppendingPathComponent: @"Documents"];
  PASS_EQUAL([tmp stringByAbbreviatingWithTildeInPath], @"~/Documents",
    "the Documents subdirectory becomes ~/Documents");
  
  tmp = [home stringByAppendingString: @"/Documents"];
  PASS_EQUAL([tmp stringByAbbreviatingWithTildeInPath], @"~/Documents",
    "trailing slash removed");

  tmp = [home stringByAppendingString: @"//Documents///"];
  PASS_EQUAL([tmp stringByAbbreviatingWithTildeInPath], @"~/Documents",
    "multiple slashes removed");

  tmp = [home stringByAppendingString: @"/Documents//.."];
  PASS_EQUAL([tmp stringByAbbreviatingWithTildeInPath], @"~/Documents/..",
    "upper directory reference retained");

  tmp = [home stringByAppendingString: @"/Documents/./.."];
  PASS_EQUAL([tmp stringByAbbreviatingWithTildeInPath], @"~/Documents/./..",
    "dot directory reference retained");

  tmp  = NSHomeDirectoryForUser(@"root");
  PASS_EQUAL([tmp stringByAbbreviatingWithTildeInPath], tmp,
    "tilde does nothing for root's home");

  tmp = [NSString stringWithFormat: @"////%@//Documents///", home];
  PASS_EQUAL([tmp stringByAbbreviatingWithTildeInPath], @"~/Documents",
    "multiple slashes removed");

  PASS_EQUAL([@"//////Documents///" stringByAbbreviatingWithTildeInPath],
    @"/Documents",
    "multiple slashes removed without tilde replacement");

  PASS_EQUAL([@".//////Documents///" stringByAbbreviatingWithTildeInPath],
    @"./Documents",
    "multiple slashes removed without tilde replacement");

  END_SET("tilde")
  return 0;
}
