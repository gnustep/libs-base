/* Stream of bytes class for serialization and persistance in GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   
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

#include <gnustep/base/preface.h>
#include <gnustep/base/MallocAddress.h>
#include <Foundation/byte_order.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSGData.h>
#include <Foundation/NSHData.h>
#include <string.h>		/* for memset() */
#include <unistd.h>             /* SEEK_* on SunOS 4 */

/* xxx Pretty messy.  Needs work. */

@implementation NSData

static Class NSData_concrete_class;
static Class NSMutableData_concrete_class;

+ (void) _setConcreteClass: (Class)c
{
  NSData_concrete_class = c;
}

+ (void) _setMutableConcreteClass: (Class)c
{
  NSMutableData_concrete_class = c;
}

+ (Class) _concreteClass
{
  return NSData_concrete_class;
}

+ (Class) _mutableConcreteClass
{
  return NSMutableData_concrete_class;
}

+ (void) initialize
{
#if 0
  NSData_concrete_class = [NSGData class];
  NSMutableData_concrete_class = [NSGMutableData class];
#else
  NSData_concrete_class = [NSHData class];
  NSMutableData_concrete_class = [NSHMutableData class];
#endif
}

// Allocating and Initializing a Data Object
+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([self _concreteClass], 0, zone);
}

+ (id) data
{
  return [[[self alloc] init] 
	  autorelease];
}

+ (id) dataWithBytes: (const void*)bytes
   length: (unsigned int)length
{
  return [[[self alloc] initWithBytes:bytes length:length] 
	  autorelease];
}

+ (id) dataWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length
{
  return [[[self alloc] initWithBytesNoCopy:bytes length:length]
	  autorelease];
}

/* FIXME: Should these next two be autorelease?  The pattern says yes.
 * But the docs fail to explicitly indicate it.  It only makes sense,
 * though. */
+ (id)dataWithContentsOfFile: (NSString*)path
{
  return [[[self alloc] initWithContentsOfFile:path] 
	  autorelease];
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
  return [[[self alloc] initWithContentsOfMappedFile:path]
          autorelease];
}

- (id) initWithBytes: (const void*)bytes
   length: (unsigned int)length
{
  /* xxx Eventually we'll have to be aware of malloc'ed memory
     vs vm_allocate'd memory, etc. */
  void *buf = NSZoneMalloc([self zone], length);
  memcpy(buf, bytes, length);
  return [self initWithBytesNoCopy:buf length:length];
}

/* This is the (internal) designated initializer for NSData.  This routine
   should only be called by known subclasses of NSData. Other subclasses
   should just use [super init]. */
- (id) _initWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length
{
    return [super init];
}

- (id) initWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length
{
  /* xxx Eventually we'll have to be aware of malloc'ed memory
     vs vm_allocate'd memory, etc. */
  [self subclassResponsibility:_cmd];
  return nil;
}

- init
{
  /* xxx Is this right? */
  /* FIXME: It seems so; mutable subclasses need to deal gracefully
   * with NULL pointers and/or 0 length data objects, though.  Which
   * they do. */
  return [self _initWithBytesNoCopy:NULL length:0];
}

- (id) initWithContentsOfFile: (NSString *)path
{
  void *tmpBytes;
  const char *theFileName;
  FILE *theFile;
  long int length;
  long int d;
  int c;
  
  /* FIXME: I'm not sure that I'm dealing with failures correctly
   * here.  I just return nil; should I return something like
   *
   *   [self initWithBytesNoCopy:NULL length:0]
   *
   * instead?  The docs don't indicate any exception raising should
   * take place; so what else can I do? */

  /* FIXME: I believe that we should take the name of the file to be
   * the cString of the path provided.  It is unclear, however, that
   * this is correct for fully internationalized functionality.  If
   * the cString <--> Unicode translation isn't completely
   * bidirectional, this simple translation might not be the proper
   * one. */

  theFileName = [path cString];
  theFile = fopen(theFileName, "r");
  
  if (theFile == NULL)          /* We failed to open the file. */
    goto failure;

  /* Seek to the end of the file. */
  c = fseek(theFile, 0L, SEEK_END);
  
  if (c != 0)                   /* Something went wrong; though I
                                 * don't know what. */
    goto failure;

  /* Determine the length of the file (having seeked to the end of the
   * file) by calling ftell(). */
  length = ftell(theFile);
  
  if (length == -1)             /* I can't imagine what could go
                                 * wrong, but here we are. */
    goto failure;

  /* Set aside the space we'll need. */
  tmpBytes = NSZoneMalloc([self zone], length);

  if (tmpBytes == NULL)         /* Out of memory, I guess. */
    goto failure;

  /* Rewind the file pointer to the beginning, preparing to read in
   * the file. */
  c = fseek(theFile, 0L, SEEK_SET);
  
  if (c != 0)                   /* Oh, No. */
    goto failure;

  /* Now we read the file into tmpBytes one (unsigned) byte at a
   * time.  We should probably be more careful to check that we don't
   * get an EOF.  But what would this mean?  That the file had been
   * changed in the middle of all this.  So maybe we should think
   * about locking the file? */
  for (d = 0; d < length; d++)
    ((unsigned char *)tmpBytes)[d] = (unsigned char) fgetc(theFile);

  /* success: */
  return [self initWithBytesNoCopy:tmpBytes length:length];

  /* Just in case the failure action needs to be changed. */
 failure:
  return nil;
}

- (id) initWithContentsOfMappedFile: (NSString *)path;
{
  /* FIXME: Until I can learn about mapped files on various systems,
   * the docs indicate that this should be identical with
   *
   *   [self initWithContentsOfFile:path].
   *
   * Linux, for example, has mapped files, as do many (all?) SYSV
   * unices, but I don't know enough about these various systems to
   * deal with them.  Does any POSIX standard specify mapped file
   * capabilities? */
  return [self initWithContentsOfFile:path];
}

- (id) initWithData: (NSData*)data
{
  return [self initWithBytes:[data bytes] length:[data length]];
}


// Accessing Data 

- (const void*) bytes
{
  [self subclassResponsibility:_cmd];
  return NULL;
}

- (NSString*) description
{
  const char *src = [self bytes];
  char *dest;
  int length = [self length];
  int i,j;

#define num2char(num) ((num) < 0xa ? ((num)+'0') : ((num)+0x57))

  /* we can just build a cString and convert it to an NSString */
  dest = (char*) malloc (2*length+length/4+3);
  dest[0] = '<';
  for (i=0,j=1; i<length; i++,j++)
    {
      dest[j++] = num2char((src[i]>>4) & 0x0f);
      dest[j] = num2char(src[i] & 0x0f);
      if((i&0x3) == 3)
	/* if we've just finished a 32-bit int, print a space */
	dest[++j] = ' ';
    }
  dest[j++] = '>';
  dest[j] = '\0';
  return [NSString stringWithCString: dest];
}

- (void)getBytes: (void*)buffer
{
  [self getBytes:buffer length:[self length]];
}

- (void)getBytes: (void*)buffer
   length: (unsigned int)length
{
  /* FIXME: Is this static NSRange creation preferred to the
   * documented NSMakeRange()? */
  [self getBytes:buffer range:((NSRange){0, length})];
}

- (void)getBytes: (void*)buffer
   range: (NSRange)aRange
{
  auto	int	size;

  // Check for 'out of range' errors.  This code assumes that the
  // NSRange location and length types will remain unsigned (hence
  // the lack of a less-than-zero check).
  size = [self length];
  if (aRange.location >= size ||
      aRange.length   >= size ||
      NSMaxRange( aRange ) > size)
  {
    /* FIXME: I think that this is the proper way to raise this
     * exception.  Maybe not, though.  Does GNUStep have a standard
     * format that ``internal'' exceptions like this one should have?
     * If not, then maybe it should.  It would help debugging. */

	/* Raise an exception.
	*	I, too, do not know if GNUStep has a standard
	*	format.  I do feel, however, that more info is
	*	better.  Note that the previous check did not
	*	check both ends of the range.
	*/
	[NSException raise    : NSRangeException
		     format   : @"Range: (%u, %u) Size: %d",
		     		aRange.location,
				aRange.length,
				size];
  }
  else
    /* FIXME: I guess we're guaranteed that memcpy() exists? */
    memcpy(buffer, [self bytes] + aRange.location, aRange.length);
  return;
}

- (NSData*) subdataWithRange: (NSRange)aRange
{
  void *buffer;

  /* FIXME: Just a question; is it safe to have all of the
   * NSZoneMalloc'ing without closing NSZoneFree'ing?  It seems to be
   * popular in this code.  */
  buffer = NSZoneMalloc([self zone], aRange.length);

  /* Remember, [NSData -getBytes:range:] will raise an exception if
   * aRange is out-of-bounds. */
  [self getBytes:buffer range:aRange];

  /* FIXME: Should this be an autoreleased object, as it is now? */
  return [NSData dataWithBytesNoCopy:buffer length:aRange.length];
}

- (BOOL) isEqual: anObject
{
  /* FIXME: OpenStep uses -isKindOfClass: rather than -isKindOf:.  Is
   * it better to use -isKindOf:, since we know we're using GNUObjC?
   * It seems to me more prudent to stick with the OpenStep version,
   * since we're writing OpenStep code. */
  if ([anObject isKindOf:[NSData class]])
    return [self isEqualToData:anObject];
  return NO;
}

// Querying a Data Object
- (BOOL) isEqualToData: (NSData*)other;
{
  int len;
  if ((len = [self length]) != [other length])
    return NO;
  return (memcmp([self bytes], [other bytes], len) ? NO : YES);
}

- (unsigned int)length;
{
  /* This is left to concrete subclasses to implement. */
  [self subclassResponsibility:_cmd];
  return 0;
}


// Storing Data

- (BOOL) writeToFile: (NSString *)path
   atomically: (BOOL)useAuxiliaryFile
{
  const char *theFileName;
  const char *theRealFileName = NULL;
  FILE *theFile;
  int c;

  /* FIXME: The docs say nothing about the raising of any exceptions,
   * but if someone can provide evidence as to the proper handling of
   * bizarre situations here, I'll add whatever functionality is
   * needed.  For the time being, I'm returning the success or failure
   * of the write as a boolean YES or NO. */

  /* FIXME: I believe that we should take the name of the file to be
   * the cString of the path provided.  It is unclear, however, that
   * this is correct for fully internationalized functionality.  If
   * the cString <--> Unicode translation isn't completely
   * bidirectional, this simple translation might not be the proper
   * one. */

  if (useAuxiliaryFile)
    {
      /* FIXME: Is it clear that using the tmpnam() system call is the
       * right way to go?  Do we need to worry about renaming the
       * tempfile thus created, if we happen to be moving it across
       * filesystems, for example?  I don't think so.  In particular,
       * I think that this *is* a correct way to handle things. */
      theFileName = tmpnam(NULL);
      theRealFileName = [path cString];
    }
  else
    {
      theFileName = [path cString];
    }

  /* Open the file (whether temp or real) for writing. */
  theFile = fopen(theFileName, "w");

  if (theFile == NULL)          /* Something went wrong; we weren't
                                 * even able to open the file. */
    goto failure;

  /* Now we try and write the NSData's bytes to the file.  Here `c' is
   * the number of bytes which were successfully written to the file
   * in the fwrite() call. */
  /* FIXME: Do we need the `sizeof(char)' here? Is there any system
   * where sizeof(char) isn't just 1?  Or is it guaranteed to be 8
   * bits? */
  c = fwrite([self bytes], sizeof(char), [self length], theFile);

  if (c < [self length])        /* We failed to write everything for
                                 * some reason. */
    goto failure;

  /* We're done, so close everything up. */
  c = fclose(theFile);

  if (c != 0)                   /* I can't imagine what went wrong
                                 * closing the file, but we got here,
                                 * so we need to deal with it. */
    goto failure;

  /* If we used a temporary file, we still need to rename() it be the
   * real file.  Am I forgetting anything here? */
  if (useAuxiliaryFile)
    {
      c = rename(theFileName, theRealFileName);

      if (c != 0)               /* Many things could go wrong, I
                                 * guess. */
	goto failure;
    }

  /* success: */
  return YES;

  /* Just in case the failure action needs to be changed. */
 failure:
  return NO;
}


// Deserializing Data

- (unsigned int)deserializeAlignedBytesLengthAtCursor:(unsigned int*)cursor
{
    return *cursor;
}

- (void)deserializeBytes:(void*)buffer
  length:(unsigned int)bytes
  atCursor:(unsigned int*)cursor
{
    NSRange range = { *cursor, bytes };
    [self getBytes:buffer range:range];
    *cursor += bytes;
}

- (void)deserializeDataAt:(void*)data
  ofObjCType:(const char*)type
  atCursor:(unsigned int*)cursor
  context:(id <NSObjCTypeSerializationCallBack>)callback
{
    if(!type || !data)
	return;

    switch(*type) {
	case _C_ID: {
	    [callback deserializeObjectAt:data ofObjCType:type
		    fromData:self atCursor:cursor];
	    break;
	}
	case _C_CHARPTR: {
	    int length = [self deserializeIntAtCursor:cursor];
	    id adr = nil;

	    if (length == -1) {
		*(const char**)data = NULL;
		return;
	    }
	    else {
		OBJC_MALLOC (*(char**)data, char, length+1);
		adr = [MallocAddress autoreleaseMallocAddress:*(void**)data];
	    }

	    [self deserializeBytes:*(char**)data length:length atCursor:cursor];
	    (*(char**)data)[length] = '\0';
	    [adr retain];

	    break;
	}
	case _C_ARY_B: {
	    int i, count, offset, itemSize;
	    const char* itemType;

	    count = atoi(type + 1);
	    itemType = type;
	    while(isdigit(*++itemType));
		itemSize = objc_sizeof_type(itemType);

		for(i = offset = 0; i < count; i++, offset += itemSize)
		    [self deserializeDataAt:(char*)data + offset
				    ofObjCType:itemType
				    atCursor:cursor
				    context:callback];
	    break;
	}
	case _C_STRUCT_B: {
	    int offset = 0;
	    int align, rem;

	    while(*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	    while(1) {
		[self deserializeDataAt:((char*)data) + offset
			ofObjCType:type
			atCursor:cursor
			context:callback];
		offset += objc_sizeof_type(type);
		type = objc_skip_typespec(type);
		if(*type != _C_STRUCT_E) {
		    align = objc_alignof_type(type);
		    if((rem = offset % align))
			offset += align - rem;
		}
		else break;
	    }
	    break;
        }
        case _C_PTR: {
	    id adr;

	    OBJC_MALLOC (*(char**)data, char, objc_sizeof_type(++type));
	    adr = [MallocAddress autoreleaseMallocAddress:*(void**)data];

	    [self deserializeDataAt:*(char**)data
		    ofObjCType:type
		    atCursor:cursor
		    context:callback];

	    [adr retain];

	    break;
        }
	case _C_CHR:
	case _C_UCHR: {
	    [self deserializeBytes:data
		  length:sizeof(unsigned char)
		  atCursor:cursor];
	    break;
	}
        case _C_SHT:
	case _C_USHT: {
	    unsigned short ns;

	    [self deserializeBytes:&ns
		  length:sizeof(unsigned short)
		  atCursor:cursor];
	    *(unsigned short*)data = network_short_to_host (ns);
	    break;
	}
        case _C_INT:
	case _C_UINT: {
	    unsigned int ni;

	    [self deserializeBytes:&ni
		  length:sizeof(unsigned int)
		  atCursor:cursor];
	    *(unsigned int*)data = network_int_to_host (ni);
	    break;
	}
        case _C_LNG:
	case _C_ULNG: {
	    unsigned int nl;

	    [self deserializeBytes:&nl
		  length:sizeof(unsigned long)
		  atCursor:cursor];
	    *(unsigned long*)data = network_long_to_host (nl);
	    break;
	}
        case _C_FLT: {
	    network_float nf;

	    [self deserializeBytes:&nf
		  length:sizeof(float)
		  atCursor:cursor];
	    *(float*)data = network_float_to_host (nf);
	    break;
	}
        case _C_DBL: {
	    network_double nd;

	    [self deserializeBytes:&nd
		  length:sizeof(double)
		  atCursor:cursor];
	    *(double*)data = network_double_to_host (nd);
	    break;
	}
        default:
	    [NSException raise:NSGenericException
                format:@"Unknown type to deserialize - '%s'", type];
    }
}

- (int)deserializeIntAtCursor:(unsigned int*)cursor
{
    unsigned int ni, result;

    [self deserializeBytes:&ni length:sizeof(unsigned int) atCursor:cursor];
    result = network_int_to_host (ni);
    return result;
}

- (int)deserializeIntAtIndex:(unsigned int)index
{
    unsigned int ni, result;

    [self deserializeBytes:&ni length:sizeof(unsigned int) atCursor:&index];
    result = network_int_to_host (ni);
    return result;
}

- (void)deserializeInts:(int*)intBuffer
  count:(unsigned int)numInts
  atCursor:(unsigned int*)cursor
{
    unsigned i;

    [self deserializeBytes:&intBuffer
	  length:numInts * sizeof(unsigned int)
	  atCursor:cursor];
    for (i = 0; i < numInts; i++)
	intBuffer[i] = network_int_to_host (intBuffer[i]);
}

- (void)deserializeInts:(int*)intBuffer
  count:(unsigned int)numInts
  atIndex:(unsigned int)index
{
    unsigned i;

    [self deserializeBytes:&intBuffer
		    length:numInts * sizeof(int)
		    atCursor:&index];
    for (i = 0; i < numInts; i++)
	intBuffer[i] = network_int_to_host (intBuffer[i]);
}

- (id) copyWithZone: (NSZone*)zone
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  [self subclassResponsibility:_cmd];
  return nil;
}

@end


/* xxx Pretty messy.  Needs work. */

@implementation NSMutableData

+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([self _mutableConcreteClass], 0, zone);
}

+ (id) dataWithCapacity: (unsigned int)numBytes
{
  return [[[self alloc] initWithCapacity:numBytes]
	  autorelease];
}

+ (id) dataWithLength: (unsigned int)length
{
  return [[[self alloc] initWithLength:length]
	  autorelease];
}

- (id) initWithCapacity: (unsigned int)capacity
{
  return [self initWithBytesNoCopy: objc_malloc (capacity)
	       length:capacity];
}

- (id) initWithBytesNoCopy: (void*)bytes
   length: (unsigned int)length
{
  /* xxx Eventually we'll have to be aware of malloc'ed memory
     vs vm_allocate'd memory, etc. */
  [self subclassResponsibility:_cmd];
  return nil;
}

- (id) initWithLength: (unsigned int)length
{
  [self initWithCapacity:length];
  memset ((char*)[self bytes], 0, length);
  return self;
}

/* This method not in OpenStep */
- (unsigned) capacity
{
  [self subclassResponsibility: _cmd];
  return 0;
}

// Adjusting Capacity

- (void) increaseLengthBy: (unsigned int)extraLength
{
  [self setLength:[self length]+extraLength];
}

- (void) setLength: (unsigned int)length
{
  [self subclassResponsibility:_cmd];
}

- (void*) mutableBytes
{
  [self subclassResponsibility:_cmd];
  return NULL;
}

// Appending Data

- (void) appendBytes: (const void*)bytes
	      length: (unsigned int)length
{
  [self subclassResponsibility:_cmd];
}

- (void) appendData: (NSData*)other
{
  [self appendBytes:[other bytes]
	length:[other length]];
}


// Modifying Data

- (void) replaceBytesInRange: (NSRange)aRange
		   withBytes: (const void*)bytes
{
  auto	int	size;

  // Check for 'out of range' errors.  This code assumes that the
  // NSRange location and length types will remain unsigned (hence
  // the lack of a less-than-zero check).
  size = [self length];
  if (aRange.location >= size ||
      aRange.length   >= size ||
      NSMaxRange( aRange ) > size)
  {
	// Raise an exception.
	[NSException raise    : NSRangeException
		     format   : @"Range: (%u, %u) Size: %d",
		     		aRange.location,
				aRange.length,
				size];
  }
  memcpy([self mutableBytes] + aRange.location, bytes, aRange.length);
}

- (void) resetBytesInRange: (NSRange)aRange
{
  auto	int	size;

  // Check for 'out of range' errors.  This code assumes that the
  // NSRange location and length types will remain unsigned (hence
  // the lack of a less-than-zero check).
  size = [self length];
  if (aRange.location >= size ||
      aRange.length   >= size ||
      NSMaxRange( aRange ) > size)
  {
	// Raise an exception.
	[NSException raise    : NSRangeException
		     format   : @"Range: (%u, %u) Size: %d",
		     		aRange.location,
				aRange.length,
				size];
  }
  memset((char*)[self bytes] + aRange.location, 0, aRange.length);
}

// Serializing Data

- (void)serializeAlignedBytesLength:(unsigned int)length
{
}

- (void)serializeDataAt:(const void*)data
  ofObjCType:(const char*)type
  context:(id <NSObjCTypeSerializationCallBack>)callback
{
    if(!data || !type)
	    return;

    switch(*type) {
        case _C_ID: {
	    [callback serializeObjectAt:(id*)data
			ofObjCType:type
			intoData:self];
	    break;
	}
        case _C_CHARPTR: {
	    int len;

	    if(!*(void**)data) {
		[self serializeInt:-1];
		return;
	    }
	    len = strlen(*(void**)data);
	    [self serializeInt:len];
	    [self appendBytes:*(void**)data length:len];

	    break;
	}
        case _C_ARY_B: {
            int i, offset, itemSize, count = atoi(type + 1);
            const char* itemType = type;

            while(isdigit(*++itemType));
		itemSize = objc_sizeof_type(itemType);

		for(i = offset = 0; i < count; i++, offset += itemSize)
		    [self serializeDataAt:(char*)data + offset
			    ofObjCType:itemType
			    context:callback];

		break;
        }
        case _C_STRUCT_B: {
            int offset = 0;
            int align, rem;

            while(*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
            while(1) {
                [self serializeDataAt:((char*)data) + offset
			ofObjCType:type
			context:callback];
                offset += objc_sizeof_type(type);
                type = objc_skip_typespec(type);
                if(*type != _C_STRUCT_E) {
                    align = objc_alignof_type(type);
                    if((rem = offset % align))
                        offset += align - rem;
                }
                else break;
            }
            break;
        }
	case _C_PTR:
	    [self serializeDataAt:*(char**)data
		    ofObjCType:++type context:callback];
	    break;
        case _C_CHR:
	case _C_UCHR:
	    [self appendBytes:data length:sizeof(unsigned char)];
	    break;
	case _C_SHT:
	case _C_USHT: {
	    unsigned short ns = host_short_to_network (*(unsigned short*)data);
	    [self appendBytes:&ns length:sizeof(unsigned short)];
	    break;
	}
	case _C_INT:
	case _C_UINT: {
	    unsigned int ni = host_int_to_network (*(unsigned int*)data);
	    [self appendBytes:&ni length:sizeof(unsigned int)];
	    break;
	}
	case _C_LNG:
	case _C_ULNG: {
	    unsigned long nl = host_long_to_network (*(unsigned long*)data);
	    [self appendBytes:&nl length:sizeof(unsigned long)];
	    break;
	}
	case _C_FLT: {
	    network_float nf = host_float_to_network (*(float*)data);
	    [self appendBytes:&nf length:sizeof(float)];
	    break;
	}
	case _C_DBL: {
	    network_double nd = host_double_to_network (*(double*)data);
	    [self appendBytes:&nd length:sizeof(double)];
	    break;
	}
	default:
	    [NSException raise:NSGenericException
                format:@"Unknown type to deserialize - '%s'", type];
    }
}

- (void)serializeInt:(int)value
{
    unsigned int ni = host_int_to_network (value);
    [self appendBytes:&ni length:sizeof(unsigned int)];
}

- (void)serializeInt:(int)value atIndex:(unsigned int)index
{
    unsigned int ni = host_int_to_network (value);
    NSRange range = { index, sizeof(int) };
    [self replaceBytesInRange:range withBytes:&ni];
}

- (void)serializeInts:(int*)intBuffer count:(unsigned int)numInts
{
    unsigned i;
    SEL selector = @selector (serializeInt:);
    IMP imp = [self methodForSelector:selector];

    for (i = 0; i < numInts; i++)
	(*imp)(self, selector, intBuffer[i]);
}

- (void)serializeInts:(int*)intBuffer
  count:(unsigned int)numInts
  atIndex:(unsigned int)index
{
    unsigned i;
    SEL selector = @selector (serializeInt:atIndex:);
    IMP imp = [self methodForSelector:selector];

    for (i = 0; i < numInts; i++)
	(*imp)(self, selector, intBuffer[i], index++);
}

@end

