/**
 * GSNumberTypes expects the INTEGER_MACRO macro to be defined.  This macro is
 * invoked once for every type and its Objective-C name.  Use this file when
 * implementing things like the -unsignedIntValue family of methods.  For this
 * case, the macro will be invoked with unsigned int as the type and
 * unsignedInt as the name.
 *
 */
#ifndef INTEGER_MACRO
#error Define INTEGER_MACRO(type, name, capitalizedName) before including GSNumberTypes.h
#endif
INTEGER_MACRO(double, double, Double)
INTEGER_MACRO(float, float, Float)
INTEGER_MACRO(signed char, char, Char)
INTEGER_MACRO(int, int, Int)
INTEGER_MACRO(short, short, Short)
INTEGER_MACRO(long, long, Long)
INTEGER_MACRO(NSInteger, integer, Integer)
INTEGER_MACRO(NSUInteger, unsignedInteger, UnsignedInteger)
INTEGER_MACRO(long long, longLong, LongLong)
INTEGER_MACRO(unsigned char, unsignedChar, UnsignedChar)
INTEGER_MACRO(unsigned short, unsignedShort, UnsignedShort)
INTEGER_MACRO(unsigned int, unsignedInt, UnsignedInt)
INTEGER_MACRO(unsigned long, unsignedLong, UnsignedLong)
INTEGER_MACRO(unsigned long long, unsignedLongLong, UnsignedLongLong)
#undef INTEGER_MACRO
