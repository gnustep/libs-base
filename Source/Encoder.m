/* Abstract class for writing objects to a stream
   Copyright (C) 1996 Free Software Foundation, Inc.
   
   Written by:  R. Andrew McCallum <mccallum@gnu.ai.mit.edu>
   Created: February 1996
   
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
#include <objects/CoderPrivate.h>
#include <objects/MemoryStream.h>
#include <objects/StdioStream.h>
#include <objects/BinaryCStream.h>
#include <Foundation/NSArchiver.h>

static int default_format_version;
static id default_stream_class;
static id default_cstream_class;

#define debug_coder 0
#define DEFAULT_FORMAT_VERSION 0


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


@implementation Encoder

+ (void) initialize
{
  if (self == [Coder class])
    {
      /* This code has not yet been ported to machines for which
	 a pointer is not the same size as an int. */
      assert(sizeof(void*) == sizeof(unsigned)); 

      /* Initialize some defaults. */
      default_stream_class = [MemoryStream class];
      default_cstream_class = [BinaryCStream class];
      default_format_version = DEFAULT_FORMAT_VERSION;
    }
}


/* Default format version, Stream and CStream class handling. */

+ (int) defaultFormatVersion
{
  return default_format_version;
}

+ (void) setDefaultFormatVersion: (int)f
{
  default_format_version = f;
}

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

/* xxx This method interface may change in the future. */
- (const char *) defaultDecoderClassname
{
  return "Unarchiver";
}


/* Signature Handling. */

- (void) writeSignature
{
  /* Careful: the string should not contain newlines. */
  [[cstream stream] writeFormat: SIGNATURE_FORMAT_STRING,
		    [self defaultDecoderClassname],
		    format_version];
}



/* This is the designated initializer for this class. */
- initForWritingToStream: (id <Streaming>) s
       withFormatVersion: (int) version
            cStreamClass: (Class) cStreamClass
    cStreamFormatVersion: (int) cStreamFormatVersion
{
  [super _initWithCStream: [[cStreamClass alloc] 
			    initForWritingToStream: s
			    withFormatVersion: cStreamFormatVersion]
	 formatVersion: version];
  in_progress_table = NULL;
  object_2_xref = NULL;
  object_2_fref = NULL;
  const_ptr_2_xref = NULL;
  [self writeSignature];
  return self;
}

/* ..Writing... methods */

- initForWritingToStream: (id <Streaming>) s
	withCStreamClass: (Class) cStreamClass
{
  return [self initForWritingToStream: s
	       withFormatVersion: DEFAULT_FORMAT_VERSION
	       cStreamClass: cStreamClass
	       cStreamFormatVersion: [cStreamClass defaultFormatVersion]];
}

- initForWritingToStream: (id <Streaming>) s
{
  return [self initForWritingToStream: s
	       withCStreamClass: [[self class] defaultCStreamClass]];
}

- initForWritingToFile: (id <String>) filename
     withFormatVersion: (int) version
          cStreamClass: (Class) cStreamClass
  cStreamFormatVersion: (int) cStreamFormatVersion
{
  return [self initForWritingToStream: [StdioStream 
					 streamWithFilename: filename
					 fmode: "w"]
	       withFormatVersion: version
	       cStreamClass: cStreamClass
	       cStreamFormatVersion: cStreamFormatVersion];
}

- initForWritingToFile: (id <String>) filename
      withCStreamClass: (Class) cStreamClass
{
  return [self initForWritingToStream: [StdioStream 
					 streamWithFilename: filename
					 fmode: "w"]
	       withCStreamClass: cStreamClass];
}

- initForWritingToFile: (id <String>) filename
{
  return [self initForWritingToStream: 
		 [StdioStream streamWithFilename: filename
			      fmode: "w"]];
}

+ newWritingToStream: (id <Streaming>)s
{
  return [[self alloc] initForWritingToStream: s];
}

+ newWritingToFile: (id <String>)filename
{
  return [self newWritingToStream:
		 [StdioStream streamWithFilename: filename
			      fmode: "w"]];
}

+ (BOOL) encodeRootObject: anObject
		 withName: (id <String>) name
		 toStream: (id <Streaming>)stream
{
  id c = [[self alloc] initForWritingToStream: stream];
  [c encodeRootObject: anObject withName: name];
  [c closeCoding];
  [c release];
  return YES;
}

+ (BOOL) encodeRootObject: anObject 
  	         withName: (id <String>) name
                   toFile: (id <String>) filename
{
  return [self encodeRootObject: anObject
	       withName: name
	       toStream: [StdioStream streamWithFilename: filename
				      fmode: "w"]];
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
- (unsigned) _coderCreateReferenceForObject: anObj
{
  unsigned xref;
  if (!object_2_xref)
    {
      object_2_xref = 
	NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
			  NSIntMapValueCallBacks, 0);
    }
  xref = NSCountMapTable (object_2_xref) + 1;
  NSMapInsert (const_ptr_2_xref, anObj, (void*)xref);
}

- (unsigned) _coderReferenceForObject: anObject
{
  if (object_2_xref)
    return (unsigned) NSMapGet (object_2_xref, anObject);
  else
    return 0;
}


/* Methods for handling constant pointers */
/* By overriding the next three methods, subclasses can change the way
   that const pointers (like SEL, Class, Atomic strings, etc) are
   archived. */

- (unsigned) _coderCreateReferenceForConstPtr: (const void*)ptr
{
  unsigned xref;
  if (!const_ptr_2_xref)
    const_ptr_2_xref = 
      NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
			NSIntMapValueCallBacks, 0);
  else
    assert(! NSMapGet (const_ptr_2_xref, (void*)xref));
  xref = NSCountMapTable (const_ptr_2_xref) + 1;
  NSMapInsert (const_ptr_2_xref, ptr, (void*)xref);
}

- (unsigned) _coderReferenceForConstPtr: (const void*)ptr
{
  if (const_ptr_2_xref)
    return (unsigned) NSMapGet (const_ptr_2_xref, ptr);
  else
    return 0;
}


/* Methods for forward references */

- (unsigned) _coderCreateForwardReferenceForObject: anObject
{
  unsigned fref = NSCountMapTable (object_2_fref) + 1;
  assert ( ! NSMapGet (object_2_fref, anObject));
  NSMapInsert (object_2_fref, anObject, (void*)fref);
  return fref;
}

- (unsigned) _coderForwardReferenceForObject: anObject
{
  /* This method must return 0 if it's not there. */
  if (!object_2_fref)
    return 0;
  return (unsigned) NSMapGet (object_2_fref, anObject);
}

- (void) _coderRemoveForwardReferenceForObject: anObject
{
  NSMapRemove (object_2_fref, anObject);
}


/* This is the Coder's interface to the over-ridable
   "_coderPutObject:atReference" method.  Do not override it.  It
   handles the root_object_table. */

- (void) _coderInternalCreateReferenceForObject: anObj
{
  [self _coderCreateReferenceForObject: anObj];
}


/* Method for encoding things. */

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


- (void) encodeTag: (unsigned char)t
{
  if ([cstream respondsToSelector: @selector(encodeTag:)])
    [(id)cstream encodeTag:t];
  else
    [self encodeValueOfCType:@encode(unsigned char) 
	  at:&t 
	  withName:@"Coder tag"];
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
      /* xxx Perhaps I should do classname substitution here. */
      const char *class_name = class_get_class_name (aClass);
      unsigned xref;

      /* Do classname substitution, ala encodeClassName:intoClassName */
      if (classname_2_classname)
	{
	  char *subst_class_name = NSMapGet (classname_2_classname,
					     class_name);
	  if (subst_class_name)
	    {
	      class_name = subst_class_name;
	      aClass = objc_lookup_class (class_name);
	    }
	}

      xref = [self _coderReferenceForConstPtr: aClass];
      if (xref)
	{
	  /* It's already been encoded, so just encode the x-reference */
	  [self encodeTag: CODER_CLASS_REPEATED];
	  [self encodeValueOfCType: @encode(unsigned)
		at: &xref 
		withName: @"Class cross-reference number"];
	}
      else
	{
	  /* It hasn't been encoded before; encode it. */
	  int class_version = class_get_version (aClass);

	  assert (class_name);
	  assert (*class_name);

	  [self encodeTag: CODER_CLASS];
	  [self encodeValueOfCType: @encode(char*)
		at: &class_name
		withName: @"Class name"];
	  [self encodeValueOfCType: @encode(int)
		at: &class_version
		withName: @"Class version"];
	  [self _coderCreateReferenceForConstPtr: aClass];
	}
    }
  [self encodeUnindent];
  return;
}

- (void) encodeAtomicString: (const char*) sp
   withName: (id <String>) name
{
  /* xxx Add repeat-string-ptr checking here. */
  [self notImplemented:_cmd];
  [self encodeValueOfCType:@encode(char*) at:&sp withName:name];
}

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
      unsigned xref = [self _coderReferenceForConstPtr: sel];
      if (xref)
	{
	  /* It's already been encoded, so just encode the x-reference */
	  [self encodeTag: CODER_CONST_PTR_REPEATED];
	  [self encodeValueOfCType: @encode(unsigned)
		at: &xref
		withName: @"SEL cross-reference number"];
	}
      else
	{
	  const char *sel_name;
	  const char *sel_types;

	  [self encodeTag: CODER_CONST_PTR];

	  /* Get the selector name and type. */
	  sel_name = sel_get_name(sel);
#if NeXT_runtime
	  sel_types = NO_SEL_TYPES;
#else
	  sel_types = sel_get_type(sel);
#endif
#if 1 /* xxx Yipes,... careful... */
	  /* xxx Think about something like this. */
	  if (!sel_types)
	    sel_types = sel_get_type (sel_get_any_uid (sel_get_name (sel)));
#endif
	  if (!sel_name) [self error:"ObjC runtime didn't provide SEL name"];
	  if (!*sel_name) [self error:"ObjC runtime didn't provide SEL name"];
	  if (!sel_types) [self error:"ObjC runtime didn't provide SEL type"];
	  if (!*sel_types) [self error:"ObjC runtime didn't provide SEL type"];

	  [self _coderCreateReferenceForConstPtr: sel];
	  [self encodeValueOfCType: @encode(char*) 
		at: &sel_name 
		withName: @"SEL name"];
	  [self encodeValueOfCType: @encode(char*) 
		at: &sel_types 
		withName: @"SEL types"];
	  if (debug_coder)
	    fprintf(stderr, "Coder encoding registered sel xref %u\n", xref);
	}
    }
  [self encodeUnindent];
  return;
}

- (void) encodeValueOfObjCType: (const char*) type 
   at: (const void*) d 
   withName: (id <String>) name
{
  switch (*type)
    {
    case _C_CLASS:
      [self encodeName: name];
      [self encodeClass: *(id*)d];
      break;
    case _C_ATOM:
      [self encodeAtomicString: *(char**)d withName: name];
      break;
    case _C_SEL:
      {
	[self encodeSelector: *(SEL*)d withName: name];
	break;
      }
    case _C_ID:
      [self encodeObject: *(id*)d withName: name];
      break;
    default:
      [self encodeValueOfCType:type at:d withName:name];
    }
}


/* Methods for handling interconnected objects */

- (void) startEncodingInterconnectedObjects
{
  interconnect_stack_height++;
}

- (void) finishEncodingInterconnectedObjects
{
  /* xxx Perhaps we should look at the forward references and
     encode here any forward-referenced objects that haven't been
     encoded yet.  No---the current behavior implements NeXT's
     -encodeConditionalObject: */
  assert (interconnect_stack_height);
  interconnect_stack_height--;
}

/* NOTE: Unlike NeXT's, this *can* be called recursively */
- (void) encodeRootObject: anObj
    withName: (id <String>)name
{
  [self encodeName: @"Root Object"];
  [self encodeIndent];
  [self encodeTag: CODER_OBJECT_ROOT];
  [self startEncodingInterconnectedObjects];
  [self encodeObject: anObj withName: name];
  [self finishEncodingInterconnectedObjects];
  [self encodeUnindent];
}


/* These next two methods are the designated coder methods called when
   we've determined that the object has not already been
   encoded---we're not simply going to encode a cross-reference number
   to the object, we're actually going to encode an object (either a
   proxy to the object or the object itself).

   ConnectedCoder overrides _doEncodeObject: in order to implement
   the encoding of proxies. */

- (void) _doEncodeBycopyObject: anObj
{
  id encoded_object, encoded_class;

  /* Give the user the opportunity to substitute the class and object */
  /* xxx Is this the right place for this substitution? */
  if ([[self class] isKindOf: [NSCoder class]]
      && ! [[self class] isKindOf: [NSArchiver class]])
    /* Make sure we don't do this for the Coder class, because
       by default Coder should behave like NSArchiver. */
    {
      encoded_object = [anObj replacementObjectForCoder: (NSCoder*)self];
      encoded_class = [encoded_object classForCoder];
    }
  else
    {
      encoded_object = [anObj replacementObjectForArchiver: (NSArchiver*)self];
      encoded_class = [encoded_object classForArchiver];
    }
  [self encodeClass: encoded_class];
  /* xxx We should make sure it responds to this selector! */
  [encoded_object encodeWithCoder: (id)self];
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
      [self encodeTag: CODER_OBJECT_CLASS];
      [self encodeClass:anObj];
    }
  else
    {
      unsigned xref = [self _coderReferenceForObject: anObj];
      if (xref)
	{
	  /* It's already been encoded, so just encode the x-reference */
	  [self encodeTag: CODER_OBJECT_REPEATED];
	  [self encodeValueOfCType: @encode(unsigned)
		at: &xref 
		withName: @"Object cross-reference number"];
	}
      else if (forward_ref_flag
	       || (in_progress_table
		   && NSMapGet (in_progress_table, anObj)))
	{
	  unsigned fref;

	  /* We are going to encode a forward reference, either because 
	     (1) our caller asked for it, or (2) we are in the middle
	     of encoding this object, and haven't finished encoding it yet. */
	  /* Find out if it already has a forward reference number. */
	  fref = [self _coderForwardReferenceForObject: anObj];
	  if (!fref)
	    /* It doesn't, so create one. */
	    fref = [self _coderCreateForwardReferenceForObject: anObj];
	  [self encodeTag: CODER_OBJECT_FORWARD_REFERENCE];
	  [self encodeValueOfCType: @encode(unsigned)
		at: &fref 
		withName: @"Object forward cross-reference number"];
	}
      else
	{
	  /* No backward or forward references, we are going to encode
	     the object. */
	  unsigned fref;

	  /* Register the object as being in progress of encoding. */
	  if (!in_progress_table)
	    in_progress_table = 
	      NSCreateMapTable (NSObjectMapKeyCallBacks, 
				NSIntMapValueCallBacks, 0);
	  NSMapInsert (in_progress_table, anObj, (void*)1);

	  /* Find out if this object satisfies any previous forward 
	     references. */
	  fref = [self _coderForwardReferenceForObject: anObj];
	  if (fref)
	    {

	      /* It does satisfy a forward reference; write the forward 
		 reference number, so the decoder can know. */
	      [self encodeTag: CODER_OBJECT_FORWARD_SATISFIER];
	      [self encodeValueOfCType: @encode(unsigned)
		    at: &fref 
		    withName: @"Object forward cross-reference number"];
	    }
	  else
	    {
	      /* It does not satisfy a forward reference.  Note: in future
		 encoding we may have backward references to this object,
		 but we will never need forward references to this object. */
	      [self encodeTag: CODER_OBJECT];
	    }
	  /* Encode the object. */
	  [self encodeIndent];
	  if (bycopy_flag)
	    [self _doEncodeBycopyObject:anObj];
	  else
	    [self _doEncodeObject:anObj];	    
	  [self encodeUnindent];

	  /* Register that we have encoded it so that future encoding can 
	     do backward references properly. */
	  [self _coderInternalCreateReferenceForObject: anObj];
	  /* Remove it from the forward reference table, since we'll never
	     have another forward reference for this object. */
	  if (fref)
	    [self _coderRemoveForwardReferenceForObject: anObj];
	  /* We're done encoding the object, it's no longer in progress. */
	  NSMapRemove (in_progress_table, anObj);
	}
    }
  [self encodeUnindent];
}

- (void) encodeObject: anObj
   withName: (id <String>)name
{
  [self _encodeObject:anObj withName:name isBycopy:NO isForwardReference:NO];
}


- (void) encodeBycopyObject: anObj
   withName: (id <String>)name
{
  [self _encodeObject:anObj withName:name isBycopy:YES isForwardReference:NO];
}

- (void) encodeObjectReference: anObj
   withName: (id <String>)name
{
  [self _encodeObject:anObj withName:name isBycopy:NO isForwardReference:YES];
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

- (void) encodeArrayOfObjCType: (const char *)type
   count: (unsigned)c
   at: (const void *)d
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

- (void) encodeIndent
{
  [cstream encodeIndent];
}

- (void) encodeUnindent
{
  [cstream encodeUnindent];
}

- (void) encodeName: (id <String>)n
{
  [cstream encodeName: n];
}


/* Substituting Classes */

- (id <String>) classNameEncodedForTrueClassName: (id <String>) trueName
{
  [self notImplemented: _cmd];
  return nil;

#if 0
  if (classname_2_classname)
    return NSMapGet (classname_2_classname, [trueName cStringNoCopy]);
  return trueName;
#endif
}

- (void) encodeClassName: (id <String>) trueName
   intoClassName: (id <String>) inArchiveName
{
  [self notImplemented: _cmd];

#if 0
  /* The table should hold char*'s, not id's. */
  if (!classname_2_classname)
    classname_2_classname = 
      NSCreateMapTable (NSObjectsMapKeyCallBacks,
			NSObjectsMapValueCallBacks, 0);
  NSMapInsert (classname_2_classname, trueName, inArchiveName);
#endif
}

- (void) dealloc
{
  if (in_progress_table) NSFreeMapTable (in_progress_table);
  if (object_2_xref) NSFreeMapTable (object_2_xref);
  if (object_2_fref) NSFreeMapTable (object_2_fref);
  if (const_ptr_2_xref) NSFreeMapTable (const_ptr_2_xref);
  if (classname_2_classname) NSFreeMapTable (classname_2_classname);
  [super dealloc];
}

@end
