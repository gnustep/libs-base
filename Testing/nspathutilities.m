/* Test/example program for the base library

   Copyright (C) 2005 Free Software Foundation, Inc.
   
  Copying and distribution of this file, with or without modification,
  are permitted in any medium without royalty provided the copyright
  notice and this notice are preserved.

   This file is part of the GNUstep Base Library.
*/
/* TESTING:  NSPathUtilities.h ************************************************
*                                                                             *
* Author:  Sheldon Gill                                                       *
* Date:    20-Dec-2003                                                        *
*                                                                             *
*  Lists all search paths                                                     *
*                                                                             *
**************************************************************************** */

#include <Foundation/NSString.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSAutoreleasePool.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSException.h>

/* Define any unknown directory keys */
#ifndef NSDocumentDirectory
#define NSDocumentDirectory       155
#endif
#ifndef GSFrameworksDirectory
#define GSFrameworksDirectory  153
#endif
#ifndef GSFontsDirectory
#define GSFontsDirectory       154
#endif

void print_paths(NSArray *paths)
{
  int i, count;

  count = [paths count];
  if (count==1)
    {
      printf("%s\n", [[paths objectAtIndex:0] cString]);
    }
  else
    {
      printf("<list>\n");
      for ( i = 0; i < count; i++ )
        {
          printf("    %s\n", [[paths objectAtIndex:i] cString]);
        }
    }
}


int main( int argc, char *argv[] )
{
  NSAutoreleasePool *arp;
  
  NSArray      *domain_names;
  NSArray      *directory_key_names;
  NSArray      *paths;
  int i, j, k;

  BOOL tilde_expansion = YES;
  
#define DIR_KEYS      16
#define DOMAIN_MASKS  5

  NSSearchPathDomainMask      domain_masks[DOMAIN_MASKS] = {
    NSUserDomainMask,
    NSLocalDomainMask,
    NSNetworkDomainMask,
    NSSystemDomainMask,
    NSAllDomainsMask
    };

  NSSearchPathDirectory directory_keys[DIR_KEYS] = {
    NSApplicationDirectory,
    NSDemoApplicationDirectory,
    NSDeveloperApplicationDirectory,
    NSAdminApplicationDirectory,
    NSLibraryDirectory,
    NSDeveloperDirectory,
    NSUserDirectory,
    NSDocumentationDirectory,
    NSDocumentDirectory,
    NSAllApplicationsDirectory,
    NSAllLibrariesDirectory,
    GSLibrariesDirectory,
    GSToolsDirectory,
    GSApplicationSupportDirectory,
    GSFrameworksDirectory,
    GSFontsDirectory
  };
  
  NSSearchPathDirectory  key;
  NSSearchPathDomainMask domain;
    
  printf("TESTING: NSPathUtilities.h\n");
  
  arp = [NSAutoreleasePool new];

  if (argc > 1)
    tilde_expansion = NO;
    
  printf("Begin...\n");
    
  domain_names = [NSArray arrayWithObjects:
    @"NSUserDomainMask", 
    @"NSLocalDomainMask", 
    @"NSNetworkDomainMask", 
    @"NSSystemDomainMask", 
    @"NSAllDomainsMask",
    nil
    ];

  directory_key_names = [NSArray arrayWithObjects:
    @"NSApplicationDirectory",
    @"NSDemoApplicationDirectory",
    @"NSDeveloperApplicationDirectory",
    @"NSAdminApplicationDirectory",
    @"NSLibraryDirectory",
    @"NSDeveloperDirectory",
    @"NSUserDirectory",
    @"NSDocumentationDirectory",
    @"NSDocumentDirectory",
    @"NSAllApplicationsDirectory",
    @"NSAllLibrariesDirectory",
    @"GSLibrariesDirectory",
    @"GSToolsDirectory",
    @"GSApplicationSupportDirectory",
    @"GSFrameworksDirectory",
    @"GSFontsDirectory",
    nil
    ];

  printf("NSSearchPathForDirectoriesInDomains()\n");  
  for ( i = 0 ; i < DOMAIN_MASKS ; i++ )
    {
      printf("Domain: %s\n",[[domain_names objectAtIndex: i] cString]);
      domain = domain_masks[i];

      for ( j = 0 ; j < DIR_KEYS ; j++ )
        {          
          printf("  %s = ",[[directory_key_names objectAtIndex: j] cString]);
          key = directory_keys[j];
          
          paths = NSSearchPathForDirectoriesInDomains( key, domain, tilde_expansion );
          if ([paths count] == 0)
            {
              printf("<Empty>\n");
            }
          else
            {
              print_paths(paths);
            }
        }
    }
  printf("End NSSearchPathForDirectoriesInDomains\n\n");

  printf("Begin NSUser functions...\n");
  GSPrintf(stdout,@"User name is '%@'\n",NSUserName());
  GSPrintf(stdout,@"Home directory is '%@'\n",NSHomeDirectory());
  GSPrintf(stdout,@"GSDefaultsRoot for user is '%@'\n",GSDefaultsRootForUser(NSUserName()));
  GSPrintf(stdout,@"Temp for user is '%@'\n",NSTemporaryDirectory());
  printf("End NSUser functions\n\n");

  [arp release];
 
  printf("End Testing!\n");
  return 0;
}
