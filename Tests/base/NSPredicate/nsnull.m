#import "ObjectTesting.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSPredicate.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSNull.h"

int main(void) {
    NSAutoreleasePool *arp = [NSAutoreleasePool new];
	NSArray *array, *filtered;
	NSPredicate *predicate;

    // Basic filtering with NSPredicate
    array = @[@{@"key": @"value1"}, @{@"key": @"value2"}, [NSNull null]];
	predicate = [NSPredicate predicateWithFormat:@"key == %@", @"value2"];
    filtered = [array filteredArrayUsingPredicate: predicate];

    PASS(filtered.count == 1 && [filtered[0][@"key"] isEqualToString:@"value2"], 
         "NSPredicate should correctly filter array including NSNull");

    // Filtering with NSPredicate where no match is found
	predicate = [NSPredicate predicateWithFormat:@"key == %@", @"nonexistent"];
    filtered = [array filteredArrayUsingPredicate: predicate];
    PASS(filtered.count == 0, 
         "NSPredicate should return an empty array when no match is found");

    // Filtering with NSPredicate with a different key
	predicate = [NSPredicate predicateWithFormat:@"anotherKey == %@", @"value1"];
    filtered = [array filteredArrayUsingPredicate: predicate];
    PASS(filtered.count == 0, 
         "NSPredicate should return an empty array when filtering with a non-existent key");

    [arp release];
    return 0;
}
