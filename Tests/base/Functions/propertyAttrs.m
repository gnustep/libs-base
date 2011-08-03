#import "Testing.h"
#include <objc/runtime.h>
#include <string.h>
#include <stdio.h>

#ifdef OBJC_NEW_PROPERTIES

// Test that property attributes work correctly.  These examples are taken from
// the Apple documentation, however it seems that the runtime team at Apple
// can't actually read documentation, so they're tweaked to correspond to what
// Apple actually implemented.

enum FooManChu { FOO, MAN, CHU };
struct YorkshireTeaStruct { int pot; char lady; };
typedef struct YorkshireTeaStruct YorkshireTeaStructType;
union MoneyUnion { float alone; double down; };

@interface PropertyTest
{
	Class isa;
	char charDefault;
	double doubleDefault;
	enum FooManChu enumDefault;
	float floatDefault;
	int intDefault;
	long longDefault;
	short shortDefault;
	signed signedDefault;
	struct YorkshireTeaStruct structDefault;
	YorkshireTeaStructType typedefDefault;
	union MoneyUnion unionDefault;
	unsigned unsignedDefault;
	int (*functionPointerDefault)(char *);
	int *intPointer;
	void *voidPointerDefault;
	int intSynthEquals;
	int intSetterGetter;
	int intReadonly;
	int intReadonlyGetter;
	int intReadwrite;
	int intAssign;
	id idRetain;
	id idCopy;
	int intNonatomic;
	id idReadonlyCopyNonatomic;
	id idReadonlyRetainNonatomic;
}
@property char charDefault;
@property double doubleDefault;
@property enum FooManChu enumDefault;
@property float floatDefault;
@property int intDefault;
@property long longDefault;
@property short shortDefault;
@property signed signedDefault;
@property struct YorkshireTeaStruct structDefault;
@property YorkshireTeaStructType typedefDefault;
@property union MoneyUnion unionDefault;
@property unsigned unsignedDefault;
@property int (*functionPointerDefault)(char *);
@property int *intPointer;
@property void *voidPointerDefault;
@property(getter=intGetFoo, setter=intSetFoo:) int intSetterGetter;
@property(readonly) int intReadonly;
@property(getter=isIntReadOnlyGetter, readonly) int intReadonlyGetter;
@property(readwrite) int intReadwrite;
@property(assign) int intAssign;
@property(retain) id idRetain;
@property(copy) id idCopy;
@property(nonatomic) int intNonatomic;
@property(nonatomic, readonly, copy) id idReadonlyCopyNonatomic;
@property(nonatomic, readonly, retain) id idReadonlyRetainNonatomic;
@end

@implementation PropertyTest
@synthesize charDefault;
@synthesize doubleDefault;
@synthesize enumDefault;
@synthesize floatDefault;
@synthesize intDefault;
@synthesize longDefault;
@synthesize shortDefault;
@synthesize signedDefault;
@synthesize structDefault;
@synthesize typedefDefault;
@synthesize unionDefault;
@synthesize unsignedDefault;
@synthesize functionPointerDefault;
@synthesize intPointer;
@synthesize voidPointerDefault;
@synthesize intSetterGetter;
@synthesize intReadonly;
@synthesize intReadonlyGetter;
@synthesize intReadwrite;
@synthesize intAssign;
@synthesize idRetain;
@synthesize idCopy;
@synthesize intNonatomic;
@synthesize idReadonlyCopyNonatomic;
@synthesize idReadonlyRetainNonatomic;
@end


void testProperty(const char *name, const char *types)
{
	objc_property_t p = class_getProperty(objc_getClass("PropertyTest"), name);
	if (0 == p )
	{
		pass(0, "Lookup failed for property %s", name);
		return;
	}
	pass(1, "Lookup succeeded for property %s", name);
	const char *attrs = property_getAttributes(p);
	pass((strcmp(name, property_getName(p)) == 0),
		"Proprety name should be '%s' was '%s'", name, property_getName(p));
	pass((strcmp(types, attrs) == 0),
		"Property attributes for %s should be '%s' was '%s'", name, types, attrs);
}

int main(void)
{
	testProperty("charDefault", "Tc,VcharDefault");
	testProperty("doubleDefault", "Td,VdoubleDefault");
	testProperty("enumDefault", "Ti,VenumDefault");
	testProperty("floatDefault", "Tf,VfloatDefault");
	testProperty("intDefault", "Ti,VintDefault");
	if (sizeof(long) == 4)
	{
		testProperty("longDefault", "Tl,VlongDefault");
	}
	else
	{
		testProperty("longDefault", "Tq,VlongDefault");
	}
	testProperty("shortDefault", "Ts,VshortDefault");
	testProperty("signedDefault", "Ti,VsignedDefault");
	testProperty("structDefault", "T{YorkshireTeaStruct=ic},VstructDefault");
	testProperty("typedefDefault", "T{YorkshireTeaStruct=ic},VtypedefDefault");
	testProperty("unionDefault", "T(MoneyUnion=fd),VunionDefault");
	testProperty("unsignedDefault", "TI,VunsignedDefault");
	testProperty("functionPointerDefault", "T^?,VfunctionPointerDefault");
	testProperty("intPointer", "T^i,VintPointer");
	testProperty("voidPointerDefault", "T^v,VvoidPointerDefault");
	testProperty("intSetterGetter", "Ti,GintGetFoo,SintSetFoo:,VintSetterGetter");
	testProperty("intReadonly", "Ti,R,VintReadonly");
	testProperty("intReadonlyGetter", "Ti,R,GisIntReadOnlyGetter,VintReadonlyGetter");
	testProperty("intReadwrite", "Ti,VintReadwrite");
	testProperty("intAssign", "Ti,VintAssign");
	testProperty("idRetain", "T@,&,VidRetain");
	testProperty("idCopy", "T@,C,VidCopy");
	testProperty("intNonatomic", "Ti,N,VintNonatomic");
	testProperty("idReadonlyCopyNonatomic", "T@,R,C,N,VidReadonlyCopyNonatomic");
	testProperty("idReadonlyRetainNonatomic", "T@,R,&,N,VidReadonlyRetainNonatomic");
	return 0;
}
#else
int main(void)
{
  START_SET("Properties")
    OMIT("Your compiler does not support declared properties");
  END_SET("Properties")
  return 0;
}
#endif
