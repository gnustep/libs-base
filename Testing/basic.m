#include <Foundation/Foundation.h>
#include <stdio.h>


#if 1

static void test1(void)
{
    NSURL *baseURL = [NSURL fileURLWithPath:@"/usr/local/bin"];
    NSURL *url = [NSURL URLWithString:@"filename" relativeToURL:baseURL];
    NSString *result = [url absoluteString];
    NSString *expected = @"file:/usr/local/bin/filename";

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
  NSArray	*a = [NSArray arrayWithObjects: @"a", @"b", nil];


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
