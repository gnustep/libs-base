#include <Foundation/Foundation.h>
#include <objc/Protocol.h>

@interface Foo: NSObject
{
}

+ foo;
- (BOOL) conformsToProtocol: (Protocol *) aProtocol;
- (BOOL) respondsToSelector: (SEL) aSelector;
- copyWithZone: (NSZone *) zone;
- mutableCopyWithZone: (NSZone *) zone;
@end


@implementation Foo

+ foo
{
  return [[[Foo alloc] init] autorelease];
}

- (BOOL) conformsToProtocol: (Protocol *) aProtocol
{
  BOOL ret = [super conformsToProtocol: aProtocol];

  NSLog(@"-[<%@:0x%x> %@<%s>] -> %@",
    NSStringFromClass([self class]), self, NSStringFromSelector(_cmd),
    [aProtocol name], ret ? @"YES" : @"NO");
  return ret;
}

	  
- (BOOL) respondsToSelector: (SEL) aSelector
{
 BOOL ret = [super respondsToSelector: aSelector];

 if (![NSStringFromSelector(aSelector) hasPrefix:@"description"])
    NSLog(@"-[<%@:0x%x> %@%@] -> %@",
      NSStringFromClass([self class]), self, NSStringFromSelector(_cmd),
      NSStringFromSelector(aSelector), ret ? @"YES" : @"NO");
  return ret;
}

- copyWithZone: (NSZone *) zone
{
  id ret = [Foo foo];

  NSLog(@"-[<%@:0x%x> %@0x%x] -> <%@:0x%x>",
    NSStringFromClass([self class]), self,
    NSStringFromSelector(_cmd), zone, NSStringFromClass([ret class]), ret);
  return ret;
}

- mutableCopyWithZone: (NSZone *) zone
{
  id ret = [Foo foo];

  NSLog(@"-[<%@:0x%x> %@0x%x] -> <%@:0x%x>",
    NSStringFromClass([self class]), self,
    NSStringFromSelector(_cmd), zone, NSStringFromClass([ret class]), ret);
  return ret;
}

- retain
{
  id ret = [super retain];

  NSLog(@"-[<%@:0x%x> %@] -> retainCount = %d",
    NSStringFromClass([self class]), self,
    NSStringFromSelector(_cmd), [ret retainCount]);
  return ret;
}

@end

void
isDeepArrayCopy(NSArray  *obj1, NSArray  *obj2)
{
  id obj1FirstObject = [obj1 objectAtIndex:0];
  id obj2FirstObject = [obj2 objectAtIndex:0];

  NSLog(@"<%@:0x%x> -> <%@:0x%x>, %@",
                NSStringFromClass([obj1 class]), obj1,
                NSStringFromClass([obj2 class]), obj2,
        (obj1FirstObject == obj2FirstObject) ? ((obj1 == obj2) ? @"retained" : @"shallow") : @"deep(ish)");
}

void
isDeepDictionaryCopy(NSDictionary  *obj1, NSDictionary  *obj2)
{
  id obj1FirstObject = [obj1 objectForKey: @"Key"];
  id obj2FirstObject = [obj2 objectForKey: @"Key"];

  NSLog(@"<%@:0x%x> -> <%@:0x%x>, %@",
                NSStringFromClass([obj1 class]), obj1,
                NSStringFromClass([obj2 class]), obj2,
        (obj1FirstObject == obj2FirstObject) ? ((obj1 == obj2) ? @"retained" : @"shallow") : @"deep(ish)");
}

void
isDeepSetCopy(NSSet  *obj1, NSSet  *obj2)
{
  id obj1FirstObject = [obj1 anyObject];
  id obj2FirstObject = [obj2 anyObject];

  NSLog(@"<%@:0x%x> -> <%@:0x%x>, %@",
                NSStringFromClass([obj1 class]), obj1,
                NSStringFromClass([obj2 class]), obj2,
        (obj1FirstObject == obj2FirstObject) ? ((obj1 == obj2) ? @"retained" : @"shallow") : @"deep(ish)");
}


int main(int argc, char **argv)
{
  NSAutoreleasePool	*thePool = [[NSAutoreleasePool alloc] init];
  NSArray		*anArrayCopy;
  NSArray		*aMutableArrayCopy;
  NSArray		*anArrayMutableCopy;
  NSArray		*aMutableArrayMutableCopy;
  NSMutableArray	*aMutableArray
	= [NSMutableArray arrayWithObject: [Foo foo]];
  NSArray		*anArray = [NSArray arrayWithObject: [Foo foo]];
  NSDictionary		*aDictionaryCopy;
  NSDictionary		*aMutableDictionaryCopy;
  NSDictionary		*aDictionaryMutableCopy;
  NSDictionary		*aMutableDictionaryMutableCopy;
  NSMutableDictionary	*aMutableDictionary
	= [NSMutableDictionary dictionaryWithObjectsAndKeys: [Foo foo], @"Key", nil];
  NSDictionary		*aDictionary
	= [NSDictionary dictionaryWithObjectsAndKeys: [Foo foo], @"Key", nil];
  NSSet			*aSetCopy;
  NSSet			*aMutableSetCopy;
  NSSet			*aSetMutableCopy;
  NSSet			*aMutableSetMutableCopy;
  NSMutableSet		*aMutableSet = [NSMutableSet setWithObject: [Foo foo]];
  NSSet			*aSet = [NSSet setWithObject: [Foo foo]];
  NSZone		*zone = NSDefaultMallocZone();

  while (zone != 0)
    {
      NSLog(@"Copying from zone 0x%x -> 0x%x", NSDefaultMallocZone(), zone);

      NSLog(@"MutableArray -copy");
      aMutableArrayCopy = [aMutableArray copyWithZone:zone];
      NSLog(@"MutableArray -mutableCopy");
      aMutableArrayMutableCopy = [aMutableArray mutableCopyWithZone:zone];
      NSLog(@"Array -copy");
      anArrayCopy = [anArray copyWithZone:zone];
      NSLog(@"Array -mutableCopy");
      anArrayMutableCopy = [anArray mutableCopyWithZone:zone];

      NSLog(@"MutableArray: %@", aMutableArray);
      NSLog(@"MutableArrayCopy: %@", aMutableArrayCopy);
      NSLog(@"MutableArrayMutableCopy: %@", aMutableArrayMutableCopy);
      NSLog(@"anArray: %@", anArray);
      NSLog(@"anArrayCopy: %@", anArrayCopy);
      NSLog(@"anArrayCopy: %@", anArrayMutableCopy);

      NSLog(@"Test MutableArray against Copy");
      isDeepArrayCopy(aMutableArray, aMutableArrayCopy);

      NSLog(@"Test MutableArray against MutableCopy");
      isDeepArrayCopy(aMutableArray, aMutableArrayMutableCopy);

      NSLog(@"Test Array against Copy");
      isDeepArrayCopy(anArray, anArrayCopy);

      NSLog(@"Test Array against MutableCopy");
      isDeepArrayCopy(anArray, anArrayMutableCopy);

      NSLog(@"MutableDictionary -copy");
      aMutableDictionaryCopy = [aMutableDictionary copyWithZone:zone];
      NSLog(@"MutableDictionary -mutableCopy");
      aMutableDictionaryMutableCopy = [aMutableDictionary mutableCopyWithZone:zone];
      NSLog(@"Dictionary -copy");
      aDictionaryCopy = [aDictionary copyWithZone:zone];
      NSLog(@"Dictionary -mutableCopy");
      aDictionaryMutableCopy = [aDictionary mutableCopyWithZone:zone];

      NSLog(@"MutableDictionary: %@", aMutableDictionary);
      NSLog(@"MutableDictionaryCopy: %@", aMutableDictionaryCopy);
      NSLog(@"MutableDictionaryMutableCopy: %@", aMutableDictionaryMutableCopy);
      NSLog(@"aDictionary: %@", aDictionary);
      NSLog(@"aDictionaryCopy: %@", aDictionaryCopy);
      NSLog(@"aDictionaryCopy: %@", aDictionaryMutableCopy);

      NSLog(@"Test MutableDictionary against Copy");
      isDeepDictionaryCopy(aMutableDictionary, aMutableDictionaryCopy);

      NSLog(@"Test MutableDictionary against MutableCopy");
      isDeepDictionaryCopy(aMutableDictionary, aMutableDictionaryMutableCopy);

      NSLog(@"Test Dictionary against Copy");
      isDeepDictionaryCopy(aDictionary, aDictionaryCopy);

      NSLog(@"Test Dictionary against MutableCopy");
      isDeepDictionaryCopy(aDictionary, aDictionaryMutableCopy);

      NSLog(@"MutableSet -copy");
      aMutableSetCopy = [aMutableSet copyWithZone:zone];
      NSLog(@"MutableSet -mutableCopy");
      aMutableSetMutableCopy = [aMutableSet mutableCopyWithZone:zone];
      NSLog(@"Set -copy");
      aSetCopy = [aSet copyWithZone:zone];
      NSLog(@"Set -mutableCopy");
      aSetMutableCopy = [aSet mutableCopyWithZone:zone];

      NSLog(@"MutableSet: %@", aMutableSet);
      NSLog(@"MutableSetCopy: %@", aMutableSetCopy);
      NSLog(@"MutableSetMutableCopy: %@", aMutableSetMutableCopy);
      NSLog(@"aSet: %@", aSet);
      NSLog(@"aSetCopy: %@", aSetCopy);
      NSLog(@"aSetCopy: %@", aSetMutableCopy);

      NSLog(@"Test MutableSet against Copy");
      isDeepSetCopy(aMutableSet, aMutableSetCopy);

      NSLog(@"Test MutableSet against MutableCopy");
      isDeepSetCopy(aMutableSet, aMutableSetMutableCopy);

      NSLog(@"Test Set against Copy");
      isDeepSetCopy(aSet, aSetCopy);

      NSLog(@"Test Set against MutableCopy");
      isDeepSetCopy(aSet, aSetMutableCopy);

      if (zone == NSDefaultMallocZone())
	zone = NSCreateZone(NSPageSize(), NSPageSize(), YES);
      else
	zone = 0;
    }
  [thePool release];

  return 0;
}

