#ifndef second_server_h
#define second_server_h

#include <objc/Object.h>
#include <objects/Array.h>
#include <objects/InvalidationListening.h>

@interface SecondServer : Object <InvalidationListening>
{
  Array *array;
}

- init;
- addRemoteObject: o;
- array;

@end

#endif
