#import <Foundation/Foundation.h>

/* Helper program that checks for a specific environment variable
 * Usage: testenvvar VARNAME [expected_value]
 * Exit code 0 if variable exists (and matches expected value if provided)
 * Exit code 1 otherwise
 */
int
main(int argc, char **argv)
{
  NSAutoreleasePool *arp = [NSAutoreleasePool new];
  int result = 1;
  
  if (argc >= 2)
    {
      NSString *varName = [NSString stringWithUTF8String: argv[1]];
      NSDictionary *env = [[NSProcessInfo processInfo] environment];
      NSString *value = [env objectForKey: varName];
      
      if (value != nil)
        {
          GSPrintf(stdout, @"%@=%@\n", varName, value);
          
          if (argc >= 3)
            {
              NSString *expected = [NSString stringWithUTF8String: argv[2]];
              result = [value isEqualToString: expected] ? 0 : 1;
            }
          else
            {
              result = 0; // Variable exists
            }
        }
      else
        {
          GSPrintf(stdout, @"%@ not found\n", varName);
        }
    }
  
  fflush(stdout);
  [arp release];
  return result;
}
