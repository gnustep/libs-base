#include <Foundation/Foundation.h>
#include <gnustep/base/GCObject.h>
#include <stdio.h>


#if 1

static void test1(void)
{
    NSURL *baseURL = [NSURL fileURLWithPath:@"/usr/local/bin"];
    NSURL *url = [NSURL URLWithString:@"filename" relativeToURL:baseURL];
    NSString *result = [url absoluteString];
    NSString *expected = @"file://localhost/usr/local/bin/filename";

    if ([result isEqualToString:expected])
        NSLog(@"test 1 ok");
    else
        NSLog(@"-[NSURL absoluteString] returned \"%@\", expected \"%@\"", result, expected);
}

static void test2(void)
{
    NSURL *url = [NSURL fileURLWithPath:@"/tmp/foo"];
    NSString *result = [url path];
    NSString *expected = @"/tmp/foo";

    if ([result isEqualToString:expected])
        NSLog(@"Test 2 ok");
    else
        NSLog(@"-[NSURL path] returned \"%@\", expected \"%@\"", result, expected);
}

int main ()
{
  id	pool = [NSAutoreleasePool new];
  id	o = [NSObject new];
  id	x;
  NSString	*s;
  NSArray	*a = [NSArray arrayWithObjects: @"a", @"b", nil];
  struct aa {char a; double b; char c;} bb[2];
  struct objc_struct_layout layout;
  unsigned i;

  printf("size = %d\n", objc_sizeof_type(@encode(struct aa)));
  printf("pos = %d\n", (void*)&bb[1] - (void*)&bb[0]);

  objc_layout_structure (@encode(struct aa), &layout);
  while (objc_layout_structure_next_member (&layout))
    {
      int position, align;
      const char *type;

      objc_layout_structure_get_info (&layout, &position, &align, &type);
      printf ("element %d has offset %d, alignment %d\n",
              i++, position, align);
    }



  o = [GCMutableArray new];
  x = [GCMutableArray new];
  [o addObject: x];
  [x addObject: o];
  [o release];
  [x release];
  [GCObject gcCollectGarbage];

  o = [NSDictionary dictionaryWithObjectsAndKeys:
   @"test", @"one",
   [NSNumber numberWithBool: YES], @"two",
   [NSDate date], @"three",
   [NSNumber numberWithInt: 33], @"four",
   [NSNumber numberWithFloat: 4.5], @"five",
   nil];
  s = [o description];
  NSLog(@"%@", s);
  x = [s propertyList];
  NSLog(@"%d", [o isEqual: x]);
  

    test1();
    test2();

  printf ("Hello from object at 0x%x\n", (unsigned)[o self]);

  NSLog(@"Value for foo is %@", [a valueForKey: @"foo"]);

  [o release];
  o = [NSString stringWithFormat: @"/proc/%d/status", getpid()];
  NSLog(@"'%@'", o);
  o = [NSString stringWithContentsOfFile: o];
  NSLog(@"'%@'", o);

  exit (0);
}
#else
int main (int argc, char **argv)
{
  NSString *string;
  id	pool = [NSAutoreleasePool new];
  NSProcessInfo	*info = [NSProcessInfo processInfo];
  NSUserDefaults	*defaults;
  
  NSLog(@"Temporary directory - %@", NSTemporaryDirectory());
  [info setProcessName: @"TestProcess"];
  defaults = [NSUserDefaults standardUserDefaults];
  NSLog(@"%@", [defaults  dictionaryRepresentation]);
  return 0;
}
#endif
