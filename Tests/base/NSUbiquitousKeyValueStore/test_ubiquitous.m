#import <Foundation/Foundation.h>

int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    printf("Testing NSUbiquitousKeyValueStore implementation...\n");

    // Test basic functionality
    NSUbiquitousKeyValueStore *store = [NSUbiquitousKeyValueStore defaultStore];
    if (store == nil) {
        printf("FAIL: Could not get default store\n");
        [pool drain];
        return 1;
    }
    printf("PASS: Got default store instance\n");

    // Test string storage
    [store setString:@"TestValue" forKey:@"TestKey"];
    NSString *retrievedValue = [store stringForKey:@"TestKey"];
    if ([retrievedValue isEqualToString:@"TestValue"]) {
        printf("PASS: String storage and retrieval works\n");
    } else {
        printf("FAIL: String storage failed\n");
    }

    // Test number storage
    [store setBool:YES forKey:@"BoolTest"];
    BOOL boolValue = [store boolForKey:@"BoolTest"];
    if (boolValue == YES) {
        printf("PASS: Boolean storage works\n");
    } else {
        printf("FAIL: Boolean storage failed\n");
    }

    // Test synchronization
    [store synchronize];
    printf("PASS: Synchronize method executed without crash\n");

    // Test dictionary representation
    NSDictionary *dict = [store dictionaryRepresentation];
    if (dict != nil && [dict count] > 0) {
        printf("PASS: Dictionary representation works (contains %lu items)\n", (unsigned long)[dict count]);
    } else {
        printf("FAIL: Dictionary representation failed\n");
    }

    // Test removal
    [store removeObjectForKey:@"TestKey"];
    NSString *removedValue = [store stringForKey:@"TestKey"];
    if (removedValue == nil) {
        printf("PASS: Object removal works\n");
    } else {
        printf("FAIL: Object removal failed\n");
    }

    printf("NSUbiquitousKeyValueStore test completed!\n");

    [pool drain];
    return 0;
}
