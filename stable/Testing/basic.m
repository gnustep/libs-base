#include <Foundation/Foundation.h>
int main ()
{
  static unsigned char bytes[9] = {'\355', '\264', '\200', '\346', '\224', '\200', '\347', '\214', '\200'};
  NSString *s = [[NSString alloc] initWithBytes: bytes length: 9 encoding: NSUTF8StringEncoding];
  NSLog(@"s %@", s);
  return 0;
}
