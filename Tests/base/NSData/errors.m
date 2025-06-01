#import "Testing.h"
#import "ObjectTesting.h"
#import <Foundation/Foundation.h>

int main()
{
    NSError *error;
    NSString *path;
    NSData *data;

    START_SET("NSData file/url loading")

    // Try loading from a nonexistent path to trigger error
    path = @"/tmp/nonexistent_file.txt";
    data = [NSData dataWithContentsOfFile: path options:0 error:&error];
    PASS(data == nil && error != nil, "+dataWithContentsOfFile:options:error: sets error on failure");

    data = [NSData dataWithContentsOfURL:[NSURL fileURLWithPath:path]
                                                options:0
                                                  error:&error];
    PASS(data == nil && error != nil, "+dataWithContentsOfURL:options:error: sets error on failure");

    // Try loading with invalid utf-8 path
    data = [NSData dataWithContentsOfFile: @"\xC3\x28" options:0 error:&error];
    PASS(data == nil && error != nil, "+dataWithContentsOfURL:options:error: sets error when path is invalid");

    END_SET("NSData file/url loading")

    return 0;
}
