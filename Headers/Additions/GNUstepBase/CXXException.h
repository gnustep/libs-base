
struct _Unwind_Exception;
@interface CXXException : NSObject
{
	struct _Unwind_Exception *ex;
}
+ (id)exceptionWithForeignException: (struct _Unwind_Exception*)ex;
- (void*)thrownValue;
- (void*)cxx_type_info;
@end
