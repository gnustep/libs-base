#import <Foundation/NSGeometry.h>

#import "Testing.h"
#import "../../../Source/typeEncodingHelper.h"

int main(int argc, char *argv[]) {
    START_SET("Known Struct Type Encodings")

    PASS(strncmp(@encode(NSPoint), CGPOINT_ENCODING_PREFIX, strlen(CGPOINT_ENCODING_PREFIX)) == 0, "CGPoint encoding");
    PASS(strncmp(@encode(NSSize), CGSIZE_ENCODING_PREFIX, strlen(CGSIZE_ENCODING_PREFIX)) == 0, "CGSize encoding");
    PASS(strncmp(@encode(NSRect), CGRECT_ENCODING_PREFIX, strlen(CGRECT_ENCODING_PREFIX)) == 0, "CGRect encoding");
    PASS(strncmp(@encode(NSRange), NSRANGE_ENCODING_PREFIX, strlen(NSRANGE_ENCODING_PREFIX)) == 0, "NSRange encoding");

    END_SET("Known Struct Type Encodings")
    return 0;
}
