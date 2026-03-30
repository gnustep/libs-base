#import "Testing.h"
#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

static NSString*
stringFromSet(NSCharacterSet *set)
{
  NSMutableString       *m = [NSMutableString stringWithCapacity: 100];
  int			plane;

  for (plane = 0; plane <= 16; plane++)
    {
      if ([set hasMemberInPlane: plane])
        {
          UTF32Char c;

          for (c = plane << 16; c < (plane+1) << 16; c++)
            {
              if ([set longCharacterIsMember: c])
                {
                  UTF32Char     c1 = GSSwapHostI64ToLittle(c);
                  NSString      *s;

                  s = [[NSString alloc] initWithBytes: &c1
		    length: 4
		    encoding: NSUTF32LittleEndianStringEncoding];
                  [m appendString: s];
		  RELEASE(s);
                }
            }
        }
    }
  return m;
}

int main()
{
  ENTER_POOL
  NSCharacterSet	*set;
  NSString		*str;

  set = [NSCharacterSet URLPathAllowedCharacterSet];
  str = stringFromSet(set);
  PASS_EQUAL(str, @"!$&'()*+,-./0123456789:;=@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~", "URLPathAllowedCharacterSet")
  
  LEAVE_POOL

  return 0;
}
