/* Demonstration of windows NSTask launching bug */

#include "Foundation/Foundation.h"

int main()
{
  CREATE_AUTORELEASE_POOL(arp);

  NSTask        *task;
  NSProcessInfo *info;
  NSDictionary  *env;
  NSString      *path;

  info = [NSProcessInfo processInfo];
  env  = [info environment];

#if defined(__MINGW32__)
  path = @"C:\\WINDOWS\\system32\\net.exe";
//  path = @"E:\\WINNT\\system32\\net.exe";
#else
  path = @"/bin/ls";
#endif
  printf("Determined command to run as '%s'\n",[path lossyCString]);

  task = [NSTask launchedTaskWithLaunchPath: path
		 arguments: [NSArray array]];
  [task waitUntilExit];

  printf("First task has completed\n");


#if defined(__MINGW32__)
  path = @"C:\\WINDOWS\\system32\\mem.exe";
//  path = @"E:\\WINNT\\system32\\mem.exe";
#else
  path = @"/bin/ls";
#endif
  printf("Determined command to run as '%s'\n",[path lossyCString]);

  task = [NSTask launchedTaskWithLaunchPath: path
		 arguments: [NSArray array]];
  [task waitUntilExit];

  printf("Second task has completed\n");

  DESTROY(arp);
  return 0;
}
