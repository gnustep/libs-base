#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSValue.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSAutoreleasePool.h>

int
main(int argc, char** argv, char** envp)
{
  NSString	*strs[100000];
  NSMutableDictionary	*dict;
  NSDate	*when;
  int		i, j;
  NSAutoreleasePool	*arp;
  id a, b;			/* dictionaries */
  id enumerator;
  id objects, keys;
  id key;
  BOOL ok;
  id o1, o2, o3, o4, o5, o6;
  NSMutableDictionary	*d1, *d2;

  arp = [NSAutoreleasePool new];

  o1 = [[NSNumber numberWithInt:1] stringValue];
  o2 = [[NSNumber numberWithInt:2] stringValue];
  o3 = [[NSNumber numberWithInt:3] stringValue];
  o4 = [[NSNumber numberWithInt:4] stringValue];
  o5 = [[NSNumber numberWithInt:5] stringValue];
  o6 = [[NSNumber numberWithInt:6] stringValue];

  d1 = [[NSMutableDictionary new] autorelease];
  [d1 setObject:o1 forKey:o1];
  [d1 setObject:o2 forKey:o2];
  [d1 setObject:o3 forKey:o3];
  
  d2 = [[NSMutableDictionary new] autorelease];
  [d2 setObject:o4 forKey:o4];
  [d2 setObject:o5 forKey:o5];
  [d2 setObject:o6 forKey:o6];

  [d1 addEntriesFromDictionary: d2];

  enumerator = [d1 objectEnumerator];
  while ((b = [enumerator nextObject]))
    printf("%s ", [b cString]);
  printf("\n");

  behavior_set_debug(0);

  objects = [NSArray arrayWithObjects:
		     @"vache", @"poisson", @"cheval", @"poulet", nil];
  keys = [NSArray arrayWithObjects:
		  @"cow", @"fish", @"horse", @"chicken", nil];
  a = [NSDictionary dictionaryWithObjects:objects forKeys:keys];

  printf("NSDictionary has count %d\n", [a count]);
  key = @"fish";
  printf("Object at key %s is %s\n", 
	 [key cString],
	 [[a objectForKey:key] cString]);

  assert([a count] == [[a allValues] count]);
  
  enumerator = [a objectEnumerator];
  while ((b = [enumerator nextObject]))
    printf("%s ", [b cString]);
  printf("\n");

  enumerator = [a keyEnumerator];
  while ((b = [enumerator nextObject]))
    printf("%s ", [b cString]);
  printf("\n");

  b = [a mutableCopy];
  assert([b count]);

  ok = [b isEqual: a];
  assert(ok);

  [b setObject:@"formi" forKey:@"ant"];
  [b removeObjectForKey:@"horse"];


  when = [NSDate date];
  dict = [NSMutableDictionary dictionaryWithCapacity: 100];
  for (i = 0; i < 10; i++)
    {
      strs[i] = [NSString stringWithFormat: @"Dictkey-%d", i];
      [dict setObject: strs[i] forKey: strs[i]];
    }
  printf("    10 creation: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
printf("%s\n", [[[dict allKeys] description] cString]);
    
  when = [NSDate date];
  for (i = 0; i < 100000; i++) {
    for (j = 0; j < 10; j++) {
      NSString	*val = [dict objectForKey: strs[j]];
    }
  }
  printf("    10 For: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
  [arp release];

  arp = [NSAutoreleasePool new];

  when = [NSDate date];
  dict = [NSMutableDictionary dictionaryWithCapacity: 100];
  for (i = 0; i < 100; i++)
    {
      strs[i] = [NSString stringWithFormat: @"Dictkey-%d", i];
      [dict setObject: strs[i] forKey: strs[i]];
    }
  printf("   100 creation: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
    
  when = [NSDate date];
  for (i = 0; i < 10000; i++) {
    for (j = 0; j < 100; j++) {
      NSString	*val = [dict objectForKey: strs[j]];
    }
  }
  printf("   100 For: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
  [arp release];

  arp = [NSAutoreleasePool new];

  when = [NSDate date];
  dict = [NSMutableDictionary dictionaryWithCapacity: 1000];
  for (i = 0; i < 1000; i++)
    {
      strs[i] = [NSString stringWithFormat: @"Dictkey-%d", i];
      [dict setObject: strs[i] forKey: strs[i]];
    }
  printf("  1000 creation: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
    
  when = [NSDate date];
  for (i = 0; i < 1000; i++) {
    for (j = 0; j < 1000; j++) {
      NSString	*val = [dict objectForKey: strs[j]];
    }
  }
  printf("  1000 For: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
  [arp release];

  arp = [NSAutoreleasePool new];

  when = [NSDate date];
  dict = [NSMutableDictionary dictionaryWithCapacity: 10000];
  for (i = 0; i < 10000; i++)
    {
      strs[i] = [NSString stringWithFormat: @"Dictkey-%d", i];
      [dict setObject: strs[i] forKey: strs[i]];
    }
  printf(" 10000 creation: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
    
  when = [NSDate date];
  for (i = 0; i < 100; i++) {
    for (j = 0; j < 10000; j++) {
      NSString	*val = [dict objectForKey: strs[j]];
    }
  }
  printf(" 10000 For: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
  [arp release];

  arp = [NSAutoreleasePool new];

  when = [NSDate date];
  dict = [NSMutableDictionary dictionaryWithCapacity: 100000];
  for (i = 0; i < 100000; i++)
    {
      strs[i] = [NSString stringWithFormat: @"Dictkey-%d", i];
      [dict setObject: strs[i] forKey: strs[i]];
    }
  printf("100000 creation: %f\n", [[NSDate date] timeIntervalSinceDate: when]);
    
  when = [NSDate date];
  for (i = 0; i < 10; i++) {
    for (j = 0; j < 100000; j++) {
      NSString	*val = [dict objectForKey: strs[j]];
    }
  }
  printf("100000 For: %f\n", [[NSDate date] timeIntervalSinceDate: when]);

  exit(0);
}
