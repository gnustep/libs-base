/*
    Test NSValue, NSNumber, and related classes

*/

#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGeometry.h>
#include <Foundation/NSArray.h>
#include    <Foundation/NSAutoreleasePool.h>


int main()
{
    NSPoint p;
    NSRange range;
    NSRect rect;
    NSValue *v1, *v2;
    NSNumber *nc, *ns, *n1, *n2, *n3, *n4, *n5, *n6, *n7;
    NSArray *a1, *a2;
    NSAutoreleasePool	*arp = [NSAutoreleasePool new];

    // Numbers
    nc = [NSNumber numberWithChar: -100];
    ns = [NSNumber numberWithShort: -100];
printf("try %d, %d", [nc charValue], [ns shortValue]);
printf("nc compare: ns is %d\n", [nc compare: ns]);
    n1 = [NSNumber numberWithUnsignedShort: 30];
printf("n1 = %s\n", [[n1 description] cString]);
    n2 = [NSNumber numberWithDouble: 2.7];
printf("n2 = %s\n", [[n2 description] cString]);
    n3 = [NSNumber numberWithDouble: 30];
printf("n3 = %s\n", [[n3 description] cString]);
    n4 = [NSNumber numberWithChar: 111];
printf("n4 = %s\n", [[n4 description] cString]);
    n5 = [NSNumber numberWithChar: 111];
printf("n5 = %s\n", [[n5 description] cString]);
    n6 = [NSNumber numberWithFloat: 1.5];
printf("n6 = %s\n", [[n6 description] cString]);
    n7 = [NSNumber numberWithShort: 25];
printf("n7 = %s\n", [[n7 description] cString]);
    printf("Number(n1) as int %d, as float %f\n", 
		[n1 intValue], [n1 floatValue]);
    printf("n1 times n2=%f as int to get %d\n", 
	[n2 floatValue], [n1 intValue]*[n2 intValue]);
    printf("n2 as string: %s\n", [[n2 stringValue] cString]);
    printf("n2 compare: n1 is %d\n", [n2 compare: n1]);
    printf("n1 compare: n2 is %d\n", [n1 compare: n2]);
    printf("n1 isEqual: n3 is %d\n", [n1 isEqual: n3]);
    printf("n4 isEqual: n5 is %d\n", [n4 isEqual: n5]);    

    a1 = [NSArray arrayWithObjects: 
		      [NSNumber numberWithChar: 111],
		    [NSNumber numberWithUnsignedChar: 112],
		    [NSNumber numberWithShort: 121],
		    [NSNumber numberWithUnsignedShort: 122],
		    [NSNumber numberWithInt: 131],
		    [NSNumber numberWithUnsignedInt: 132],
		    [NSNumber numberWithInt: 141],
		    [NSNumber numberWithUnsignedInt: 142],
		    [NSNumber numberWithFloat: 151],
		    [NSNumber numberWithDouble: 152], nil];

    a2 = [NSArray arrayWithObjects: 
		   [NSNumber numberWithChar: 111],
		   [NSNumber numberWithUnsignedChar: 112],
		   [NSNumber numberWithShort: 121],
		   [NSNumber numberWithUnsignedShort: 122],
		   [NSNumber numberWithInt: 131],
		   [NSNumber numberWithUnsignedInt: 132],
		   [NSNumber numberWithInt: 141],
		   [NSNumber numberWithUnsignedInt: 142],
		   [NSNumber numberWithFloat: 151],
		   [NSNumber numberWithDouble: 152], nil];

    printf("a1 isEqual: a2 is %d\n", [a1 isEqual: a2]);    

    // Test values, Geometry
    rect = NSMakeRect(1.0, 103.3, 40.0, 843.);
    rect = NSIntersectionRect(rect, NSMakeRect(20, 78., 89., 30));
    v1 = [NSValue valueWithRect: rect];
    printf("Encoding for rect is %s\n", [v1 objCType]);
    rect = [v1 rectValue];
    printf("Rect is %f %f %f %f\n", NSMinX(rect), NSMinY(rect), NSMaxX(rect),
	NSMaxY(rect));
    v2 = [NSValue valueWithPoint: NSMakePoint(3,4)];
    v1 = [NSValue valueWithNonretainedObject: v2];
    [[v1 nonretainedObjectValue] getValue: &p];
    printf("point is %f %f\n", p.x, p.y);
    range = NSMakeRange(1, 103);
    range = NSIntersectionRange(range, NSMakeRange(2, 73));
    v1 = [NSValue valueWithRange: range];
    printf("Encoding for range is %s\n", [v1 objCType]);
    range = [v1 rangeValue];
    printf("Range is %u %u\n", range.location, range.length);

    printf("Try getting a null NSValue, should get a NSLog error message: \n");
    v2 = [NSValue value: NULL withObjCType: @encode(int)];
    [arp release];
    return 0;
}
