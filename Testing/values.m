/*
    Test NSValue, NSNumber, and related classes

*/

#include <Foundation/NSValue.h>
#include <Foundation/NSException.h>
#include <Foundation/NSString.h>
#include <Foundation/NSGeometry.h>


int main()
{
    NSPoint p;
    NSRect rect;
    NSValue *v1, *v2;
    NSNumber *n1, *n2;

    // Numbers
    n1 = [NSNumber numberWithUnsignedShort:30];
    n2 = [NSNumber numberWithDouble:2.7];
    printf("Number(n1) as int %d, as float %f\n", 
		[n1 intValue], [n1 floatValue]);
    printf("n1 times n2=%f as int to get %d\n", 
	[n2 floatValue], [n1 intValue]*[n2 intValue]);
    printf("n2 as string: %s\n", [[n2 stringValue] cString]);
    printf("n2 compare:n1 is %d\n", [n2 compare:n1]);
    printf("n1 compare:n2 is %d\n", [n1 compare:n2]);


    // Test values, Geometry
    rect = NSMakeRect(1.0, 103.3, 40.0, 843.);
    rect = NSIntersectionRect(rect, NSMakeRect(20, 78., 89., 30));
    v1 = [NSValue valueWithRect:rect];
    printf("Encoding for rect is %s\n", [v1 objCType]);
    rect = [v1 rectValue];
    printf("Rect is %f %f %f %f\n", NSMinX(rect), NSMinY(rect), NSMaxX(rect),
	NSMaxY(rect));
    v2 = [NSValue valueWithPoint:NSMakePoint(3,4)];
    v1 = [NSValue valueWithNonretainedObject:v2];
    [[v1 nonretainedObjectValue] getValue:&p];
    printf("point is %f %f\n", p.x, p.y);

    printf("Try getting a null NSValue, should get a NSLog error message:\n");
    v2 = [NSValue value:NULL withObjCType:@encode(int)];
    return 0;
}
