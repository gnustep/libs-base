/* Stream of bytes class for serialization and persistance in GNUStep
   Copyright (C) 1995, 1996, 1997, 2000 Free Software Foundation, Inc.
   
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
#include <base/behavior.h>
#include <Foundation/NSObjCRuntime.h>
#include <Foundation/NSByteOrder.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSData.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSDebug.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSPathUtilities.h>
#include <Foundation/NSRange.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSZone.h>
#include <stdio.h>
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
static SEL	appendSel;
static Class	dataStatic;
static Class	dataMalloc;
static Class	mutableDataMalloc;
static Class	NSDataAbstract;
static Class	NSMutableDataAbstract;
static SEL	appendSel;
static IMP	appendImp;

static BOOL
readContentsOfFile(NSString* path, void** buf, unsigned* len, NSZone* zone)
{
  char		thePath[BUFSIZ*2];
  FILE		*theFile = 0;
  void		*tmp = 0;
  int		c;
#if defined(__MINGW__)
  HANDLE	fh;
  DWORD		fileLength;
  DWORD		high;
  DWORD		got;
#else
  unsigned	fileLength;
#endif

  if ([path getFileSystemRepresentation: thePath
			      maxLength: sizeof(thePath)-1] == NO)
    {
      NSDebugLog(@"Open (%s) attempt failed - bad path", thePath);
      return NO;
    }

#if defined(__MINGW__)
  fh = CreateFile(thePath, GENERIC_READ, FILE_SHARE_READ, 0, OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL, 0);
  if (fh == INVALID_HANDLE_VALUE)
    {
      NSDebugLog(@"Open (%s) attempt failed", thePath);
      return NO;
    }

  fileLength = GetFileSize(fh, &high);
  if ((fileLength == 0xFFFFFFFF) && (GetLastError() != NO_ERROR))
    {
      CloseHandle(fh);
      NSLog(@"Failed to determine size of - %s", thePath);
      return NO;
    }
  if (high != 0)
    {
      CloseHandle(fh);
      NSLog(@"File too big to handle - %s", thePath);
      return NO;
    }

#if	GS_WITH_GC == 1
  tmp = NSZoneMalloc(GSAtomicMallocZone(), fileLength);
#else
  tmp = NSZoneMalloc(zone, fileLength);
#endif
  if (tmp == 0)
    {
      CloseHandle(fh);
      NSLog(@"Malloc failed for file (%s) of length %d - %s",
	thePath, fileLength, GSLastErrorStr(errno));
      return NO;
    }
  if (!ReadFile(fh, tmp, fileLength, &got, 0))
    {
      if (tmp != 0)
	{
	  NSZoneFree(zone, tmp);
	  CloseHandle(fh);
	  NSLog(@"File read operation failed for %s", thePath);
	  return NO;
	}
    }
  if (got != fileLength)
    {
      NSZoneFree(zone, tmp);
      CloseHandle(fh);
      NSLog(@"File read operation short for %s", thePath);
      return NO;
    }
  CloseHandle(fh);
  *buf = tmp;
  *len = fileLength;
  return YES;
#endif

  theFile = fopen(thePath, "rb");

  if (theFile == NULL)		/* We failed to open the file. */
    {
      NSDebugLog(@"Open (%s) attempt failed - %s", thePath, GSLastErrorStr(errno));
      goto failure;
    }

  /*
   *	Seek to the end of the file.
   */
  c = fseek(theFile, 0L, SEEK_END);
  if (c != 0)
    {
      NSLog(@"Seek to end of file failed - %s", GSLastErrorStr(errno));
      goto failure;
    }

  /*
   *	Determine the length of the file (having seeked to the end of the
   *	file) by calling ftell().
   */
  fileLength = ftell(theFile);
  if (fileLength == -1)
    {
      NSLog(@"Ftell failed - %s", GSLastErrorStr(errno));
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
		fileLength, GSLastErrorStr(errno));
      goto failure;
    }

  /*
   *	Rewind the file pointer to the beginning, preparing to read in
   *	the file.
   */
  c = fseek(theFile, 0L, SEEK_SET);
  if (c != 0)
    {
      NSLog(@"Fseek to start of file failed - %s", GSLastErrorStr(errno));
      goto failure;
    }

  c = fread(tmp, 1, fileLength, theFile);
  if (c != fileLength)
    {
      NSLog(@"read of file contents failed - %s", GSLastErrorStr(errno));
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
  if (tmp != 0)
    NSZoneFree(zone, tmp);
  if (theFile != 0)
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
      NSDataAbstract = self;
      NSMutableDataAbstract = [NSMutableData class];
      dataMalloc = [NSDataMalloc class];
      dataStatic = [NSDataStatic class];
      mutableDataMalloc = [NSMutableDataMalloc class];
      appendSel = @selector(appendBytes:length:);
      appendImp = [mutableDataMalloc instanceMethodForSelector: appendSel];
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSDataAbstract)
    {
      return NSAllocateObject(dataMalloc, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
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

+ (id) dataWithContentsOfURL: (NSURL*)url
{
  NSData	*d;

  d = [url resourceDataUsingCache: YES];
  return d;
}

+ (id) dataWithData: (NSData*)data
{
  NSData	*d;

  d = [dataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytes: [data bytes] length: [data length]];
  return AUTORELEASE(d);
}

+ (id) new
{
  NSData	*d;

  d = [dataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithBytesNoCopy: 0 length: 0];
  return d;
}

- (id) init
{
   return [self initWithBytesNoCopy: 0 length: 0];
}

- (id) initWithBytes: (const void*)aBuffer
	      length: (unsigned)bufferSize
{
  void	*ptr = 0;

  if (bufferSize > 0)
    {
      ptr = NSZoneMalloc(NSDefaultMallocZone(), bufferSize);
      memcpy(ptr, aBuffer, bufferSize);
    }
  return [self initWithBytesNoCopy: ptr length: bufferSize];
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithContentsOfFile: (NSString *)path
{
  void		*fileBytes;
  unsigned	fileLength;
  NSZone	*zone;

#if	GS_WITH_GC
  zone = GSAtomicMallocZone();
#else
  zone = GSObjCZone(self);
#endif
  if (readContentsOfFile(path, &fileBytes, &fileLength, zone) == NO)
    {
      RELEASE(self);
      self = nil;
    }
  else
    {
      self = [self initWithBytesNoCopy: fileBytes length: fileLength];
    }
  return self;
}

- (id) initWithContentsOfMappedFile: (NSString *)path;
{
#if	HAVE_MMAP
  RELEASE(self);
  self = [NSDataMappedFile allocWithZone: GSObjCZone(self)];
  return [self initWithContentsOfMappedFile: path];
#else
  return [self initWithContentsOfFile: path];
#endif
}

- (id) initWithContentsOfURL: (NSURL*)url
{
  NSData	*data = [url resourceDataUsingCache: YES];

  return [self initWithData: data];
}

- (id) initWithData: (NSData*)data
{
  if (data == nil)
    {
      return [self initWithBytesNoCopy: 0 length: 0];
    }
  if ([data isKindOfClass: [NSData class]] == NO)
    {
      NSLog(@"-initWithData: passed a non-data object");
      RELEASE(self);
      return nil;
    }
  return [self initWithBytes: [data bytes] length: [data length]];
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
  str = [[NSString allocWithZone: z] initWithCStringNoCopy: dest
						    length: j
					      freeWhenDone: YES];
  return AUTORELEASE(str);
}

- (void) getBytes: (void*)buffer
{
  [self getBytes: buffer range: NSMakeRange(0, [self length])];
}

- (void) getBytes: (void*)buffer length: (unsigned)length
{
  [self getBytes: buffer range: NSMakeRange(0, length)];
}

- (void) getBytes: (void*)buffer range: (NSRange)aRange
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
  unsigned char	buf[64];
  unsigned	l = [self length];
  unsigned	ret =0;
  
  l = MIN(l,64);

  /*
   * hash for empty data matches hash for empty string
   */
  if (l == 0)
    {
      return 0xfffffffe;
    }
  
  [self getBytes: &buf range: NSMakeRange(0, l)];

  while (l-- > 0)
    {
      ret = (ret << 5 ) + ret + buf[l];
    }
  // Again, match NSString
  if (ret == 0)
    {
       ret = 0xffffffff;
    }
  return ret;
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

- (unsigned) length;
{
  /* This is left to concrete subclasses to implement. */
  [self subclassResponsibility: _cmd];
  return 0;
}


// Storing Data

- (BOOL) writeToFile: (NSString*)path atomically: (BOOL)useAuxiliaryFile
{
  char		thePath[BUFSIZ*2+8];
  char		theRealPath[BUFSIZ*2];
  FILE		*theFile;
  int		c;
#if defined(__MINGW__)
  NSString	*tmppath = path;
  HANDLE	fh;
  DWORD		wroteBytes;
#endif


  if ([path getFileSystemRepresentation: theRealPath
			      maxLength: sizeof(theRealPath)-1] == NO)
    {
      NSDebugLog(@"Open (%s) attempt failed - bad path", theRealPath);
      return NO;
    }

#if defined(__MINGW__)
  if (useAuxiliaryFile)
    {
      tmppath = [path stringByAppendingPathExtension: @"tmp"];
    }
  if ([tmppath getFileSystemRepresentation: thePath
			      maxLength: sizeof(thePath)-1] == NO)
    {
      NSDebugLog(@"Open (%s) attempt failed - bad path", thePath);
      return NO;
    }
  
  fh = CreateFile(thePath, GENERIC_WRITE, 0, 0, CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL, NULL);
  if (fh == INVALID_HANDLE_VALUE)
    {
      NSLog(@"Create (%s) attempt failed", thePath);
      return NO;
    }

  if (!WriteFile(fh, [self bytes], [self length], &wroteBytes, 0))
    {
      CloseHandle(fh);
      NSLog(@"Write (%s) attempt failed", thePath);
      goto failure;
    }
  CloseHandle(fh);
#else

#ifdef	HAVE_MKSTEMP
  if (useAuxiliaryFile)
    {
      int	desc;
      int	mask;

      strcpy(thePath, theRealPath);
      strcat(thePath, "XXXXXX");
      if ((desc = mkstemp(thePath)) < 0)
	{
          NSLog(@"mkstemp (%s) failed - %s", thePath, GSLastErrorStr(errno));
          goto failure;
	}
      mask = umask(0);
      umask(mask);
      fchmod(desc, 0644 & ~mask);
      if ((theFile = fdopen(desc, "w")) == 0)
	{
	  close(desc);
	}
    }
  else
    {
      strcpy(thePath, theRealPath);
      theFile = fopen(thePath, "wb");
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
          NSLog(@"mktemp (%s) failed - %s", thePath, GSLastErrorStr(errno));
          goto failure;
	}
    }
  else
    {
      strcpy(thePath, theRealPath);
    }

  /* Open the file (whether temp or real) for writing. */
  theFile = fopen(thePath, "wb");
#endif

  if (theFile == NULL)          /* Something went wrong; we weren't
                                 * even able to open the file. */
    {
      NSLog(@"Open (%s) failed - %s", thePath, GSLastErrorStr(errno));
      goto failure;
    }

  /* Now we try and write the NSData's bytes to the file.  Here `c' is
   * the number of bytes which were successfully written to the file
   * in the fwrite() call. */
  c = fwrite([self bytes], sizeof(char), [self length], theFile);

  if (c < [self length])        /* We failed to write everything for
                                 * some reason. */
    {
      NSLog(@"Fwrite (%s) failed - %s", thePath, GSLastErrorStr(errno));
      goto failure;
    }

  /* We're done, so close everything up. */
  c = fclose(theFile);

  if (c != 0)                   /* I can't imagine what went wrong
                                 * closing the file, but we got here,
                                 * so we need to deal with it. */
    {
      NSLog(@"Fclose (%s) failed - %s", thePath, GSLastErrorStr(errno));
      goto failure;
    }
#endif

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
 	  [mgr removeFileAtPath: path handler: nil];
	}

      c = rename(thePath, theRealPath);
      if (c != 0)               /* Many things could go wrong, I guess. */
        {
          NSLog(@"Rename ('%s' to '%s') failed - %s",
	    thePath, theRealPath, GSLastErrorStr(errno));
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
#ifndef __MINGW__
      else if (geteuid() == 0 && [@"root" isEqualToString: NSUserName()] == NO)
	{
	  att = [NSDictionary dictionaryWithObjectsAndKeys:
			NSFileOwnerAccountName, NSUserName(), nil];
	  if ([mgr changeFileAttributes: att atPath: path] == NO)
	    NSLog(@"Unable to correctly set ownership for '%@'", path);
	}
#endif
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

#if	GS_WITH_GC == 0
	      *(char**)data = (char*)NSZoneMalloc(NSDefaultMallocZone(), len);
#else
	      *(char**)data = (char*)NSZoneMalloc(NSAtomicMallocZone(), len);
#endif
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

#if	GS_WITH_GC == 0
	  *(char**)data = (char*)NSZoneMalloc(NSDefaultMallocZone(), len);
#else
	  *(char**)data = (char*)NSZoneMalloc(NSAtomicMallocZone(), len);
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
		  if (lt)
		    {
		      sel = sel_register_typed_name(name, types);
		    }
		  else
		    {
		      sel = sel_register_name(name);
		    }
		  if (sel == 0)
		    {
		      [NSException raise: NSInternalInconsistencyException
				  format: @"can't make sel with name '%s' "
					      @"and types '%s'", name, types];
		    }
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
  [coder encodeDataObject: self];
}

- (id) initWithCoder: (NSCoder*)coder
{
  id	obj = [coder decodeDataObject];

  if (obj != self)
    {
      ASSIGN(self, obj);
    }
  return self;
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

@end


@implementation NSMutableData
+ (id) allocWithZone: (NSZone*)z
{
  if (self == NSMutableDataAbstract)
    {
      return NSAllocateObject(mutableDataMalloc, 0, z);
    }
  else
    {
      return NSAllocateObject(self, 0, z);
    }
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
  NSMutableData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithContentsOfFile: path];
  return AUTORELEASE(d);
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
  NSMutableData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithContentsOfMappedFile: path];
  return AUTORELEASE(d);
}

+ (id) dataWithContentsOfURL: (NSURL*)url
{
  NSMutableData	*d;
  NSData	*data;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  data = [url resourceDataUsingCache: YES];
  d = [d initWithBytes: [data bytes] length: [data length]];
  return AUTORELEASE(d);
}

+ (id) dataWithData: (NSData*)data
{
  NSMutableData	*d;

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

+ (id) new
{
  NSMutableData	*d;

  d = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
  d = [d initWithCapacity: 0];
  return d;
}

- (const void*) bytes
{
  return [self mutableBytes];
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  unsigned	length = [self length];
  void		*bytes = [self mutableBytes];

  [aCoder encodeValueOfObjCType: @encode(unsigned long)
			     at: &length];
  if (length)
    {
      [aCoder encodeArrayOfObjCType: @encode(unsigned char)
			      count: length
				 at: bytes];
    }
}

- (id) initWithCapacity: (unsigned)capacity
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  unsigned	l;
  NSZone	*zone;

#if	GS_WITH_GC
  zone = GSAtomicMallocZone();
#else
  zone = [self zone];
#endif

  [aCoder decodeValueOfObjCType: @encode(unsigned long) at: &l];
  if (l)
    {
      void	*b = NSZoneMalloc(zone, l);

      if (b == 0)
	{
	  NSLog(@"[NSDataMalloc -initWithCoder:] unable to get %lu bytes", l);
	  RELEASE(self);
	  return nil;
        }
      [aCoder decodeArrayOfObjCType: @encode(unsigned char) count: l at: b];
      self = [self initWithBytesNoCopy: b length: l];
    }
  else
    {
      self = [self initWithBytesNoCopy: 0 length: 0];
    }
  return self;
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
  [self appendBytes: [other bytes] length: [other length]];
}


// Modifying Data

- (void) replaceBytesInRange: (NSRange)aRange
		   withBytes: (const void*)bytes
{
  unsigned	size = [self length];
  unsigned	need = NSMaxRange(aRange);

  if (aRange.location > size)
    {
      [NSException raise: NSRangeException
		  format: @"location bad in replaceByteInRange:withBytes:"];
    }
  if (aRange.length > 0)
    {
      if (need > size)
	{
	  [self setLength: need];
	}
      memcpy([self mutableBytes] + aRange.location, bytes, aRange.length);
    }
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

  [self setCapacity: r.length];
  [self replaceBytesInRange: r withBytes: [data bytes]];
}

// Serializing Data

- (void) serializeAlignedBytesLength: (unsigned)length
{
  [self serializeInt: length];
}

- (void) serializeDataAt: (const void*)data
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
	  const char  *name = *(Class*)data?GSObjCName(*(Class*)data):"";
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
	  const char  *name = *(SEL*)data?GSObjCSelectorName(*(SEL*)data):"";
	  gsu16	ln = (name == 0) ? 0 : (gsu16)strlen(name);
	  const char  *types = *(SEL*)data?GSObjCSelectorTypes(*(SEL*)data):"";
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

+ (id) allocWithZone: (NSZone*)z
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

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
{
  bytes = aBuffer;
  length = bufferSize;
  return self;
}

- (Class) classForCoder
{
  return dataMalloc;		/* Will not be static data when decoded. */
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
#if	GS_WITH_GC == 0
	      *(char**)data = (char*)NSZoneMalloc(NSDefaultMallocZone(), len+1);
#else
	      *(char**)data = (char*)NSZoneMalloc(NSAtomicMallocZone(), len+1);
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

#if	GS_WITH_GC == 0
	  *(char**)data = (char*)NSZoneMalloc(NSDefaultMallocZone(), len);
#else
	  *(char**)data = (char*)NSZoneMalloc(NSAtomicMallocZone(), len);
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
		  if (lt)
		    {
		      sel = sel_register_typed_name(name, types);
		    }
		  else
		    {
		      sel = sel_register_name(name);
		    }
		  if (sel == 0)
		    {
		      [NSException raise: NSInternalInconsistencyException
				  format: @"can't make sel with name '%s' "
					      @"and types '%s'", name, types];
		    }
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
#if NEED_WORD_ALIGNMENT
	      if ((*cursor % __alignof__(gsu16)) != 0)
		memcpy(&x, (bytes + *cursor), 2);
	      else
#endif
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
#if NEED_WORD_ALIGNMENT
	      if ((*cursor % __alignof__(gsu32)) != 0)
		memcpy(&x, (bytes + *cursor), 4);
	      else
#endif
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
  if (bytes != 0)
    {
      NSZoneFree(NSZoneFromPointer(bytes), bytes);
      bytes = 0;
    }
  [super dealloc];
}

- (id) initWithBytesNoCopy: (void*)aBuffer
		    length: (unsigned)bufferSize
{
  bytes = aBuffer;
  length = bufferSize;
  return self;
}

@end

#if	HAVE_MMAP
@implementation	NSDataMappedFile
+ (id) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSDataMappedFile class], 0, z);
}

- (void) dealloc
{
  if (bytes != 0)
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
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to open %s - %s", thePath, GSLastErrorStr(errno));
      RELEASE(self);
      return nil;
    }
  /* Find size of file to be mapped. */
  length = lseek(fd, 0, SEEK_END);
  if (length < 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to seek to eof %s - %s", thePath, GSLastErrorStr(errno));
      close(fd);
      RELEASE(self);
      return nil;
    }
  /* Position at start of file. */
  if (lseek(fd, 0, SEEK_SET) != 0)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] unable to seek to sof %s - %s", thePath, GSLastErrorStr(errno));
      close(fd);
      RELEASE(self);
      return nil;
    }
  bytes = mmap(0, length, PROT_READ, MAP_SHARED, fd, 0);
  if (bytes == MAP_FAILED)
    {
      NSLog(@"[NSDataMappedFile -initWithContentsOfMappedFile:] mapping failed for %s - %s", thePath, GSLastErrorStr(errno));
      close(fd);
      RELEASE(self);
      self = [dataMalloc allocWithZone: NSDefaultMallocZone()];
      self = [self initWithContentsOfFile: path];
    }
  close(fd);
  return self;
}

@end
#endif	/* HAVE_MMAP	*/

#if	HAVE_SHMCTL
@implementation	NSDataShared
+ (id) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSDataShared class], 0, z);
}

- (void) dealloc
{
  if (bytes != 0)
    {
      struct shmid_ds	buf;

      if (shmctl(shmid, IPC_STAT, &buf) < 0)
        NSLog(@"[NSDataShared -dealloc] shared memory control failed - %s",
		GSLastErrorStr(errno));
      else if (buf.shm_nattch == 1)
	if (shmctl(shmid, IPC_RMID, &buf) < 0)	/* Mark for deletion. */
          NSLog(@"[NSDataShared -dealloc] shared memory delete failed - %s",
		GSLastErrorStr(errno));
      if (shmdt(bytes) < 0)
        NSLog(@"[NSDataShared -dealloc] shared memory detach failed - %s",
		GSLastErrorStr(errno));
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
		    bufferSize, GSLastErrorStr(errno));
	  RELEASE(self);
	  self = [dataMalloc allocWithZone: NSDefaultMallocZone()];
	  return [self initWithBytes: aBuffer length: bufferSize];
	}

    bytes = shmat(shmid, 0, 0);
    if (bytes == (void*)-1)
      {
	NSLog(@"[-initWithBytes:length:] shared mem attach failed for %u - %s",
		  bufferSize, GSLastErrorStr(errno));
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
      NSLog(@"[NSDataShared -initWithShmID:length:] shared memory control failed - %s", GSLastErrorStr(errno));
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
		GSLastErrorStr(errno));
      bytes = 0;
      RELEASE(self);	/* Unable to attach to memory. */
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


@implementation	NSMutableDataMalloc
+ (void) initialize
{
  if (self == [NSMutableDataMalloc class])
    {
      behavior_class_add_class(self, [NSDataMalloc class]);
    }
}

+ (id) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject(mutableDataMalloc, 0, z);
}

- (Class) classForCoder
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
  if (aBuffer == 0)
    {
      self = [self initWithCapacity: bufferSize];
      if (self != nil)
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
      zone = NSZoneFromPointer(aBuffer);
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
  zone = GSObjCZone(self);
#endif
  if (size)
    {
      bytes = NSZoneMalloc(zone, size);
      if (bytes == 0)
	{
	  NSLog(@"[NSMutableDataMalloc -initWithCapacity:] out of memory for %u bytes - %s", size, GSLastErrorStr(errno));
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

- (void) replaceBytesInRange: (NSRange)aRange
		   withBytes: (const void*)moreBytes
{
  unsigned	need = NSMaxRange(aRange);

  if (aRange.location > length)
    {
      [NSException raise: NSRangeException
		  format: @"location bad in replaceByteInRange:withBytes:"];
    }
  if (aRange.length > 0)
    {
      if (need > length)
	{
	  [self setCapacity: need];
	  length = need;
	}
      memcpy(bytes + aRange.location, moreBytes, aRange.length);
    }
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
	  const char  *name = *(Class*)data?GSObjCName(*(Class*)data):"";
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
	  const char  *name = *(SEL*)data?GSObjCSelectorName(*(SEL*)data):"";
	  gsu16	ln = (name == 0) ? 0 : (gsu16)strlen(name);
	  const char  *types = *(SEL*)data?GSObjCSelectorTypes(*(SEL*)data):"";
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
#if NEED_WORD_ALIGNMENT
      if ((length % __alignof__(gsu16)) != 0)
	{
	  x = GSSwapHostI16ToBig(x);
	  memcpy((bytes + length), &x, 2);
	}
      else
#endif
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
#if NEED_WORD_ALIGNMENT
      if ((length % __alignof__(gsu32)) != 0)
	{
	  x = GSSwapHostI32ToBig(x);
	  memcpy((bytes + length), &x, 4);
	}
      else
#endif
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

- (void) setData: (NSData*)data
{
  unsigned	l = [data length];

  [self setCapacity: l];
  length = l;
  memcpy(bytes, [data bytes], length);
}

- (void) setLength: (unsigned)size
{
  if (size > capacity)
    {
      [self setCapacity: size];
    }
  if (size > length)
    {
      memset(bytes + length, '\0', size - length);
    }
  length = size;
}

@end


#if	HAVE_SHMCTL
@implementation	NSMutableDataShared
+ (id) allocWithZone: (NSZone*)z
{
  return (NSData*)NSAllocateObject([NSMutableDataShared class], 0, z);
}

- (void) dealloc
{
  if (bytes)
    {
      struct shmid_ds	buf;

      if (shmctl(shmid, IPC_STAT, &buf) < 0)
        NSLog(@"[NSMutableDataShared -dealloc] shared memory control failed - %s", GSLastErrorStr(errno));
      else if (buf.shm_nattch == 1)
	if (shmctl(shmid, IPC_RMID, &buf) < 0)	/* Mark for deletion. */
          NSLog(@"[NSMutableDataShared -dealloc] shared memory delete failed - %s", GSLastErrorStr(errno));
      if (shmdt(bytes) < 0)
        NSLog(@"[NSMutableDataShared -dealloc] shared memory detach failed - %s", GSLastErrorStr(errno));
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
      NSLog(@"[NSMutableDataShared -initWithCapacity:] shared memory get failed for %u - %s", bufferSize, GSLastErrorStr(errno));
      RELEASE(self);
      self = [mutableDataMalloc allocWithZone: NSDefaultMallocZone()];
      return [self initWithCapacity: bufferSize];
    }

  bytes = shmat(shmid, 0, 0);
  e = errno;
  if (bytes == (void*)-1)
    {
      NSLog(@"[NSMutableDataShared -initWithCapacity:] shared memory attach failed for %u - %s", bufferSize, GSLastErrorStr(e));
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
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory control failed - %s", GSLastErrorStr(errno));
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
      NSLog(@"[NSMutableDataShared -initWithShmID:length:] shared memory attach failed - %s", GSLastErrorStr(errno));
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
		    GSLastErrorStr(errno)];
      tmp = shmat(newid, 0, 0);
      if ((int)tmp == -1)			/* Attached memory? */
	[NSException raise: NSMallocException
		    format: @"Unable to attach to shared memory segment."];
      memcpy(tmp, bytes, length);
      if (bytes)
	{
          struct shmid_ds	buf;

          if (shmctl(shmid, IPC_STAT, &buf) < 0)
            NSLog(@"[NSMutableDataShared -setCapacity:] shared memory control failed - %s", GSLastErrorStr(errno));
          else if (buf.shm_nattch == 1)
	    if (shmctl(shmid, IPC_RMID, &buf) < 0)	/* Mark for deletion. */
              NSLog(@"[NSMutableDataShared -setCapacity:] shared memory delete failed - %s", GSLastErrorStr(errno));
	  if (shmdt(bytes) < 0)				/* Detach memory. */
              NSLog(@"[NSMutableDataShared -setCapacity:] shared memory detach failed - %s", GSLastErrorStr(errno));
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

