/* Abstract class for writing objects to a stream
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
   */ 

#include <config.h>
#include <base/preface.h>
#include <base/Coder.h>
#include <base/CoderPrivate.h>
#include <base/MemoryStream.h>
#include <base/StdioStream.h>
#include <base/BinaryCStream.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSException.h>

static int default_format_version;
static id default_stream_class;
static id default_cstream_class;
#define DEFAULT_DEFAULT_FORMAT_VERSION 0

static int debug_coder = 0;


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
  if (self == [Encoder class])
    {
      /* This code has not yet been ported to machines for which
	 a pointer is not the same size as an int. */
      NSAssert(sizeof(void*) == sizeof(unsigned),
	@"Pointer and int are different sizes"); 

      /* Initialize some defaults. */
      default_stream_class = [MemoryStream class];
      default_cstream_class = [BinaryCStream class];
      default_format_version = DEFAULT_DEFAULT_FORMAT_VERSION;
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
		    WRITE_SIGNATURE_FORMAT_ARGS];
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
  [cstream release];
  in_progress_table = NULL;
  object_2_xref = NULL;
  object_2_fref = NULL;
  const_ptr_2_xref = NULL;
  fref_counter = 0;
  [self writeSignature];
  return self;
}

/* ..Writing... methods */

- initForWritingToStream: (id <Streaming>) s
	withCStreamClass: (Class) cStreamClass
{
  return [self initForWritingToStream: s
	       withFormatVersion: DEFAULT_DEFAULT_FORMAT_VERSION
	       cStreamClass: cStreamClass
	       cStreamFormatVersion: [cStreamClass defaultFormatVersion]];
}

- initForWritingToStream: (id <Streaming>) s
{
  return [self initForWritingToStream: s
	       withCStreamClass: [[self class] defaultCStreamClass]];
}

- initForWritingToFile: (NSString*) filename
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

- initForWritingToFile: (NSString*) filename
      withCStreamClass: (Class) cStreamClass
{
  return [self initForWritingToStream: [StdioStream 
					 streamWithFilename: filename
					 fmode: "w"]
	       withCStreamClass: cStreamClass];
}

- initForWritingToFile: (NSString*) filename
{
  return [self initForWritingToStream: 
		 [StdioStream streamWithFilename: filename
			      fmode: "w"]];
}

+ newWritingToStream: (id <Streaming>)s
{
  return [[self alloc] initForWritingToStream: s];
}

+ newWritingToFile: (NSString*)filename
{
  return [self newWritingToStream:
		 [StdioStream streamWithFilename: filename
			      fmode: "w"]];
}

+ (BOOL) encodeRootObject: anObject
		 withName: (NSString*) name
		 toStream: (id <Streaming>)stream
{
  id c = [[self alloc] initForWritingToStream: stream];
  [c encodeRootObject: anObject withName: name];
  [c close];
  [c release];
  return YES;
}

+ (BOOL) encodeRootObject: anObject 
  	         withName: (NSString*) name
                   toFile: (NSString*) filename
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
  NSMapInsert (object_2_xref, anObj, (void*)xref);
  return xref;
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

  xref = NSCountMapTable (const_ptr_2_xref) + 1;
  NSAssert (! NSMapGet (const_ptr_2_xref, (void*)xref), @"xref already in Map");
  NSMapInsert (const_ptr_2_xref, ptr, (void*)xref);
  return xref;
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
  unsigned fref;
  if (!object_2_fref)
    object_2_fref = 
      NSCreateMapTable (NSNonOwnedPointerOrNullMapKeyCallBacks,
			NSIntMapValueCallBacks, 0);
  fref = ++fref_counter;
  NSAssert ( ! NSMapGet (object_2_fref, anObject), @"anObject already in Map");
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


/* Handling the in_progress_table.  These are called before and after
   the actual object (not a forward or backward reference) is encoded.

   One of these objects should also call
   -_coderInternalCreateReferenceForObject:.  GNU archiving calls it
   in the first, in order to force forward references to objects that
   are in progress; this allows for -initWithCoder: methods that
   deallocate self, and return another object.  OpenStep-style coding
   calls it in the second, meaning that we never create forward
   references to objects that are in progress; we encode a backward
   reference to the in progress object, and assume that it will not
   change location. */

- (void) _objectWillBeInProgress: anObj
{
  if (!in_progress_table)
    in_progress_table = 
      /* This is "NonOwnedPointer", and not "Object", because
	 with "Object" we would get an infinite loop with distributed
	 objects when we try to put a Proxy in in the table, and
	 send the proxy the -hash method. */ 
      NSCreateMapTable (NSNonOwnedPointerMapKeyCallBacks, 
			NSIntMapValueCallBacks, 0);
  NSMapInsert (in_progress_table, anObj, (void*)1);
}

- (void) _objectNoLongerInProgress: anObj
{
  NSMapRemove (in_progress_table, anObj);
  /* Register that we have encoded it so that future encoding can 
     do backward references properly. */
  [self _coderInternalCreateReferenceForObject: anObj];
}


/* Method for encoding things. */

- (void) encodeValueOfCType: (const char*)type 
   at: (const void*)d 
   withName: (NSString*)name
{
  [cstream encodeValueOfCType:type
	   at:d
	   withName:name];
}

- (void) encodeBytes: (const void *)b
   count: (unsigned)c
   withName: (NSString*)name
{
  /* xxx Is this what we want?  
     It won't be cleanly readable in TextCStream's. */
  [cstream encodeName: name];
  [[cstream stream] writeBytes: b length: c];
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

	  NSAssert (class_name, @"Class doesn't have a name");
	  NSAssert (*class_name, @"Class name is empty");

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
   withName: (NSString*) name
{
  /* xxx Add repeat-string-ptr checking here. */
  [self notImplemented:_cmd];
  [self encodeValueOfCType:@encode(char*) at:&sp withName:name];
}

- (void) encodeSelector: (SEL)sel withName: (NSString*) name
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
	    sel_types = 
	      sel_get_type (sel_get_any_typed_uid (sel_get_name (sel)));
#endif
	  if (!sel_name || !*sel_name)
	    [NSException raise: NSGenericException
			 format: @"ObjC runtime didn't provide SEL name"];
	  if (!sel_types || !*sel_types)
	    sel_types = NO_SEL_TYPES;

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
   withName: (NSString*) name
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
  NSParameterAssert (interconnect_stack_height);
  interconnect_stack_height--;
}

/* NOTE: Unlike NeXT's, this *can* be called recursively */
- (void) encodeRootObject: anObj
    withName: (NSString*)name
{
  [self encodeName: @"Root Object"];
  [self encodeIndent];
  [self encodeTag: CODER_OBJECT_ROOT];
  [self startEncodingInterconnectedObjects];
  [self encodeObject: anObj withName: name];
  [self finishEncodingInterconnectedObjects];
  [self encodeUnindent];
}


/* These next three methods are the designated coder methods called when
   we've determined that the object has not already been
   encoded---we're not simply going to encode a cross-reference number
   to the object, we're actually going to encode an object (either a
   proxy to the object or the object itself).

   NSPortCoder overrides _doEncodeObject: in order to implement
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

/* This method overridden by NSPortCoder */
- (void) _doEncodeObject: anObj
{
  [self _doEncodeBycopyObject:anObj];
}

/* This method overridden by NSPortCoder */
- (void) _doEncodeByrefObject: anObj
{
  [self _doEncodeObject: anObj];
}


/* This is the designated object encoder */
- (void) _encodeObject: anObj
   withName: (NSString*) name
   isBycopy: (BOOL) bycopy_flag
   isByref: (BOOL) byref_flag
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

	  /* Register the object as being in progress of encoding.  In
	     OpenStep-style archiving, this method also calls
	     -_coderInternalCreateReferenceForObject:. */
	  [self _objectWillBeInProgress: anObj];

	  /* Encode the object. */
	  [self encodeTag: CODER_OBJECT];
	  [self encodeIndent];
	  if (bycopy_flag)
	    [self _doEncodeBycopyObject:anObj];
	  else if (byref_flag)
	    [self _doEncodeByrefObject:anObj];
	  else
	    [self _doEncodeObject:anObj];	    
	  [self encodeUnindent];

	  /* Find out if this object satisfies any forward references,
	     and encode either the forward reference number, or a
	     zero.  NOTE: This test is here, and not before the
	     _doEncode.., because the encoding of this object may,
	     itself, generate a "forward reference" to this object,
	     (ala the in_progress_table).  That is, we cannot know
	     whether this object satisfies a forward reference until
	     after it has been encoded. */
	  fref = [self _coderForwardReferenceForObject: anObj];
	  if (fref)
	    {
	      /* It does satisfy a forward reference; write the forward 
		 reference number, so the decoder can know. */
	      [self encodeValueOfCType: @encode(unsigned)
		    at: &fref 
		    withName: @"Object forward cross-reference number"];
	      /* Remove it from the forward reference table, since we'll never
		 have another forward reference for this object. */
	      [self _coderRemoveForwardReferenceForObject: anObj];
	    }
	  else
	    {
	      /* It does not satisfy any forward references.  Let the
		 decoder know this by encoding NULL.  Note: in future
		 encoding we may have backward references to this
		 object, but we will never need forward references to
		 this object.  */
	      unsigned null_fref = 0;
	      [self encodeValueOfCType: @encode(unsigned)
		    at: &null_fref 
		    withName: @"Object forward cross-reference number"];
	    }

	  /* We're done encoding the object, it's no longer in progress.
	     In GNU-style archiving, this method also calls
	     -_coderInternalCreateReferenceForObject:. */
	  [self _objectNoLongerInProgress: anObj];
	}
    }
  [self encodeUnindent];
}

- (void) encodeObject: anObj
   withName: (NSString*)name
{
  [self _encodeObject:anObj
	     withName:name
	     isBycopy:NO
	      isByref:NO
   isForwardReference:NO];
}


- (void) encodeBycopyObject: anObj
   withName: (NSString*)name
{
  [self _encodeObject:anObj
	     withName:name
	     isBycopy:YES
	      isByref:NO
   isForwardReference:NO];
}

- (void) encodeByrefObject: anObj
   withName: (NSString*)name
{
  [self _encodeObject:anObj
	     withName:name
	     isBycopy:NO
	      isByref:YES
   isForwardReference:NO];
}

- (void) encodeObjectReference: anObj
   withName: (NSString*)name
{
  [self _encodeObject:anObj
	     withName:name
	     isBycopy:NO
	      isByref:NO
   isForwardReference:YES];
}



- (void) encodeWithName: (NSString*)name
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
   withName: (NSString*)name
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
   withName: (NSString*)name
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

- (void) encodeName: (NSString*)n
{
  [cstream encodeName: n];
}


/* Substituting Classes */

- (NSString*) classNameEncodedForTrueClassName: (NSString*) trueName
{
  [self notImplemented: _cmd];
  return nil;

#if 0
  if (classname_2_classname)
    return NSMapGet (classname_2_classname, [trueName cString]);
  return trueName;
#endif
}

- (void) encodeClassName: (NSString*) trueName
   intoClassName: (NSString*) inArchiveName
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
