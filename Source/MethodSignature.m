#include <remote/MethodSignature.h>

static int
types_get_size_of_arguments(const char *types)
{
  const char* type = objc_skip_typespec (types);
  return atoi (type);
}

static int
types_get_number_of_arguments (const char *types)
{
  int i = 0;
  const char* type = types;
  while (*type)
    {
      type = objc_skip_argspec (type);
      i += 1;
    }
  return i - 1;
}


@implementation MethodSignature

+ fromDescription:(struct objc_method_description *)omd 
    fromZone:(NXZone *)aZone
{
  MethodSignature *newMs = [[MethodSignature alloc] init];
  newMs->sig = *omd;
  newMs->selName = (char*)sel_get_name(omd->name);
  newMs->nargs = types_get_number_of_arguments(omd->types);
  newMs->sizeofParams = types_get_size_of_arguments(omd->types);
  return newMs;
}

- encodeMethodParams:(arglist_t)argFrame onto:(id <NXEncoding>)portal
{
  char *datum;
  const char *type;
  unsigned flags;

  for (type = sig.types;
       (datum = method_get_next_argument(argFrame, &type));)
    {
      flags = objc_get_type_qualifiers(type);
      type = objc_skip_type_qualifiers(type);
      [portal encodeData:datum ofType:type];
    }
  return self;
}

- (arglist_t) decodeMethodParamsFrom: (id <NXDecoding>)portal
{
  arglist_t argFrame = 0;  //(marg_list) malloc(sizeofParams);
  char *datum;
  const char *type;
  unsigned flags;

  for (type = sig.types;
       (datum = method_get_next_argument(argFrame, &type));)
    {
      flags = objc_get_type_qualifiers(type);
      type = objc_skip_type_qualifiers(type);
      [portal decodeData:datum ofType:type];
    }
  return argFrame;
}

#define ENCODE_RET(RETVAL,TYPE) \
do { \
  TYPE __r (void* __rf) {__builtin_return(__rf);} \
  TYPE __tmp = __r(RETVAL); \
  [portal encodeData:&__tmp ofType:sig.types]; \
} while(0);

/* Note: NeXT's direct passing of the ret value instead of a
   pointer to the ret value means we can't return doubles.
   I'm improving on this by passing a pointer what's
   returns from __builtin_apply() */
- encodeMethodRet: retframe
    withargs:(void *)argFrame
    onto:(id <NXEncoding>)portal
{
  /* NOTE: we don't yet handle changing values passed by reference */
  switch (*sig.types)
    {
    case _C_CHR:
    case _C_UCHR:
      ENCODE_RET(retframe, char);
      break;
    case _C_SHT:
    case _C_USHT:
      ENCODE_RET(retframe, short);
      break;
    case _C_INT:
    case _C_UINT:
      ENCODE_RET(retframe, int);
      break;
    case _C_LNG:
    case _C_ULNG:
      ENCODE_RET(retframe, int);
      break;
    case _C_FLT:
      ENCODE_RET(retframe, float);
      break;
    case _C_DBL:
      ENCODE_RET(retframe, double);
      break;
    default:
      [self error:"Can't handle type %s", sig.types];
    }
  return self;
}

/* In my version this actually returns the void* to be given to
   __builtin_return.  I'm not sure what NeXT's version does */

- decodeMethodRetFrom:(id <NXDecoding>)portal 
    withargs:(void *)aVoidPtr
{
//#warning this should be sizeof return
  void *datum = malloc(32);	/* this should be sizeof return */
  [portal decodeData:datum ofType:sig.types];
  return datum;
}

- (BOOL) isOneway
{
  return NO;
}

@end


