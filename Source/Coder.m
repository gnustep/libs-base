/* Implementation of GNU Objective-C coder object for use serializing
   Copyright (C) 1994, 1995 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Date: July 1994
   
   This file is part of the GNU Objective C Class Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#include <objects/stdobjects.h>
#include <objects/Coder.h>
#include <objects/MemoryStream.h>
#include <objects/Coding.h>
#include <objects/Dictionary.h>
#include <objects/Stack.h>
#include <assert.h>

#define CODER_FORMAT_VERSION 0

enum {CODER_OBJECT_NIL = 0, CODER_OBJECT, CODER_ROOT_OBJECT, 
	CODER_REPEATED_OBJECT, CODER_CLASS_OBJECT, 
	CODER_OBJECT_FORWARD_REFERENCE,
	CODER_CLASS_NIL, CODER_CLASS, CODER_REPEATED_CLASS,
	CODER_CONST_PTR_NULL, CODER_CONST_PTR, CODER_REPEATED_CONST_PTR};

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })

static BOOL debug_coder = NO;
static id defaultStreamClass;

/* xxx For experimentation.  The function in objc-api.h doesn't always
   work for objects; it sometimes returns YES for an instance. */

/* But, metaclasses return YES too? */
static BOOL
my_object_is_class(id object)
{
  if (object != nil 
#if NeXT_runtime
      && CLS_ISMETA(((Class)object)->isa)
      && ((Class)object)->isa != ((Class)object)->isa)
#else
      && CLS_ISMETA(((Class)object)->class_pointer)
      && ((Class)object)->class_pointer != ((Class)object)->class_pointer)
#endif
    return YES;
  else
    return NO;
}


@implementation Coder

+ (void) initialize
{
  if (self == [Coder class])
    {
      defaultStreamClass = [MemoryStream class];
      assert(sizeof(void*) == sizeof(unsigned)); 
    }
}

+ setDebugging: (BOOL)f
{
  debug_coder = f;
  return self;
}

+ (void) setDefaultStreamClass: sc
{
  defaultStreamClass = sc;
}

+ defaultStreamClass
{
  return defaultStreamClass;
}

/* Careful, this shouldn't contain newlines */
+ (const char *) coderSignature
{
  return "GNU Objective C Class Library Coder";
}

+ (int) coderFormatVersion
{
  return CODER_FORMAT_VERSION;
}

+ (int) coderConcreteFormatVersion
{
  [self notImplemented:_cmd];
  return 0;
}

- (void) encodeSignature
{
  [stream writeLine:[[self class] coderSignature]];
  [self encodeValueOfSimpleType:@encode(int)
	at:&format_version
	withName:"Coder Format Version"];
  [self encodeValueOfSimpleType:@encode(int)
	at:&concrete_format_version
	withName:"Coder Concrete Format Version"];
}

- (void) decodeSignature
{
  char *s;

  s = [stream readLine];
  if (strcmp(s, [[self class] coderSignature]))
    [self error:"Signature mismatch, executable (%s) != encoded (%s)", 
	  [[self class] coderSignature], s];
  (*objc_free)(s);

  [self decodeValueOfSimpleType:@encode(int)
	at:&format_version
	withName:NULL];
  if (format_version != [[self class] coderFormatVersion])
    [self error:"Format version mismatch, executable %d != encoded %d\n",
	  [[self class] coderFormatVersion], format_version];

  [self decodeValueOfSimpleType:@encode(int)
	at:&concrete_format_version
	withName:NULL];
  if (concrete_format_version != [[self class] coderConcreteFormatVersion])
    [self error:"Concrete format version mismatch, "
	  "executable %d != encoded %d\n",
	  [[self class] coderConcreteFormatVersion], concrete_format_version];
}

/* This is the designated sub-initializer.  
   Don't call it yourself.
   Do override it and call [super...] in subclasses. */
- doInitOnStream: (Stream*)s isDecoding: (BOOL)f
{
  is_decoding = f;
  doing_root_object = NO;
  //  [s retain];
  stream = s;
  object_table = nil;
  in_progress_table = [[Set alloc] initWithType:@encode(unsigned)];
  const_ptr_table = [[Dictionary alloc] initWithType:@encode(void*) 
					keyType:@encode(unsigned)];
  root_object_tables = nil;
  forward_object_tables = nil;
  return self;
}

/* These are the two designated initializers for users. 
   Should I combine them and differentiate encoding/decoding with
   an argument, just like doInitOnStream... does? */

- initEncodingOnStream: (Stream *)s
{
  [self doInitOnStream:s isDecoding:NO];
  format_version = [[self class] coderFormatVersion];
  concrete_format_version = [[self class] coderConcreteFormatVersion];
  [self encodeSignature];
  return self;
}

- initDecodingOnStream: (Stream *)s
{
  [self doInitOnStream:s isDecoding:YES];
  [self decodeSignature];
  return self;
}

- initEncoding
{
  return [self initEncodingOnStream:[[defaultStreamClass alloc] init]];
}

- initDecoding
{
  return [self initDecodingOnStream:[[defaultStreamClass alloc] init]];
}

- init
{
  return [self initEncoding];
}

/* These _coder... methods may be overriden by subclasses so that 
   cross-references can be kept differently.

   For instance, ConnectedCoder keeps cross-references to const
   pointers on a per-Connection basis instead of a per-Coder basis.
   We avoid encoding/decoding the same classes and selectors over and
   over again.
*/

static inline id
new_object_table()
{
  return [[Dictionary alloc] initWithType:@encode(void*)
	  keyType:@encode(unsigned)];
}

- (BOOL) _coderHasObjectReference: (unsigned)xref
{
  if (!object_table)
    object_table = new_object_table();
  return [object_table includesKey:xref];
}

- _coderObjectAtReference: (unsigned)xref;
{
  if (!object_table)
    object_table = new_object_table();
  return [object_table elementAtKey:xref].id_u;
}

- (void) _coderPutObject: anObj atReference: (unsigned)xref
{
  if (!object_table)
    object_table = new_object_table();
  [object_table putElement:anObj atKey:xref];
}

/* Using the next three methods, subclasses can change the way that
   const pointers (like SEL, Class, Atomic strings, etc) are
   archived. */

/* Only use _coderHasConstPtrReference during encoding, not decoding.
   Otherwise you'll confuse ConnectedCoder that distinguishes between
   incoming and outgoing tables.  xxx What am I talking about here?? */

- (BOOL) _coderHasConstPtrReference: (unsigned)xref 
{ 
  return [const_ptr_table includesKey:xref]; 
}

static elt 
exc_return_null(arglist_t f)
{
  return (void*)0;
}

- (const void*) _coderConstPtrAtReference: (unsigned)xref;
{
  return [const_ptr_table elementAtKey:xref 
			  ifAbsentCall:exc_return_null].void_ptr_u;
}

- (void) _coderPutConstPtr: (const void*)p atReference: (unsigned)xref
{
  assert(![const_ptr_table includesKey:xref]);
  [const_ptr_table putElement:(void*)p atKey:xref];
}

/* Here are the methods for root objects */

- (void) _coderPushRootObjectTable
{
  if (!root_object_tables)
    root_object_tables = [[Stack alloc] init];
  [root_object_tables pushObject:
		      [[Dictionary alloc] initWithType:@encode(void*)
		       keyType:@encode(unsigned)]];
}

- (void) _coderPopRootObjectTable
{
  assert(root_object_tables);
  [[root_object_tables popObject] release];
}

- _coderTopRootObjectTable
{
  assert(root_object_tables);
  return [root_object_tables topObject];
}

/* Here are the methods for forward object references. */

- (void) _coderPushForwardObjectTable
{
  if (!forward_object_tables)
    forward_object_tables = [[Stack alloc] init];
  [forward_object_tables pushObject:
			  [[Dictionary alloc] initWithType:@encode(void*)
			   keyType:@encode(unsigned)]];
}

- (void) _coderPopForwardObjectTable
{
  assert(forward_object_tables);
  [[forward_object_tables popObject] release];
}

- _coderTopForwardObjectTable
{
  assert(forward_object_tables);
  return [forward_object_tables topObject];
}

- (struct objc_list *) _coderForwardObjectsAtReference: (unsigned)xref
{
  assert(forward_object_tables);
  return (struct objc_list*)
    [[forward_object_tables topObject] elementAtKey:xref 
     ifAbsentCall:exc_return_null].void_ptr_u;
}

- (void) _coderPutForwardObjects: (struct objc_list *)head
   atReference: (unsigned)xref
{
  assert(forward_object_tables);
  [[forward_object_tables topObject] putElement:head atKey:xref];
}


/* This is the Coder's interface to the over-ridable
   "_coderPutObject:atReference" method.  Do not override it.  It
   handles the root_object_table. */

- (void) _internalCoderPutObject: anObj atReference: (unsigned)xref
{
  if (doing_root_object)
    {
      assert(![[self _coderTopRootObjectTable] includesKey:xref]);
      [[self _coderTopRootObjectTable] putElement:anObj atKey:xref];
    }
  [self _coderPutObject:anObj atReference:xref];
}

- (BOOL) isDecoding
{
  return is_decoding;
}

- (void) encodeTag: (unsigned char)t
{
  [self encodeValueOfSimpleType:@encode(unsigned char) 
	at:&t 
	withName:"Coder tag"];
}

- (unsigned char) decodeTag
{
  unsigned char t;
  [self decodeValueOfSimpleType:@encode(unsigned char)
	at:&t 
	withName:NULL];
  return t;
}

- (void) encodeClass: aClass 
{
  [self encodeIndent];
  if (aClass == Nil)
    {
      [self encodeTag: CODER_CLASS_NIL];
    }
  else
    {
      unsigned xref = PTR2LONG(aClass);
      if ([self _coderHasConstPtrReference:xref])
	{
	  [self encodeTag: CODER_REPEATED_CLASS];
	  [self encodeValueOfSimpleType:@encode(unsigned)
		at:&xref 
		withName:"Class cross-reference number"];
	}
      else
	{
	  const char *class_name = class_get_class_name(aClass);
	  int class_version = class_get_version(aClass);

	  assert(class_name);
	  assert(*class_name);
	  [self encodeTag: CODER_CLASS];
	  [self encodeValueOfSimpleType:@encode(unsigned)
		at:&xref
		withName:"Class cross-reference number"];
	  [self encodeValueOfSimpleType:@encode(char*)
		at:&class_name
		withName:"Class name"];
	  [self encodeValueOfSimpleType:@encode(int)
		at:&class_version
		withName:"Class version"];
	  [self _coderPutConstPtr:aClass atReference:xref];
	}
    }
  [self encodeUnindent];
  return;
}

- decodeClass
{
  unsigned char tag;
  char *class_name;
  int class_version;
  id ret = Nil;
  
  [self decodeIndent];
  tag = [self decodeTag];
  switch (tag)
    {
    case CODER_CLASS_NIL:
      break;
    case CODER_CLASS:
      {
	unsigned xref;
	[self decodeValueOfSimpleType:@encode(unsigned)
	      at:&xref
	      withName:NULL];
	[self decodeValueOfSimpleType:@encode(char*)
	      at:&class_name
	      withName:NULL];
	[self decodeValueOfSimpleType:@encode(int)
	      at:&class_version
	      withName:NULL];
	ret = objc_lookup_class(class_name);
	if (ret == Nil)
	  [self error:"Couldn't find class `%s'", class_name];
	if (class_get_version(ret) != class_version)
	  [self error:"Class version mismatch, executable %d != encoded %d",
		class_get_version(ret), class_version];
	if ([self _coderHasConstPtrReference:xref])
	  [self error:"two classes have the same cross-reference number"];
	[self _coderPutConstPtr:ret atReference:xref];
	if (debug_coder)
	  fprintf(stderr, "Coder decoding registered class xref %u\n", xref);
	(*objc_free)(class_name);
	break;
      }
    case CODER_REPEATED_CLASS:
      {
	unsigned xref;
	[self decodeValueOfSimpleType:@encode(unsigned)
	      at:&xref
	      withName:NULL];
	ret = (id) [self _coderConstPtrAtReference:xref];
	if (!ret)
	  [self error:"repeated class cross-reference number %u not found",
		xref];
	break;
      }
    default:
      [self error:"unrecognized class tag = %d", (int)tag];
    }
  [self decodeUnindent];
  return ret;
}

- (void) encodeAtomicString: (const char*)sp
   withName: (const char*)name
{
  /* xxx Add repeat-string-ptr checking here. */
  [self notImplemented:_cmd];
  [self encodeValueOfSimpleType:@encode(char*) at:&sp withName:name];
}

- (const char *) decodeAtomicStringWithName: (const char **)name
{
  char *s;
  /* xxx Add repeat-string-ptr checking here */
  [self notImplemented:_cmd];
  [self decodeValueOfSimpleType:@encode(char*) at:&s withName:name];
  return s;
}

#define NO_SEL_TYPES "none"

- (void) encodeSelector: (SEL)sel withName: (const char*)name
{
  [self encodeName:name];
  [self encodeIndent];
  if (sel == 0)
    {
      [self encodeTag: CODER_CONST_PTR_NULL];
    }
  else
    {
      unsigned xref = PTR2LONG(sel);
      if ([self _coderHasConstPtrReference:xref])
	{
	  [self encodeTag: CODER_REPEATED_CONST_PTR];
	  [self encodeValueOfSimpleType:@encode(unsigned)
		at:&xref
		withName:"SEL cross-reference number"];
	}
      else
	{
	  const char *sel_name;
	  const char *sel_types;

	  [self encodeTag: CODER_CONST_PTR];
	  sel_name = sel_get_name(sel);
#if NeXT_runtime
	  sel_types = NO_SEL_TYPES;
#else
	  sel_types = sel_get_type(sel);
#endif
#if 1 /* xxx Yipes,... careful... */
	  /* xxx Think about something like this. */
	  if (!sel_types)
	    sel_types = sel_get_type(sel_get_any_uid(sel_get_name(sel)));
#endif
	  if (!sel_name) [self error:"ObjC runtime didn't provide SEL name"];
	  if (!*sel_name) [self error:"ObjC runtime didn't provide SEL name"];
	  if (!sel_types) [self error:"ObjC runtime didn't provide SEL type"];
	  if (!*sel_types) [self error:"ObjC runtime didn't provide SEL type"];
	  [self encodeValueOfSimpleType:@encode(unsigned)
		at:&xref
		withName:"SEL cross-reference number"];
	  [self encodeValueOfSimpleType:@encode(char*) 
		at:&sel_name 
		withName:"SEL name"];
	  [self encodeValueOfSimpleType:@encode(char*) 
		at:&sel_types 
		withName:"SEL types"];
	  [self _coderPutConstPtr:sel atReference:xref];
	  if (debug_coder)
	    fprintf(stderr, "Coder encoding registered sel xref %u\n", xref);
	}
    }
  [self encodeUnindent];
  return;
}

- (SEL) decodeSelectorWithName: (const char **)name
{
  char tag;
  SEL ret = NULL;

  [self decodeName:name];
  [self decodeIndent];
  tag = [self decodeTag];
  switch (tag)
    {
    case CODER_CONST_PTR_NULL:
      break;
    case CODER_CONST_PTR:
      {
	unsigned xref;
	char *sel_name;
	char *sel_types;

	[self decodeValueOfSimpleType:@encode(unsigned)
	      at:&xref
	      withName:NULL];
	[self decodeValueOfSimpleType:@encode(char *) 
	      at:&sel_name 
	      withName:NULL];
	[self decodeValueOfSimpleType:@encode(char *) 
	      at:&sel_types 
	      withName:NULL];
#if NeXT_runtime
	ret = sel_getUid(sel_name);
#else
	if (!strcmp(sel_types, NO_SEL_TYPES))
	  ret = sel_get_any_uid(sel_name);
	else
	  ret = sel_get_typed_uid(sel_name, sel_types);
#endif
	if (!ret)
	  [self error:"Could not find selector (%s) with types [%s]",
		sel_name, sel_types];
#if ! NeXT_runtime
	if (strcmp(sel_types, NO_SEL_TYPES)
	    && !(sel_types_match(sel_types, ret->sel_types)))
	  [self error:"ObjC runtime didn't provide SEL with matching type"];
#endif
	[self _coderPutConstPtr:ret atReference:xref];
	if (debug_coder)
	  fprintf(stderr, "Coder decoding registered sel xref %u\n", xref);
	(*objc_free)(sel_name);
	(*objc_free)(sel_types);
	break;
      }
    case CODER_REPEATED_CONST_PTR:
      {
	unsigned xref;
	[self decodeValueOfSimpleType:@encode(unsigned)
	      at:&xref
	      withName:NULL];
	ret = (SEL)[self _coderConstPtrAtReference:xref];
	if (!ret)
	  [self error:"repeated selector cross-reference number %u not found",
		xref];
	break;
      }
    default:
      [self error:"unrecognized selector tag = %d", (int)tag];
    }
  [self decodeUnindent];
  return ret;
}

- (void) encodeValueOfType: (const char*)type 
   at: (const void*)d 
   withName: (const char *)name
{
  switch (*type)
    {
    case _C_CLASS:
      [self encodeName:name];
      [self encodeClass: *(id*)d];
      break;
    case _C_ATOM:
      [self encodeAtomicString:*(char**)d withName:name];
      break;
    case _C_SEL:
      {
	[self encodeSelector:*(SEL*)d withName:name];
	break;
      }
    case _C_ID:
      [self encodeObject:*(id*)d withName:name];
      break;
    case _C_ARY_B:
      {
	int len = atoi(type+1);	/* xxx why +1 ? */
	int offset;

	while (isdigit(*++type));
	offset = objc_sizeof_type(type);
	[self encodeName:name];
	[self encodeIndent];
	while (len-- > 0)
	  {
	    [self encodeValueOfType:type 
		  at:d 
		  withName:"array component"];
	    ((char*)d) += offset;
	  }
	[self encodeUnindent];
	break; 
      }
    case _C_STRUCT_B:
      {
	int acc_size = 0;
	int align;

	while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	[self encodeName:name];
	[self encodeIndent];
	while (*type != _C_STRUCT_E)
	  {
	    align = objc_alignof_type (type); /* pad to alignment */
	    acc_size = ROUND (acc_size, align);
	    [self encodeValueOfType:type 
		  at:((char*)d)+acc_size 
		  withName:"structure component"];
	    acc_size += objc_sizeof_type (type); /* add component size */
	    type = objc_skip_typespec (type); /* skip component */
	  }
	[self encodeUnindent];
	break;
      }
    case _C_PTR:
      [self error:"Cannot encode pointers"];
      break;
#if 0 /* No, don't know how far to recurse */
      [self encodeValueOfType:type+1 at:*(char**)d withName:name];
      break;
#endif
    default:
      [self encodeValueOfSimpleType:type at:d withName:name];
    }
}

- (void) encodeValueOfSimpleType: (const char*)type 
   at: (const void*)d 
   withName: (const char *)name
{
  [self notImplemented:_cmd];
}

- (void) decodeValueOfType: (const char*)type
   at: (void*)d 
   withName: (const char **)namePtr
{
  switch (*type)
    {
    case _C_CLASS:
      {
	[self decodeName:namePtr];
	*(id*)d = [self decodeClass];
	break;
      }
    case _C_ATOM:
      *(const char**)d = [self decodeAtomicStringWithName:namePtr];
      break;
    case _C_SEL:
      *(SEL*)d = [self decodeSelectorWithName:namePtr];
      break;
    case _C_ID:
      [self decodeObjectAt:d withName:namePtr];
      break;
    case _C_ARY_B:
      {
	/* xxx Do we need to allocate space, just like _C_CHARPTR ? */
	int len = atoi(type+1);
	int offset;
	[self decodeName:namePtr];
	[self decodeIndent];
	while (isdigit(*++type));
	offset = objc_sizeof_type(type);
	while (len-- > 0)
	  {
	    [self decodeValueOfType:type 
		  at:d 
		  withName:namePtr];
	    ((char*)d) += offset;
	  }
	[self decodeUnindent];
	break; 
      }
    case _C_STRUCT_B:
      {
	/* xxx Do we need to allocate space just like char* ?  No. */
	int acc_size = 0;
	int align;
	while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	[self decodeName:namePtr];
	[self decodeIndent];		/* xxx insert [self decodeName:] */
	while (*type != _C_STRUCT_E)
	  {
	    align = objc_alignof_type (type); /* pad to alignment */
	    acc_size = ROUND (acc_size, align);
	    [self decodeValueOfType:type 
		  at:((char*)d)+acc_size 
		  withName:namePtr];
	    acc_size += objc_sizeof_type (type); /* add component size */
	    type = objc_skip_typespec (type); /* skip component */
	  }
	[self decodeUnindent];
	break;
      }
    case _C_PTR:
      [self error:"Cannot decode pointers"];
      break;
#if 0 /* No, don't know how far to recurse */
      OBJC_MALLOC(*(void**)d, void*, 1);
      [self decodeValueOfType:type+1 at:*(char**)d withName:namePtr];
      break;
#endif
    default:
      [self decodeValueOfSimpleType:type at:d withName:namePtr];
    }
  /* xxx We need to catch unions and make a sensible error message */
}

- (void) decodeValueOfSimpleType: (const char*)type
   at: (void*)d 
   withName: (const char **)namePtr
{
  [self notImplemented:_cmd];
}

- (void) encodeBytes: (const char *)b
   count: (unsigned)c
   withName: (const char *)name
{
  [self notImplemented:_cmd];
}

- (void) decodeBytes: (char *)b
   count: (unsigned*)c
   withName: (const char **)name
{
  [self notImplemented:_cmd];
}

- (void) startEncodingInterconnectedObjects
{
  doing_root_object = YES;
  [self _coderPushRootObjectTable];
  [self _coderPushForwardObjectTable];
}

- (void) finishEncodingInterconnectedObjects
{
  /* xxx Perhaps we should look at the forward references and
     encode here any forward-referenced objects that haven't been
     encoded yet. */
  doing_root_object = NO;
  [self _coderPopRootObjectTable];
  [self _coderPopForwardObjectTable];
}

- (void) startDecodingInterconnectedObjects
{
  doing_root_object = YES;
  [self _coderPushRootObjectTable];
  [self _coderPushForwardObjectTable];
}

- (void) finishDecodingInterconnectedObjects
{
  SEL awake_sel = sel_get_any_uid("awakeAfterUsingCoder:");
  
  /* resolve object forward references */
  if (forward_object_tables)
    {
      void set_obj_addrs_for_xref(elt key, elt content)
	{
	  const struct objc_list *addr_list = content.void_ptr_u;
	  id object = [self _coderObjectAtReference:key.unsigned_int_u];
	  /* If reference isn't there, object will be nil, and all the
	     forward references to that object will be set to nil.  
	     I suppose this is fine. */
	  while (addr_list)
	    {
	      *((id*)(addr_list->head)) = object;
	      addr_list = addr_list->tail;
	    }
	}
      [[self _coderTopForwardObjectTable]
       withKeyElementsAndContentElementsCall:set_obj_addrs_for_xref];
      [self _coderPopForwardObjectTable];
    }

  /* call awake all the objects read */
  if (awake_sel)
    {
      void ask_awake(elt e)
	{
	  if (__objc_responds_to(e.id_u, awake_sel))
	    (*objc_msg_lookup(e.id_u,awake_sel))(e.id_u, awake_sel, self);
	}
      [[self _coderTopRootObjectTable] withElementsCall:ask_awake];
    }
  [self _coderPopRootObjectTable];
  doing_root_object = NO;
}

/* NOTE: This *can* be called recursively */
- (void) encodeRootObject: anObj
    withName: (const char *)name
{
  [self encodeTag:CODER_ROOT_OBJECT];
  [self startEncodingInterconnectedObjects];
  [self encodeIndent];
  [self encodeObject:anObj withName:name];
  [self encodeUnindent];
  [self finishEncodingInterconnectedObjects];
}

- (void) _decodeRootObjectAt: (id*)ret withName: (const char **)name
{
  [self startDecodingInterconnectedObjects];
  [self decodeIndent];
  [self decodeObjectAt:ret withName:name];
  [self decodeUnindent];
  [self finishDecodingInterconnectedObjects];
}


/* These two methods are the designated coder methods called when
   we've determined that the object has not already been
   encoded---we're not simply going to encode a cross-reference number
   to the object, we're actually going to encode an object (either a
   proxy to the object or the object itself).

   ConnectedCoder overrides _doEncodeObject: in order to implement
   the encoding of proxies. */

- (void) _doEncodeBycopyObject: anObj
{
  [self encodeClass:object_get_class(anObj)];
  /* xxx Make sure it responds to this selector! */
  [anObj encodeWithCoder:(id)self];
}

/* This method overridden by ConnectedCoder */
- (void) _doEncodeObject: anObj
{
  [self _doEncodeBycopyObject:anObj];
}


/* This is the designated object encoder */
- (void) _encodeObject: anObj
   withName: (const char*) name
   isBycopy: (BOOL) bycopy_flag
   isForwardReference: (BOOL) forward_ref_flag
{
  [self encodeName:name];
  [self encodeIndent];
  if (!anObj)
    {
      [self encodeTag:CODER_OBJECT_NIL];
    }
  else if (my_object_is_class(anObj))
    {
      [self encodeTag:CODER_CLASS_OBJECT];
      [self encodeClass:anObj];
    }
  else
    {
      unsigned xref = PTR2LONG(anObj);
      if ([self _coderHasObjectReference:xref])
	{
	  [self encodeTag:CODER_REPEATED_OBJECT];
	  [self encodeValueOfSimpleType:@encode(unsigned)
		at:&xref 
		withName:"Object cross-reference number"];
	}
      else if (forward_ref_flag
	       || [in_progress_table containsElement:xref])
	{
	  [self encodeTag:CODER_OBJECT_FORWARD_REFERENCE];
	  [self encodeValueOfSimpleType:@encode(unsigned)
		at:&xref 
		withName:"Object forward cross-reference number"];
	}
      else
	{
	  [in_progess_table addElement:xref];
	  [self encodeTag:CODER_OBJECT];
	  [self encodeValueOfSimpleType:@encode(unsigned)
		at:&xref 
		withName:"Object cross-reference number"];
	  [self encodeIndent];
	  if (bycopy_flag)
	    [self _doEncodeBycopyObject:anObj];
	  else
	    [self _doEncodeObject:anObj];	    
	  [self encodeUnindent];
	  [self _internalCoderPutObject:anObj atReference:xref];
	  [in_progess_table removeElement:xref];
	}
    }
  [self encodeUnindent];
}

- (void) encodeObject: anObj
   withName: (const char *)name
{
  [self _encodeObject:anObj withName:name isBycopy:NO isForwardReference:NO];
}


- (void) encodeObjectBycopy: anObj
   withName: (const char *)name
{
  [self _encodeObject:anObj withName:name isBycopy:YES isForwardReference:NO];
}

- (void) encodeObjectReference: anObj
   withName: (const char *)name
{
  [self _encodeObject:anObj withName:name isBycopy:NO isForwardReference:YES];
}


/* This is the designated (and one-and-only) object decoder */
- (void) decodeObjectAt: (id*)anObjPtr withName: (const char**)name
{
  unsigned char tag;

  [self decodeName:name];
  [self decodeIndent];
  tag = [self decodeTag];
  switch (tag)
    {
    case CODER_OBJECT_NIL:
      *anObjPtr = nil;
      break;
    case CODER_CLASS_OBJECT:
      *anObjPtr = [self decodeClass];
      break;
    case CODER_OBJECT:
      {
	unsigned xref;
	Class object_class;
	SEL new_sel = sel_get_any_uid("newWithCoder:");
	Method* new_method;

	[self decodeValueOfSimpleType:@encode(unsigned) 
	      at:&xref 
	      withName:NULL];
	[self decodeIndent];
	object_class = [self decodeClass];
	/* xxx Should change the runtime.
	   class_get_class_method should take the class as its first
	   argument, not the metaclass! */
	new_method = class_get_class_method(class_get_meta_class(object_class),
					    new_sel);
	if (new_method)
	  *anObjPtr = (*(new_method->method_imp))(object_class, new_sel, self);
	else
	  {
	    SEL init_sel = sel_get_any_uid("initWithCoder:");
	    Method *init_method = 
	      class_get_instance_method(object_class, init_sel);
	    /*xxx Fix this NS_NOZONE. */
	    *anObjPtr = (id) NSAllocateObject (object_class, 0, NS_NOZONE);
	    if (init_method)
	      *anObjPtr = 
		(*(init_method->method_imp))(*anObjPtr, init_sel, self);
	    /* xxx else, error? */
	  }
	/* Would get error here with Connection-wide object references
	   because addProxy gets called in +newRemote:connection: */
	if ([self _coderHasObjectReference:xref])
	  [self error:"two objects have the same cross-reference number"];
	if (debug_coder)
	  fprintf(stderr, "Coder decoding registered class xref %u\n", xref);
	[self _internalCoderPutObject:*anObjPtr atReference:xref];
	[self decodeUnindent];
	break;
      }
    case CODER_ROOT_OBJECT:
      {
	doing_root_object = YES;
	[self _decodeRootObjectAt:anObjPtr withName:name];
	doing_root_object = NO;
	break;
      }
    case CODER_REPEATED_OBJECT:
      {
	unsigned xref;

	[self decodeValueOfSimpleType:@encode(unsigned)
	      at:&xref 
	      withName:NULL];
	*anObjPtr = [self _coderObjectAtReference:xref];
	if (!*anObjPtr)
	  [self error:"repeated object cross-reference number %u not found",
		xref];
	break;
      }
    case CODER_OBJECT_FORWARD_REFERENCE:
      {
	unsigned xref;
	struct objc_list* addr_list;

	if (!doing_root_object)
	  [self error:"can't decode forward reference when not decoding "
		"a root object"];
	[self decodeValueOfSimpleType:@encode(unsigned)
	      at:&xref 
	      withName:NULL];
	addr_list = [self _coderForwardObjectsAtReference:xref];
	[self _coderPutForwardObjects:list_cons(anObjPtr,addr_list)
	      atReference:xref];
	break;
      }
    default:
      [self error:"unrecognized object tag = %d", (int)tag];
    }
  [self decodeUnindent];
}

- (void) encodeWithName: (const char *)name
   valuesOfTypes: (const char *)types, ...
{
  va_list ap;

  [self encodeName:name];
  va_start(ap, types);
  while (*types)
    {
      [self encodeValueOfType:types
	    at:va_arg(ap, void*)
	    withName:"Encoded Types Component"];
      types = objc_skip_typespec(types);
    }
  va_end(ap);
}

- (void) decodeWithName: (const char **)name
   valuesOfTypes: (const char *)types, ...
{
  va_list ap;

  [self decodeName:name];
  va_start(ap, types);
  while (*types)
    {
      [self decodeValueOfType:types
	    at:va_arg(ap, void*)
	    withName:NULL];
      types = objc_skip_typespec(types);
    }
  va_end(ap);
}

- (void) encodeValueOfTypes: (const char *)types
   at: (const void *)d
   withName: (const char *)name
{
  [self encodeName:name];
  while (*types)
    {
      [self encodeValueOfType:types
	    at:d
	    withName:"Encoded Types Component"];
      types = objc_skip_typespec(types);
    }
}

- (void) decodeValueOfTypes: (const char *)types
   at: (void *)d
   withName: (const char **)name
{
  [self decodeName:name];
  while (*types)
    {
      [self decodeValueOfType:types
	    at:d
	    withName:NULL];
      types = objc_skip_typespec(types);
    }
}

- (void) encodeArrayOfType: (const char *)type
   at: (const void *)d
   count: (unsigned)c
   withName: (const char *)name
{
  int i;
  int offset = objc_sizeof_type(type);
  const char *where = d;

  [self encodeName:name];
  [self encodeValueOfType:@encode(unsigned) at:&c withName:"Array Count"];
  for (i = 0; i < c; i++)
    {
      [self encodeValueOfType:type
	    at:where
	    withName:"Encoded Array Component"];
      where += offset;
    }
}

- (void) decodeArrayOfType: (const char *)type
   at: (void *)d
   count: (unsigned *)c
   withName: (const char **)name
{
  int i;
  int offset = objc_sizeof_type(type);
  char *where = d;

  [self decodeName:name];
  [self decodeValueOfType:@encode(unsigned) at:c withName:NULL];
  for (i = 0; i < *c; i++)
    {
      [self decodeValueOfType:type
	    at:where
	    withName:NULL];
      where += offset;
    }
}

- (void) dealloc
{
  /* xxx No. [self _finishDecodeRootObject]; */
  [const_ptr_table release];
  [in_progress_table release];
  [object_table release];
  [forward_object_tables release];
  [root_object_tables release];
  [stream release];		/* xxx should we do this? */
  [super dealloc];
}

- (void) encodeIndent
{
  /* Do nothing */
}

- (void) encodeUnindent
{
  /* Do nothing */
}

- (void) decodeIndent
{
  /* Do nothing */
}

- (void) decodeUnindent
{
  /* Do nothing */
}

- (void) encodeName: (const char*)n
{
  /* Do nothing */
}

- (void) decodeName: (const char**)n
{
  if (n)
    {
      OBJC_MALLOC(*n, char, 1);
      **(char**)n = '\0';
#if 0
      {
	/* xxx fix this junk */
	char *foo = *(char**)n;
	foo[0] = '\0';
      }
#endif
    }
}

- (int) coderFormatVersion
{
  return format_version;
}

- (int) coderConcreteFormatVersion
{
  return concrete_format_version;
}

- (void) resetCoder
{
  /* xxx Finish this */
  [const_ptr_table empty];
}

@end


/* Here temporarily until GCC category bug is fixed */
#include <objects/Connection.h>
#include <objects/Proxy.h>
#include <objects/ConnectedCoder.h>


/* Eventually put these directly in Object */

/* By combining these, we're working around the GCC 2.6 bug that
   causes not all the categories to be processed by the runtime. */

@implementation NSObject (CoderAdditions)

/* Now in NSObject.m */
#if 0
- (void) encodeWithCoder: (id <Encoding>)anEncoder
{
  return;
}

- initWithCoder: (id <Decoding>)aDecoder
{
  return self;
}

+ newWithCoder: (id <Decoding>)aDecoder
{
  return NSAllocateObject(self, 0, NULL); /* xxx Fix this NULL */
}
#endif



/* @implementation Object (ConnectionRequests) */


/* By default, Object's encode themselves as proxies across Connection's */
- classForConnectedCoder:aRmc
{
  return [[aRmc connection] proxyClass];
}

/* But if any object overrides the above method to return [Object class]
   instead, the Object implementation of the coding method will actually
   encode the object itself, not a proxy */
+ (void) encodeObject: anObject withConnectedCoder: aRmc
{
  [anObject encodeWithCoder:aRmc];
}

@end


