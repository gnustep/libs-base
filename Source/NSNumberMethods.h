#define INTEGER_MACRO(type, name, ignored) \
- (type) name ## Value\
{\
  return (type)VALUE;\
}
#include "GSNumberTypes.h"
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
