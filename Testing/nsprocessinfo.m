#include <<Foundation/NSProcessInfo.h>
#include <<Foundation/NSString.h>
#include <<Foundation/NSArray.h>
#include <<Foundation/NSDictionary.h>
#include <<Foundation/NSDate.h>

int main(int argc, char *argv[]) 
{
  NSProcessInfo *pi = [NSProcessInfo processInfo];
  NSString* aString;
  NSString* aKey;
  NSEnumerator* enumerator;


  enumerator = [[pi arguments] objectEnumerator];
  while (aString = [enumerator nextObject])
    printf("-->%s",[aString cString]);
        
  enumerator = [[pi environment] keyEnumerator];
  while (aKey = [enumerator nextObject])
    printf("++>%s=%s",[aKey cString],[[[pi environment] 
				       objectForKey:aKey] cString]);
        
  printf("==>%s",[[pi hostName] cString]);
  printf("==>%s",[[pi processName] cString]);
  printf("==>%s",[[pi globallyUniqueString] cString]);
}
