/* Implementation of GNU Objective-C coder object for use serializing
   Copyright (C) 1994, 1995, 1996 Free Software Foundation, Inc.
   
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
#include <objects/Set.h>
#include <objects/NSString.h>
#include <objects/Streaming.h>
#include <objects/Stream.h>
#include <objects/CStreaming.h>
#include <objects/CStream.h>
#include <objects/TextCStream.h>
#include <objects/StdioStream.h>
#include <Foundation/NSException.h>
#include <assert.h>


/* Exception strings */
id CoderSignatureMalformedException = @"CoderSignatureMalformedException";

#define DEFAULT_FORMAT_VERSION 0

enum {CODER_OBJECT_NIL = 0, CODER_OBJECT, CODER_ROOT_OBJECT, 
	CODER_REPEATED_OBJECT, CODER_CLASS_OBJECT, 
	CODER_OBJECT_FORWARD_REFERENCE,
	CODER_CLASS_NIL, CODER_CLASS, CODER_REPEATED_CLASS,
	CODER_CONST_PTR_NULL, CODER_CONST_PTR, CODER_REPEATED_CONST_PTR};

#define ROUND(V, A) \
  ({ typeof(V) __v=(V); typeof(A) __a=(A); \
     __a*((__v+__a-1)/__a); })

#define DOING_ROOT_OBJECT (interconnected_stack_height != 0)

static BOOL debug_coder = NO;
static id default_stream_class;
static id default_cstream_class;


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
      default_stream_class = [MemoryStream class];
      default_cstream_class = [TextCStream class];
      assert(sizeof(void*) == sizeof(unsigned)); 
    }
}

+ setDebugging: (BOOL)f
{
  debug_coder = f;
  return self;
}


/* Default Stream and CStream class handling. */

+ (void) setDefaultCStreamClass: sc
{
  default_cstream_class = sc;
}

+ defaultCStreamClass
{
  return default_cstream_class;
}

+ (void) setDefaultStreamClass: sc
{
  default_stream_class = sc;
}

+ defaultStreamClass
{
  return default_stream_class;
}


/* Signature Handling. */

+ (int) defaultFormatVersion
{
  return DEFAULT_FORMAT_VERSION;
}

#define SIGNATURE_FORMAT_STRING \
@"GNU Objective C Class Library %s version %d\n"

- (void) writeSignature
{
  /* Careful: the string should not contain newlines. */
  [[cstream stream] writeFormat: SIGNATURE_FORMAT_STRING,
		    object_get_class_name(self),
		    format_version];
}

+ (void) readSignatureFromCStream: (id <CStreaming>) cs
		     getClassname: (char *) name
		    formatVersion: (int*) version
{
  int got;

  got = [[cs stream] readFormat: SIGNATURE_FORMAT_STRING,
		     name, version];
  if (got != 2)
    [NSException raise:CoderSignatureMalformedException
		 format:@"Coder found a malformed signature"];
}


/* Initialization. */

/* This is the designated sub-initializer.  
   Don't call it yourself.
   Do override it and call [super...] in subclasses. */
- _initWithCStream: (id <CStreaming>) cs
    formatVersion: (int) version
       isDecoding: (BOOL) f
{
  is_decoding = f;
  format_version = version;
  cstream = [cs retain];

  object_table = nil;
  classname_map = [[Dictionary alloc] initWithType:@encode(char*)
				      keyType:@encode(char*)];
  in_progress_table = [[Array alloc] initWithType:@encode(unsigned)];
  const_ptr_table = [[Dictionary alloc] initWithType:@encode(void*) 
					keyType:@encode(unsigned)];
  root_object_table = nil;
  forward_object_table = nil;
  interconnected_stack_height = 0;

  return self;
}

+ coderReadingFromStream: (id <Streaming>) stream
{
  id cs = [CStream cStreamReadingFromStream: stream];
  char name[128];		/* Max classname length. */
  int version;
  id new_coder;

  [self readSignatureFromCStream: cs
	getClassname: name
	formatVersion: &version];

  new_coder = [[objc_lookup_class(name) alloc]
		_initWithCStream: cs
		formatVersion: version
		isDecoding: YES];
  return [new_coder autorelease];
}

+ coderReadingFromFile: (id <String>) filename
{
  return [self coderReadingFromStream: 
		 [[[StdioStream alloc] initWithFilename:filename fmode:"r"]
		   autorelease]];
}

- initForReadingFromStream: (id <Streaming>) stream
	     formatVersion: (int)version
{
  [self notImplemented:_cmd];
  [self _initWithCStream: [[[[[self class] defaultCStreamClass] alloc]
			     initForWritingToStream: stream]
			    autorelease]
	formatVersion: version
	isDecoding: YES];
  /* Model this after [CStream -initForReading...] */
  return self;
}

- initForReadingFromStream: (id <Streaming>) s
{
  return [self initForReadingFromStream: s
	       formatVersion: DEFAULT_FORMAT_VERSION];
}

- initForReadingFromFile: (id <String>) filename
{
  return [self initForReadingFromStream: 
		 [StdioStream streamWithFilename: filename
			      fmode: "r"]];
}

- initForWritingToStream: (id <Streaming>) s
	   formatVersion: (int) version
{
  [self _initWithCStream: [[[self class] defaultCStreamClass] 
			    cStreamWritingToStream: s]
	formatVersion: version
	isDecoding: NO];
  [self writeSignature];
  return self;
}

- initForWritingToStream: (id <Streaming>) s
{
  return [self initForWritingToStream: s
	       formatVersion: DEFAULT_FORMAT_VERSION];
}

- initForWritingToFile: (id <String>) filename
{
  return [self initForWritingToStream: 
		 [StdioStream streamWithFilename: filename
			      fmode: "w"]];
}

+ coderWritingToStream: (id <Streaming>)s
{
  return [[[self alloc] initForWritingToStream: s]
	   autorelease];
}

+ coderWritingToFile: (id <String>)filename
{
  return [self coderWritingToStream:
		 [StdioStream streamWithFilename: filename
			      fmode: "w"]];
}

- init
{
  [self shouldNotImplement:_cmd];
  return self;
}

+ decodeObjectFromStream: (id <Streaming>)stream
{
  id c, o;
  c = [self coderReadingFromStream:stream];
  [c decodeObjectAt: &o withName: NULL];
  return [o autorelease];
}

+ decodeObjectFromFile: (id <String>) filename
{
  return [self decodeObjectFromStream:
		 [StdioStream streamWithFilename:filename fmode: "r"]];
}



/* Functions and methods for keeping cross-references
   so objects aren't written/read twice. */

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
  if (!root_object_table)
    root_object_table = [[Dictionary alloc] initWithType:@encode(void*)
					    keyType:@encode(unsigned)];
}

- (void) _coderPopRootObjectTable
{
  assert(root_object_table);
  [root_object_table release];
  root_object_table = nil;
}

- _coderTopRootObjectTable
{
  assert(root_object_table);
  return root_object_table;
}

/* Here are the methods for forward object references. */

- (void) _coderPushForwardObjectTable
{
  if (!forward_object_table)
    forward_object_table = [[Dictionary alloc] initWithType:@encode(void*)
					       keyType:@encode(unsigned)];
}

- (void) _coderPopForwardObjectTable
{
  assert(forward_object_table);
  [forward_object_table release];
  forward_object_table = nil;
}

- _coderTopForwardObjectTable
{
  assert(forward_object_table);
  return forward_object_table;
}

- (struct objc_list *) _coderForwardObjectsAtReference: (unsigned)xref
{
  return (struct objc_list*)
    [[self _coderTopForwardObjectTable] elementAtKey:xref 
     ifAbsentCall:exc_return_null].void_ptr_u;
}

- (void) _coderPutForwardObjects: (struct objc_list *)head
   atReference: (unsigned)xref
{
  [[self _coderTopForwardObjectTable] putElement:head atKey:xref];
}


/* This is the Coder's interface to the over-ridable
   "_coderPutObject:atReference" method.  Do not override it.  It
   handles the root_object_table. */

- (void) _internalCoderPutObject: anObj atReference: (unsigned)xref
{
  if (DOING_ROOT_OBJECT)
    {
      assert(![[self _coderTopRootObjectTable] includesKey:xref]);
      [[self _coderTopRootObjectTable] putElement:anObj atKey:xref];
    }
  [self _coderPutObject:anObj atReference:xref];
}


/* Method for encoding things. */

- (void) decodeValueOfCType: (const char*)type
   at: (void*)d 
   withName: (id <String> *)namePtr
{
  [cstream decodeValueOfCType:type
	   at:d
	   withName:namePtr];
}

- (void) encodeValueOfCType: (const char*)type 
   at: (const void*)d 
   withName: (id <String>)name
{
  [cstream encodeValueOfCType:type
	   at:d
	   withName:name];
}

- (void) encodeBytes: (const char *)b
   count: (unsigned)c
   withName: (id <String>)name
{
  [self notImplemented:_cmd];
}

- (void) decodeBytes: (char *)b
   count: (unsigned*)c
   withName: (id <String> *) name
{
  [self notImplemented:_cmd];
}


- (void) encodeTag: (unsigned char)t
{
  [self encodeValueOfCType:@encode(unsigned char) 
	at:&t 
	withName:@"Coder tag"];
}

- (unsigned char) decodeTag
{
  unsigned char t;
  [self decodeValueOfCType:@encode(unsigned char)
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
	  [self encodeValueOfCType:@encode(unsigned)
		at:&xref 
		withName:@"Class cross-reference number"];
	}
      else
	{
	  const char *class_name = class_get_class_name(aClass);
	  int class_version = class_get_version(aClass);

	  assert(class_name);
	  assert(*class_name);
	  [self encodeTag: CODER_CLASS];
	  [self encodeValueOfCType:@encode(unsigned)
		at:&xref
		withName:@"Class cross-reference number"];
	  [self encodeValueOfCType:@encode(char*)
		at:&class_name
		withName:@"Class name"];
	  [self encodeValueOfCType:@encode(int)
		at:&class_version
		withName:@"Class version"];
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
	[self decodeValueOfCType:@encode(unsigned)
	      at:&xref
	      withName:NULL];
	[self decodeValueOfCType:@encode(char*)
	      at:&class_name
	      withName:NULL];
	[self decodeValueOfCType:@encode(int)
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
	[self decodeValueOfCType:@encode(unsigned)
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

- (void) encodeAtomicString: (const char*) sp
   withName: (id <String>) name
{
  /* xxx Add repeat-string-ptr checking here. */
  [self notImplemented:_cmd];
  [self encodeValueOfCType:@encode(char*) at:&sp withName:name];
}

- (const char *) decodeAtomicStringWithName: (id <String> *) name
{
  char *s;
  /* xxx Add repeat-string-ptr checking here */
  [self notImplemented:_cmd];
  [self decodeValueOfCType:@encode(char*) at:&s withName:name];
  return s;
}

#define NO_SEL_TYPES "none"

- (void) encodeSelector: (SEL)sel withName: (id <String>) name
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
	  [self encodeValueOfCType:@encode(unsigned)
		at:&xref
		withName:@"SEL cross-reference number"];
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
	  [self encodeValueOfCType:@encode(unsigned)
		at:&xref
		withName:@"SEL cross-reference number"];
	  [self encodeValueOfCType:@encode(char*) 
		at:&sel_name 
		withName:@"SEL name"];
	  [self encodeValueOfCType:@encode(char*) 
		at:&sel_types 
		withName:@"SEL types"];
	  [self _coderPutConstPtr:sel atReference:xref];
	  if (debug_coder)
	    fprintf(stderr, "Coder encoding registered sel xref %u\n", xref);
	}
    }
  [self encodeUnindent];
  return;
}

- (SEL) decodeSelectorWithName: (id <String> *) name
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

	[self decodeValueOfCType:@encode(unsigned)
	      at:&xref
	      withName:NULL];
	[self decodeValueOfCType:@encode(char *) 
	      at:&sel_name 
	      withName:NULL];
	[self decodeValueOfCType:@encode(char *) 
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
	[self decodeValueOfCType:@encode(unsigned)
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

- (void) encodeValueOfObjCType: (const char*) type 
   at: (const void*) d 
   withName: (id <String>) name
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
    default:
      [self encodeValueOfCType:type at:d withName:name];
    }
}

- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)d 
   withName: (id <String> *)namePtr
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
    default:
      [self decodeValueOfCType:type at:d withName:namePtr];
    }
  /* xxx We need to catch unions and make a sensible error message */
}



- (void) startEncodingInterconnectedObjects
{
  if (interconnected_stack_height++)
    return;
  [self _coderPushRootObjectTable];
  [self _coderPushForwardObjectTable];
}

- (void) finishEncodingInterconnectedObjects
{
  /* xxx Perhaps we should look at the forward references and
     encode here any forward-referenced objects that haven't been
     encoded yet.  No---the current behavior implements NeXT's
     -encodeConditionalObject: */
  assert (interconnected_stack_height);
  if (--interconnected_stack_height)
    return;
  [self _coderPopRootObjectTable];
  [self _coderPopForwardObjectTable];
}

- (void) startDecodingInterconnectedObjects
{
  if (interconnected_stack_height++)
    return;
  [self _coderPushRootObjectTable];
  [self _coderPushForwardObjectTable];
}

- (void) finishDecodingInterconnectedObjects
{
  SEL awake_sel = sel_get_any_uid("awakeAfterUsingCoder:");
  
  assert (interconnected_stack_height);
  if (--interconnected_stack_height)
    return;

  /* resolve object forward references */
  if (forward_object_table)
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
}

/* NOTE: This *can* be called recursively */
- (void) encodeRootObject: anObj
    withName: (id <String>)name
{
  [self encodeName:@"Root Object"];
  [self encodeIndent];
  [self encodeTag:CODER_ROOT_OBJECT];
  [self startEncodingInterconnectedObjects];
  [self encodeObject:anObj withName:name];
  [self finishEncodingInterconnectedObjects];
  [self encodeUnindent];
}

- (void) _decodeRootObjectAt: (id*)ret withName: (id <String> *) name
{
  [self startDecodingInterconnectedObjects];
  [self decodeObjectAt:ret withName:name];
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
   withName: (id <String>) name
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
	  [self encodeValueOfCType:@encode(unsigned)
		at:&xref 
		withName:@"Object cross-reference number"];
	}
      else if (forward_ref_flag
	       || [in_progress_table includesElement:xref])
	{
	  [self encodeTag:CODER_OBJECT_FORWARD_REFERENCE];
	  [self encodeValueOfCType:@encode(unsigned)
		at:&xref 
		withName:@"Object forward cross-reference number"];
	}
      else
	{
	  [in_progress_table addElement:xref];
	  [self encodeTag:CODER_OBJECT];
	  [self encodeValueOfCType:@encode(unsigned)
		at:&xref 
		withName:@"Object cross-reference number"];
	  [self encodeIndent];
	  if (bycopy_flag)
	    [self _doEncodeBycopyObject:anObj];
	  else
	    [self _doEncodeObject:anObj];	    
	  [self encodeUnindent];
	  [self _internalCoderPutObject:anObj atReference:xref];
	  [in_progress_table removeElement:xref];
	}
    }
  [self encodeUnindent];
}

- (void) encodeObject: anObj
   withName: (id <String>)name
{
  [self _encodeObject:anObj withName:name isBycopy:NO isForwardReference:NO];
}


- (void) encodeObjectBycopy: anObj
   withName: (id <String>)name
{
  [self _encodeObject:anObj withName:name isBycopy:YES isForwardReference:NO];
}

- (void) encodeObjectReference: anObj
   withName: (id <String>)name
{
  [self _encodeObject:anObj withName:name isBycopy:NO isForwardReference:YES];
}


/* This is the designated (and one-and-only) object decoder */
- (void) decodeObjectAt: (id*) anObjPtr withName: (id <String> *) name
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

	[self decodeValueOfCType:@encode(unsigned) 
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
	[self _decodeRootObjectAt:anObjPtr withName:name];
	break;
      }
    case CODER_REPEATED_OBJECT:
      {
	unsigned xref;

	[self decodeValueOfCType:@encode(unsigned)
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

	if (!DOING_ROOT_OBJECT)
	  [self error:"can't decode forward reference when not decoding "
		"a root object"];
	[self decodeValueOfCType:@encode(unsigned)
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

- (void) encodeWithName: (id <String>)name
   valuesOfObjCTypes: (const char *)types, ...
{
  va_list ap;

  [self encodeName:name];
  va_start(ap, types);
  while (*types)
    {
      [self encodeValueOfObjCType:types
	    at:va_arg(ap, void*)
	    withName:@"Encoded Types Component"];
      types = objc_skip_typespec(types);
    }
  va_end(ap);
}

- (void) decodeWithName: (id <String> *)name
   valuesOfObjCTypes: (const char *)types, ...
{
  va_list ap;

  [self decodeName:name];
  va_start(ap, types);
  while (*types)
    {
      [self decodeValueOfObjCType:types
	    at:va_arg(ap, void*)
	    withName:NULL];
      types = objc_skip_typespec(types);
    }
  va_end(ap);
}

- (void) encodeValueOfObjCTypes: (const char *)types
   at: (const void *)d
   withName: (id <String>)name
{
  [self encodeName:name];
  while (*types)
    {
      [self encodeValueOfObjCType:types
	    at:d
	    withName:@"Encoded Types Component"];
      types = objc_skip_typespec(types);
    }
}

- (void) decodeValueOfObjCTypes: (const char *)types
   at: (void *)d
   withName: (id <String> *)name
{
  [self decodeName:name];
  while (*types)
    {
      [self decodeValueOfObjCType:types
	    at:d
	    withName:NULL];
      types = objc_skip_typespec(types);
    }
}

- (void) encodeArrayOfObjCType: (const char *)type
   at: (const void *)d
   count: (unsigned)c
   withName: (id <String>)name
{
  int i;
  int offset = objc_sizeof_type(type);
  const char *where = d;

  [self encodeName:name];
  for (i = 0; i < c; i++)
    {
      [self encodeValueOfObjCType:type
	    at:where
	    withName:@"Encoded Array Component"];
      where += offset;
    }
}

- (void) decodeArrayOfObjCType: (const char *)type
   at: (void *)d
   count: (unsigned)c
   withName: (id <String> *) name
{
  int i;
  int offset = objc_sizeof_type(type);
  char *where = d;

  [self decodeName:name];
  for (i = 0; i < c; i++)
    {
      [self decodeValueOfObjCType:type
	    at:where
	    withName:NULL];
      where += offset;
    }
}

/* We must separate the idea of "closing" a coder and "deallocating"
   a coder because of delays in deallocation due to -autorelease. */
- (void) closeCoder
{
  [[cstream stream] closeStream];
}

- (BOOL) isClosed
{
  return [[cstream stream] isClosed];
}

- (void) dealloc
{
  /* xxx No. [self _finishDecodeRootObject]; */
  [const_ptr_table release];
  [in_progress_table release];
  [object_table release];
  [forward_object_table release];
  [root_object_table release];
  [cstream release];
  [super dealloc];
}

- (void) encodeIndent
{
  [cstream encodeIndent];
}

- (void) encodeUnindent
{
  [cstream encodeUnindent];
}

- (void) decodeIndent
{
  [cstream decodeIndent];
}

- (void) decodeUnindent
{
  [cstream decodeUnindent];
}

- (void) encodeName: (id <String>)n
{
  [cstream encodeName: n];
}

- (void) decodeName: (id <String> *)n
{
  [cstream decodeName: n];
}


/* Access to instance variables. */

- (int) formatVersion
{
  return format_version;
}

- (BOOL) isDecoding
{
  return is_decoding;
}


- (void) resetCoder
{
  /* xxx Finish this */
  [self notImplemented:_cmd];
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


