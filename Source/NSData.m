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
 *			never shrinks the allocated buffer capacity
 *		[-setCapacity:]
 *			doesn't clear newly allocated bytes
 *			sets the size of the allocated buffer.
 *
 *	The actual class hierarchy is as follows -
 *
 *	NSData					Abstract base class.
 *	    NSDataStatic			Concrete class static buffers.
 *		NSDataMalloc			Concrete class.
 *		    NSDataMappedFile		Memory mapped files.
 *		    NSDataShared		Extension for shared memory.
 *	    NSMutableData			Abstract base class.
 *		NSMutableDataMalloc		Concrete class.
 *		    NSMutableDataShared		Extension for shared memory.
 *
 *	NSMutableDataMalloc MUST share it's initial instance variable layout
 *	with NSDataMalloc so that it can use the 'behavior' code to inherit
 *	methods from NSDataMalloc.
 *
 *	Since all the other subclasses are based on NSDataMalloc or
 *	NSMutableDataMalloc, we can put most methods in here and not
 *	bother with duplicating them in the other classes.
 *		
 */

#include <config.h>
#include <objc/objc-api.h>
#include <gnustep/base/preface.h>
#include <gnustep/base/fast.x>
#include <gnustep/base/behavior.h>
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

/*
 *	Some static variables to cache classes and methods for quick access -
 *	these are set up at process startup or in [NSData +initialize]
 */
static SEL	appendSel = @selector(appendBytes:length:);
static Class	dataMalloc;
static Class	mutableDataMalloc;
static IMP	appendImp;

static BOOL
readContentsOfFile(NSString* path, void** buf, unsigned* len, NSZone* zone)
{
    char		thePath[BUFSIZ*2];
    FILE		*theFile = 0;
    unsigned	fileLength;
    void		*tmp = 0;
    int			c;

    if ([path getFileSystemRepresentation: thePath
				maxLength: sizeof(thePath)-1] == NO) {
	NSLog(@"Open (%s) attempt failed - bad path", thePath);
	return NO;
    }
    theFile = fopen(thePath, "r");

    if (theFile == NULL) {          /* We failed to open the file. */
	NSLog(@"Open (%s) attempt failed - %s", thePath, strerror(errno));
	goto failure;
    }

    /*
     *	Seek to the end of the file.
     */
    c = fseek(theFile, 0L, SEEK_END);
    if (c != 0) {
	NSLog(@"Seek to end of file failed - %s", strerror(errno));
	goto failure;
    }

    /*
     *	Determine the length of the file (having seeked to the end of the
     * file) by calling ftell().
     */
    fileLength = ftell(theFile);
    if (fileLength == -1) {
	NSLog(@"Ftell failed - %s", strerror(errno));
	goto failure;
    }

    tmp = NSZoneMalloc(zone, fileLength);
    if (tmp == 0) {
	NSLog(@"Malloc failed for file of length %d- %s",
		fileLength, strerror(errno));
	goto failure;
    }

    /*
     *	Rewind the file pointer to the beginning, preparing to read in
     *	the file.
     */
    c = fseek(theFile, 0L, SEEK_SET);
    if (c != 0) {
	NSLog(@"Fseek to start of file failed - %s", strerror(errno));
	goto failure;
    }

    c = fread(tmp, 1, fileLength, theFile);
    if (c != fileLength) {
	NSLog(@"Fread of file contents failed - %s", strerror(errno));
	goto failure;
    }

    *buf = tmp;
    *len = fileLength;
    fclose(theFile);
    return YES;

    /*
     *	Just in case the failure action needs to be changed.
     */
failure:
    if (tmp)
	NSZoneFree(zone, tmp);
    if (theFile)
	fclose(theFile);
    return NO;
}



/*
 *	NB, The start of the NSMutableDataMalloc instance variables must be
 *	identical to that of NSDataMalloc in order to inherit its methods.
 */
@interface	NSDataStatic : NSData
{
  unsigned	length;
  void		*bytes;
}
@end

@interface	NSDataMalloc : NSDataStatic
{
  NSZone	*zone;
}
@end

@interface	NSMutableDataMalloc : NSMutableData
{
  unsigned	length;
  void		*bytes;
  NSZone	*zone;
  unsigned	capacity;
  unsigned	growth;
}
/* Increase capacity to at least the specified minimum value.	*/ 
- (void) _grow: (unsigned)minimum;
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


@implementation NSData

+ (void) initialize
{
    if ([self class] == [NSData class]) {
	dataMalloc = [NSDataMalloc class];
	mutableDataMalloc = [NSMutableDataMalloc class];
	appendImp = [mutableDataMalloc
	    instanceMethodForSelector: appendSel];
    }
}

+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject(dataMalloc, 0, z);
}

+ (id) data
{
  return [[[NSDataStatic alloc] initWithBytesNoCopy: 0 length: 0] 
	  autorelease];
}

+ (id) dataWithBytes: (const void*)bytes
	      length: (unsigned)length
{
  return [[[dataMalloc alloc] initWithBytes: bytes length: length] 
	  autorelease];
}

+ (id) dataWithBytesNoCopy: (void*)bytes
		    length: (unsigned)length
{
  return [[[dataMalloc alloc] initWithBytesNoCopy: bytes
						       length: length]
	  autorelease];
}

+ (id) dataWithContentsOfFile: (NSString*)path
{
  return [[[dataMalloc alloc] initWithContentsOfFile: path] 
	  autorelease];
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
#if	HAVE_MMAP
  return [[[NSDataMappedFile alloc] initWithContentsOfMappedFile: path]
          autorelease];
#else
  return [[[dataMalloc alloc] initWithContentsOfMappedFile: path]
          autorelease];
#endif
}

+ (id) dataWithData: (NSData*)data
{
  return [[[dataMalloc alloc] initWithBytes: [data bytes]
				       length: [data length]] autorelease];
}

- (id) init
{
   return [self initWithBytesNoCopy: 0
			     length: 0];
}

- (id) initWithBytes: (const void*)aBuffer
	      length: (unsigned)bufferSize
{
    [self subclassResponsibility: _cmd];
    return nil;
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
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
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithContentsOfMappedFile: (NSString *)path;
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithData: (NSData*)data
{
    return [self initWithBytes: [data bytes]
			length: [data length]];
}


// Accessing Data 

- (const void*) bytes
{
  [self subclassResponsibility: _cmd];
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
    [NSException raise: NSMallocException
		format: @"No memory for description of NSData object"];
  dest[0] = '<';
  for (i=0,j=1; i<length; i++,j++)
    {
      dest[j++] = num2char((src[i]>>4) & 0x0f);
      dest[j] = num2char(src[i] & 0x0f);
      if ((i&0x3) == 3 && i != length-1)
	/* if we've just finished a 32-bit int, print a space */
	dest[++j] = ' ';
    }
  dest[j++] = '>';
  dest[j] = '\0';
  str = [[[NSString allocWithZone: z] initWithCStringNoCopy: dest
						     length: j
						   fromZone: z] autorelease];
  return str;
}

- (void)getBytes: (void*)buffer
{
    [self getBytes: buffer range: NSMakeRange(0, [self length])];
}

- (void)getBytes: (void*)buffer
	  length: (unsigned)length
{
    [self getBytes: buffer range: NSMakeRange(0, length)];
}

- (void)getBytes: (void*)buffer
	   range: (NSRange)aRange
{
  int	size;

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
    [NSException raise: NSMallocException
		format: @"No memory for subdata of NSData object"];
  [self getBytes: buffer range: aRange];

  return [NSData dataWithBytesNoCopy: buffer length: aRange.length];
}

- (unsigned) hash
{
  return [self length];
}

- (BOOL) isEqual: anObject
{
  if ([anObject isKindOfClass: [NSData class]])
    return [self isEqualToData: anObject];
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

- (unsigned)length;
{
  /* This is left to concrete subclasses to implement. */
  [self subclassResponsibility: _cmd];
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

- (unsigned) deserializeAlignedBytesLengthAtCursor: (unsigned int*)cursor
{
    return (unsigned)[self deserializeIntAtCursor: cursor];
}

- (void) deserializeBytes: (void*)buffer
		   length: (unsigned)bytes
		 atCursor: (unsigned*)cursor
{
    NSRange	range = { *cursor, bytes };

    [self getBytes: buffer range: range];
    *cursor += bytes;
}

- (void)deserializeDataAt: (void*)data
	       ofObjCType: (const char*)type
		 atCursor: (unsigned*)cursor
		  context: (id <NSObjCTypeSerializationCallBack>)callback
{
    if (!type || !data)
	return;

    switch(*type) {
	case _C_ID: {
	    [callback deserializeObjectAt: data ofObjCType: type
		    fromData: self atCursor: cursor];
	    break;
	}
	case _C_CHARPTR: {
	    int length = [self deserializeIntAtCursor: cursor];

	    if (length == -1) {
		*(const char**)data = NULL;
		return;
	    }
	    else {
		unsigned len = (length+1)*sizeof(char);
		NSZone	*z = [self zone];

		*(char**)data = (char*)NSZoneMalloc(z, len);
		[[[dataMalloc allocWithZone: z]
			     initWithBytesNoCopy: *(void**)data
					  length: len
				        fromZone: z] autorelease];
	    }

	    [self deserializeBytes: *(char**)data
			    length: length
			  atCursor: cursor];
	    (*(char**)data)[length] = '\0';
	    break;
	}
	case _C_ARY_B: {
	    unsigned	offset = 0;
	    unsigned	size;
	    unsigned	count = atoi(++type);
	    unsigned	i;

            while (isdigit(*type)) {
		type++;
	    }
	    size = objc_sizeof_type(type);

	    for (i = 0; i < count; i++) {
		[self deserializeDataAt: (char*)data + offset
			     ofObjCType: type
			       atCursor: cursor
				context: callback];
		offset += size;
	    }
	    return;
	}
	case _C_STRUCT_B: {
	    int offset = 0;

	    while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	    for (;;) {
		[self deserializeDataAt: ((char*)data) + offset
			     ofObjCType: type
			       atCursor: cursor
				context: callback];
		offset += objc_sizeof_type(type);
		type = objc_skip_typespec(type);
		if (*type != _C_STRUCT_E) {
		    int	align = objc_alignof_type(type);
		    int	rem = offset % align;

		    if (rem != 0) {
			offset += align - rem;
		    }
		}
		else break;
	    }
	    break;
        }
        case _C_PTR: {
	    unsigned len = objc_sizeof_type(++type);
	    NSZone *z = [self zone];

	    *(char**)data = (char*)NSZoneMalloc(z, len);
	    [[[dataMalloc allocWithZone: z]
			 initWithBytesNoCopy: *(void**)data
				      length: len
				    fromZone: z] autorelease];
	    [self deserializeDataAt: *(char**)data
		         ofObjCType: type
			   atCursor: cursor
			    context: callback];
	    break;
        }
	case _C_CHR:
	case _C_UCHR: {
	    [self deserializeBytes: data
			    length: sizeof(unsigned char)
			  atCursor: cursor];
	    break;
	}
        case _C_SHT:
	case _C_USHT: {
	    unsigned short ns;

	    [self deserializeBytes: &ns
			    length: sizeof(unsigned short)
			  atCursor: cursor];
	    *(unsigned short*)data = NSSwapBigShortToHost(ns);
	    break;
	}
        case _C_INT:
	case _C_UINT: {
	    unsigned ni;

	    [self deserializeBytes: &ni
			    length: sizeof(unsigned)
			  atCursor: cursor];
	    *(unsigned*)data = NSSwapBigIntToHost(ni);
	    break;
	}
        case _C_LNG:
	case _C_ULNG: {
	    unsigned long nl;

	    [self deserializeBytes: &nl
			    length: sizeof(unsigned long)
			  atCursor: cursor];
	    *(unsigned long*)data = NSSwapBigLongToHost(nl);
	    break;
	}
#ifdef	_C_LNG_LNG
        case _C_LNG_LNG:
	case _C_ULNG_LNG: {
	    unsigned long long nl;

	    [self deserializeBytes: &nl
			    length: sizeof(unsigned long long)
			  atCursor: cursor];
	    *(unsigned long long*)data = NSSwapBigLongLongToHost(nl);
	    break;
	}
#endif
        case _C_FLT: {
	    NSSwappedFloat nf;

	    [self deserializeBytes: &nf
			    length: sizeof(NSSwappedFloat)
			  atCursor: cursor];
	    *(float*)data = NSSwapBigFloatToHost(nf);
	    break;
	}
        case _C_DBL: {
	    NSSwappedDouble nd;

	    [self deserializeBytes: &nd
			    length: sizeof(NSSwappedDouble)
			  atCursor: cursor];
	    *(double*)data = NSSwapBigDoubleToHost(nd);
	    break;
	}
        default:
	    [NSException raise: NSGenericException
                format: @"Unknown type to deserialize - '%s'", type];
    }
}

- (int)deserializeIntAtCursor: (unsigned*)cursor
{
    unsigned ni, result;

    [self deserializeBytes: &ni length: sizeof(unsigned) atCursor: cursor];
    result = NSSwapBigIntToHost(ni);
    return result;
}

- (int)deserializeIntAtIndex: (unsigned)index
{
    unsigned ni, result;

    [self deserializeBytes: &ni length: sizeof(unsigned) atCursor: &index];
    result = NSSwapBigIntToHost(ni);
    return result;
}

- (void)deserializeInts: (int*)intBuffer
		  count: (unsigned)numInts
	       atCursor: (unsigned*)cursor
{
    unsigned i;

    [self deserializeBytes: &intBuffer
	  length: numInts * sizeof(unsigned)
	  atCursor: cursor];
    for (i = 0; i < numInts; i++)
	intBuffer[i] = NSSwapBigIntToHost(intBuffer[i]);
}

- (void)deserializeInts: (int*)intBuffer
		  count: (unsigned)numInts
		atIndex: (unsigned)index
{
    unsigned i;

    [self deserializeBytes: &intBuffer
		    length: numInts * sizeof(int)
		  atCursor: &index];
    for (i = 0; i < numInts; i++) {
	intBuffer[i] = NSSwapBigIntToHost(intBuffer[i]);
    }
}

- (id) copyWithZone: (NSZone*)zone
{
    if (NSShouldRetainWithZone(self, zone) &&
	[self isKindOfClass: [NSMutableData class]] == NO)
	return [self retain];
    else
	return [[dataMalloc allocWithZone: zone]
	    initWithBytes: [self bytes] length: [self length]];
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
    return [[mutableDataMalloc allocWithZone: zone]
	initWithBytes: [self bytes] length: [self length]];
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  [self subclassResponsibility: _cmd];
}

- (id) initWithCoder: (NSCoder*)coder
{
  [self subclassResponsibility: _cmd];
  return nil;
}

@end

@implementation	NSData (GNUstepExtensions)
+ (id) dataWithShmID: (int)anID length: (unsigned)length
{
#if	HAVE_SHMCTL
  return [[[NSDataShared alloc] initWithShmID: anID length: length]
	  autorelease];
#else
  NSLog(@"[NSData -dataWithSmdID:length:] no shared memory support");
  return nil;
#endif
}

+ (id) dataWithSharedBytes: (const void*)bytes length: (unsigned)length
{
#if	HAVE_SHMCTL
  return [[[NSDataShared alloc] initWithBytes: bytes length: length]
	  autorelease];
#else
  return [[[dataMalloc alloc] initWithBytes: bytes length: length]
	  autorelease];
#endif
}

+ (id) dataWithStaticBytes: (const void*)bytes length: (unsigned)length
{
  return [[[NSDataStatic alloc] initWithBytesNoCopy: (void*)bytes
					     length: length] autorelease];
}

- (id) initWithBytesNoCopy: (void*)bytes
		    length: (unsigned)length
		  fromZone: (NSZone*)zone
{
  [self subclassResponsibility: _cmd];
}

- (void*) relinquishAllocatedBytes
{
    return [self relinquishAllocatedBytesFromZone: 0];
}

- (void*) relinquishAllocatedBytesFromZone: (NSZone*)aZone;
{
    return 0;	/* No data from NSZoneMalloc - return nul pointer	*/
}
@end


@implementation NSMutableData
+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject(mutableDataMalloc, 0, z);
}

+ (id) data
{
  return [[[mutableDataMalloc alloc] initWithCapacity: 0]
		autorelease];
}

+ (id) dataWithBytes: (const void*)bytes
	      length: (unsigned)length
{
  return [[[mutableDataMalloc alloc] initWithBytes: bytes
							length: length] 
	  autorelease];
}

+ (id) dataWithBytesNoCopy: (void*)bytes
		    length: (unsigned)length
{
  return [[[mutableDataMalloc alloc] initWithBytesNoCopy: bytes
							      length: length]
	  autorelease];
}

+ (id) dataWithCapacity: (unsigned)numBytes
{
  return [[[mutableDataMalloc alloc] initWithCapacity: numBytes]
	  autorelease];
}

+ (id) dataWithContentsOfFile: (NSString*)path
{
  return [[[mutableDataMalloc alloc] initWithContentsOfFile: path] 
	  autorelease];
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
  return [[[mutableDataMalloc alloc] initWithContentsOfFile: path] 
	  autorelease];
}

+ (id) dataWithData: (NSData*)data
{
  return [[[mutableDataMalloc alloc] initWithBytes: [data bytes]
					      length: [data length]]
		autorelease];
}

+ (id) dataWithLength: (unsigned)length
{
  return [[[mutableDataMalloc alloc] initWithLength: length]
	  autorelease];
}

- (const void*) bytes
{
  return [self mutableBytes];
}

- (id) initWithCapacity: (unsigned)capacity
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithLength: (unsigned)length
{
  [self subclassResponsibility: _cmd];
  return nil;
}

// Adjusting Capacity

- (void) increaseLengthBy: (unsigned)extraLength
{
  [self setLength: [self length]+extraLength];
}

- (void) setLength: (unsigned)size
{
  [self subclassResponsibility: _cmd];
}

- (void*) mutableBytes
{
  [self subclassResponsibility: _cmd];
  return NULL;
}

// Appending Data

- (void) appendBytes: (const void*)aBuffer
	      length: (unsigned)bufferSize
{
  unsigned	oldLength = [self length];
  void*		buffer;

  [self setLength: oldLength + bufferSize];
  buffer = [self mutableBytes];
  memcpy(buffer + oldLength, aBuffer, bufferSize);
}

- (void) appendData: (NSData*)other
{
  [self appendBytes: [other bytes]
	     length: [other length]];
}


// Modifying Data

- (void) replaceBytesInRange: (NSRange)aRange
		   withBytes: (const void*)bytes
{
  int	size;

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
  int	size;

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

- (void)serializeAlignedBytesLength: (unsigned)length
{
    [self serializeInt: length];
}

- (void)serializeDataAt: (const void*)data
	     ofObjCType: (const char*)type
	        context: (id <NSObjCTypeSerializationCallBack>)callback
{
    if (!data || !type)
	return;

    switch (*type) {
        case _C_ID:
	    [callback serializeObjectAt: (id*)data
			ofObjCType: type
			intoData: self];
	    return;

        case _C_CHARPTR: {
	    int len;

	    if (!*(void**)data) {
		[self serializeInt: -1];
		return;
	    }
	    len = strlen(*(void**)data);
	    [self serializeInt: len];
	    [self appendBytes: *(void**)data length: len];
	    return;
	}
        case _C_ARY_B: {
	    unsigned	offset = 0;
	    unsigned	size;
	    unsigned	count = atoi(++type);
	    unsigned	i;

            while (isdigit(*type)) {
		type++;
	    }
	    size = objc_sizeof_type(type);

	    for (i = 0; i < count; i++) {
		[self serializeDataAt: (char*)data + offset
			   ofObjCType: type
			      context: callback];
		offset += size;
	    }
	    return;
        }
        case _C_STRUCT_B: {
            int offset = 0;
            int align, rem;

            while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
            for (;;) {
                [self serializeDataAt: ((char*)data) + offset
			ofObjCType: type
			context: callback];
                offset += objc_sizeof_type(type);
                type = objc_skip_typespec(type);
                if (*type != _C_STRUCT_E) {
                    align = objc_alignof_type(type);
                    if ((rem = offset % align))
                        offset += align - rem;
                }
                else break;
            }
            return;
        }
	case _C_PTR:
	    [self serializeDataAt: *(char**)data
		       ofObjCType: ++type
			  context: callback];
	    return;
        case _C_CHR:
	case _C_UCHR:
	    [self appendBytes: data length: sizeof(unsigned char)];
	    break;
	case _C_SHT:
	case _C_USHT: {
	    unsigned short ns = NSSwapHostShortToBig(*(unsigned short*)data);
	    [self appendBytes: &ns length: sizeof(unsigned short)];
	    break;
	}
	case _C_INT:
	case _C_UINT: {
	    unsigned ni = NSSwapHostIntToBig(*(unsigned int*)data);
	    [self appendBytes: &ni length: sizeof(unsigned)];
	    break;
	}
	case _C_LNG:
	case _C_ULNG: {
	    unsigned long nl = NSSwapHostLongToBig(*(unsigned long*)data);
	    [self appendBytes: &nl length: sizeof(unsigned long)];
	    break;
	}
#ifdef	_C_LNG_LNG
	case _C_LNG_LNG:
	case _C_ULNG_LNG: {
	    unsigned long long nl;

	    nl = NSSwapHostLongLongToBig(*(unsigned long long*)data);
	    [self appendBytes: &nl length: sizeof(unsigned long long)];
	    break;
	}
#endif
	case _C_FLT: {
	    NSSwappedFloat nf = NSSwapHostFloatToBig(*(float*)data);
	    [self appendBytes: &nf length: sizeof(NSSwappedFloat)];
	    break;
	}
	case _C_DBL: {
	    NSSwappedDouble nd = NSSwapHostDoubleToBig(*(double*)data);
	    [self appendBytes: &nd length: sizeof(NSSwappedDouble)];
	    break;
	}
	default:
	    [NSException raise: NSGenericException
                format: @"Unknown type to deserialize - '%s'", type];
    }
}

- (void)serializeInt: (int)value
{
    unsigned ni = NSSwapHostIntToBig(value);
    [self appendBytes: &ni length: sizeof(unsigned)];
}

- (void)serializeInt: (int)value atIndex: (unsigned)index
{
    unsigned ni = NSSwapHostIntToBig(value);
    NSRange range = { index, sizeof(int) };
    [self replaceBytesInRange: range withBytes: &ni];
}

- (void) serializeInts: (int*)intBuffer
		 count: (unsigned)numInts
{
    unsigned	i;
    SEL		sel = @selector(serializeInt:);
    IMP		imp = [self methodForSelector: sel];

    for (i = 0; i < numInts; i++) {
	(*imp)(self, sel, intBuffer[i]);
    }
}

- (void) serializeInts: (int*)intBuffer
		 count: (unsigned)numInts
	       atIndex: (unsigned)index
{
    unsigned	i;
    SEL		sel = @selector(serializeInt:atIndex:);
    IMP		imp = [self methodForSelector: sel];

    for (i = 0; i < numInts; i++) {
	(*imp)(self, sel, intBuffer[i], index++);
    }
}

@end

@implementation	NSMutableData (GNUstepExtensions)
+ (id) dataWithShmID: (int)anID length: (unsigned)length
{
#if	HAVE_SHMCTL
  return [[[NSMutableDataShared alloc] initWithShmID: anID length: length]
	  autorelease];
#else
  NSLog(@"[NSMutableData -dataWithSmdID:length:] no shared memory support");
  return nil;
#endif
}

+ (id) dataWithSharedBytes: (const void*)bytes length: (unsigned)length
{
#if	HAVE_SHMCTL
  return [[[NSMutableDataShared alloc] initWithBytes: bytes length: length]
	  autorelease];
#else
  return [[[mutableDataMalloc alloc] initWithBytes: bytes length: length]
	  autorelease];
#endif
}

- (unsigned) capacity
{
  [self subclassResponsibility: _cmd];
  return 0;
}

- (id) setCapacity: (unsigned)newCapacity
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (int) shmID
{
  return -1;
}
@end


/*
 *	This is the top of the hierarchy of concrete implementations.
 *	As such, it contains efficient implementations of most methods.
 */
@implementation	NSDataStatic

+ (NSData*) allocWithZone: (NSZone*)z
{
    return (NSData*)NSAllocateObject(self, 0, z);
}

/*	Creation and Destruction of objects.	*/

- (void) dealloc
{
    bytes = 0;
    length = 0;
    [super dealloc];
}

- (id) init
{
    return [self initWithBytesNoCopy: 0
			      length: 0
			    fromZone: [self zone]];
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
		  fromZone: (NSZone*)aZone
{
    bytes = aBuffer;
    length = bufferSize;
    return self;  
}

/* NSCoding	*/

- (Class) classForArchiver
{
    return dataMalloc;		/* Will not be static data when decoded. */
}

- (Class) classForCoder
{
    return dataMalloc;		/* Will not be static data when decoded. */
}

- (Class) classForPortCoder
{
    return dataMalloc;		/* Will not be static data when decoded. */
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
    [aCoder encodeValueOfObjCType: @encode(unsigned long)
			       at: &length];
    [aCoder encodeArrayOfObjCType: @encode(unsigned char)
			    count: length
			       at: bytes];
}

/* Basic methods	*/

- (const void*) bytes
{
    return bytes;
}

- (void) getBytes: (void*)buffer
	    range: (NSRange)aRange
{
    if (aRange.location > length || NSMaxRange(aRange) > length) {
	[NSException raise: NSRangeException
		    format: @"Range: (%u, %u) Size: %d",
			aRange.location, aRange.length, length];
    }
    else {
	memcpy(buffer, bytes + aRange.location, aRange.length);
    }
    return;
}

- (unsigned) length
{
    return length;
}

@end

@implementation	NSDataMalloc

- (void) dealloc
{
    if (bytes) {
	NSZoneFree(zone, bytes);
	bytes = 0;
    }
    [super dealloc];
}

- (id) initWithBytes: (const void*)aBuffer length: (unsigned)bufferSize
{
    void*	tmp = 0;

    if (aBuffer != 0 && bufferSize > 0) {
	zone = [self zone];
	tmp = NSZoneMalloc(zone, bufferSize);
	if (tmp == 0) {
	    NSLog(@"[NSDataMalloc -initWithBytes:length:] unable to allocate %lu bytes", bufferSize);
	    [self release];
	    return nil;
	}
	else {
	    memcpy(tmp, aBuffer, bufferSize);
	}
    }
    self = [self initWithBytesNoCopy: tmp length: bufferSize fromZone: zone];
    return self;
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
{
    NSZone *z = NSZoneFromPointer(aBuffer);

    return [self initWithBytesNoCopy: aBuffer length: bufferSize fromZone: z];
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
		  fromZone: (NSZone*)aZone
{
    /*
     *	If the zone is zero, the data we have been given does not belong
     *	to use so we must create an NSDataStatic object to contain it.
     */
    if (aZone == 0) {
	NSData	*data;

	data = [[NSDataStatic alloc] initWithBytesNoCopy: aBuffer
						  length: bufferSize];
	[self release];
	return data;
    }

    zone = aZone;
    bytes = aBuffer;
    if (bytes) {
	length = bufferSize;
    }
    return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    unsigned	l;
    void*		b;

    zone = [self zone];

    [aCoder decodeValueOfObjCType: @encode(unsigned long) at: &l];
    if (l) {
	b = NSZoneMalloc(zone, l);
	if (b == 0) {
	    NSLog(@"[NSDataMalloc -initWithCoder:] unable to get %lu bytes", l);
	    [self release];
	    return nil;
        }
	[aCoder decodeArrayOfObjCType: @encode(unsigned char) count: l at: b];
    }
    else {
	b = 0;
    }
    return [self initWithBytesNoCopy: b length: l fromZone: zone];
}

- (id) initWithContentsOfFile: (NSString *)path
{
    zone = [self zone];
    if (readContentsOfFile(path, &bytes, &length, zone) == NO) {
	[self release];
	self = nil;
    }
    return self;
}

- (id) initWithContentsOfMappedFile: (NSString *)path
{
#if	HAVE_MMAP
    NSZone	*z = [self zone];

    [self release];
    self = [NSDataMappedFile allocWithZone: z];
    return [self initWithContentsOfMappedFile: path];
#else
    return [self initWithContentsOfFile: path];
#endif
}

- (id) initWithData: (NSData*)anObject
{
    if (anObject == nil) {
	return [self initWithBytesNoCopy: 0 length: 0 fromZone: [self zone]];
    }
    if ([anObject isKindOfClass: [NSData class]] == NO) {
        NSLog(@"-initWithData: passed a non-data object");
        [self release];
        return nil;
    }
    return [self initWithBytes: [anObject bytes] length: [anObject length]];
}

- (void*) relinquishAllocatedBytesFromZone: (NSZone*)aZone
{
    if (aZone == zone || aZone == 0) {
	void	*buf = bytes;

	bytes = 0;
	length = 0;
	return buf;
    }
    return 0;
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
    if (bytes) {
	munmap(bytes, length);
	bytes = 0;
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
      [self release];
      return nil;
    }
  /* Find size of file to be mapped. */
  length = lseek(fd, 0, SEEK_END);
  if (length < 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to seek to eof %s - %s", thePath, strerror(errno));
      close(fd);
      [self release];
      return nil;
    }
  /* Position at start of file. */
  if (lseek(fd, 0, SEEK_SET) != 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to seek to sof %s - %s", thePath, strerror(errno));
      close(fd);
      [self release];
      return nil;
    }
  bytes = mmap(0, length, PROT_READ, MAP_SHARED, fd, 0);
  if (bytes == MAP_FAILED)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] mapping failed for %s - %s", thePath, strerror(errno));
      close(fd);
      [self release];
      self = [dataMalloc alloc];
      self = [self initWithContentsOfFile: path];
    }
  close(fd);
  return self;
}

- (void*) relinquishAllocatedBytesFromZone: (NSZone*)aZone
{
    return 0;
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
	  [self release];
	  self = [dataMalloc alloc];
	  return [self initWithBytes: aBuffer length: bufferSize];
	}

    bytes = shmat(shmid, 0, 0);
    if (bytes == (void*)-1)
      {
	NSLog(@"[-initWithBytes:length:] shared mem attach failed for %u - %s",
		  bufferSize, strerror(errno));
	bytes = 0;
	[self release];
	self = [dataMalloc alloc];
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
      [self release];	/* Unable to access memory. */
      return nil;
    }
  if (buf.shm_segsz < bufferSize)
    {
      NSLog(@"[NSDataShared -initWithShmID:length:] shared memory segment too small");
      [self release];	/* Memory segment too small. */
      return nil;
    }
  bytes = shmat(shmid, 0, 0);
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSDataShared -initWithShmID:length:] shared memory attach failed - %s",
		strerror(errno));
      bytes = 0;
      [self release];	/* Unable to attach to memory. */
      return nil;
    }
  length = bufferSize;
  return self;
}

- (void*) relinquishAllocatedBytesFromZone: (NSZone*)aZone
{
    return 0;
}

- (int) shmID
{
  return shmid;
}

@end
#endif	/* HAVE_SHMCTL	*/


@implementation	NSMutableDataMalloc
+ (void) initialize
{
    if ([self class] == [NSMutableDataMalloc class]) {
        behavior_class_add_class(self, [NSDataMalloc class]);
    }
}

+ (NSData*) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject(mutableDataMalloc, 0, z);
}

- (Class) classForArchiver
{
    return mutableDataMalloc;
}

- (Class) classForCoder
{
    return mutableDataMalloc;
}

- (Class) classForPortCoder
{
    return mutableDataMalloc;
}

- (id) initWithBytes: (const void*)aBuffer length: (unsigned)bufferSize
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
		    length: (unsigned)bufferSize
{
  NSZone	*aZone = NSZoneFromPointer(aBuffer);
  return [self initWithBytesNoCopy: aBuffer length: bufferSize fromZone: aZone];
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
		  fromZone: (NSZone*)aZone
{
    if (aZone == 0) {
	self = [self initWithBytes: aBuffer length: bufferSize];
	return self;
    }

    if (aBuffer == 0) {
	self = [self initWithCapacity: bufferSize];
	if (self) {
	    [self setLength: bufferSize];
	}
	return self;
    }
    self = [self initWithCapacity: 0];
    if (self) {
	zone = aZone;
	bytes = aBuffer;
	length = bufferSize;
	capacity = bufferSize;
	growth = capacity/2;
	if (growth == 0) {
	    growth = 1;
	}
    }
    return self;
}

/*
 *	THIS IS THE DESIGNATED INITIALISER
 */
- (id) initWithCapacity: (unsigned)size
{
    zone = [self zone];
    if (size) {
	bytes = NSZoneMalloc(zone, size);
	if (bytes == 0) {
	    NSLog(@"[NSMutableDataMalloc -initWithCapacity:] out of memory for %u bytes - %s", size, strerror(errno));
	    [self release];
	    return nil;
	}
    }
    capacity = size;
    growth = capacity/2;
    if (growth == 0) {
	growth = 1;
    }
    length = 0;

    return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
    unsigned	l;
    void*		b;

    [aCoder decodeValueOfObjCType: @encode(unsigned long) at: &l];
    if (l) {
	[self initWithCapacity: l];
	if (bytes == 0) {
	    NSLog(@"[NSMutableDataMalloc -initWithCoder:] unable to allocate %lu bytes", l);
	    [self release];
	    return nil;
	}
	[aCoder decodeArrayOfObjCType: @encode(unsigned char)
				count: l
				   at: bytes];
	length = l;
    }
    return self;
}

- (id) initWithLength: (unsigned)size
{
    self = [self initWithCapacity: size];
    if (self) {
	memset(bytes, '\0', size);
	length = size;
    }
    return self;
}

- (id) initWithContentsOfFile: (NSString *)path
{
    self = [self initWithCapacity: 0];
    if (readContentsOfFile(path, &bytes, &length, zone) == NO) {
	[self release];
	self = nil;
    }
    else {
	capacity = length;
    }
    return self;
}

- (id) initWithContentsOfMappedFile: (NSString *)path
{
    return [self initWithContentsOfFile: path];
}

- (id) initWithData: (NSData*)anObject
{
    if (anObject == nil) {
	return [self initWithCapacity: 0];
    }
    if ([anObject isKindOfClass: [NSData class]] == NO) {
        NSLog(@"-initWithData: passed a non-data object");
	[self release];
	return nil;
    }
    return [self initWithBytes: [anObject bytes] length: [anObject length]];
}

- (void) appendBytes: (const void*)aBuffer
	      length: (unsigned)bufferSize
{
    unsigned	oldLength = length;
    unsigned	minimum = length + bufferSize;

    if (minimum > capacity) {
	[self _grow: minimum];
    }
    memcpy(bytes + oldLength, aBuffer, bufferSize);
    length = minimum;
}

- (unsigned) capacity
{
  return capacity;
}

- (void) _grow: (unsigned)minimum
{
    if (minimum > capacity) {
	unsigned	nextCapacity = capacity + growth;
	unsigned	nextGrowth = capacity ? capacity : 1;

	while (nextCapacity < minimum) {
	    unsigned	tmp = nextCapacity + nextGrowth;
	    nextGrowth = nextCapacity;
	    nextCapacity = tmp;
	}
	[self setCapacity: nextCapacity];
	growth = nextGrowth;
    }
}

- (void*) mutableBytes
{
    return bytes;
}

- (void*) relinquishAllocatedBytesFromZone: (NSZone*)aZone
{
    void	*ptr = [super relinquishAllocatedBytesFromZone: aZone];

    if (ptr != 0) {
	capacity = 0;
	growth = 1;
    }
    return ptr;
}

- (void) replaceBytesInRange: (NSRange)aRange
		   withBytes: (const void*)moreBytes
{
    if (aRange.location > length || NSMaxRange(aRange) > length) {
	[NSException raise: NSRangeException
		    format: @"Range: (%u, %u) Size: %u",
		     		aRange.location, aRange.length, length];
    }
    memcpy(bytes + aRange.location, moreBytes, aRange.length);
}

- (void) serializeDataAt: (const void*)data
	      ofObjCType: (const char*)type
		 context: (id <NSObjCTypeSerializationCallBack>)callback
{
    if (data == 0 || type == 0) {
	if (data == 0) {
            NSLog(@"attempt to serialize from a nul pointer");
	}
	if (type == 0) {
            NSLog(@"attempt to serialize with a nul type encoding");
	}
	return;
    }
    switch (*type) {
        case _C_ID:
	    [callback serializeObjectAt: (id*)data
			ofObjCType: type
			intoData: self];
	    return;

        case _C_CHARPTR: {
	    unsigned len;
	    unsigned ni;
	    unsigned minimum;

	    if (!*(void**)data) {
		[self serializeInt: -1];
		return;
	    }
	    len = strlen(*(void**)data);
	    ni = NSSwapHostIntToBig(len);
	    minimum = length + len + sizeof(unsigned);
	    if (minimum > capacity) {
		[self _grow: minimum];
	    }
	    (*appendImp)(self, appendSel, &ni, sizeof(unsigned));
	    (*appendImp)(self, appendSel, *(void**)data, len);
	    return;
	}
        case _C_ARY_B: {
	    unsigned	offset = 0;
	    unsigned	size;
	    unsigned	count = atoi(++type);
	    unsigned	i;
	    unsigned	minimum;

            while (isdigit(*type)) {
		type++;
	    }
	    size = objc_sizeof_type(type);

	    /*
	     *	Serialized objects are going to take up at least as much
	     *	space as the originals, so we can calculate a minimum space
	     *	we are going to need and make sure our buffer is big enough.
	     */
	    minimum = length + size*count;
	    if (minimum > capacity) {
		[self _grow: minimum];
	    }

	    for (i = 0; i < count; i++) {
		[self serializeDataAt: (char*)data + offset
			   ofObjCType: type
			      context: callback];
		offset += size;
	    }
	    return;
        }
        case _C_STRUCT_B: {
            int offset = 0;

            while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
            for (;;) {
                [self serializeDataAt: ((char*)data) + offset
			   ofObjCType: type
			      context: callback];
                offset += objc_sizeof_type(type);
                type = objc_skip_typespec(type);
                if (*type != _C_STRUCT_E) {
                    unsigned	align = objc_alignof_type(type);
		    unsigned	rem = offset % align;

                    if (rem != 0) {
                        offset += align - rem;
		    }
                }
                else break;
            }
            return;
        }
	case _C_PTR:
	    [self serializeDataAt: *(char**)data
		       ofObjCType: ++type
			  context: callback];
	    return;
        case _C_CHR:
	case _C_UCHR:
	    (*appendImp)(self, appendSel, data, sizeof(unsigned char));
	    break;
	case _C_SHT:
	case _C_USHT: {
	    unsigned short ns = NSSwapHostShortToBig(*(unsigned short*)data);
	    (*appendImp)(self, appendSel, &ns, sizeof(unsigned short));
	    break;
	}
	case _C_INT:
	case _C_UINT: {
	    unsigned ni = NSSwapHostIntToBig(*(unsigned int*)data);
	    (*appendImp)(self, appendSel, &ni, sizeof(unsigned));
	    break;
	}
	case _C_LNG:
	case _C_ULNG: {
	    unsigned long nl = NSSwapHostLongToBig(*(unsigned long*)data);
	    (*appendImp)(self, appendSel, &nl, sizeof(unsigned long));
	    break;
	}
#ifdef	_C_LNG_LNG
	case _C_LNG_LNG:
	case _C_ULNG_LNG: {
	    unsigned long long nl;

	    nl = NSSwapHostLongLongToBig(*(unsigned long long*)data);
	    (*appendImp)(self, appendSel, &nl, sizeof(unsigned long long));
	    break;
	}
#endif
	case _C_FLT: {
	    NSSwappedFloat nf = NSSwapHostFloatToBig(*(float*)data);
	    (*appendImp)(self, appendSel, &nf, sizeof(NSSwappedFloat));
	    break;
	}
	case _C_DBL: {
	    NSSwappedDouble nd = NSSwapHostDoubleToBig(*(double*)data);
	    (*appendImp)(self, appendSel, &nd, sizeof(NSSwappedDouble));
	    break;
	}
	default:
	    [NSException raise: NSGenericException
                format: @"Unknown type to deserialize - '%s'", type];
    }
}

- (id) setCapacity: (unsigned)size
{
    if (size != capacity) {
	void*	tmp;

	if (bytes) {
	    tmp = NSZoneRealloc(zone, bytes, size);
	}
	else {
	    tmp = NSZoneMalloc(zone, size);
	}
	if (tmp == 0) {
	    [NSException raise: NSMallocException
			format: @"Unable to set data capacity to '%d'", size];
	}
	bytes = tmp;
	capacity = size;
	growth = capacity/2;
	if (growth == 0) {
	    growth = 1;
	}
    }
    if (size < length) {
	length = size;
    }
    return self;
}

- (void) setLength: (unsigned)size
{
    if (size > capacity) {
	[self setCapacity: size];
    }
    if (size > length) {
	memset(bytes + length, '\0', size - length);
    }
    length = size;
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
      [self release];
      self = [mutableDataMalloc alloc];
      return [self initWithCapacity: bufferSize];
    }

  bytes = shmat(shmid, 0, 0);
  e = errno;
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSMutableDataShared -initWithCapacity:] shared memory attach failed for %u - %s", bufferSize, strerror(e));
      bytes = 0;
      [self release];
      self = [mutableDataMalloc alloc];
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
      [self release];	/* Unable to access memory. */
      return nil;
    }
  if (buf.shm_segsz < bufferSize)
    {
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory segment too small");
      [self release];	/* Memory segment too small. */
      return nil;
    }
  bytes = shmat(shmid, 0, 0);
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory attach failed - %s", strerror(errno));
      bytes = 0;
      [self release];	/* Unable to attach to memory. */
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
	[NSException raise: NSMallocException
		    format: @"Unable to create shared memory segment - %s.",
		    strerror(errno)];
      tmp = shmat(newid, 0, 0);
      if ((int)tmp == -1)			/* Attached memory? */
	[NSException raise: NSMallocException
		    format: @"Unable to attach to shared memory segment."];
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

- (void*) relinquishAllocatedBytesFromZone: (NSZone*)aZone
{
    return 0;
}

- (int) shmID
{
  return shmid;
}

@end
#endif	/* HAVE_SHMCTL	*/

