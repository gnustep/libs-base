#ifndef second_client_h
#define second_client_h

#include <objects/Connection.h>
#include <objects/Proxy.h>
#include "second-server.h"

@interface AppellationObject : Object
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
