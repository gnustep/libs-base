#ifndef __NSObject_h_INCLUDE_GNU
#define __NSObject_h_INCLUDE_GNU

#include <objc/objc.h>
#include <objc/Protocol.h>

@class NSArchiver
@class NSCoder
@class NSMethodSignature
@class NSString

@interface NSObject
{
  Class *isa;
}

+ (void) initialize;
+ (id) alloc;
+ (id) allocWithZone: (NSZone*)z;
+ (id) new;
- (id) copy;
- (void) dealloc;
- (id) init;
- (id) mutableCopy;

+ (Class) class;
+ (Class) superclass;

+ (BOOL) instancesRespondToSelector: (SEL)aSelector;

+ (BOOL) conformsToProtocol: (Protocol*)aProtocol;

+ (IMP) instanceMethodForSelector: (SEL)aSelector;
- (IMP) methodForSelector: (SEL)aSelector;
- (NSMethodSignature*) methodSignatureForSelector: (SEL)aSelector;

+ (NSString*) description;

+ (void) poseAsClass: (Class)aClass;

- (void) doesNotRecognizeSelector: (SEL)aSelector;

+ (void) cancelPreviousPerformRequestsWithTarget: (id)aTarget
   selector: (SEL)aSelector
   object: (id)anObject;
- (void) performSelector: (SEL)aSelector
   object: (id)anObject
   afterDelay: (NSTimeInterval)delay;

- (void) forwardInvocation: (NSInvocation*)anInvocation;

- (id) awakAfterUsingCoder: (NSCoder*)aDecoder;
- (Class) classForArchiver;
- (Class) classForCoder;
- (id) replacementObjectForArchiveer: (NSArchiver*)anArchiver;
- (id) replacementObjectForCoder: (NSCoder*)anEncoder;

@end

#endif /* __NSObject_h_INCLUDE_GNU */
