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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
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
#include <base/preface.h>
#include <base/fast.x>
#include <base/behavior.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSRange.h>
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
  int		c;

  if ([path getFileSystemRepresentation: thePath
			      maxLength: sizeof(thePath)-1] == NO)
    {
      NSDebugLog(@"Open (%s) attempt failed - bad path", thePath);
      return NO;
    }
#if	defined(__WIN32__)
  theFile = fopen(thePath, "rb");
#else
  theFile = fopen(thePath, "r");
#endif

  if (theFile == NULL)		/* We failed to open the file. */
    {
      NSDebugLog(@"Open (%s) attempt failed - %s", thePath, strerror(errno));
      goto failure;
    }

  /*
   *	Seek to the end of the file.
   */
  c = fseek(theFile, 0L, SEEK_END);
  if (c != 0)
    {
      NSLog(@"Seek to end of file failed - %s", strerror(errno));
      goto failure;
    }

  /*
   *	Determine the length of the file (having seeked to the end of the
   *	file) by calling ftell().
   */
  fileLength = ftell(theFile);
  if (fileLength == -1)
    {
      NSLog(@"Ftell failed - %s", strerror(errno));
      goto failure;
    }

#if	GS_WITH_GC == 1
  tmp = NSZoneMalloc(GSAtomicMallocZone(), fileLength);
#else
  tmp = NSZoneMalloc(zone, fileLength);
#endif
  if (tmp == 0)
    {
      NSLog(@"Malloc failed for file of length %d- %s",
		fileLength, strerror(errno));
      goto failure;
    }

  /*
   *	Rewind the file pointer to the beginning, preparing to read in
   *	the file.
   */
  c = fseek(theFile, 0L, SEEK_SET);
  if (c != 0)
    {
      NSLog(@"Fseek to start of file failed - %s", strerror(errno));
      goto failure;
    }

  c = fread(tmp, 1, fileLength, theFile);
  if (c != fileLength)
    {
      NSLog(@"read of file contents failed - %s", strerror(errno));
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
  if (self == [NSData class])
    {
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
  NSData	*d;

  d = [NSDataStatic allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytesNoCopy: 0 length: 0];
  return AUTORELEASE(d);
}

+ (id) dataWithBytes: (const void*)bytes
	      length: (unsigned)length
{
  NSData	*d;

  d = [dataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: bytes length: length];
  return AUTORELEASE(d);
}

+ (id) dataWithBytesNoCopy: (void*)bytes
		    length: (unsigned)length
{
  NSData	*d;

  d = [dataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytesNoCopy: bytes length: length];
  return AUTORELEASE(d);
}

+ (id) dataWithContentsOfFile: (NSString*)path
{
  NSData	*d;

  d = [dataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithContentsOfFile: path];
  return AUTORELEASE(d);
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
  NSData	*d;

#if	HAVE_MMAP
  d = [NSDataMappedFile allocWithZone: NSDefaultMallocZone()];
  d = [d initWithContentsOfMappedFile: path];
#else
  d = [dataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithContentsOfMappedFile: path];
#endif
  return AUTORELEASE(d);
}

+ (id) dataWithData: (NSData*)data
{
  NSData	*d;

  d = [dataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: [data bytes] length: [data length]];
  return AUTORELEASE(d);
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
#if	GS_WITH_GC
  dest = (char*) NSZoneMalloc(GSAtomicMallocZone(), 2*length+length/4+3);
#else
  dest = (char*) NSZoneMalloc(z, 2*length+length/4+3);
#endif
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
#if	GS_WITH_GC
  str = [[NSString allocWithZone: z]
    initWithCStringNoCopy: dest length: j fromZone: GSAtomicMallocZone()];
#else
  str = [[NSString allocWithZone: z] initWithCStringNoCopy: dest
						    length: j
						  fromZone: z];
#endif
  return AUTORELEASE(str);
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
  unsigned	size = [self length];

  GS_RANGE_CHECK(aRange, size);
  memcpy(buffer, [self bytes] + aRange.location, aRange.length);
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}

- (NSData*) subdataWithRange: (NSRange)aRange
{
  void		*buffer;
  unsigned	l = [self length];

  GS_RANGE_CHECK(aRange, l);

#if	GS_WITH_GC
  buffer = NSZoneMalloc(GSAtomicMallocZone(), aRange.length);
#else
  buffer = NSZoneMalloc([self zone], aRange.length);
#endif
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
      NSDebugLog(@"Open (%s) attempt failed - bad path", theRealPath);
      return NO;
    }

#ifdef	HAVE_MKSTEMP
  if (useAuxiliaryFile)
    {
      int	desc;

      strcpy(thePath, theRealPath);
      strcat(thePath, "XXXXXX");
      if ((desc = mkstemp(thePath)) < 0)
	{
          NSLog(@"mkstemp (%s) failed - %s", thePath, strerror(errno));
          goto failure;
	}
      if ((theFile = fdopen(desc, "w")) == 0)
	{
	  close(desc);
	}
    }
  else
    {
      strcpy(thePath, theRealPath);
#if	defined(__WIN32__)
      theFile = fopen(thePath, "wb");
#else
      theFile = fopen(thePath, "w");
#endif
    }
#else
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
#if	defined(__WIN32__)
  theFile = fopen(thePath, "wb");
#else
  theFile = fopen(thePath, "w");
#endif
#endif

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
   * real file.  Also, we need to try to retain the file attributes of
   * the original file we are overwriting (if we are) */
  if (useAuxiliaryFile)
    {
      NSFileManager		*mgr = [NSFileManager defaultManager];
      NSMutableDictionary	*att = nil;

      if ([mgr fileExistsAtPath: path])
	{
	  att = [[mgr fileAttributesAtPath: path
			      traverseLink: YES] mutableCopy];
	  IF_NO_GC(TEST_AUTORELEASE(att));
	}

      c = rename(thePath, theRealPath);
      if (c != 0)               /* Many things could go wrong, I guess. */
        {
          NSLog(@"Rename ('%s' to '%s') failed - %s",
	    thePath, theRealPath, strerror(errno));
          goto failure;
        }

      if (att)
	{
	  /*
	   * We have created a new file - so we attempt to make it's
	   * attributes match that of the original.
	   */
	  [att removeObjectForKey: NSFileSize];
	  [att removeObjectForKey: NSFileModificationDate];
	  [att removeObjectForKey: NSFileReferenceCount];
	  [att removeObjectForKey: NSFileSystemNumber];
	  [att removeObjectForKey: NSFileSystemFileNumber];
	  [att removeObjectForKey: NSFileDeviceIdentifier];
	  [att removeObjectForKey: NSFileType];
	  if ([mgr changeFileAttributes: att atPath: path] == NO)
	    NSLog(@"Unable to correctly set all attributes for '%@'", path);
	}
      else if (geteuid() == 0 && [@"root" isEqualToString: NSUserName()] == NO)
	{
	  att = [NSDictionary dictionaryWithObjectsAndKeys:
			NSFileOwnerAccountName, NSUserName(), nil];
	  if ([mgr changeFileAttributes: att atPath: path] == NO)
	    NSLog(@"Unable to correctly set ownership for '%@'", path);
	}
    }

  /* success: */
  return YES;

  /* Just in case the failure action needs to be changed. */
 failure:
  /*
   * Attempt to tidy up by removing temporary file on failure.
   */
  if (useAuxiliaryFile)
    {
      unlink(thePath);
    }
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

- (void) deserializeDataAt: (void*)data
	        ofObjCType: (const char*)type
		  atCursor: (unsigned*)cursor
		   context: (id <NSObjCTypeSerializationCallBack>)callback
{
  if (!type || !data)
    return;

  switch (*type)
    {
      case _C_ID:
	{
	  [callback deserializeObjectAt: data
			     ofObjCType: type
			       fromData: self
			       atCursor: cursor];
	  return;
	}
      case _C_CHARPTR:
	{
	  gss32 length;

	  [self deserializeBytes: &length
			  length: sizeof(length)
			atCursor: cursor];
	  length = GSSwapBigI32ToHost(length);
	  if (length == -1)
	    {
	      *(const char**)data = NULL;
	      return;
	    }
	  else
	    {
	      unsigned	len = (length+1)*sizeof(char);
	      NSZone	*z = [self zone];
	      NSData	*d;

	      *(char**)data = (char*)NSZoneMalloc(z, len);
	      d = [dataMalloc allocWithZone: z];
	      d = [d initWithBytesNoCopy: *(void**)data
				  length: len
			        fromZone: z];
	      IF_NO_GC(AUTORELEASE(d));
	    }

	  [self deserializeBytes: *(char**)data
			  length: length
			atCursor: cursor];
	  (*(char**)data)[length] = '\0';
	  return;
	}
      case _C_ARY_B:
	{
	  unsigned	offset = 0;
	  unsigned	size;
	  unsigned	count = atoi(++type);
	  unsigned	i;

	  while (isdigit(*type))
	    {
	      type++;
	    }
	  size = objc_sizeof_type(type);

	  for (i = 0; i < count; i++)
	    {
	      [self deserializeDataAt: (char*)data + offset
			   ofObjCType: type
			     atCursor: cursor
			      context: callback];
	      offset += size;
	    }
	  return;
	}
      case _C_STRUCT_B:
	{
	  int offset = 0;

	  while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	  for (;;)
	    {
	      [self deserializeDataAt: ((char*)data) + offset
			   ofObjCType: type
			     atCursor: cursor
			      context: callback];
	      offset += objc_sizeof_type(type);
	      type = objc_skip_typespec(type);
	      if (*type != _C_STRUCT_E)
		{
		  int	align = objc_alignof_type(type);
		  int	rem = offset % align;

		  if (rem != 0)
		    {
		      offset += align - rem;
		    }
		}
	      else break;
	    }
	  return;
        }
      case _C_PTR:
	{
	  unsigned	len = objc_sizeof_type(++type);
	  NSZone	*z = [self zone];
	  NSData	*d;

	  *(char**)data = (char*)NSZoneMalloc(z, len);
	  d = [dataMalloc allocWithZone: z];
	  d = [d initWithBytesNoCopy: *(void**)data
			      length: len
			    fromZone: z];
	  IF_NO_GC(AUTORELEASE(d));
	  [self deserializeDataAt: *(char**)data
		       ofObjCType: type
			 atCursor: cursor
			  context: callback];
	  return;
        }
      case _C_CHR:
      case _C_UCHR:
	{
	  [self deserializeBytes: data
			  length: sizeof(unsigned char)
			atCursor: cursor];
	  return;
	}
      case _C_SHT:
      case _C_USHT:
	{
	  unsigned short ns;

	  [self deserializeBytes: &ns
			  length: sizeof(unsigned short)
			atCursor: cursor];
	  *(unsigned short*)data = NSSwapBigShortToHost(ns);
	  return;
	}
      case _C_INT:
      case _C_UINT:
	{
	  unsigned ni;

	  [self deserializeBytes: &ni
			  length: sizeof(unsigned)
			atCursor: cursor];
	  *(unsigned*)data = NSSwapBigIntToHost(ni);
	  return;
	}
      case _C_LNG:
      case _C_ULNG:
	{
	  unsigned long nl;

	  [self deserializeBytes: &nl
			  length: sizeof(unsigned long)
			atCursor: cursor];
	  *(unsigned long*)data = NSSwapBigLongToHost(nl);
	  return;
	}
      case _C_LNG_LNG:
      case _C_ULNG_LNG:
	{
	  unsigned long long nl;

	  [self deserializeBytes: &nl
			  length: sizeof(unsigned long long)
			atCursor: cursor];
	  *(unsigned long long*)data = NSSwapBigLongLongToHost(nl);
	  return;
	}
      case _C_FLT:
	{
	  NSSwappedFloat nf;

	  [self deserializeBytes: &nf
			  length: sizeof(NSSwappedFloat)
			atCursor: cursor];
	  *(float*)data = NSSwapBigFloatToHost(nf);
	  return;
	}
      case _C_DBL:
	{
	  NSSwappedDouble nd;

	  [self deserializeBytes: &nd
			  length: sizeof(NSSwappedDouble)
			atCursor: cursor];
	  *(double*)data = NSSwapBigDoubleToHost(nd);
	  return;
	}
      case _C_CLASS:
	{
	  gsu16 ni;

	  [self deserializeBytes: &ni
			  length: sizeof(ni)
			atCursor: cursor];
	  ni = GSSwapBigI16ToHost(ni);
	  if (ni == 0)
	    {
	      *(Class*)data = 0;
	    }
	  else
	    {
	      char	name[ni+1];
	      Class	c;

	      [self deserializeBytes: name
			      length: ni
			    atCursor: cursor];
	      name[ni] = '\0';
	      c = objc_get_class(name);
	      if (c == 0)
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"can't find class - %s", name];
		}
	      *(Class*)data = c;
	    }
	  return;
	}
      case _C_SEL:
	{
	  gsu16	ln;
	  gsu16	lt;

	  [self deserializeBytes: &ln
			  length: sizeof(ln)
			atCursor: cursor];
	  ln = GSSwapBigI16ToHost(ln);
	  [self deserializeBytes: &lt
			  length: sizeof(lt)
			atCursor: cursor];
	  lt = GSSwapBigI16ToHost(lt);
	  if (ln == 0)
	    {
	      *(SEL*)data = 0;
	    }
	  else
	    {
	      char	name[ln+1];
	      char	types[lt+1];
	      SEL	sel;

	      [self deserializeBytes: name
			      length: ln
			    atCursor: cursor];
	      name[ln] = '\0';
	      [self deserializeBytes: types
			      length: lt
			    atCursor: cursor];
	      types[lt] = '\0';

	      if (lt)
		{
		  sel = sel_get_typed_uid(name, types);
		}
	      else
		{
		  sel = sel_get_any_typed_uid(name);
		}
	      if (sel == 0)
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"can't find sel with name '%s' "
				      @"and types '%s'", name, types];
		}
	      *(SEL*)data = sel;
	    }
	  return;
	}
      default:
	[NSException raise: NSGenericException
		    format: @"Unknown type to deserialize - '%s'", type];
    }
}

- (int) deserializeIntAtCursor: (unsigned*)cursor
{
  unsigned ni, result;

  [self deserializeBytes: &ni length: sizeof(unsigned) atCursor: cursor];
  result = NSSwapBigIntToHost(ni);
  return result;
}

- (int) deserializeIntAtIndex: (unsigned)index
{
  unsigned ni, result;

  [self deserializeBytes: &ni length: sizeof(unsigned) atCursor: &index];
  result = NSSwapBigIntToHost(ni);
  return result;
}

- (void) deserializeInts: (int*)intBuffer
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

- (void) deserializeInts: (int*)intBuffer
		   count: (unsigned)numInts
		 atIndex: (unsigned)index
{
  unsigned i;

  [self deserializeBytes: &intBuffer
		  length: numInts * sizeof(int)
		atCursor: &index];
  for (i = 0; i < numInts; i++)
    {
      intBuffer[i] = NSSwapBigIntToHost(intBuffer[i]);
    }
}

- (id) copyWithZone: (NSZone*)z
{
  if (NSShouldRetainWithZone(self, z) &&
	[self isKindOfClass: [NSMutableData class]] == NO)
    return RETAIN(self);
  else
    return [[dataMalloc allocWithZone: z]
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
  NSDataShared	*d;

  d = [NSDataShared allocWithZone: NSDefaultMallocZone()];
  d = [d initWithShmID: anID length: length];
  return AUTORELEASE(d);
#else
  NSLog(@"[NSData -dataWithSmdID:length:] no shared memory support");
  return nil;
#endif
}

+ (id) dataWithSharedBytes: (const void*)bytes length: (unsigned)length
{
  NSData	*d;

#if	HAVE_SHMCTL
  d = [NSDataShared allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: bytes length: length];
#else
  d = [dataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: bytes length: length];
#endif
  return AUTORELEASE(d);
}

+ (id) dataWithStaticBytes: (const void*)bytes length: (unsigned)length
{
  NSDataStatic	*d;

  d = [NSDataStatic allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytesNoCopy: (void*)bytes length: length];
  return AUTORELEASE(d);
}

- (id) initWithBytesNoCopy: (void*)bytes
		    length: (unsigned)length
		  fromZone: (NSZone*)zone
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) deserializeTypeTag: (unsigned char*)tag
		andCrossRef: (unsigned int*)ref
		   atCursor: (unsigned*)cursor
{
  [self deserializeDataAt: (void*)tag
	       ofObjCType: @encode(gsu8) 
		 atCursor: cursor
		  context: nil];
  if (*tag & _GSC_MAYX)
    {
      switch (*tag & _GSC_SIZE)
	{
	  case _GSC_X_0:
	    {
	      return;
	    }
	  case _GSC_X_1:
	    {
	      gsu8	x;

	      [self deserializeDataAt: (void*)&x
			   ofObjCType: @encode(gsu8) 
			     atCursor: cursor
			      context: nil];
	      *ref = (unsigned int)x;
	      return;
	    }
	  case _GSC_X_2:
	    {
	      gsu16	x;

	      [self deserializeDataAt: (void*)&x
			   ofObjCType: @encode(gsu16) 
			     atCursor: cursor
			      context: nil];
	      *ref = (unsigned int)x;
	      return;
	    }
	  default:
	    {
	      gsu32	x;

	      [self deserializeDataAt: (void*)&x
			   ofObjCType: @encode(gsu32) 
			     atCursor: cursor
			      context: nil];
	      *ref = (unsigned int)x;
	      return;
	    }
	}
    }
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
  NSMutableData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithCapacity: 0];
  return AUTORELEASE(d);
}

+ (id) dataWithBytes: (const void*)bytes
	      length: (unsigned)length
{
  NSData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: bytes length: length];
  return AUTORELEASE(d);
}

+ (id) dataWithBytesNoCopy: (void*)bytes
		    length: (unsigned)length
{
  NSData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytesNoCopy: bytes length: length];
  return AUTORELEASE(d);
}

+ (id) dataWithCapacity: (unsigned)numBytes
{
  NSMutableData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithCapacity: numBytes];
  return AUTORELEASE(d);
}

+ (id) dataWithContentsOfFile: (NSString*)path
{
  NSData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithContentsOfFile: path];
  return AUTORELEASE(d);
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
  NSData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithContentsOfMappedFile: path];
  return AUTORELEASE(d);
}

+ (id) dataWithData: (NSData*)data
{
  NSData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: [data bytes] length: [data length]];
  return AUTORELEASE(d);
}

+ (id) dataWithLength: (unsigned)length
{
  NSMutableData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithLength: length];
  return AUTORELEASE(d);
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
  unsigned	size = [self length];

  GS_RANGE_CHECK(aRange, size);
  memcpy([self mutableBytes] + aRange.location, bytes, aRange.length);
}

- (void) resetBytesInRange: (NSRange)aRange
{
  unsigned	size = [self length];

  GS_RANGE_CHECK(aRange, size);
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

  switch (*type)
    {
      case _C_ID:
	[callback serializeObjectAt: (id*)data
			 ofObjCType: type
			   intoData: self];
	return;

      case _C_CHARPTR:
	{
	  gsu32	len;
	  gsu32	ni;

	  if (!*(void**)data)
	    {
	      ni = (gsu32)-1;
	      ni = GSSwapHostI32ToBig(ni);
	      [self appendBytes: (void*)&ni length: sizeof(ni)];
	      return;
	    }
	  len = (gsu32)strlen(*(void**)data);
	  ni = GSSwapHostI32ToBig(len);
	  [self appendBytes: (void*)&ni length: sizeof(ni)];
	  [self appendBytes: *(void**)data length: len];
	  return;
	}
      case _C_ARY_B:
	{
	  unsigned	offset = 0;
	  unsigned	size;
	  unsigned	count = atoi(++type);
	  unsigned	i;

	  while (isdigit(*type))
	    {
	      type++;
	    }
	  size = objc_sizeof_type(type);

	  for (i = 0; i < count; i++)
	    {
	      [self serializeDataAt: (char*)data + offset
			 ofObjCType: type
			    context: callback];
	      offset += size;
	    }
	  return;
        }
      case _C_STRUCT_B:
	{
	  int offset = 0;
	  int align, rem;

	  while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	  for (;;)
	    {
	      [self serializeDataAt: ((char*)data) + offset
			 ofObjCType: type
			    context: callback];
	      offset += objc_sizeof_type(type);
	      type = objc_skip_typespec(type);
	      if (*type != _C_STRUCT_E)
		{
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
	return;
      case _C_SHT:
      case _C_USHT:
	{
	  unsigned short ns = NSSwapHostShortToBig(*(unsigned short*)data);
	  [self appendBytes: &ns length: sizeof(unsigned short)];
	  return;
	}
      case _C_INT:
      case _C_UINT:
	{
	  unsigned ni = NSSwapHostIntToBig(*(unsigned int*)data);
	  [self appendBytes: &ni length: sizeof(unsigned)];
	  return;
	}
      case _C_LNG:
      case _C_ULNG:
	{
	  unsigned long nl = NSSwapHostLongToBig(*(unsigned long*)data);
	  [self appendBytes: &nl length: sizeof(unsigned long)];
	  return;
	}
      case _C_LNG_LNG:
      case _C_ULNG_LNG:
	{
	  unsigned long long nl;

	  nl = NSSwapHostLongLongToBig(*(unsigned long long*)data);
	  [self appendBytes: &nl length: sizeof(unsigned long long)];
	  return;
	}
      case _C_FLT:
	{
	  NSSwappedFloat nf = NSSwapHostFloatToBig(*(float*)data);

	  [self appendBytes: &nf length: sizeof(NSSwappedFloat)];
	  return;
	}
      case _C_DBL:
	{
	  NSSwappedDouble nd = NSSwapHostDoubleToBig(*(double*)data);

	  [self appendBytes: &nd length: sizeof(NSSwappedDouble)];
	  return;
	}
      case _C_CLASS:
	{
	  const char  *name = *(Class*)data?fastClassName(*(Class*)data):"";
	  gsu16	ln = (gsu16)strlen(name);
	  gsu16	ni;

	  ni = GSSwapHostI16ToBig(ln);
	  [self appendBytes: &ni length: sizeof(ni)];
	  if (ln)
	    {
	      [self appendBytes: name length: ln];
	    }
	  return;
	}
      case _C_SEL:
	{
	  const char  *name = *(SEL*)data?fastSelectorName(*(SEL*)data):"";
	  gsu16	ln = (name == 0) ? 0 : (gsu16)strlen(name);
	  const char  *types = *(SEL*)data?fastSelectorTypes(*(SEL*)data):"";
	  gsu16	lt = (types == 0) ? 0 : (gsu16)strlen(types);
	  gsu16	ni;

	  ni = GSSwapHostI16ToBig(ln);
	  [self appendBytes: &ni length: sizeof(ni)];
	  ni = GSSwapHostI16ToBig(lt);
	  [self appendBytes: &ni length: sizeof(ni)];
	  if (ln)
	    {
	      [self appendBytes: name length: ln];
	    }
	  if (lt)
	    {
	      [self appendBytes: types length: lt];
	    }
	  return;
	}
      default:
	[NSException raise: NSGenericException
		    format: @"Unknown type to serialize - '%s'", type];
    }
}

- (void) serializeInt: (int)value
{
  unsigned ni = NSSwapHostIntToBig(value);
  [self appendBytes: &ni length: sizeof(unsigned)];
}

- (void) serializeInt: (int)value atIndex: (unsigned)index
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

  for (i = 0; i < numInts; i++)
    {
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

  for (i = 0; i < numInts; i++)
    {
      (*imp)(self, sel, intBuffer[i], index++);
    }
}

@end

@implementation	NSMutableData (GNUstepExtensions)
+ (id) dataWithShmID: (int)anID length: (unsigned)length
{
#if	HAVE_SHMCTL
  NSDataShared	*d;

  d = [NSMutableDataShared allocWithZone: NSDefaultMallocZone()];
  d = [d initWithShmID: anID length: length];
  return AUTORELEASE(d);
#else
  NSLog(@"[NSMutableData -dataWithSmdID:length:] no shared memory support");
  return nil;
#endif
}

+ (id) dataWithSharedBytes: (const void*)bytes length: (unsigned)length
{
  NSData	*d;

#if	HAVE_SHMCTL
  d = [NSMutableDataShared allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: bytes length: length];
#else
  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: bytes length: length];
#endif
  return AUTORELEASE(d);
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

- (void) serializeTypeTag: (unsigned char)tag
{
  [self serializeDataAt: (void*)&tag
	     ofObjCType: @encode(unsigned char)
		context: nil];
}

- (void) serializeTypeTag: (unsigned char)tag
	      andCrossRef: (unsigned)xref
{
  if (xref <= 0xff)
    {
      gsu8	x = (gsu8)xref;

      tag = (tag & ~_GSC_SIZE) | _GSC_X_1;
      [self serializeDataAt: (void*)&tag
		 ofObjCType: @encode(unsigned char)
		    context: nil];
      [self serializeDataAt: (void*)&x
		 ofObjCType: @encode(gsu8)
		    context: nil];
    }
  else if (xref <= 0xffff)
    {
      gsu16	x = (gsu16)xref;

      tag = (tag & ~_GSC_SIZE) | _GSC_X_2;
      [self serializeDataAt: (void*)&tag
		 ofObjCType: @encode(unsigned char)
		    context: nil];
      [self serializeDataAt: (void*)&x
		 ofObjCType: @encode(gsu16)
		    context: nil];
    }
  else
    {
      gsu32	x = (gsu32)xref;

      tag = (tag & ~_GSC_SIZE) | _GSC_X_4;
      [self serializeDataAt: (void*)&tag
		 ofObjCType: @encode(unsigned char)
		    context: nil];
      [self serializeDataAt: (void*)&x
		 ofObjCType: @encode(gsu32)
		    context: nil];
    }
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

- (id) copy
{
  return RETAIN(self);
}

- (id) copyWithZone: (NSZone*)z
{
  return RETAIN(self);
}

- (id) mutableCopy
{
  return [[mutableDataMalloc allocWithZone: NSDefaultMallocZone()]
	initWithBytes: bytes length: length];
}

- (id) mutableCopyWithZone: (NSZone*)z
{
  return [[mutableDataMalloc allocWithZone: z]
	initWithBytes: bytes length: length];
}

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
  if (length)
    {
      [aCoder encodeArrayOfObjCType: @encode(unsigned char)
			      count: length
				 at: bytes];
    }
}

/* Basic methods	*/

- (const void*) bytes
{
  return bytes;
}

- (void) getBytes: (void*)buffer
	    range: (NSRange)aRange
{
  GS_RANGE_CHECK(aRange, length);
  memcpy(buffer, bytes + aRange.location, aRange.length);
}

- (unsigned) length
{
  return length;
}

static inline void
getBytes(void* dst, void* src, unsigned len, unsigned limit, unsigned *pos)
{
  if (*pos > limit || len > limit || len+*pos > limit)
    {
      [NSException raise: NSRangeException
		  format: @"Range: (%u, %u) Size: %d",
			*pos, len, limit];
    }
  memcpy(dst, src + *pos, len);
  *pos += len;
}

- (void) deserializeDataAt: (void*)data
	        ofObjCType: (const char*)type
		  atCursor: (unsigned*)cursor
		   context: (id <NSObjCTypeSerializationCallBack>)callback
{
  if (data == 0 || type == 0)
    {
      if (data == 0)
	{
	  NSLog(@"attempt to deserialize to a nul pointer");
	}
      if (type == 0)
	{
            NSLog(@"attempt to deserialize with a nul type encoding");
	}
      return;
    }

  switch (*type)
    {
      case _C_ID:
	{
	  [callback deserializeObjectAt: data
			     ofObjCType: type
			       fromData: self
			       atCursor: cursor];
	  return;
	}
      case _C_CHARPTR:
	{
	  gss32 len;

	  [self deserializeBytes: &len
			  length: sizeof(len)
			atCursor: cursor];
	  len = GSSwapBigI32ToHost(len);
	  if (len == -1)
	    {
	      *(const char**)data = NULL;
	      return;
	    }
	  else
	    {
	      NSZone	*z = [self zone];

	      *(char**)data = (char*)NSZoneMalloc(z, len+1);
#if !GS_WITH_GC
	      [[[dataMalloc allocWithZone: z]
			   initWithBytesNoCopy: *(void**)data
					length: len+1
				      fromZone: z] autorelease];
#endif
	    }
	  getBytes(*(void**)data, bytes, len, length, cursor);
	  (*(char**)data)[len] = '\0';
	  return;
	}
      case _C_ARY_B:
	{
	  unsigned	offset = 0;
	  unsigned	size;
	  unsigned	count = atoi(++type);
	  unsigned	i;

	  while (isdigit(*type))
	    {
	      type++;
	    }
	  size = objc_sizeof_type(type);

	  for (i = 0; i < count; i++)
	    {
	      [self deserializeDataAt: (char*)data + offset
			   ofObjCType: type
			     atCursor: cursor
			      context: callback];
	      offset += size;
	    }
	  return;
	}
      case _C_STRUCT_B:
	{
	  int	offset = 0;

	  while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	  for (;;)
	    {
	      [self deserializeDataAt: ((char*)data) + offset
			   ofObjCType: type
			     atCursor: cursor
			      context: callback];
	      offset += objc_sizeof_type(type);
	      type = objc_skip_typespec(type);
	      if (*type != _C_STRUCT_E)
		{
		  int	align = objc_alignof_type(type);
		  int	rem = offset % align;

		  if (rem != 0)
		    {
		      offset += align - rem;
		    }
		}
	      else break;
	    }
	  return;
        }
      case _C_PTR:
	{
	  unsigned	len = objc_sizeof_type(++type);
	  NSZone	*z = [self zone];

	  *(char**)data = (char*)NSZoneMalloc(z, len);
#if !GS_WITH_GC
	  [[[dataMalloc allocWithZone: z]
			 initWithBytesNoCopy: *(void**)data
				      length: len
				    fromZone: z] autorelease];
#endif
	  [self deserializeDataAt: *(char**)data
		       ofObjCType: type
			 atCursor: cursor
			  context: callback];
	  return;
        }
      case _C_CHR:
      case _C_UCHR:
	{
	  getBytes(data, bytes, sizeof(unsigned char), length, cursor);
	  return;
	}
      case _C_SHT:
      case _C_USHT:
	{
	  unsigned short ns;

	  getBytes((void*)&ns, bytes, sizeof(ns), length, cursor);
	  *(unsigned short*)data = NSSwapBigShortToHost(ns);
	  return;
	}
      case _C_INT:
      case _C_UINT:
	{
	  unsigned ni;

	  getBytes((void*)&ni, bytes, sizeof(ni), length, cursor);
	  *(unsigned*)data = NSSwapBigIntToHost(ni);
	  return;
	}
      case _C_LNG:
      case _C_ULNG:
	{
	  unsigned long nl;

	  getBytes((void*)&nl, bytes, sizeof(nl), length, cursor);
	  *(unsigned long*)data = NSSwapBigLongToHost(nl);
	  return;
	}
      case _C_LNG_LNG:
      case _C_ULNG_LNG:
	{
	  unsigned long long nl;

	  getBytes((void*)&nl, bytes, sizeof(nl), length, cursor);
	  *(unsigned long long*)data = NSSwapBigLongLongToHost(nl);
	  return;
	}
      case _C_FLT:
	{
	  NSSwappedFloat nf;

	  getBytes((void*)&nf, bytes, sizeof(nf), length, cursor);
	  *(float*)data = NSSwapBigFloatToHost(nf);
	  return;
	}
      case _C_DBL:
	{
	  NSSwappedDouble nd;

	  getBytes((void*)&nd, bytes, sizeof(nd), length, cursor);
	  *(double*)data = NSSwapBigDoubleToHost(nd);
	  return;
	}
      case _C_CLASS:
	{
	  gsu16	ni;

	  getBytes((void*)&ni, bytes, sizeof(ni), length, cursor);
	  ni = GSSwapBigI16ToHost(ni);
	  if (ni == 0)
	    {
	      *(Class*)data = 0;
	    }
	  else
	    {
	      char	name[ni+1];
	      Class	c;

	      getBytes((void*)name, bytes, ni, length, cursor);
	      name[ni] = '\0';
	      c = objc_get_class(name);
	      if (c == 0)
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"can't find class - %s", name];
		}
	      *(Class*)data = c;
	    }
	  return;
	}
      case _C_SEL:
	{
	  gsu16	ln;
	  gsu16	lt;

	  getBytes((void*)&ln, bytes, sizeof(ln), length, cursor);
	  ln = GSSwapBigI16ToHost(ln);
	  getBytes((void*)&lt, bytes, sizeof(lt), length, cursor);
	  lt = GSSwapBigI16ToHost(lt);
	  if (ln == 0)
	    {
	      *(SEL*)data = 0;
	    }
	  else
	    {
	      char	name[ln+1];
	      char	types[lt+1];
	      SEL	sel;

	      getBytes((void*)name, bytes, ln, length, cursor);
	      name[ln] = '\0';
	      getBytes((void*)types, bytes, lt, length, cursor);
	      types[lt] = '\0';

	      if (lt)
		{
		  sel = sel_get_typed_uid(name, types);
		}
	      else
		{
		  sel = sel_get_any_typed_uid(name);
		}
	      if (sel == 0)
		{
		  [NSException raise: NSInternalInconsistencyException
			      format: @"can't find sel with name '%s' "
					  @"and types '%s'", name, types];
		}
	      *(SEL*)data = sel;
	    }
	  return;
	}
      default:
	[NSException raise: NSGenericException
		    format: @"Unknown type to deserialize - '%s'", type];
    }
}

- (void) deserializeTypeTag: (unsigned char*)tag
		andCrossRef: (unsigned int*)ref
		   atCursor: (unsigned*)cursor
{
  if (*cursor >= length)
    {
      [NSException raise: NSRangeException
		  format: @"Range: (%u, 1) Size: %d", *cursor, length];
    }
  *tag = *((unsigned char*)bytes + (*cursor)++);
  if (*tag & _GSC_MAYX)
    {
      switch (*tag & _GSC_SIZE)
	{
	  case _GSC_X_0:
	    {
	      return;
	    }
	  case _GSC_X_1:
	    {
	      if (*cursor >= length)
		{
		  [NSException raise: NSRangeException
			      format: @"Range: (%u, 1) Size: %d",
			  *cursor, length];
		}
	      *ref = (unsigned int)*((unsigned char*)bytes + (*cursor)++);
	      return;
	    }
	  case _GSC_X_2:
	    {
	      gsu16	x;

	      if (*cursor >= length-1)
		{
		  [NSException raise: NSRangeException
			      format: @"Range: (%u, 1) Size: %d",
			  *cursor, length];
		}
	      x = *(gsu16*)(bytes + *cursor);
	      *cursor += 2;
	      *ref = (unsigned int)GSSwapBigI16ToHost(x);
	      return;
	    }
	  default:
	    {
	      gsu32	x;

	      if (*cursor >= length-3)
		{
		  [NSException raise: NSRangeException
			      format: @"Range: (%u, 1) Size: %d",
			  *cursor, length];
		}
	      x = *(gsu32*)(bytes + *cursor);
	      *cursor += 4;
	      *ref = (unsigned int)GSSwapBigI32ToHost(x);
	      return;
	    }
	}
    }
}


@end

@implementation	NSDataMalloc

- (id) copy
{
  if (NSShouldRetainWithZone(self, NSDefaultMallocZone()))
    return RETAIN(self);
  else
    return [[dataMalloc allocWithZone: NSDefaultMallocZone()]
      initWithBytes: bytes length: length];
}

- (id) copyWithZone: (NSZone*)z
{
  if (NSShouldRetainWithZone(self, z))
    return RETAIN(self);
  else
    return [[dataMalloc allocWithZone: z]
      initWithBytes: bytes length: length];
}

- (void) dealloc
{
  if (bytes)
    {
      NSZoneFree(zone, bytes);
      bytes = 0;
    }
  [super dealloc];
}

- (id) initWithBytes: (const void*)aBuffer length: (unsigned)bufferSize
{
  void*	tmp = 0;

  if (aBuffer != 0 && bufferSize > 0)
    {
#if	GS_WITH_GC
      zone = GSAtomicMallocZone();
#else
      zone = [self zone];
#endif
      tmp = NSZoneMalloc(zone, bufferSize);
      if (tmp == 0)
	{
	  NSLog(@"[NSDataMalloc -initWithBytes:length:] unable to allocate %lu bytes", bufferSize);
	  RELEASE(self);
	  return nil;
	}
      else
	{
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
  if (aZone == 0)
    {
      NSData	*data;

      data = [[NSDataStatic allocWithZone: NSDefaultMallocZone()]
	initWithBytesNoCopy: aBuffer length: bufferSize];
      RELEASE(self);
      return data;
    }

#if	GS_WITH_GC
  zone = GSAtomicMallocZone();
#else
  zone = aZone;
#endif
  bytes = aBuffer;
  if (bytes)
    {
      length = bufferSize;
    }
  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	l;
  void*		b;

#if	GS_WITH_GC
  zone = GSAtomicMallocZone();
#else
  zone = [self zone];
#endif

  [aCoder decodeValueOfObjCType: @encode(unsigned long) at: &l];
  if (l)
    {
      b = NSZoneMalloc(zone, l);
      if (b == 0)
	{
	  NSLog(@"[NSDataMalloc -initWithCoder:] unable to get %lu bytes", l);
	  RELEASE(self);
	  return nil;
        }
      [aCoder decodeArrayOfObjCType: @encode(unsigned char) count: l at: b];
    }
  else
    {
      b = 0;
    }
  return [self initWithBytesNoCopy: b length: l fromZone: zone];
}

- (id) initWithContentsOfFile: (NSString *)path
{
#if	GS_WITH_GC
  zone = GSAtomicMallocZone();
#else
  zone = [self zone];
#endif
  if (readContentsOfFile(path, &bytes, &length, zone) == NO)
    {
      RELEASE(self);
      self = nil;
    }
  return self;
}

- (id) initWithContentsOfMappedFile: (NSString *)path
{
#if	HAVE_MMAP
  NSZone	*z = [self zone];

  RELEASE(self);
  self = [NSDataMappedFile allocWithZone: z];
  return [self initWithContentsOfMappedFile: path];
#else
  return [self initWithContentsOfFile: path];
#endif
}

- (id) initWithData: (NSData*)anObject
{
  if (anObject == nil)
    {
      return [self initWithBytesNoCopy: 0 length: 0 fromZone: [self zone]];
    }
  if ([anObject isKindOfClass: [NSData class]] == NO)
    {
      NSLog(@"-initWithData: passed a non-data object");
      RELEASE(self);
      return nil;
    }
  return [self initWithBytes: [anObject bytes] length: [anObject length]];
}

- (void*) relinquishAllocatedBytesFromZone: (NSZone*)aZone
{
  if (aZone == zone || aZone == 0)
    {
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
  if (bytes)
    {
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
      NSDebugLog(@"Open (%s) attempt failed - bad path", thePath);
      return NO;
    }
  fd = open(thePath, O_RDONLY);
  if (fd < 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to open %s - %s", thePath, strerror(errno));
      RELEASE(self);
      return nil;
    }
  /* Find size of file to be mapped. */
  length = lseek(fd, 0, SEEK_END);
  if (length < 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to seek to eof %s - %s", thePath, strerror(errno));
      close(fd);
      RELEASE(self);
      return nil;
    }
  /* Position at start of file. */
  if (lseek(fd, 0, SEEK_SET) != 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to seek to sof %s - %s", thePath, strerror(errno));
      close(fd);
      RELEASE(self);
      return nil;
    }
  bytes = mmap(0, length, PROT_READ, MAP_SHARED, fd, 0);
  if (bytes == MAP_FAILED)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] mapping failed for %s - %s", thePath, strerror(errno));
      close(fd);
      RELEASE(self);
      self = [dataMalloc allocWithZone: NSDefaultMallocZone()];
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
  shmid = -1;
  if (aBuffer && bufferSize)
    {
      shmid = shmget(IPC_PRIVATE, bufferSize, IPC_CREAT|VM_RDONLY);
      if (shmid == -1)			/* Created memory? */
	{
	  NSLog(@"[-initWithBytes:length:] shared mem get failed for %u - %s",
		    bufferSize, strerror(errno));
	  RELEASE(self);
	  self = [dataMalloc allocWithZone: NSDefaultMallocZone()];
	  return [self initWithBytes: aBuffer length: bufferSize];
	}

    bytes = shmat(shmid, 0, 0);
    if (bytes == (void*)-1)
      {
	NSLog(@"[-initWithBytes:length:] shared mem attach failed for %u - %s",
		  bufferSize, strerror(errno));
	bytes = 0;
	RELEASE(self);
	self = [dataMalloc allocWithZone: NSDefaultMallocZone()];
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
      RELEASE(self);	/* Unable to access memory. */
      return nil;
    }
  if (buf.shm_segsz < bufferSize)
    {
      NSLog(@"[NSDataShared -initWithShmID:length:] shared memory segment too small");
      RELEASE(self);	/* Memory segment too small. */
      return nil;
    }
  bytes = shmat(shmid, 0, 0);
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSDataShared -initWithShmID:length:] shared memory attach failed - %s",
		strerror(errno));
      bytes = 0;
      RELEASE(self);	/* Unable to attach to memory. */
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
  if (self == [NSMutableDataMalloc class])
    {
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

- (id) copy
{
  return [[dataMalloc allocWithZone: NSDefaultMallocZone()]
    initWithBytes: bytes length: length];
}

- (id) copyWithZone: (NSZone*)z
{
  return [[dataMalloc allocWithZone: z]
    initWithBytes: bytes length: length];
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
  if (aZone == 0)
    {
      self = [self initWithBytes: aBuffer length: bufferSize];
      return self;
    }

  if (aBuffer == 0)
    {
      self = [self initWithCapacity: bufferSize];
      if (self)
	{
	  [self setLength: bufferSize];
	}
      return self;
    }
  self = [self initWithCapacity: 0];
  if (self)
    {
#if	GS_WITH_GC
      zone = GSAtomicMallocZone();
#else
      zone = aZone;
#endif
      bytes = aBuffer;
      length = bufferSize;
      capacity = bufferSize;
      growth = capacity/2;
      if (growth == 0)
	{
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
#if	GS_WITH_GC
  zone = GSAtomicMallocZone();
#else
  zone = [self zone];
#endif
  if (size)
    {
      bytes = NSZoneMalloc(zone, size);
      if (bytes == 0)
	{
	  NSLog(@"[NSMutableDataMalloc -initWithCapacity:] out of memory for %u bytes - %s", size, strerror(errno));
	  RELEASE(self);
	  return nil;
	}
    }
  capacity = size;
  growth = capacity/2;
  if (growth == 0)
    {
      growth = 1;
    }
  length = 0;

  return self;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	l;

  [aCoder decodeValueOfObjCType: @encode(unsigned long) at: &l];
  if (l)
    {
      [self initWithCapacity: l];
      if (bytes == 0)
	{
	  NSLog(@"[NSMutableDataMalloc -initWithCoder:] unable to allocate %lu bytes", l);
	  RELEASE(self);
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
      RELEASE(self);
      self = nil;
    }
  else
    {
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
  if (anObject == nil)
    {
      return [self initWithCapacity: 0];
    }
  if ([anObject isKindOfClass: [NSData class]] == NO)
    {
      NSLog(@"-initWithData: passed a non-data object");
      RELEASE(self);
      return nil;
    }
  return [self initWithBytes: [anObject bytes] length: [anObject length]];
}

- (void) appendBytes: (const void*)aBuffer
	      length: (unsigned)bufferSize
{
  unsigned	oldLength = length;
  unsigned	minimum = length + bufferSize;

  if (minimum > capacity)
    {
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
  if (minimum > capacity)
    {
      unsigned	nextCapacity = capacity + growth;
      unsigned	nextGrowth = capacity ? capacity : 1;

      while (nextCapacity < minimum)
	{
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

  if (ptr != 0)
    {
      capacity = 0;
      growth = 1;
    }
  return ptr;
}

- (void) replaceBytesInRange: (NSRange)aRange
		   withBytes: (const void*)moreBytes
{
  GS_RANGE_CHECK(aRange, length);
  memcpy(bytes + aRange.location, moreBytes, aRange.length);
}

- (void) serializeDataAt: (const void*)data
	      ofObjCType: (const char*)type
		 context: (id <NSObjCTypeSerializationCallBack>)callback
{
  if (data == 0 || type == 0)
    {
      if (data == 0)
	{
	  NSLog(@"attempt to serialize from a nul pointer");
	}
      if (type == 0)
	{
	  NSLog(@"attempt to serialize with a nul type encoding");
	}
      return;
    }
  switch (*type)
    {
      case _C_ID:
	[callback serializeObjectAt: (id*)data
			 ofObjCType: type
			   intoData: self];
	return;

      case _C_CHARPTR:
	{
	  unsigned	len;
	  gss32		ni;
	  unsigned	minimum;

	  if (!*(void**)data)
	    {
	      ni = -1;
	      ni = GSSwapHostI32ToBig(ni);
	      [self appendBytes: (void*)&len length: sizeof(len)];
	      return;
	    }
	  len = strlen(*(void**)data);
	  ni = GSSwapHostI32ToBig(len);
	  minimum = length + len + sizeof(ni);
	  if (minimum > capacity)
	    {
	      [self _grow: minimum];
	    }
	  memcpy(bytes+length, &ni, sizeof(ni));
	  length += sizeof(ni);
	  if (len)
	    {
	      memcpy(bytes+length, *(void**)data, len);
	      length += len;
	    }
	  return;
	}
      case _C_ARY_B:
	{
	  unsigned	offset = 0;
	  unsigned	size;
	  unsigned	count = atoi(++type);
	  unsigned	i;
	  unsigned	minimum;

	  while (isdigit(*type))
	    {
	      type++;
	    }
	  size = objc_sizeof_type(type);

	  /*
	   *	Serialized objects are going to take up at least as much
	   *	space as the originals, so we can calculate a minimum space
	   *	we are going to need and make sure our buffer is big enough.
	   */
	  minimum = length + size*count;
	  if (minimum > capacity)
	    {
	      [self _grow: minimum];
	    }

	  for (i = 0; i < count; i++)
	    {
	      [self serializeDataAt: (char*)data + offset
			 ofObjCType: type
			    context: callback];
	      offset += size;
	    }
	  return;
	}
      case _C_STRUCT_B:
	{
	  int offset = 0;

	  while (*type != _C_STRUCT_E && *type++ != '='); /* skip "<name>=" */
	  for (;;)
	    {
	      [self serializeDataAt: ((char*)data) + offset
			 ofObjCType: type
			    context: callback];
	      offset += objc_sizeof_type(type);
	      type = objc_skip_typespec(type);
	      if (*type != _C_STRUCT_E)
		{
		  unsigned	align = objc_alignof_type(type);
		  unsigned	rem = offset % align;

		  if (rem != 0)
		    {
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
	return;
      case _C_SHT:
      case _C_USHT:
	{
	  unsigned short ns = NSSwapHostShortToBig(*(unsigned short*)data);
	  (*appendImp)(self, appendSel, &ns, sizeof(unsigned short));
	  return;
	}
      case _C_INT:
      case _C_UINT:
	{
	  unsigned ni = NSSwapHostIntToBig(*(unsigned int*)data);
	  (*appendImp)(self, appendSel, &ni, sizeof(unsigned));
	  return;
	}
      case _C_LNG:
      case _C_ULNG:
	{
	  unsigned long nl = NSSwapHostLongToBig(*(unsigned long*)data);
	  (*appendImp)(self, appendSel, &nl, sizeof(unsigned long));
	  return;
	}
      case _C_LNG_LNG:
      case _C_ULNG_LNG:
	{
	  unsigned long long nl;

	  nl = NSSwapHostLongLongToBig(*(unsigned long long*)data);
	  (*appendImp)(self, appendSel, &nl, sizeof(unsigned long long));
	  return;
	}
      case _C_FLT:
	{
	  NSSwappedFloat nf = NSSwapHostFloatToBig(*(float*)data);
	  (*appendImp)(self, appendSel, &nf, sizeof(NSSwappedFloat));
	  return;
	}
      case _C_DBL:
	{
	  NSSwappedDouble nd = NSSwapHostDoubleToBig(*(double*)data);
	  (*appendImp)(self, appendSel, &nd, sizeof(NSSwappedDouble));
	  return;
	}
      case _C_CLASS:
	{
	  const char  *name = *(Class*)data?fastClassName(*(Class*)data):"";
	  gsu16	ln = (gsu16)strlen(name);
	  gsu16	minimum = length + ln + sizeof(gsu16);
	  gsu16	ni;

	  if (minimum > capacity)
	    {
	      [self _grow: minimum];
	    }
	  ni = GSSwapHostI16ToBig(ln);
	  memcpy(bytes+length, &ni, sizeof(ni));
	  length += sizeof(ni);
	  if (ln)
	    {
	      memcpy(bytes+length, name, ln);
	      length += ln;
	    }
	  return;
	}
      case _C_SEL:
	{
	  const char  *name = *(SEL*)data?fastSelectorName(*(SEL*)data):"";
	  gsu16	ln = (name == 0) ? 0 : (gsu16)strlen(name);
	  const char  *types = *(SEL*)data?fastSelectorTypes(*(SEL*)data):"";
	  gsu16	lt = (types == 0) ? 0 : (gsu16)strlen(types);
	  gsu16	minimum = length + ln + lt + 2*sizeof(gsu16);
	  gsu16	ni;

	  if (minimum > capacity)
	    {
	      [self _grow: minimum];
	    }
	  ni = GSSwapHostI16ToBig(ln);
	  memcpy(bytes+length, &ni, sizeof(ni));
	  length += sizeof(ni);
	  ni = GSSwapHostI16ToBig(lt);
	  memcpy(bytes+length, &ni, sizeof(ni));
	  length += sizeof(ni);
	  if (ln)
	    {
	      memcpy(bytes+length, name, ln);
	      length += ln;
	    }
	  if (lt)
	    {
	      memcpy(bytes+length, types, lt);
	      length += lt;
	    }
	  return;
	}
      default:
	[NSException raise: NSGenericException
		    format: @"Unknown type to serialize - '%s'", type];
    }
}

- (void) serializeTypeTag: (unsigned char)tag
{
  if (length == capacity)
    {
      [self _grow: length + 1];
    }
  ((unsigned char*)bytes)[length++] = tag;
}

- (void) serializeTypeTag: (unsigned char)tag
	      andCrossRef: (unsigned)xref
{
  if (xref <= 0xff)
    {
      tag = (tag & ~_GSC_SIZE) | _GSC_X_1;
      if (length + 2 >= capacity)
	{
	  [self _grow: length + 2];
	}
      *(gsu8*)(bytes + length++) = tag;
      *(gsu8*)(bytes + length++) = xref;
    }
  else if (xref <= 0xffff)
    {
      gsu16	x = (gsu16)xref;

      tag = (tag & ~_GSC_SIZE) | _GSC_X_2;
      if (length + 3 >= capacity)
	{
	  [self _grow: length + 3];
	}
      *(gsu8*)(bytes + length++) = tag;
      *(gsu16*)(bytes + length) = GSSwapHostI16ToBig(x);
      length += 2;
    }
  else
    {
      gsu32	x = (gsu32)xref;

      tag = (tag & ~_GSC_SIZE) | _GSC_X_4;
      if (length + 5 >= capacity)
	{
	  [self _grow: length + 5];
	}
      *(gsu8*)(bytes + length++) = tag;
      *(gsu32*)(bytes + length) = GSSwapHostI32ToBig(x);
      length += 4;
    }
}

- (id) setCapacity: (unsigned)size
{
  if (size != capacity)
    {
      void*	tmp;

      if (bytes)
	{
	  tmp = NSZoneRealloc(zone, bytes, size);
	}
      else
	{
	  tmp = NSZoneMalloc(zone, size);
	}
      if (tmp == 0)
	{
	  [NSException raise: NSMallocException
		      format: @"Unable to set data capacity to '%d'", size];
	}
      bytes = tmp;
      capacity = size;
      growth = capacity/2;
      if (growth == 0)
	{
	  growth = 1;
	}
    }
  if (size < length)
    {
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
  int	e;

  shmid = shmget(IPC_PRIVATE, bufferSize, IPC_CREAT|VM_ACCESS);
  if (shmid == -1)			/* Created memory? */
    {
      NSLog(@"[NSMutableDataShared -initWithCapacity:] shared memory get failed for %u - %s", bufferSize, strerror(errno));
      RELEASE(self);
      self = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
      return [self initWithCapacity: bufferSize];
    }

  bytes = shmat(shmid, 0, 0);
  e = errno;
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSMutableDataShared -initWithCapacity:] shared memory attach failed for %u - %s", bufferSize, strerror(e));
      bytes = 0;
      RELEASE(self);
      self = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
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
      RELEASE(self);	/* Unable to access memory. */
      return nil;
    }
  if (buf.shm_segsz < bufferSize)
    {
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory segment too small");
      RELEASE(self);	/* Memory segment too small. */
      return nil;
    }
  bytes = shmat(shmid, 0, 0);
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory attach failed - %s", strerror(errno));
      bytes = 0;
      RELEASE(self);	/* Unable to attach to memory. */
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
      void	*tmp;
      int	newid;

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

