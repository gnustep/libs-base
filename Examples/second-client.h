#ifndef second_client_h
#define second_client_h

#include <gnustep/base/Connection.h>
#include <gnustep/base/Proxy.h>
#include "second-server.h"

@interface AppellationObject : NSObject
{
  const char *appellation;
}

@end

@implementation AppellationObject

- setAppellation: (const char *)n
{
  appellation = n;
  return self;
}

- (const char *) appellation
{
  return appellation;
}

@end

#endif
