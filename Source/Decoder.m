/* Abstract class for reading objects from a stream
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Created: February 1996, with core from Coder, created 1994.
   
   This file is part of the GNUstep Base Library.

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

#include <config.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/Coder.h>
#include <gnustep/base/CoderPrivate.h>
#include <gnustep/base/CStream.h>
#include <gnustep/base/Stream.h>
#include <gnustep/base/StdioStream.h>
#include <gnustep/base/Array.h>
#include <Foundation/NSException.h>

static int debug_coder = 0;

@implementation Decoder

static id dummyObject;

+ (void)initialize
{
  BOOL	beenHere = NO;

  if (beenHere == NO)
    {
      beenHere = YES;
      dummyObject = [NSObject new];
    }
}


/* Signature Handling. */

+ (void) readSignatureFromCStream: (id <CStreaming>) cs
		     getClassname: (char *) name
		    formatVersion: (int*) version
{
  int got;
  char package_name[64];
  int major_version;
  int minor_version;
  int subminor_version;

  /* SIGNATURE_FORMAT_STRING is defined in gnustep/base/CoderPrivate.h */
  got = [[cs stream] readFormat: SIGNATURE_FORMAT_STRING,
		     &package_name, 
		     &major_version,
		     &minor_version,
		     &subminor_version,
		     name, version];
  if (got != 6)
    [NSException raise: CoderSignatureMalformedException
		 format: @"Decoder found a malformed signature"];
}

/* This is the designated initializer. */
+ newReadingFromStream: (id <Streaming>) stream
{
  id cs = [CStream cStreamReadingFromStream: stream];
  char name[128];		/* Max classname length. */
  int version;
  Decoder *new_coder;

  [self readSignatureFromCStream: cs
	getClassname: name
	formatVersion: &version];

  new_coder = [[objc_lookup_class(name) alloc]
		_initWithCStream: cs
		formatVersion: version];
  new_coder->xref_2_object = NULL;
  new_coder->xref_2_object_root = NULL;
  new_coder->fref_2_object = NULL;
  new_coder->address_2_fref = NULL;
  new_coder->zone = NSDefaultMallocZone();
  return new_coder;
}

+ newReadingFromFile: (NSString*) filename
{
  return [self newReadingFromStream: 
		 [StdioStream streamWithFilename: filename 
			      fmode: "r"]];
}

+ decodeObjectWithName: (NSString* *) name
	    fromStream: (id <Streaming>)stream;
{
  id c, o;
  c = [self newReadingFromStream:stream];
  [c decodeObjectAt: &o withName: name];
  [c release];
  return [o autorelease];
}

+ decodeObjectWithName: (NSString* *) name
	      fromFile: (NSString*) filename;
{
  return [self decodeObjectWithName: name
	       fromStream:
		 [StdioStream streamWithFilename:filename fmode: "r"]];
}



/* Functions and methods for keeping cross-references
   so objects that were already read can be referred to again. */

/* These _coder... methods may be overriden by subclasses so that 
   cross-references can be kept differently. */

- (unsigned) _coderCreateReferenceForObject: anObj
{
  if (!xref_2_object)
    {
      xref_2_object = [Array new];
      /* Append an object so our xref numbers are in sync with the 
	 Encoders, which start at 1. */
      [xref_2_object appendObject: dummyObject];
    }
  if (debug_coder)
    fprintf (stderr, "Decoder registering object xref %u\n",
	     [xref_2_object count] - 1);
  [xref_2_object appendObject: anObj]; // xxx but this will retain anObj.  NO.
  /* This return value should be the same as the index of anObj 
     in xref_2_object. */
  return ([xref_2_object count] - 1);
}

- (void) _coderSubstituteObject: anObj atReference: (unsigned)xref
{
  [xref_2_object replaceObjectAtIndex: xref withObject: anObj];
}

- _coderObjectAtReference: (unsigned)xref
{
  assert (xref_2_object);
  return [xref_2_object objectAtIndex: xref];
}


/* The methods for the root object table.  The *root* object table
   (XREF_2_OBJECT_ROOT) isn't really used for much right now, but it
   may be in the future.  For now, most of the work is don't by
   XREF_2_OBJECT. */

- (void) _coderPushRootObjectTable
{
  if (!xref_2_object_root)
    xref_2_object_root = [Array new];
}

- (void) _coderPopRootObjectTable
{
  assert (xref_2_object_root);
  if (!interconnect_stack_height)
    {
      [xref_2_object_root release];
      xref_2_object_root = NULL;
    }
}

- (unsigned) _coderCreateReferenceForInterconnectedObject: anObj
{
  if (!xref_2_object_root)
    {
      xref_2_object_root = [Array new];
      /* Append an object so our xref numbers are in sync with the 
	 Encoders, which start at 1. */
      [xref_2_object_root appendObject: dummyObject];
    }
  [xref_2_object_root appendObject: anObj];
  /* This return value should be the same as the index of anObj 
     in xref_2_object_root. */
  return ([xref_2_object_root count] - 1);
}

- _coderTopRootObjectTable
{
  assert (xref_2_object_root);
  return xref_2_object_root;
}


/* Using the next three methods, subclasses can change the way that
   const pointers (like SEL, Class, Atomic strings, etc) are
   archived. */

- (unsigned) _coderCreateReferenceForConstPtr: (const void*)ptr
{
  unsigned xref;

  if (!xref_2_const_ptr)
    {
      xref_2_const_ptr = NSCreateMapTable (NSIntMapKeyCallBacks,
					   NSNonOwnedPointerMapValueCallBacks,
					   0);
      /* Append an object so our xref numbers are in sync with the 
	 Encoders, which start at 1. */
      NSMapInsert (xref_2_const_ptr, (void*)0, (void*)1);
    }
  xref = NSCountMapTable (xref_2_const_ptr);
  NSMapInsert (xref_2_const_ptr, (void*)xref, ptr);
  return xref;
}

- (const void*) _coderConstPtrAtReference: (unsigned)xref;
{
  assert (xref_2_const_ptr);
  return NSMapGet (xref_2_const_ptr, (void*)xref);
}


/* Here are the methods for forward object references. */

- (void) _coderPushForwardObjectTable
{
#if 0
  if (!fref_stack)
    fref_stack = o_list_of_void_p ();
  o_list_append_element (fref_stack, NSCreateMap (...));
#endif
  if (!address_2_fref)
    address_2_fref = NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks,
				       NSIntMapValueCallBacks, 0);
				    
}

- (void) _coderPopForwardObjectTable
{
  assert (address_2_fref);
  if (!interconnect_stack_height)
    {
      NSFreeMapTable (address_2_fref);
      address_2_fref = NULL;
    }
}

- (void) _coderSatisfyForwardReference: (unsigned)fref withObject: anObj
{
  assert (address_2_fref);
  if (!fref_2_object)
    /* xxx Or should this be NSObjectMapValueCallBacks, so we make
       sure the object doesn't get released before we can resolve
       references with it? */
    fref_2_object = NSCreateMapTable (NSIntMapKeyCallBacks,
				      NSNonOwnedPointerMapValueCallBacks, 0);
  /* There should only be one object for each fref. */
  assert (!NSMapGet (fref_2_object, (void*)fref));
  NSMapInsert (fref_2_object, (void*)fref, anObj);
}

- (void) _coderAssociateForwardReference: (unsigned)fref
		       withObjectAddress: (void*)addr
{
  /* Register ADDR as associated with FREF; later we will put id 
     associated with FREF at ADDR. */
  assert (address_2_fref);
  /* There should not be duplicate addresses */
  assert (!NSMapGet (address_2_fref, addr));
  NSMapInsert (address_2_fref, addr, (void*)fref);
}

- (void) _coderResolveTopForwardReferences
{
  /* Enumerate the forward references and put them at the proper addresses. */
  NSMapEnumerator me;
  void *fref;
  void *addr;

  if (!address_2_fref)
    return;

  /* Go through all the addresses that are needing to be filled
     in with forward references, and put the correct object there.
     If fref_2_object does not contain an object for fref, (i.e. there 
     was no satisfier for the forward reference), put nil there. */
  me = NSEnumerateMapTable (address_2_fref);
  while (NSNextMapEnumeratorPair (&me, &addr, &fref))
    *(id*)addr = (id) NSMapGet (fref_2_object, fref);
}


/* This is the Coder's interface to the over-ridable
   "_coderCreateReferenceForObject" method.  Do not override it.  It
   handles the xref_2_object_root. */

- (unsigned) _coderInternalCreateReferenceForObject: anObj
{
  unsigned xref = [self _coderCreateReferenceForObject: anObj];
  if (DOING_ROOT_OBJECT)
    [self _coderCreateReferenceForInterconnectedObject: anObj];
  return xref;
}

- (void) _coderInternalSubstituteObject: anObj atReference: (unsigned)xref
{
  [self _coderSubstituteObject: anObj atReference: xref];
  /* xxx If we ever use the root object table, do something with it also. */
}



/* Method for decoding things. */

- (void) decodeValueOfCType: (const char*)type
   at: (void*)d 
   withName: (NSString* *)namePtr
{
  [cstream decodeValueOfCType:type
	   at:d
	   withName:namePtr];
}

- (void) decodeBytes: (void *)b
   count: (unsigned)c
   withName: (NSString* *) name
{
  int actual_count;
  /* xxx Is this what we want?  
     It won't be cleanly readable in TextCStream's. */
  [cstream decodeName: name];
  actual_count = [[cstream stream] readBytes: b length: c];
  assert (actual_count == c);
}

- (unsigned char) decodeTag
{
  if ([cstream respondsToSelector: @selector(decodeTag)])
    return [(id)cstream decodeTag];
  {
    unsigned char t;
    [self decodeValueOfCType:@encode(unsigned char)
	  at:&t 
	  withName:NULL];
    return t;
  }
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
    case CODER_CLASS_REPEATED:
      {
	unsigned xref;
	[self decodeValueOfCType: @encode(unsigned)
	      at: &xref
	      withName: NULL];
	ret = (id) [self _coderConstPtrAtReference: xref];
	if (!ret)
	  [NSException 
	    raise: NSGenericException
	    format: @"repeated class cross-reference number %u not found",
	    xref];
	break;
      }
    case CODER_CLASS:
      {
	[self decodeValueOfCType: @encode(char*)
	      at: &class_name
	      withName: NULL];
	[self decodeValueOfCType: @encode(int)
	      at: &class_version
	      withName: NULL];

	/* xxx should do classname substitution, 
	   ala decodeClassName:intoClassName: here. */

	ret = objc_lookup_class (class_name);
	if (ret == Nil)
	  [NSException raise: NSGenericException
		       format: @"Couldn't find class `%s'", class_name];
	if (class_get_version(ret) != class_version)
	  [NSException 
	    raise: NSGenericException
	    format: @"Class version mismatch, executable %d != encoded %d",
	    class_get_version(ret), class_version];

	{
	  unsigned xref;
	  xref = [self _coderCreateReferenceForConstPtr: ret];
	  if (debug_coder)
	    fprintf(stderr,
		    "Decoder decoding registered class xref %u\n", xref);
	}
	(*objc_free) (class_name);
	break;
      }
    default:
      [NSException raise: NSGenericException
		   format: @"unrecognized class tag = %d", (int)tag];
    }
  [self decodeUnindent];
  return ret;
}

- (const char *) decodeAtomicStringWithName: (NSString* *) name
{
  char *s;
  /* xxx Add repeat-string-ptr checking here */
  [self notImplemented:_cmd];
  [self decodeValueOfCType:@encode(char*) at:&s withName:name];
  return s;
}

- (SEL) decodeSelectorWithName: (NSString* *) name
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
    case CODER_CONST_PTR_REPEATED:
      {
	unsigned xref;
	[self decodeValueOfCType: @encode(unsigned)
	      at: &xref
	      withName: NULL];
	ret = (SEL) [self _coderConstPtrAtReference: xref];
	if (!ret)
	  [NSException 
	    raise: NSGenericException
	    format: @"repeated selector cross-reference number %u not found",
		xref];
	break;
      }
    case CODER_CONST_PTR:
      {
	char *sel_name;
	char *sel_types;

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
	  [NSException raise: NSGenericException
		       format: @"Could not find selector (%s) with types [%s]",
		       sel_name, sel_types];
#if ! NeXT_runtime
	if (strcmp(sel_types, NO_SEL_TYPES)
	    && !(sel_types_match(sel_types, ret->sel_types)))
	  [NSException 
	    raise: NSGenericException
	    format: @"ObjC runtime didn't provide SEL with matching type"];
#endif
	{
	  unsigned xref;
	  xref = [self _coderCreateReferenceForConstPtr: ret];
	  if (debug_coder)
	    fprintf(stderr,
		    "Decoder decoding registered sel xref %u\n", xref);
	}
	(*objc_free)(sel_name);
	(*objc_free)(sel_types);
	break;
      }
    default:
      [NSException raise: NSGenericException
		   format: @"unrecognized selector tag = %d", (int)tag];
    }
  [self decodeUnindent];
  return ret;
}


- (void) startDecodingInterconnectedObjects
{
  interconnect_stack_height++;
  [self _coderPushRootObjectTable];
  [self _coderPushForwardObjectTable];
}

- (void) finishDecodingInterconnectedObjects
{
  assert (interconnect_stack_height);

  /* xxx This might not be the right thing to do; perhaps we should do
     this finishing up work at the end of each nested call, not just
     at the end of all nested calls.
     However, then we might miss some forward references that we could
     have resolved otherwise. */
  if (--interconnect_stack_height)
    return;

  /* xxx fix the use of _coderPopForwardObjectTable and
     _coderPopRootObjectTable. */

#if 0   /* Actually, we do this below in -decodeObjectAt:withName: */
  /* Send "-awakeAfterUsingCoder:" to all the objects that were read */
  {
    SEL awake_sel = sel_get_any_uid("awakeAfterUsingCoder:");
    if (awake_sel)
      {
	int i;
	id table = [self _coderTopRootObjectTable];

	/* Loop through all objects that we decoded by this Decoder */
	for (i = [table count]-1; i >= 0; i--)
	  {
	    id o = [table objectAtIndex: i];
	    if (__objc_responds_to(o, awake_sel))
	      {
		replacement_obj = 
		  (*objc_msg_lookup(e.id_u,awake_sel))(o, awake_sel, self);
		/* xxx Make the replacement in the decoder's object tables. */
	      }
	  }
      }
  }
#endif

  /* resolve object forward references */
  [self _coderResolveTopForwardReferences];
  [self _coderPopForwardObjectTable];

  [self _coderPopRootObjectTable];
}

- (void) _decodeRootObjectAt: (id*)ret withName: (NSString* *) name
{
  [self startDecodingInterconnectedObjects];
  [self decodeObjectAt:ret withName:name];
  [self finishDecodingInterconnectedObjects];
}


- (void) decodeValueOfObjCType: (const char*)type
   at: (void*)d 
   withName: (NSString* *)namePtr
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

- (BOOL) _createReferenceBeforeInit
{
  return NO;
}

/* This is the designated (and one-and-only) object decoder */
- (void) decodeObjectAt: (id*) anObjPtr withName: (NSString* *) name
{
  unsigned char tag;
  unsigned fref = 0;
  id dummy_object;

  /* Sometimes the user wants to decode an object, but doesn't care to
     have a pointer to it, (LinkedList elements, for example).  In
     this case, the user can pass in NULL for anObjPtr, and all will
     be safe. */
  if (!anObjPtr)
    anObjPtr = &dummy_object;

  [self decodeName:name];
  [self decodeIndent];
  tag = [self decodeTag];
  switch (tag)
    {
    case CODER_OBJECT_NIL:
      *anObjPtr = nil;
      break;
    case CODER_OBJECT_CLASS:
      *anObjPtr = [self decodeClass];
      break;
    case CODER_OBJECT_FORWARD_REFERENCE:
      {
	if (!DOING_ROOT_OBJECT)
	  [NSException 
	    raise: NSGenericException
	    format: @"can't decode forward reference when not decoding "
	    @"a root object"];
	[self decodeValueOfCType: @encode(unsigned)
	      at: &fref 
	      withName: NULL];
	/* The user doesn't need the object pointer anyway, don't record
	   it in the table. */
	if (anObjPtr == &dummy_object)
	  break;
	[self _coderAssociateForwardReference: fref
	      withObjectAddress: anObjPtr];
	break;
      }
    case CODER_OBJECT:
      {
	Class object_class;
	SEL new_sel = sel_get_any_uid ("newWithCoder:");
	Method* new_method;
	BOOL create_ref_before_init = [self _createReferenceBeforeInit];
	/* Initialize this to <0 so we can tell below if it's been set */
	int xref = -1;

	[self decodeIndent];
	object_class = [self decodeClass];
	/* xxx Should change the runtime.
	   class_get_class_method should take the class as its first
	   argument, not the metaclass! */
	new_method = class_get_class_method(class_get_meta_class(object_class),
					    new_sel);
	if (new_method && !create_ref_before_init)
	  *anObjPtr = (*(new_method->method_imp))(object_class, new_sel, self);
	else
	  {
	    SEL init_sel = sel_get_any_uid ("initWithCoder:");
	    Method *init_method = 
	      class_get_instance_method (object_class, init_sel);
	    /* xxx Or should I send +alloc? */
	    *anObjPtr = (id) NSAllocateObject (object_class, 0, zone);
	    if (create_ref_before_init)
	      xref = [self _coderInternalCreateReferenceForObject: *anObjPtr];
	    if (init_method)
	      *anObjPtr = 
		(*(init_method->method_imp))(*anObjPtr, init_sel, self);
	    /* xxx else what, error? */
	  }

	/* Send -awakeAfterUsingCoder: */
	/* xxx Unknown whether -awakeAfterUsingCoder: should be sent here, or
	   when Decoder is deallocated, or after a root object is finished
	   decoding. */
	/* NOTE: Use of this with the NeXT archiving methods is
	   tricky, because if [*anObj initWithCoder:] creates any
	   objects that references *anObj, and if [*anObj
	   awakeAfterUsingCoder:] replaces itself, then the
	   subobject's references will not be to the replacement.
	   There is no way to magically fix this circular dependancy;
	   users must be aware.  We should just make sure we require
	   the same cautions as NeXT's implementation.  Note that, with
	   the GNU archiving methods, this problem doesn't occur because
	   we don't register the object until after it has been fully
	   initialized and awakened. */
	{
	  SEL awake_sel = sel_get_any_uid ("awakeAfterUsingCoder:");
	  IMP awake_imp = objc_msg_lookup (*anObjPtr, awake_sel);
	  id replacement;

	  if (awake_imp)
	    {
	      replacement = (*awake_imp) (*anObjPtr, awake_sel, self);
	      if (replacement != *anObjPtr)
		{
		  if (xref > 0)
		    [self _coderInternalSubstituteObject: replacement
			  atReference: xref];
		  *anObjPtr = replacement;
		}
	    }
	}

	[self decodeUnindent];

	/* If this was a CODER_OBJECT_FORWARD_SATISFIER, then remember it. */
	[self decodeValueOfCType: @encode(unsigned)
	      at: &fref 
	      withName: NULL];
	if (fref)
	  {
	    NSAssert (!create_ref_before_init,
		      @"You are trying to decode an object with the non-GNU\n"
		      @"OpenStep-style forward references, but the object's\n"
		      @"decoding mechanism wants to use GNU features.");
	    [self _coderSatisfyForwardReference: fref withObject: *anObjPtr];
	  }

	/* Would get error here with Connection-wide object references
	   because addProxy gets called in +newRemote:connection: */
	if (!create_ref_before_init)
	  {
	    unsigned xref = 
	      [self _coderInternalCreateReferenceForObject: *anObjPtr];
	    if (debug_coder)
	      fprintf(stderr, 
		      "Decoder decoding registered class xref %u\n", xref);
	  }
	break;
      }
    case CODER_OBJECT_ROOT:
      {
	[self _decodeRootObjectAt: anObjPtr withName: name];
	break;
      }
    case CODER_OBJECT_REPEATED:
      {
	unsigned xref;

	[self decodeValueOfCType: @encode(unsigned)
	      at: &xref 
	      withName: NULL];
	*anObjPtr = [[self _coderObjectAtReference: xref] retain];
	if (!*anObjPtr)
	  [NSException 
	    raise: NSGenericException
	    format: @"repeated object cross-reference number %u not found",
	    xref];
	break;
      }
    default:
      [NSException raise: NSGenericException
		   format: @"unrecognized object tag = %d", (int)tag];
    }
  [self decodeUnindent];
}


- (void) decodeWithName: (NSString* *)name
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

- (void) decodeValueOfObjCTypes: (const char *)types
   at: (void *)d
   withName: (NSString* *)name
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

- (void) decodeArrayOfObjCType: (const char *)type
   count: (unsigned)c
   at: (void *)d
   withName: (NSString* *) name
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

- (void) decodeIndent
{
  [cstream decodeIndent];
}

- (void) decodeUnindent
{
  [cstream decodeUnindent];
}

- (void) decodeName: (NSString* *)n
{
  [cstream decodeName: n];
}


+ (NSString*) classNameDecodedForArchiveClassName: (NSString*) inArchiveName
{
  [self notImplemented:_cmd];
  return nil;
}

+ (void) decodeClassName: (NSString*) inArchiveName
             asClassName:(NSString *)trueName
{
  [self notImplemented:_cmd];
}


/* Managing Zones */

- (NSZone*) objectZone
{
  return zone;
}

- (void) setObjectZone: (NSZone*)z
{
  zone = z;
}

- (void) dealloc
{
  if (xref_2_object) [xref_2_object release];
  if (xref_2_object_root) [xref_2_object_root release];
  if (xref_2_const_ptr) NSFreeMapTable (xref_2_const_ptr);
  if (fref_2_object) NSFreeMapTable (fref_2_object);
  if (address_2_fref) NSFreeMapTable (address_2_fref);
  [super dealloc];
}

@end
