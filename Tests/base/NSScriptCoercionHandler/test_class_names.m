#import <Foundation/Foundation.h>

int main()
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  NSNumber *num = [NSNumber numberWithInt: 42];
  
  NSLog(@"NSNumber class: %@", NSStringFromClass([NSNumber class]));
  NSLog(@"num class: %@", NSStringFromClass([num class]));
  NSLog(@"num's class == NSNumber: %d", [num class] == [NSNumber class]);
  NSLog(@"num isKindOfClass NSNumber: %d", [num isKindOfClass: [NSNumber class]]);
  
  Class c = [num class];
  while (c != Nil)
    {
      NSLog(@"  Hierarchy: %@", NSStringFromClass(c));
      c = [c superclass];
    }
  
  [pool release];
  return 0;
}
