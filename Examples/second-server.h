#ifndef second_server_h
#define second_server_h

#include <Foundation/NSObject.h>
#include <objects/Array.h>
#include <objects/InvalidationListening.h>

@interface SecondServer : NSObject <InvalidationListening>
{
  Array *array;
}

- init;
- addRemoteObject: o;
- array;

@end

#endif
