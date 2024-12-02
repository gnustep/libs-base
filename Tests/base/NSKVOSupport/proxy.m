#import <GNUstepBase/GNUstep.h>

#import <Foundation/NSProxy.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSKeyValueObserving.h>

#import "Testing.h"


@interface Observee : NSObject
{
    NSString *_name;
    NSString *_derivedName;
}

- (NSString *) name;
- (void) setName: (NSString *)name;

- (NSString *) derivedName;
- (void) setDerivedName: (NSString *)name;

@end

@implementation Observee

- (NSString *) name
{
    return [[_name retain] autorelease];
}
- (void) setName: (NSString *)name
{
    ASSIGN(_name, name);
}

- (NSString *)derivedName
{
	return [NSString stringWithFormat:@"Derived %@", self.name];
}
- (void) setDerivedName: (NSString *)name
{
    ASSIGN(_derivedName, name);
}

+ (NSSet *)keyPathsForValuesAffectingDerivedName
{
	return [NSSet setWithObject:@"name"];
}

- (void) dealloc {
    RELEASE(_name);
    RELEASE(_derivedName);
    [super dealloc];
}

@end

@interface TProxy : NSProxy
{
    id _proxiedObject;
}
@end

@implementation TProxy

- (instancetype)initWithProxiedObject:(id)proxiedObject
{
    ASSIGN(_proxiedObject, proxiedObject);
	return self;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
	[invocation invokeWithTarget:_proxiedObject];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [_proxiedObject methodSignatureForSelector:sel];
}

- (void) dealloc
{
    RELEASE(_proxiedObject);
    [super dealloc];
}

@end

@interface Observer: NSObject

- (void)runTest;

@end

@implementation Observer
{
    int count;
}

- (void)runTest
{
	Observee *obj = [[Observee alloc] init];
	TProxy *proxy = [[TProxy alloc] initWithProxiedObject:obj];
	
	[(Observee *)proxy addObserver:self forKeyPath:@"name" options:NSKeyValueObservingOptionNew context:NULL];
	[(Observee *)proxy addObserver:self forKeyPath:@"derivedName" options:NSKeyValueObservingOptionNew context:NULL];
	
	[((Observee *)proxy) setName: @"MOO"];
    PASS(count == 2, "Got two change notifications");
	
	[obj setName: @"BAH"];
    PASS(count == 4, "Got two change notifications");
	
	[(Observee *)proxy removeObserver:self forKeyPath:@"name" context:NULL];
	[(Observee *)proxy removeObserver:self forKeyPath:@"derivedName" context:NULL];

    [proxy release];
    [obj release];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    count += 1;
    switch (count) {
        case 1:
            PASS_EQUAL(keyPath, @"derivedName", "change notification for dependent key 'derivedName' is emitted first");
            break;
        case 2:
            PASS_EQUAL(keyPath, @"name", "'name' change notification for proxy is second");
            break;
        case 3:
            PASS_EQUAL(keyPath, @"derivedName", "'derivedName' change notification for object is third");
            break;
        case 4:
            PASS_EQUAL(keyPath, @"name", "'name' change notification for object is fourth");
            break;
        default:
            PASS(0, "unexpected -[Observer observeValueForKeyPath:ofObject:change:context:] callback");
    }
}

@end

int
main(int argc, char *argv[])
{
    NSAutoreleasePool *arp = [NSAutoreleasePool new];
    Observer *obs = [Observer new];

    [obs runTest];
    [obs release];

    DESTROY(arp);
    return 0;
}
