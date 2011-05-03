#define INTEGER_MACRO(encoding, type, name, ignored) \
- (type) name ## Value\
{\
  return (type)VALUE;\
}
#include "GSNumberTypes.h"
- (BOOL) boolValue
{
  return (VALUE == 0) ? NO : YES;
}
- (const char *) objCType
{
  return @encode(typeof(VALUE));
}
- (NSString*) descriptionWithLocale: (id)aLocale
{
  return [[[NSString alloc] initWithFormat: FORMAT
				    locale: aLocale, VALUE] autorelease];
}
- (void) getValue: (void*)buffer
{
  typeof(VALUE) *ptr = buffer;
  *ptr = VALUE;
}
#undef FORMAT
