#include <gnustep/base/Port.h>
#include <rpc/rpc.h>

@interface SunRpcPort : Port
{
}

@end

@implementation SunRpcPort

+ newRegisteredPortWithName: (const char *)n
{
  SunRpcPort *newPort;
  unsigned long prognum, versnum, procnum;
  char *(*procname)();
  xdrproc_t *(*procname)();

  
  if (registerrpc(prognum, versnum, procnum, procname, inproc, outproc))
    [self error:"registerrpc failed"];
  return newPort;
}

+ newPortFromRegisterWithName: (const char *)n onHost: (const char *)host
{
  [self notImplemented:_cmd];
  return nil;
}

+ newPort
{
  [self notImplemented:_cmd];
  return nil;
}

/* These sending and receiving interfaces will change */

- (int) sendPacket: (const char *)b length: (int)l
   toPort: (Port*) remote
   timeout: (int) milliseconds
{
  [self notImplemented:_cmd];
  return 0;
}

- (int) sendPacket: (const char *)b length: (int)l
   toPort: (Port*) remote
{
  return [self sendPacket:b length:l toPort:remote timeout:-1];
}

- (int) receivePacket: (char*)b length: (int)l
   fromPort: (Port**) remote
   timeout: (int) milliseconds
{
  [self notImplemented:_cmd];
  return 0;
}

- (int) receivePacket: (char*)b length: (int)l
   fromPort: (Port**) remote
{
  return [self receivePacket:b length:l fromPort:remote timeout:-1];
}

- (BOOL) canReceive
{
  [self notImplemented:_cmd];
  return NO;
}

- (BOOL) isEqual: anotherPort
{
  [self notImplemented:_cmd];
  return NO;
}

- (unsigned) hash
{
  [self notImplemented:_cmd];
  return 0;
}

- (void) encodeWithCoder: (Coder*)anEncoder
{
  [self notImplemented:_cmd];
}

+ newWithCoder: (Coder*)aDecoder;
{
  [self notImplemented:_cmd];
  return 0;
}

@end

