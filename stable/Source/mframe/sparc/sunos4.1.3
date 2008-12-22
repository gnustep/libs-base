/* See ../README for copyright */

#define	MFRAME_STACK_STRUCT	0
#define	MFRAME_STRUCT_BYREF	1
#define MFRAME_SMALL_STRUCT	0
#define MFRAME_ARGS_SIZE	32
#define MFRAME_RESULT_SIZE	16

#define MFRAME_GET_STRUCT_ADDR(ARGS, TYPES) \
((*(TYPES)==_C_STRUCT_B || *(TYPES)==_C_UNION_B || *(TYPES)==_C_ARY_B) ? \
      *(void**)((ARGS)->arg_regs+sizeof(void*)): (void*)0)

#define MFRAME_SET_STRUCT_ADDR(ARGS, TYPES, ADDR) \
({if (*(TYPES)==_C_STRUCT_B || *(TYPES)==_C_UNION_B || *(TYPES)==_C_ARY_B) \
      *(void**)((ARGS)->arg_regs+sizeof(void*)) = (ADDR);})

#define	IN_REGS 0
#define	ON_STACK 1

struct sparc_args {
  int offsets[2];   /* 0 for args in regs, 1 for the rest of args on stack */
  int onStack;
};

#define MFRAME_ARGS struct sparc_args

#define MFRAME_INIT_ARGS(CUM, RTYPE)	\
({ \
  (CUM).offsets[0] = 8; /* encoding in regs starts from 8 */ \
  (CUM).offsets[1] = 20; /* encoding on stack starts from 20 or 24 */ \
  (CUM).onStack = NO; \
})

#define GET_SPARC_ARG_LOCATION(CUM, CSTRING_TYPE, TYPESIZE) \
((CUM).onStack \
  ? ON_STACK \
  : ((CUM).offsets[IN_REGS] + TYPESIZE <= 6 * sizeof(int) + 8 \
    ? (((CUM).offsets[IN_REGS] + TYPESIZE <= 6 * sizeof(int) + 4 \
      ? 0 : ((CUM).offsets[ON_STACK] += 4)),\
      IN_REGS) \
    : ((CUM).onStack = YES, ON_STACK)))

#define MFRAME_ARG_ENCODING(CUM, TYPE, STACK, DEST) \
({  \
  const char* type = (TYPE); \
  int align = objc_alignof_type(type); \
  int size = objc_sizeof_type(type); \
  int locn = GET_SPARC_ARG_LOCATION(CUM, type, size); \
\
  (CUM).offsets[locn] = ROUND((CUM).offsets[locn], align); \
  if (size < sizeof(int)) \
    { \
      (CUM).offsets[locn] += sizeof(int) - ROUND(size, align); \
    } \
  (TYPE) = objc_skip_typespec(type); \
  if (locn == IN_REGS) \
    { \
      sprintf((DEST), "%.*s+%d", (TYPE)-type, type, (CUM).offsets[locn]); \
    } \
  else \
    { \
      sprintf((DEST), "%.*s%d", (TYPE)-type, type, (CUM).offsets[locn]); \
    } \
  if (*(TYPE) == '+') \
    { \
      (TYPE)++; \
    } \
  while (isdigit(*(TYPE))) \
    { \
      (TYPE)++; \
    } \
  (DEST)=&(DEST)[strlen(DEST)]; \
  if (locn == ON_STACK) \
    { \
      if ((*type==_C_STRUCT_B || *type==_C_UNION_B || *type==_C_ARY_B)) \
	{ \
	  (STACK) = (CUM).offsets[ON_STACK] + ROUND(size, align); \
	} \
      else \
	{ \
	  (STACK) = (CUM).offsets[ON_STACK] + size; \
	} \
    } \
  (CUM).offsets[locn] += \
    size < sizeof(int) \
      ? ROUND(size, align) \
      : ROUND(size, sizeof(void*)); \
})

