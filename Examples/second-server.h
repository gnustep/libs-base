#ifndef second_server_h
#define second_server_h

#include <Foundation/NSObject.h>
#include <objects/Array.h>

@interface SecondServer : NSObject
{
  Array *array;
}

- init;
- addRemoteObject: o;
- array;

@end

#endif
