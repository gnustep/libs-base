/* Stream of bytes class for serialization and persistance in GNUStep
   Copyright (C) 1995, 1996, 1997 Free Software Foundation, Inc.
   
   Written by:  Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: March 1995
   Rewritten by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: September 1997
   
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

/* NOTES	-	Richard Frith-Macdonald 1997
 *
 *	Rewritten to use the class cluster architecture as in OPENSTEP.
 *
 *	NB. In our implementaion we require an extra primitive for the
 *	    NSMutableData subclasses.  This new primitive method is the
 *	    [-setCapacity:] method, and it differs from [-setLength:]
 *	    as follows -
 *
 *		[-setLength:]
 *			clears bytes when the allocated buffer grows
 *			never shrinks the allocated buffer capcity
 *		[-setCapacity:]
 *			doesn't clear newly allocated bytes
 *			sets the size of the allocated buffer.
 *
 *	The actual class hierarchy is as follows -
 *
 *	NSData					Abstract base class.
 *	    NSDataMalloc			Concrete class.
 *		NSDataMappedFile		Memory mapped files.
 *		NSDataShared			Extension for shared memory.
 *		NSDataStatic			Extension for static buffers.
 *	    NSMutableData			Abstract base class.
 *		NSMutableDataMalloc		Concrete class.
 *		    NSMutableDataShared		Extension for shared memory.
 *
 *	Since all the other subclasses are based on NSDataMalloc or
 *	NSMutableDataMalloc, we can put most methods in here and not
 *	bother with duplicating them in the other classes.
 *		
 */

#include <config.h>
#include <objc/objc-api.h>
#include <gnustep/base/preface.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#include <string.h>		/* for memset() */
#include <unistd.h>             /* SEEK_* on SunOS 4 */

#if	HAVE_MMAP
#include	<unistd.h>
#include	<sys/mman.h>
#include	<fcntl.h>
#ifndef	MAP_FAILED
#define	MAP_FAILED	((void*)-1)	/* Failure address.	*/
#endif
@class	NSDataMappedFile;
#endif

#if	HAVE_SHMCTL
#include	<sys/ipc.h>
#include	<sys/shm.h>

#define	VM_RDONLY	0644		/* self read/write - other readonly */
#define	VM_ACCESS	0666		/* read/write access for all */
@class	NSDataShared;
@class	NSMutableDataShared;
#endif

@class	NSDataMalloc;
@class	NSDataStatic;
@class	NSMutableDataMalloc;


static BOOL
readContentsOfFile(NSString* path, void** buf, unsigned* len, NSZone* zone)
{
  char		thePath[BUFSIZ*2];
  FILE		*theFile = 0;
  unsigned int	fileLength;
  void		*tmp = 0;
  int		c;

  if ([path getFileSystemRepresentation: thePath
			      maxLength: sizeof(thePath)-1] == NO)
    {
      NSLog(@"Open (%s) attempt failed - bad path", thePath);
      return NO;
    }
  theFile = fopen(thePath, "r");

  if (theFile == NULL)          /* We failed to open the file. */
    {
      NSLog(@"Open (%s) attempt failed - %s", thePath, strerror(errno));
      goto failure;
    }

  /* Seek to the end of the file. */
  c = fseek(theFile, 0L, SEEK_END);
  if (c != 0)
    {
      NSLog(@"Seek to end of file failed - %s", strerror(errno));
      goto failure;
    }

  /* Determine the length of the file (having seeked to the end of the
   * file) by calling ftell(). */
  fileLength = ftell(theFile);
  if (fileLength == -1)
    {
      NSLog(@"Ftell failed - %s", strerror(errno));
      goto failure;
    }

  tmp = NSZoneMalloc(zone, fileLength);
  if (tmp == 0)
    {
      NSLog(@"Malloc failed for file of length %d- %s",
		fileLength, strerror(errno));
      goto failure;
    }

  /* Rewind the file pointer to the beginning, preparing to read in
   * the file. */
  c = fseek(theFile, 0L, SEEK_SET);
  if (c != 0)
    {
      NSLog(@"Fseek to start of file failed - %s", strerror(errno));
      goto failure;
    }

  c = fread(tmp, 1, fileLength, theFile);
  if (c != fileLength)
    {
      NSLog(@"Fread of file contents failed - %s", strerror(errno));
      goto failure;
    }

  *buf = tmp;
  *len = fileLength;
  fclose(theFile);
  return YES;

  /* Just in case the failure action needs to be changed. */
 failure:
  if (tmp)
    NSZoneFree(zone, tmp);
  if (theFile)
    fclose(theFile);
  return NO;
}


@interface	NSDataMalloc : NSData
{
  unsigned int	length;
  void		*bytes;
  NSZone	*zone;
}
@end

@interface	NSMutableDataMalloc : NSMutableData
{
  unsigned int	capacity;
  unsigned int	length;
  void		*bytes;
  NSZone	*zone;
}
@end

#if	HAVE_MMAP
@interface	NSDataMappedFile : NSDataMalloc
@end
#endif

#if	HAVE_SHMCTL
@interface	NSDataShared : NSDataMalloc
{
  int		shmid;
}
- (id) initWithShmID: (int)anId length: (unsigned)bufferSize;
@end

@interface	NSMutableDataShared : NSMutableDataMalloc
{
  int		shmid;
}
- (id) initWithShmID: (int)anId length: (unsigned)bufferSize;
@end
#endif

@interface	NSDataStatic: NSDataMalloc
@end


@implementation NSData
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSDataMalloc class], 0, z);
}

+ (id) data
{
  return [[[NSDataStatic alloc] initWithBytesNoCopy: 0 length: 0] 
	  autorelease];
}

+ (id) dataWithBytes: (const void*)bytes
	      length: (unsigned int)length
{
  return [[[NSDataMalloc alloc] initWithBytes:bytes length:length] 
	  autorelease];
}

+ (id) dataWithBytesNoCopy: (void*)bytes
		    length: (unsigned int)length
{
  return [[[NSDataMalloc alloc] initWithBytesNoCopy:bytes length:length]
	  autorelease];
}

+ (id) dataWithContentsOfFile: (NSString*)path
{
  return [[[NSDataMalloc alloc] initWithContentsOfFile:path] 
	  autorelease];
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
#if	HAVE_MMAP
  return [[[NSDataMappedFile alloc] initWithContentsOfMappedFile:path]
          autorelease];
#else
  return [[[NSDataMalloc alloc] initWithContentsOfMappedFile:path]
          autorelease];
#endif
}

+ (id) dataWithData: (NSData*)data
{
  return [[[NSDataMalloc alloc] initWithBytes: [data bytes]
				       length: [data length]] autorelease];
}

- (id) init
{
  return [self initWithBytesNoCopy: 0 length: 0];
}

- (id) initWithBytes: (const void*)aBuffer
	      length: (unsigned int)bufferSize
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned int)bufferSize
{
  if (aBuffer)
    return [self initWithBytesNoCopy: aBuffer
			      length: bufferSize
			    fromZone: NSZoneFromPointer(aBuffer)];
  else
    return [self initWithBytesNoCopy: aBuffer
			      length: bufferSize
			    fromZone: [self zone]];
}

- (id) initWithContentsOfFile: (NSString *)path
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (id) initWithContentsOfMappedFile: (NSString *)path;
{
  [self subclassResponsibility:_cmd];
  return nil;
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
  NSString	*str;
  const char	*src = [self bytes];
  char		*dest;
  int		length = [self length];
  int		i,j;
  NSZone	*z = [self zone];

#define num2char(num) ((num) < 0xa ? ((num)+'0') : ((num)+0x57))

  /* we can just build a cString and convert it to an NSString */
  dest = (char*) NSZoneMalloc(z, 2*length+length/4+3);
  if (dest == 0)
    [NSException raise:NSMallocException
		format:@"No memory for description of NSData object"];
  dest[0] = '<';
  for (i=0,j=1; i<length; i++,j++)
    {
      dest[j++] = num2char((src[i]>>4) & 0x0f);
      dest[j] = num2char(src[i] & 0x0f);
      if((i&0x3) == 3 && i != length-1)
	/* if we've just finished a 32-bit int, print a space */
	dest[++j] = ' ';
    }
  dest[j++] = '>';
  dest[j] = '\0';
  str = [[[NSString alloc] initWithCStringNoCopy: dest length: j fromZone: z]
		autorelease];
  return str;
}

- (void)getBytes: (void*)buffer
{
  [self getBytes:buffer length:[self length]];
}

- (void)getBytes: (void*)buffer
	  length: (unsigned int)length
{
  [self getBytes:buffer range: NSMakeRange(0, length)];
}

- (void)getBytes: (void*)buffer
	   range: (NSRange)aRange
{
  auto	int	size;

  // Check for 'out of range' errors.  This code assumes that the
  // NSRange location and length types will remain unsigned (hence
  // the lack of a less-than-zero check).
  size = [self length];
  if (aRange.location > size ||
      aRange.length   > size ||
      NSMaxRange( aRange ) > size)
  {
    [NSException raise: NSRangeException
		format: @"Range: (%u, %u) Size: %d",
			aRange.location, aRange.length, size];
  }
  else
    memcpy(buffer, [self bytes] + aRange.location, aRange.length);
  return;
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}

- (NSData*) subdataWithRange: (NSRange)aRange
{
  void		*buffer;
  unsigned	l = [self length];

  // Check for 'out of range' errors before calling [-getBytes:range:]
  // so that we can be sure that we don't get a range exception raised
  // after we have allocated memory.
  l = [self length];
  if (aRange.location > l || aRange.length > l || NSMaxRange(aRange) > l)
    [NSException raise: NSRangeException
		format: @"Range: (%u, %u) Size: %d",
			aRange.location, aRange.length, l];

  buffer = NSZoneMalloc([self zone], aRange.length);
  if (buffer == 0)
    [NSException raise:NSMallocException
		format:@"No memory for subdata of NSData object"];
  [self getBytes:buffer range:aRange];

  return [NSData dataWithBytesNoCopy:buffer length:aRange.length];
}

- (unsigned int) hash
{
  return [self length];
}

- (BOOL) isEqual: anObject
{
  if ([anObject isKindOfClass:[NSData class]])
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
  char thePath[BUFSIZ*2+8];
  char theRealPath[BUFSIZ*2];
  FILE *theFile;
  int c;

  if ([path getFileSystemRepresentation: theRealPath
			      maxLength: sizeof(theRealPath)-1] == NO)
    {
      NSLog(@"Open (%s) attempt failed - bad path", theRealPath);
      return NO;
    }

  if (useAuxiliaryFile)
    {
      /* Use the path name of the destination file as a prefix for the
       * mktemp() call so that we can be sure that both files are on
       * the same filesystem and the subsequent rename() will work. */
      strcpy(thePath, theRealPath);
      strcat(thePath, "XXXXXX");
      if (mktemp(thePath) == 0)
	{
          NSLog(@"mktemp (%s) failed - %s", thePath, strerror(errno));
          goto failure;
	}
    }
  else
    {
      strcpy(thePath, theRealPath);
    }

  /* Open the file (whether temp or real) for writing. */
  theFile = fopen(thePath, "w");

  if (theFile == NULL)          /* Something went wrong; we weren't
                                 * even able to open the file. */
    {
      NSLog(@"Open (%s) failed - %s", thePath, strerror(errno));
      goto failure;
    }

  /* Now we try and write the NSData's bytes to the file.  Here `c' is
   * the number of bytes which were successfully written to the file
   * in the fwrite() call. */
  c = fwrite([self bytes], sizeof(char), [self length], theFile);

  if (c < [self length])        /* We failed to write everything for
                                 * some reason. */
    {
      NSLog(@"Fwrite (%s) failed - %s", thePath, strerror(errno));
      goto failure;
    }

  /* We're done, so close everything up. */
  c = fclose(theFile);

  if (c != 0)                   /* I can't imagine what went wrong
                                 * closing the file, but we got here,
                                 * so we need to deal with it. */
    {
      NSLog(@"Fclose (%s) failed - %s", thePath, strerror(errno));
      goto failure;
    }

  /* If we used a temporary file, we still need to rename() it be the
   * real file.  Am I forgetting anything here? */
  if (useAuxiliaryFile)
    {
      c = rename(thePath, theRealPath);

      if (c != 0)               /* Many things could go wrong, I
                                 * guess. */
        {
          NSLog(@"Rename (%s) failed - %s", thePath, strerror(errno));
          goto failure;
        }
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
		unsigned len = (length+1)*sizeof(char);

		*(char**)data = (char*)NSZoneMalloc([self zone], len);
		adr = [NSData dataWithBytesNoCopy: *(void**)data length: len];
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
	    unsigned len = objc_sizeof_type(++type);
	    id adr;

	    *(char**)data = (char*)NSZoneMalloc([self zone], len);
	    adr = [NSData dataWithBytesNoCopy: *(void**)data length: len];

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
	    *(unsigned short*)data = NSSwapBigShortToHost (ns);
	    break;
	}
        case _C_INT:
	case _C_UINT: {
	    unsigned int ni;

	    [self deserializeBytes:&ni
		  length:sizeof(unsigned int)
		  atCursor:cursor];
	    *(unsigned int*)data = NSSwapBigIntToHost (ni);
	    break;
	}
        case _C_LNG:
	case _C_ULNG: {
	    unsigned int nl;

	    [self deserializeBytes:&nl
		  length:sizeof(unsigned long)
		  atCursor:cursor];
	    *(unsigned long*)data = NSSwapBigLongToHost (nl);
	    break;
	}
        case _C_FLT: {
	    NSSwappedFloat nf;

	    [self deserializeBytes:&nf
		  length:sizeof(NSSwappedFloat)
		  atCursor:cursor];
	    *(float*)data = NSSwapBigFloatToHost (nf);
	    break;
	}
        case _C_DBL: {
	    NSSwappedDouble nd;

	    [self deserializeBytes:&nd
		  length:sizeof(NSSwappedDouble)
		  atCursor:cursor];
	    *(double*)data = NSSwapBigDoubleToHost (nd);
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
    result = NSSwapBigIntToHost (ni);
    return result;
}

- (int)deserializeIntAtIndex:(unsigned int)index
{
    unsigned int ni, result;

    [self deserializeBytes:&ni length:sizeof(unsigned int) atCursor:&index];
    result = NSSwapBigIntToHost (ni);
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
	intBuffer[i] = NSSwapBigIntToHost (intBuffer[i]);
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
	intBuffer[i] = NSSwapBigIntToHost (intBuffer[i]);
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone) &&
	[self isKindOfClass: [NSMutableData class]] == NO)
    return [self retain];
  else
    return [[NSDataMalloc allocWithZone: zone]
	initWithBytes: [self bytes] length: [self length]];
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  return [[NSMutableDataMalloc allocWithZone: zone]
	initWithBytes: [self bytes] length: [self length]];
}

- (void) encodeWithCoder:(NSCoder*)coder
{
  [self subclassResponsibility:_cmd];
}

- (id) initWithCoder:(NSCoder*)coder
{
  [self subclassResponsibility:_cmd];
  return nil;
}

@end

@implementation	NSData (GNUstepExtensions)
+ (id) dataWithShmID: (int)anID length: (unsigned)length
{
#if	HAVE_SHMCTL
  return [[[NSDataShared alloc] initWithShmID:anID length:length]
	  autorelease];
#else
  NSLog(@"[NSData -dataWithSmdID:length:] no shared memory support");
  return nil;
#endif
}

+ (id) dataWithSharedBytes: (const void*)bytes length: (unsigned)length
{
#if	HAVE_SHMCTL
  return [[[NSDataShared alloc] initWithBytes:bytes length:length]
	  autorelease];
#else
  return [[[NSDataMalloc alloc] initWithBytes:bytes length:length]
	  autorelease];
#endif
}

+ (id) dataWithStaticBytes: (const void*)bytes length: (unsigned)length
{
  return [[[NSDataStatic alloc] initWithBytesNoCopy:(void*)bytes length:length]
	  autorelease];
}

- (id) initWithBytesNoCopy: (void*)bytes
		    length: (unsigned)length
		  fromZone: (NSZone*)zone
{
  [self subclassResponsibility:_cmd];
}

- (void*) relinquishAllocatedBytes
{
    return 0;	/* No data from NSZoneMalloc - return nul pointer	*/
}
@end


@implementation NSMutableData
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSMutableDataMalloc class], 0, z);
}

+ (id) data
{
  return [[[NSMutableDataMalloc alloc] initWithCapacity: 0] autorelease];
}

+ (id) dataWithBytes: (const void*)bytes
	      length: (unsigned int)length
{
  return [[[NSMutableDataMalloc alloc] initWithBytes:bytes length:length] 
	  autorelease];
}

+ (id) dataWithBytesNoCopy: (void*)bytes
		    length: (unsigned int)length
{
  return [[[NSMutableDataMalloc alloc] initWithBytesNoCopy:bytes length:length]
	  autorelease];
}

+ (id) dataWithCapacity: (unsigned int)numBytes
{
  return [[[NSMutableDataMalloc alloc] initWithCapacity:numBytes]
	  autorelease];
}

+ (id) dataWithContentsOfFile: (NSString*)path
{
  return [[[NSMutableDataMalloc alloc] initWithContentsOfFile:path] 
	  autorelease];
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
  return [[[NSMutableDataMalloc alloc] initWithContentsOfFile:path] 
	  autorelease];
}

+ (id) dataWithData: (NSData*)data
{
  return [[[NSMutableDataMalloc alloc] initWithBytes: [data bytes]
					      length: [data length]]
		autorelease];
}

+ (id) dataWithLength: (unsigned int)length
{
  return [[[NSMutableDataMalloc alloc] initWithLength:length]
	  autorelease];
}

- (const void*) bytes
{
  return [self mutableBytes];
}

- (id) initWithCapacity: (unsigned int)capacity
{
  [self subclassResponsibility:_cmd];
  return nil;
}

- (id) initWithLength: (unsigned int)length
{
  [self subclassResponsibility:_cmd];
  return nil;
}

// Adjusting Capacity

- (void) increaseLengthBy: (unsigned int)extraLength
{
  [self setLength:[self length]+extraLength];
}

- (void) setLength: (unsigned)size
{
  [self subclassResponsibility:_cmd];
}

- (void*) mutableBytes
{
  [self subclassResponsibility:_cmd];
  return NULL;
}

// Appending Data

- (void) appendBytes: (const void*)aBuffer
	      length: (unsigned int)bufferSize
{
  unsigned	oldLength = [self length];
  void*		buffer;

  [self setLength: oldLength + bufferSize];
  buffer = [self mutableBytes];
  memcpy(buffer + oldLength, aBuffer, bufferSize);
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
  if (aRange.location > size ||
      aRange.length   > size ||
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
  if (aRange.location > size ||
      aRange.length   > size ||
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

- (void) setData: (NSData*)data
{
  NSRange	r = NSMakeRange(0, [data length]);

  [self setCapacity: [data length]];
  [self replaceBytesInRange: r withBytes: [data bytes]];
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
	    unsigned short ns = NSSwapHostShortToBig (*(unsigned short*)data);
	    [self appendBytes:&ns length:sizeof(unsigned short)];
	    break;
	}
	case _C_INT:
	case _C_UINT: {
	    unsigned int ni = NSSwapHostIntToBig (*(unsigned int*)data);
	    [self appendBytes:&ni length:sizeof(unsigned int)];
	    break;
	}
	case _C_LNG:
	case _C_ULNG: {
	    unsigned long nl = NSSwapHostLongToBig (*(unsigned long*)data);
	    [self appendBytes:&nl length:sizeof(unsigned long)];
	    break;
	}
	case _C_FLT: {
	    NSSwappedFloat nf = NSSwapHostFloatToBig (*(float*)data);
	    [self appendBytes:&nf length:sizeof(NSSwappedFloat)];
	    break;
	}
	case _C_DBL: {
	    NSSwappedDouble nd = NSSwapHostDoubleToBig (*(double*)data);
	    [self appendBytes:&nd length:sizeof(NSSwappedDouble)];
	    break;
	}
	default:
	    [NSException raise:NSGenericException
                format:@"Unknown type to deserialize - '%s'", type];
    }
}

- (void)serializeInt:(int)value
{
    unsigned int ni = NSSwapHostIntToBig (value);
    [self appendBytes:&ni length:sizeof(unsigned int)];
}

- (void)serializeInt:(int)value atIndex:(unsigned int)index
{
    unsigned int ni = NSSwapHostIntToBig (value);
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

@implementation	NSMutableData (GNUstepExtensions)
+ (id) dataWithShmID: (int)anID length: (unsigned)length
{
#if	HAVE_SHMCTL
  return [[[NSMutableDataShared alloc] initWithShmID:anID length:length]
	  autorelease];
#else
  NSLog(@"[NSMutableData -dataWithSmdID:length:] no shared memory support");
  return nil;
#endif
}

+ (id) dataWithSharedBytes: (const void*)bytes length: (unsigned)length
{
#if	HAVE_SHMCTL
  return [[[NSMutableDataShared alloc] initWithBytes:bytes length:length]
	  autorelease];
#else
  return [[[NSMutableDataMalloc alloc] initWithBytes:bytes length:length]
	  autorelease];
#endif
}

- (unsigned int) capacity
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) setCapacity: (unsigned int)newCapacity
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (int) shmID
{
  return -1;
}
@end


@implementation	NSDataMalloc
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSDataMalloc class], 0, z);
}

- (const void*) bytes
{
  return bytes;
}

- (Class) classForArchiver
{
  return [NSDataMalloc class];
}

- (Class) classForCoder
{
  return [NSDataMalloc class];
}

- (Class) classForPortCoder
{
  return [NSDataMalloc class];
}

- (void) dealloc
{
  if (bytes)
    {
      NSZoneFree(zone, bytes);
      bytes = 0;
      length = 0;
    }
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(unsigned long) at: &length];
  [aCoder encodeArrayOfObjCType: @encode(unsigned char) count:length at: bytes];
}

- (id) init
{
  return [self initWithBytesNoCopy: 0 length: 0 fromZone: [self zone]];
}

- (id) initWithBytes: (const void*)aBuffer length: (unsigned int)bufferSize
{
  void*	tmp = 0;

  if (aBuffer != 0 && bufferSize > 0)
    {
      zone = [self zone];
      tmp = NSZoneMalloc(zone, bufferSize);
      if (tmp == 0)
	{
	  NSLog(@"[NSDataMalloc -initWithBytes:length:] unable to allocate %lu bytes", bufferSize);
	  [self dealloc];
	  return nil;
	}
      else
	{
	  memcpy(tmp, aBuffer, bufferSize);
	}
    }
  self = [self initWithBytesNoCopy:tmp length:bufferSize fromZone: zone];
  return self;
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned int)bufferSize
{
  NSZone *z = NSZoneFromPointer(aBuffer);

  return [self initWithBytesNoCopy: aBuffer length: bufferSize fromZone: z];
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
		  fromZone: (NSZone*)aZone
{
  if (aZone == 0)
    {
      NSData	*data;

      data = [[NSDataStatic alloc] initWithBytesNoCopy: aBuffer
						length: bufferSize];
      [self dealloc];
      return data;
    }

  zone = aZone;
  bytes = aBuffer;
  if (bytes)
    length = bufferSize;

  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned int	l;
  void*		b;

  zone = [self zone];

  [aCoder decodeValueOfObjCType: @encode(unsigned long) at: &l];
  if (l)
    {
      b = NSZoneMalloc(zone, l);
      if (b == 0)
        {
          NSLog(@"[NSDataMalloc -initWithCoder:] unable to get %lu bytes", l);
          [self dealloc];
          return nil;
        }
      [aCoder decodeArrayOfObjCType: @encode(unsigned char) count: l at: b];
    }
  else
    b = 0;
  return [self initWithBytesNoCopy: b length: l fromZone: zone];
}

- (id) initWithContentsOfFile: (NSString *)path
{
  zone = [self zone];
  if (readContentsOfFile(path, &bytes, &length, zone) == NO)
    {
      [self dealloc];
      self = nil;
    }
  return self;
}

- (id) initWithContentsOfMappedFile: (NSString *)path
{
#if	HAVE_MMAP
  [self dealloc];
  self = [NSDataMappedFile alloc];
  return [self initWithContentsOfMappedFile:path];
#else
  return [self initWithContentsOfFile:path];
#endif
}

- (id) initWithData: (NSData*)anObject
{
  if (anObject == nil)
    return [self initWithBytesNoCopy: 0 length: 0 fromZone: [self zone]];
    
  if ([anObject isKindOfClass:[NSData class]] == NO)
    {
      [self dealloc];
      return nil;
    }
  if ([anObject isKindOfClass:[NSMutableData class]] == NO)
    {
      [self dealloc];
      return [anObject retain];
    }
  else
    return [self initWithBytes: [anObject bytes] length: [anObject length]];
}

- (unsigned int) length
{
  return length;
}

- (void*) relinquishAllocatedBytes
{
    void	*buf = bytes;

    bytes = 0;
    length = 0;
    return buf;
}

@end

#if	HAVE_MMAP
@implementation	NSDataMappedFile
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSDataMappedFile class], 0, z);
}

- (void) dealloc
{
  if (bytes)
    {
      munmap(bytes, length);
      bytes = 0;
      length = 0;
    }
  [super dealloc];
}

- (id) initWithContentsOfMappedFile: (NSString*)path
{
  int	fd;
  char	thePath[BUFSIZ*2];

  if ([path getFileSystemRepresentation: thePath
			      maxLength: sizeof(thePath)-1] == NO)
    {
      NSLog(@"Open (%s) attempt failed - bad path", thePath);
      return NO;
    }
  fd = open(thePath, O_RDONLY);
  if (fd < 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to open %s - %s", thePath, strerror(errno));
      [self dealloc];
      return nil;
    }
  /* Find size of file to be mapped. */
  length = lseek(fd, 0, SEEK_END);
  if (length < 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to seek to eof %s - %s", thePath, strerror(errno));
      close(fd);
      [self dealloc];
      return nil;
    }
  /* Position at start of file. */
  if (lseek(fd, 0, SEEK_SET) != 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to seek to sof %s - %s", thePath, strerror(errno));
      close(fd);
      [self dealloc];
      return nil;
    }
  bytes = mmap(0, length, PROT_READ, MAP_SHARED, fd, 0);
  if (bytes == MAP_FAILED)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] mapping failed for %s - %s", thePath, strerror(errno));
      close(fd);
      [self dealloc];
      self = [NSDataMalloc alloc];
      self = [self initWithContentsOfFile: path];
    }
  close(fd);
  return self;
}

@end
#endif	/* HAVE_MMAP	*/

#if	HAVE_SHMCTL
@implementation	NSDataShared
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSDataShared class], 0, z);
}

- (void) dealloc
{
  if (bytes)
    {
      struct shmid_ds	buf;

      if (shmctl(shmid, IPC_STAT, &buf) < 0)
        NSLog(@"[NSDataShared -dealloc] shared memory control failed - %s",
		strerror(errno));
      else if (buf.shm_nattch == 1)
	if (shmctl(shmid, IPC_RMID, &buf) < 0)	/* Mark for deletion. */
          NSLog(@"[NSDataShared -dealloc] shared memory delete failed - %s",
		strerror(errno));
      if (shmdt(bytes) < 0)
        NSLog(@"[NSDataShared -dealloc] shared memory detach failed - %s",
		strerror(errno));
      bytes = 0;
      length = 0;
      shmid = -1;
    }
  [super dealloc];
}

- (id) initWithBytes: (const void*)aBuffer length: (unsigned)bufferSize
{
  struct shmid_ds	buf;

  shmid = -1;
  if (aBuffer && bufferSize)
    {
      shmid = shmget(IPC_PRIVATE, bufferSize, IPC_CREAT|VM_RDONLY);
      if (shmid == -1)			/* Created memory? */
	{
	  NSLog(@"[-initWithBytes:length:] shared mem get failed for %u - %s",
		    bufferSize, strerror(errno));
	  [self dealloc];
	  self = [NSDataMalloc alloc];
	  return [self initWithBytes: aBuffer length: bufferSize];
	}

    bytes = shmat(shmid, 0, 0);
    if (bytes == (void*)-1)
      {
	NSLog(@"[-initWithBytes:length:] shared mem attach failed for %u - %s",
		  bufferSize, strerror(errno));
	bytes = 0;
	[self dealloc];
	self = [NSDataMalloc alloc];
	return [self initWithBytes: aBuffer length: bufferSize];
      }
      length = bufferSize;
    }
  return self;
}

- (id) initWithShmID: (int)anId length: (unsigned)bufferSize
{
  struct shmid_ds	buf;

  shmid = anId;
  if (shmctl(shmid, IPC_STAT, &buf) < 0)
    {
      NSLog(@"[NSDataShared -initWithShmID:length:] shared memory control failed - %s", strerror(errno));
      [self dealloc];	/* Unable to access memory. */
      return nil;
    }
  if (buf.shm_segsz < bufferSize)
    {
      NSLog(@"[NSDataShared -initWithShmID:length:] shared memory segment too small");
      [self dealloc];	/* Memory segment too small. */
      return nil;
    }
  bytes = shmat(shmid, 0, 0);
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSDataShared -initWithShmID:length:] shared memory attach failed - %s",
		strerror(errno));
      bytes = 0;
      [self dealloc];	/* Unable to attach to memory. */
      return nil;
    }
  length = bufferSize;
  return self;
}

- (int) shmID
{
  return shmid;
}

@end
#endif	/* HAVE_SHMCTL	*/


@implementation	NSDataStatic
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSDataStatic class], 0, z);
}

- (void) dealloc
{
  bytes = 0;
  length = 0;
  [super dealloc];
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
		  fromZone: (NSZone*)aZone
{
  bytes = aBuffer;
  length = bufferSize;
  return self;  
}

@end

@implementation	NSMutableDataMalloc
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSMutableDataMalloc class], 0, z);
}

- (unsigned int) capacity
{
  return capacity;
}

- (Class) classForArchiver
{
  return [NSMutableDataMalloc class];
}

- (Class) classForCoder
{
  return [NSMutableDataMalloc class];
}

- (Class) classForPortCoder
{
  return [NSMutableDataMalloc class];
}

- (void) dealloc
{
  if (bytes)
    {
      NSZoneFree(zone, bytes);
      bytes = 0;
      length = 0;
      capacity = 0;
    }
  [super dealloc];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(unsigned long) at: &length];
  [aCoder encodeArrayOfObjCType: @encode(unsigned char) count:length at: bytes];
}

- (id) init
{
  return [self initWithBytesNoCopy: 0 length: 0];
}

- (id) initWithBytes: (const void*)aBuffer length: (unsigned int)bufferSize
{
  self = [self initWithCapacity: bufferSize];
  if (self)
    {
      if (aBuffer && bufferSize > 0)
	{
	  memcpy(bytes, aBuffer, bufferSize);
	  length = bufferSize;
	}
    }
  return self;
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned int)bufferSize
{
  NSZone	*aZone = NSZoneFromPointer(aBuffer);
  return [self initWithBytesNoCopy: aBuffer length: bufferSize fromZone: aZone];
}

/*
 *	THIS IS THE DESIGNATED INITIALISER
 */
- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
		  fromZone: (NSZone*)aZone
{
  if (aZone == 0)
    {
      self = [self initWithBytes: aBuffer length: bufferSize];
      return self;
    }

  if (aBuffer == 0)
    {
      self = [self initWithCapacity: bufferSize];
      if (self)
	[self setLength: bufferSize];
      return self;
    }

  zone = aZone;
  bytes = aBuffer;
  length = bufferSize;
  capacity = bufferSize;

  return self;
}

- (id) initWithCapacity: (unsigned)size
{
  zone = [self zone];
  if (size)
    {
      bytes = NSZoneMalloc(zone, size);
      if (bytes == 0)
	{
	  NSLog(@"[NSMutableDataMalloc -initWithCapacity:] out of memory for %u bytes - %s", size, strerror(errno));
	  [self dealloc];
	  return nil;
	}
    }
  capacity = size;
  length = 0;

  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned int	l;
  void*		b;

  [aCoder decodeValueOfObjCType: @encode(unsigned long) at: &l];
  if (l)
    {
      [self initWithCapacity: l];
      if (bytes == 0)
	{
	  NSLog(@"[NSMutableDataMalloc -initWithCoder:] unable to allocate %lu bytes", l);
	  [self dealloc];
	  return nil;
	}
      [aCoder decodeArrayOfObjCType: @encode(unsigned char) count: l at: bytes];
      length = l;
    }
  return self;
}

- (id) initWithLength: (unsigned)size
{
  self = [self initWithCapacity: size];
  if (self)
    {
      memset(bytes, '\0', size);
      length = size;
    }
  return self;
}

- (id) initWithContentsOfFile: (NSString *)path
{
  self = [self initWithCapacity: 0];
  if (readContentsOfFile(path, &bytes, &length, zone) == NO)
    {
      [self dealloc];
      self = nil;
    }
  else
    capacity = length;
  return self;
}

- (id) initWithContentsOfMappedFile: (NSString *)path
{
  return [self initWithContentsOfFile:path];
}

- (id) initWithData: (NSData*)anObject
{
  if (anObject == nil)
    return [self initWithBytesNoCopy: 0 length: 0];
    
  if ([anObject isKindOfClass:[NSData class]] == NO)
    {
      [self dealloc];
      return nil;
    }
  return [self initWithBytes: [anObject bytes] length: [anObject length]];
}

- (unsigned int) length
{
  return length;
}

- (void*) mutableBytes
{
  return bytes;
}

- (id) setCapacity: (unsigned int)size
{
  if (size != capacity)
    {
      void*	tmp;

      if (bytes)
        tmp = NSZoneRealloc(zone, bytes, size);
      else
        tmp = NSZoneMalloc(zone, size);

      if (tmp == 0)
	[NSException raise:NSMallocException
                format:@"Unable to set data capacity to '%d'", size];
     
      bytes = tmp;
      capacity = size;
    }
  if (size < length)
    length = size;
  return self;
}

- (void) setLength: (unsigned)size
{
  if (size > capacity)
    [self setCapacity: size];

  if (size > length)
    memset(bytes + length, '\0', size - length);

  length = size;
}

- (void*) relinquishAllocatedBytes
{
    capacity = 0;
    return [super relinquishAllocatedBytes];
}

@end


#if	HAVE_SHMCTL
@implementation	NSMutableDataShared
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSMutableDataShared class], 0, z);
}

- (void) dealloc
{
  if (bytes)
    {
      struct shmid_ds	buf;

      if (shmctl(shmid, IPC_STAT, &buf) < 0)
        NSLog(@"[NSMutableDataShared -dealloc] shared memory control failed - %s", strerror(errno));
      else if (buf.shm_nattch == 1)
	if (shmctl(shmid, IPC_RMID, &buf) < 0)	/* Mark for deletion. */
          NSLog(@"[NSMutableDataShared -dealloc] shared memory delete failed - %s", strerror(errno));
      if (shmdt(bytes) < 0)
        NSLog(@"[NSMutableDataShared -dealloc] shared memory detach failed - %s", strerror(errno));
      bytes = 0;
      length = 0;
      capacity = 0;
      shmid = -1;
    }
  [super dealloc];
}

- (id) initWithBytes: (const void*)aBuffer length: (unsigned)bufferSize
{
  self = [self initWithCapacity: bufferSize];
  if (self)
    {
      if (bufferSize && aBuffer)
        memcpy(bytes, aBuffer, bufferSize);
      length = bufferSize;
    }
  return self;
}

- (id) initWithCapacity: (unsigned)bufferSize
{
  struct shmid_ds	buf;
  int			e;

  shmid = shmget(IPC_PRIVATE, bufferSize, IPC_CREAT|VM_ACCESS);
  if (shmid == -1)			/* Created memory? */
    {
      NSLog(@"[NSMutableDataShared -initWithCapacity:] shared memory get failed for %u - %s", bufferSize, strerror(errno));
      [self dealloc];
      self = [NSMutableDataMalloc alloc];
      return [self initWithCapacity: bufferSize];
    }

  bytes = shmat(shmid, 0, 0);
  e = errno;
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSMutableDataShared -initWithCapacity:] shared memory attach failed for %u - %s", bufferSize, strerror(e));
      bytes = 0;
      [self dealloc];
      self = [NSMutableDataMalloc alloc];
      return [self initWithCapacity: bufferSize];
    }
  length = 0;
  capacity = bufferSize;

  return self;
}

- (id) initWithShmID: (int)anId length: (unsigned)bufferSize
{
  struct shmid_ds	buf;

  shmid = anId;
  if (shmctl(shmid, IPC_STAT, &buf) < 0)
    {
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory control failed - %s", strerror(errno));
      [self dealloc];	/* Unable to access memory. */
      return nil;
    }
  if (buf.shm_segsz < bufferSize)
    {
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory segment too small");
      [self dealloc];	/* Memory segment too small. */
      return nil;
    }
  bytes = shmat(shmid, 0, 0);
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory attach failed - %s", strerror(errno));
      bytes = 0;
      [self dealloc];	/* Unable to attach to memory. */
      return nil;
    }
  length = bufferSize;
  capacity = length;

  return self;
}

- (id) setCapacity: (unsigned)size
{
  if (size != capacity)
    {
      void		*tmp;
      struct shmid_ds	buf;
      int		newid;

      newid = shmget(IPC_PRIVATE, size, IPC_CREAT|VM_ACCESS);
      if (newid == -1)			/* Created memory? */
	[NSException raise:NSMallocException
		    format:@"Unable to create shared memory segment - %s.",
		    strerror(errno)];
      tmp = shmat(newid, 0, 0);
      if ((int)tmp == -1)			/* Attached memory? */
	[NSException raise:NSMallocException
		    format:@"Unable to attach to shared memory segment."];
      memcpy(tmp, bytes, length);
      if (bytes)
	{
          struct shmid_ds	buf;

          if (shmctl(shmid, IPC_STAT, &buf) < 0)
            NSLog(@"[NSMutableDataShared -setCapacity:] shared memory control failed - %s", strerror(errno));
          else if (buf.shm_nattch == 1)
	    if (shmctl(shmid, IPC_RMID, &buf) < 0)	/* Mark for deletion. */
              NSLog(@"[NSMutableDataShared -setCapacity:] shared memory delete failed - %s", strerror(errno));
	  if (shmdt(bytes) < 0)				/* Detach memory. */
              NSLog(@"[NSMutableDataShared -setCapacity:] shared memory detach failed - %s", strerror(errno));
	}
      bytes = tmp;
      shmid = newid;
      capacity = size;
    }
  if (size < length)
    length = size;
  return self;
}

- (int) shmID
{
  return shmid;
}

@end
#endif	/* HAVE_SHMCTL	*/

