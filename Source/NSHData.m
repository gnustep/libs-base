
/* Implementation of concrete version of NSData class
   Copyright (C) 1997 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Created: July 1997

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
#include <Foundation/NSCoder.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSData.h>
#include <Foundation/NSHData.h>
#include <Foundation/NSZone.h>

#include <stdarg.h>
#include <assert.h>
#include <errno.h>

/* Deal with memchr: */
#if STDC_HEADERS || HAVE_STRING_H
#include <string.h>
/* An ANSI string.h and pre-ANSI memory.h might conflict.  */
#if !STDC_HEADERS && HAVE_MEMORY_H
#include <memory.h>
#endif /* not STDC_HEADERS and HAVE_MEMORY_H */
#define rindex strrchr
#define bcopy(s, d, n) memcpy ((d), (s), (n))
#define bcmp(s1, s2, n) memcmp ((s1), (s2), (n))
#define bzero(s, n) memset ((s), 0, (n))
#else /* not STDC_HEADERS and not HAVE_STRING_H */
#include <strings.h>
/* memory.h and strings.h conflict on some systems.  */
#endif /* not STDC_HEADERS and not HAVE_STRING_H */



#if HAVE_MMAP
#define	MAPPED_SUPP	1
#else
#define	MAPPED_SUPP	0
#endif

#if HAVE_SHMCTL
#define	SHARED_SUPP	1
#else
#define	SHARED_SUPP	0
#endif

#if	MAPPED_SUPP
#include	<unistd.h>
#include	<sys/mman.h>
#include	<fcntl.h>
#ifndef	MAP_FAILED
#define	MAP_FAILED	((void*)-1)	/* Failure address.	*/
#endif
#endif

#if	SHARED_SUPP
#include	<sys/ipc.h>
#include	<sys/shm.h>

#define	VM_ACCESS	0644		/* self read/write - other readonly */
#endif




extern int
o_vscanf (void *stream,
		int (*inchar_func)(void*),
		void (*unchar_func)(void*,int),
		const char *format, va_list argptr);

@implementation NSHData

/*
 *	OPENSTEP says that if an NSData object is more than a few memory
 *	pages in size, the memory is allocated from the virtual memory
 *	system.
 *
 *	I assume that this means something like the system-V shared memory
 *	mechanism should be used.
 *	This has the potential to transfer huge buffers from one process to
 *	another instantly (as you want for pasteboard use etc).
 *
 *	You can set the threshold above which shared memory is used with
 *	the class method '+setVMThreshold:' which changes the value in
 *	the 'nsdata_vm_threshold' variable.
 *
 *	Each instance of an NSHMutableData object has its own threshold which
 *	is set from nsdata_vm_threshold when the object is created.
 *	This can be modified by using the [-setVMThreshold:] method.
 *
 *	Shared memory is allocated in LARGE chunks.  Perhapos the chunk size
 *	should be a class variable?
 */
static int	nsdata_vm_threshold = 2048; /* Use shared mem for big buffer. */

#define	VM_CHUNK	262144	/* 256 Kbyte chunks	*/

/* Making these nested functions (which is what I'd like to do) is
   crashing the va_arg stuff in vscanf().  Why? */
#define DS ((NSHData*)s)

/*
static int outchar_func(void *s, int c)
{
  if (DS->position >= DS->size)
    return EOF;
  DS->buffer[DS->position++] = (char)c;
  return 1;
}
*/

static int inchar_func(void *s)
{
  if (DS->position >= DS->size)
    return EOF;
  return (int) DS->buffer[DS->position++];
}

static void unchar_func(void *s, int c)
{
  if (DS->position > 0)
    DS->position--;
  DS->buffer[DS->position] = (char)c;
}

+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([NSHData class], 0, zone);
}

+ (id) data
{
  return [[[self alloc] init] autorelease];
}

+ (id) dataWithBytes: (const void*)bytes
	      length: (unsigned int)length
{
  return [[[self alloc] initWithBytes:bytes length:length] autorelease];
}

+ (id) dataWithBytesNoCopy: (void*)bytes
		    length: (unsigned int)length
{
  return [[[self alloc] initWithBytesNoCopy:bytes length:length] autorelease];
}

+ (id)dataWithContentsOfFile: (NSString*)path
{
  return [[[self alloc] initWithContentsOfFile:path] autorelease];
}

+ (id) dataWithContentsOfMappedFile: (NSString*)path
{
  return [[[self alloc] initWithContentsOfMappedFile:path] autorelease];
}

+ (id) dataWithData: (NSData*)other
{
  return [[[self alloc] initWithData:other] autorelease];
}

- (const void*)bytes
{
    return (const void*)buffer;
}

- (id) copyWithZone: (NSZone*)zone
{
  NSHData*	obj = [[NSHData class] allocWithZone:zone];
  return [obj initWithData:self];
}

- (void) dealloc
{
  if (buffer)
    {
      switch (type)
        {
#if	MAPPED_SUPP
	  case MAPPED_DATA:
	    munmap(buffer, size);
	    break;

#endif
	  case MALLOC_DATA:
#if	SHARED_SUPP
	  case SHARED_DATA:
	    if (shm_id)		/* Was it really malloced data? */
	      shmdt(buffer);
	    else		/* Perhaps fall through to free it. */
#endif
	      objc_free(buffer);
	    break;

	  case STATIC_DATA:
	  default:
	    break;
        }
    }
  [super dealloc];
}

- (NSString*) description
{
  const char *src = [self bytes];
  char *dest;
  unsigned int length = [self length];
  unsigned int i,j;
  NSString *s;

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
  s = [NSString stringWithCString: dest];
  free(dest);
  return s;
}

- (void) encodeWithCoder: (NSCoder*)coder
{
  unsigned int len = [self length];

  [super encodeWithCoder:coder];
  [coder encodeValuesOfObjCTypes:"I", &len];
  [coder encodeArrayOfObjCType:"C" count:len at:[self bytes]];
}

- (void)getBytes: (void*)buf
{
  [self getBytes:buf length:[self length]];
}

- (void)getBytes: (void*)bytes
   length: (unsigned int)length
{
  [self getBytes:bytes range:((NSRange){0, length})];
}

- (void)getBytes: (void*)bytes
   range: (NSRange)aRange
{
  if (NSMaxRange(aRange) > [self length])
    [NSException raise:NSRangeException format:@"Out of bounds of Data."];
  else
    memcpy(bytes, [self bytes] + aRange.location, aRange.length);
  return;
}

- init
{
  return [self initOnBuffer:0
		       size:0
		       type:STATIC_DATA
		  sharedMem:0
		   fileName:0
	        eofPosition:0
		   position:0
	             noCopy:NO];
}

- (id) initWithBytes: (const void*)bytes
	      length: (unsigned int)length
{
  /* We initialize with 'noCopy=NO' so that the designated initializer
     must take a copy of the data in a malloced buffer */
  return [self initOnBuffer:(void*)bytes
		       size:length
		       type:MALLOC_DATA
		  sharedMem:0
		   fileName:0
	        eofPosition:length
		   position:0
	             noCopy:NO];
}

- (id) initWithBytesNoCopy: (void*)bytes
		    length: (unsigned int)length
{
  /* We initialize with 'noCopy=YES' so that the designated initializer
     can simply adopt the buffer it has been given */
  return [self initOnBuffer:bytes
		       size:length
		       type:MALLOC_DATA
		  sharedMem:0
		   fileName:0
	        eofPosition:length
		   position:0
	             noCopy:YES];
}

- (id) initWithCoder: (NSCoder*)coder
{
  unsigned int		len;

  self = [super initWithCoder:coder];
  [coder decodeValuesOfObjCTypes:"I", &len];
  self = [self initOnBuffer:0
		       size:len
		       type:MALLOC_DATA
		  sharedMem:0
		   fileName:0
	        eofPosition:0
		   position:0
	             noCopy:NO];
  [coder decodeArrayOfObjCType:"C" count:len at:buffer];
  eof_position = len;
  position = len;
  return self;
}

- (id) initWithContentsOfFile: (NSString *)path
{
  const char *theFileName;
  FILE *theFile = 0;
  unsigned int length;
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

  theFileName = [path cStringNoCopy];
  theFile = fopen(theFileName, "r");

  if (theFile == NULL)          /* We failed to open the file. */
    goto failure;

  /* Seek to the end of the file. */
  c = fseek(theFile, 0L, SEEK_END);
  if (c != 0)
    goto failure;

  /* Determine the length of the file (having seeked to the end of the
   * file) by calling ftell(). */
  length = ftell(theFile);
  if (length == -1)
    goto failure;

  self = [self initOnBuffer:0
		       size:length
		       type:MALLOC_DATA
		  sharedMem:0
		   fileName:0
	        eofPosition:0
		   position:0
	             noCopy:NO];

  if (self == nil)         /* Out of memory, I guess. */
    goto failure;

  /* Rewind the file pointer to the beginning, preparing to read in
   * the file. */
  c = fseek(theFile, 0L, SEEK_SET);
  if (c != 0)                   /* Oh, No. */
    goto failure;

  c = fread(buffer, 1, length, theFile);
  if (c != length)
    goto failure;

  /* success: */
  eof_position = length;
  return self;

  /* Just in case the failure action needs to be changed. */
 failure:
  if (theFile)
    fclose(theFile);
  if (self)
    [self dealloc];
  return nil;
}

- (id) initWithContentsOfMappedFile: (NSString *)path;
{
#if	MAPPED_SUPP
  return [self initOnBuffer:0
		       size:0
		       type:MAPPED_DATA
		  sharedMem:0
		   fileName:path
	        eofPosition:0
		   position:0
	             noCopy:NO];
#else
  return [self initWithContentsOfFile:path];
#endif
}

- (id) initWithData: (NSData*)data
{
  return [self initWithBytes:[data bytes] length:[data length]];
}

- (BOOL) isEqual: anObject
{
  if ([anObject isKindOfClass:[NSData class]])
    return [self isEqualToData:anObject];
  return NO;
}

- (BOOL) isEqualToData: (NSData*)other;
{
  unsigned int len;
  if ((len = [self length]) != [other length])
    return NO;
  return (memcmp([self bytes], [other bytes], len) ? NO : YES);
}

- (unsigned int)length
{
    return [self streamBufferLength];
}

- (id) mutableCopyWithZone: (NSZone*)zone
{
  NSHMutableData*	obj = [[NSHMutableData class] allocWithZone:zone];
  return [obj initWithData:self];
}

- (id) subdataWithRange: (NSRange)aRange
{
  NSHData*	sub = [[NSHData class] allocWithZone:[self zone]];

  sub = [[sub initOnBuffer:0
		      size:aRange.length
		      type:MALLOC_DATA
		 sharedMem:0
		  fileName:0
	       eofPosition:aRange.length
		  position:0
	            noCopy:NO] autorelease];
  if (sub)
    [self getBytes:(void*)[sub bytes] range:aRange];

  return sub;
}

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


/*
 *	Methos to handle deserializing.
 */
- (unsigned int) deserializeAlignedBytesLengthAtCursor:(unsigned int*)cursor
{
  return *cursor;
}

- (void) deserializeBytes:(void*)buf
		   length:(unsigned int)bytes
		 atCursor:(unsigned int*)cursor
{
  NSRange range = { *cursor, bytes };
  [self getBytes:buf range:range];
  *cursor += bytes;
}

- (void) deserializeDataAt:(void*)data
	       ofObjCType:(const char*)objType
		 atCursor:(unsigned int*)cursor
		  context:(id <NSObjCTypeSerializationCallBack>)callback
{
  if(!objType || !data)
    return;

    switch(*objType) {
	case _C_ID: {
	    [callback deserializeObjectAt:data ofObjCType:objType
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

	    count = atoi(objType + 1);
	    itemType = objType;
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

	    while(*objType != _C_STRUCT_E && *objType++ != '=')
		; /* skip "<name>=" */
	    while(1) {
		[self deserializeDataAt:((char*)data) + offset
			ofObjCType:objType
			atCursor:cursor
			context:callback];
		offset += objc_sizeof_type(objType);
		objType = objc_skip_typespec(objType);
		if(*objType != _C_STRUCT_E) {
		    align = objc_alignof_type(objType);
		    if((rem = offset % align))
			offset += align - rem;
		}
		else break;
	    }
	    break;
        }
        case _C_PTR: {
	    id adr;

	    OBJC_MALLOC (*(char**)data, char, objc_sizeof_type(++objType));
	    adr = [MallocAddress autoreleaseMallocAddress:*(void**)data];

	    [self deserializeDataAt:*(char**)data
		    ofObjCType:objType
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
                format:@"Unknown type to deserialize - '%s'", objType];
    }
}

- (int) deserializeIntAtCursor:(unsigned int*)cursor
{
   unsigned int ni, result;

  [self deserializeBytes:&ni length:sizeof(unsigned int) atCursor:cursor];
  result = network_int_to_host (ni);
  return result;
}

- (int) deserializeIntAtIndex:(unsigned int)index
{
  unsigned int ni;

  [self deserializeBytes:&ni length:sizeof(unsigned int) atCursor:&index];
  return network_int_to_host (ni);
}

- (void) deserializeInts:(int*)intBuffer
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

- (void) deserializeInts:(int*)intBuffer
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


/*
 *	GNUstep extensions to NSData (for Streaming)
 */
+ (void) setVMThreshold:(unsigned int)s
{
  nsdata_vm_threshold = s;
}

- (void) close
{
  [self flushStream];
}

- (void) flushStream
{
  /* Do nothing. */
}

- initOnBuffer: (void*)b                /* data area or nul pointer     */
          size: (unsigned)s             /* size of the data area        */
          type: (NSDataType)t           /* type of storage to use       */
     sharedMem: (int)m                  /* ID of shared memory segment  */
      fileName: (NSString*)n            /* name of mmap file.           */
   eofPosition: (unsigned)l             /* length of data for reading   */
      position: (unsigned)i		/* current pos for read/write   */
        noCopy: (BOOL)f			/* Adopt malloced data?		*/
{
  self = [super init];
  if (self)
    {
#if	SHARED_SUPP == 0
      if (t == SHARED_DATA) t = MALLOC_DATA;
#else
      if (f == NO && s >= nsdata_vm_threshold && t == MALLOC_DATA)
	t = SHARED_DATA;
#endif
#if	MAPPED_SUPP == 0
      if (t == MAPPED_DATA) t = MALLOC_DATA;
#endif

      if (l > s)	/* Can't have eof_position > buffer size */
	l = s;

      if (i > l)	/* Can't have position > eof_position */
	i = l;

      switch (t)
	{
	  case STATIC_DATA:
	    buffer = b;
	    if (buffer == 0)
	      {
		buffer = "";
		s = 0;
		l = 0;
		i = 0;
	      }
	    break;

#if	MAPPED_SUPP
	  case MAPPED_DATA:
	    if (n == nil)
	      {
		[self dealloc];
		return nil;
	      }
	    else
	      {
		int	fd;

		if ([self isWritable])
		  fd = open([n cStringNoCopy], O_RDWR);
		else
		  fd = open([n cStringNoCopy], O_RDONLY);
		if (fd < 0)
		  {
		    [self dealloc];
		    return nil;
		  }
		/* Find size of file to be mapped. */
		s = lseek(fd, 0, SEEK_END);
		if (s < 0)
		  {
		    close(fd);
		    [self dealloc];
		    return nil;
		  }
		/* Position at start of file. */
		(void)lseek(fd, 0, SEEK_SET);
		if ([self isWritable])
		  buffer = mmap(0, s, PROT_READ|PROT_WRITE, MAP_PRIVATE, fd, 0);
		else
		  buffer = mmap(0, s, PROT_READ, MAP_PRIVATE, fd, 0);
		close(fd);
		if (buffer == MAP_FAILED)
		  {
		    [self dealloc];
		    return nil;
		  }
		l = s;
		if (i > l)	/* Can't have position > eof_position */
		  i = l;
	      }
	    break;

#endif
#if	SHARED_SUPP
	  case SHARED_DATA:
	    if (m == 0)
	      {
		struct shmid_ds	buf;

		if ([self isWritable])
		  if (s % VM_CHUNK)
		    s = ((s / VM_CHUNK) + 1) * VM_CHUNK;
		m = shmget(IPC_PRIVATE, s, IPC_CREAT|VM_ACCESS);
		if (m == -1)			/* Created memory? */
		  {
		    [self dealloc];
		    return nil;
		  }
		buffer = shmat(m, 0, 0);
		shmctl(m, IPC_RMID, &buf);	/* Mark for later deletion. */
		if ((int)buffer == -1)		/* Attached memory? */
		  {
		    [self dealloc];
		    return nil;
		  }
		shm_id = m;
		if (l > 0)
		  memset(buffer, '\0', l);
	      }
	    else
	      {
		struct shmid_ds	buf;

		if (shmctl(m, IPC_STAT, &buf) < 0)
		  {
		    [self dealloc];	/* Unable to access memory. */
		    return nil;
		  }
		if (buf.shm_segsz < s)
		  {
		    [self dealloc];	/* Memory segment too small. */
		    return nil;
		  }
		buffer = shmat(m, 0, 0);
		if (buffer == 0)
		  {
		    [self dealloc];	/* Unable to attach to memory. */
		    return nil;
		  }
		shm_id = m;
		if (l > 0)
		  memcpy(buffer, b, l);
	      }
	    break;

#endif
	  case MALLOC_DATA:
	  default:
	    if (f == YES)
	      buffer = b;		/* We have been given control. */
	    else
	      {			/* Can't free it, so make copy */
		buffer = objc_malloc(s);
		if (buffer == 0)
		  {
		    [self dealloc];
		    return nil;
		  }
		if (l > 0)
		  if (b == 0)
		    memset(buffer, '\0', l);
		  else
		    memcpy(buffer, b, l);
	      }
	    break;
	}
      type = t;
      size = s;
      eof_position = l;
      position = i;
    }
  return self;
}

- (id) initWithCapacity: (unsigned int)capacity
{
  return [self initOnBuffer:0
		       size:capacity
		       type:MALLOC_DATA
		  sharedMem:0
		   fileName:0
	        eofPosition:0
		   position:0
	             noCopy:NO];
}

- (BOOL) isAtEof
{
  if (position == eof_position)
    return YES;
  return NO;
}

- (BOOL) isClosed
{
  return NO;
}

- (BOOL) isWritable
{
  return NO;
}

- (int) readByte: (unsigned char*)b
{
  return [self readBytes:b length:1];
}

- (int) readBytes: (void*)b length: (int)l
{
  if (position+l > eof_position)
    l = eof_position-position;
  memcpy(b, buffer+position, l);
  position += l;
  return l;
}

- (int) readFormat: (NSString*)format
	 arguments: (va_list)arg
{
 return 0;
}

- (int) readFormat: (NSString*)format, ...
{
  int ret;
  va_list ap;

  va_start(ap, format);
  ret = o_vscanf(self, inchar_func, unchar_func,
		       [format cStringNoCopy], ap);
  va_end(ap);
  return ret;
}

- (NSString*) readLine
{
  char *nl = memchr(buffer+position, '\n', eof_position-position);
  char *ret = NULL;
  if (nl)
    {
      int len = nl-buffer-position;
      ret = objc_malloc (len+1);
      strncpy(ret, buffer+position, len);
      ret[len] = '\0';
      position += len+1;
    }
  return [[[NSString alloc] initWithCStringNoCopy: ret
			    length: ret ? strlen(ret) : 0
			    freeWhenDone: YES]
	   autorelease];
}


- (void) rewindStream
{
  [self setStreamPosition:0];
}

- (void) setFreeWhenDone: (BOOL)f
{
  [self notImplemented:_cmd];
}

- (void) setStreamBufferCapacity: (unsigned)s
{
  /* Nul operation for non-mutable object. */
}

- (void) setStreamEofPosition: (unsigned)i
{
  if (i < size)
    eof_position = i;
}

- (void) setStreamPosition: (unsigned)i  seekMode: (seek_mode_t)mode
{
  int	newposition = 0;

  switch (mode)
    {
    case STREAM_SEEK_FROM_START:
      newposition = i;
      break;
    case STREAM_SEEK_FROM_CURRENT:
      newposition += i;
      break;
    case STREAM_SEEK_FROM_END:
      newposition = eof_position + i;
      break;
    }
  if (newposition < 0)
    newposition = 0;
  if (newposition > eof_position)
    {
      [self setStreamEofPosition:newposition];
      position = eof_position;
    }
  else
    position = newposition;
}

- (void) setStreamPosition: (unsigned)i
{
  [self setStreamPosition: i seekMode: STREAM_SEEK_FROM_START];
}

- (char*) streamBuffer
{
  return 0;
}

- (unsigned) streamBufferCapacity
{
  return size;
}

- (unsigned) streamBufferLength
{
  return eof_position;
}

- (BOOL) streamEof
{
  if (position == eof_position)
    return YES;
  else
    return NO;
}

- (unsigned) streamEofPosition
{
  return eof_position;
}

- (unsigned) streamPosition
{
  return position;
}

- (unsigned int)vmThreshold
{
  return nsdata_vm_threshold;
}

- (int) writeByte: (unsigned char)b
{
  /* Nul operation for non-mutable object. */
  return 0;
}

- (int) writeBytes: (const void*)b length: (int)l
{
  /* Nul operation for non-mutable object. */
  return 0;
}

- (int) writeFormat: (NSString*)format
	  arguments: (va_list)arg
{
  /* Nul operation for non-mutable object. */
  return 0;
}

- (int) writeFormat: (NSString*)format, ...
{
  /* Nul operation for non-mutable object. */
  return 0;
}

- (void) writeLine: (NSString*)l
{
  /* Nul operation for non-mutable object. */
}

@end


@implementation NSHMutableData

+ allocWithZone:(NSZone *)zone
{
  return NSAllocateObject([NSHMutableData class], 0, zone);
}

+ (id) dataWithCapacity: (unsigned int)numBytes
{
  return [[[self alloc] initWithCapacity:numBytes] autorelease];
}

+ (id) dataWithLength: (unsigned int)length
{
  return [[[self alloc] initWithLength:length] autorelease];
}

- (void)appendBytes:(const void*)b
             length:(unsigned int)l
{
  if ((eof_position + l) >= size)
    [self increaseCapacityBy:eof_position + l - size];
  memcpy(&buffer[eof_position], b, l);
  eof_position += l;
}

- (void) appendData: (NSData*)other
{
  [self appendBytes:[other bytes] length:[other length]];
}

- (void)increaseLengthBy:(unsigned int)extraLength
{
  [self setLength:[self length] + extraLength];
}

- (id) initWithLength: (unsigned int)length
{
  return [self initOnBuffer:0
		       size:length
		       type:MALLOC_DATA
		  sharedMem:0
		   fileName:0
	        eofPosition:length
		   position:0
	             noCopy:NO];
}

- (void*)mutableBytes
{
    return buffer;
}

- (void) replaceBytesInRange: (NSRange)aRange
                   withBytes: (const void*)bytes
{
  if (aRange.location > size)
    [NSException raise:NSRangeException
                format:@"replacement location beyond end of data"];
  if (aRange.length == 0)
    return;
  if (aRange.location + aRange.length >= size)
    [self increaseCapacityBy:aRange.location + aRange.length - size];
  memcpy([self mutableBytes] + aRange.location, bytes, aRange.length);
}

- (void) resetBytesInRange: (NSRange)aRange
{
  if (aRange.location > size)
    [NSException raise:NSRangeException
                format:@"reset location beyond end of data"];
  if (aRange.length == 0)
    return;
  if (aRange.location + aRange.length >= size)
    [self increaseCapacityBy:aRange.location + aRange.length - size];
  memset((char*)[self bytes] + aRange.location, 0, aRange.length);
}

- (void) setData:(NSData*) other
{
  NSRange range;

  [self setLength:[other length]];
  range.location = 0;
  range.length = [self length];
  [self replaceBytesInRange:range withBytes:[other bytes]];
}

- (void) setLength:(unsigned int)l
{
  [self setStreamEofPosition:l];
}


/*
 *	Methods to handle serializing.
 */
- (void) serializeAlignedBytesLength:(unsigned int)length
{
}

- (void) serializeDataAt:(const void*)data
	      ofObjCType:(const char*)objType
		 context:(id <NSObjCTypeSerializationCallBack>)callback
{
  if(!data || !objType)
    return;

    switch(*objType) {
        case _C_ID: {
	    [callback serializeObjectAt:(id*)data
			ofObjCType:objType
			intoData:(NSMutableData*)self];
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
            int i, offset, itemSize, count = atoi(objType + 1);
            const char* itemType = objType;

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

            while(*objType != _C_STRUCT_E && *objType++ != '=')
		; /* skip "<name>=" */
            while(1) {
                [self serializeDataAt:((char*)data) + offset
			ofObjCType:objType
			context:callback];
                offset += objc_sizeof_type(objType);
                objType = objc_skip_typespec(objType);
                if(*objType != _C_STRUCT_E) {
                    align = objc_alignof_type(objType);
                    if((rem = offset % align))
                        offset += align - rem;
                }
                else break;
            }
            break;
        }
	case _C_PTR:
	    [self serializeDataAt:*(char**)data
		    ofObjCType:++objType context:callback];
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
                format:@"Unknown type to deserialize - '%s'", objType];
    }
}

- (void) serializeInt:(int)value
{
    unsigned int ni = host_int_to_network (value);
    [self appendBytes:&ni length:sizeof(unsigned int)];
}

- (void) serializeInt:(int)value
	      atIndex:(unsigned int)index
{
    unsigned int ni = host_int_to_network (value);
    NSRange range = { index, sizeof(int) };
    [self replaceBytesInRange:range withBytes:&ni];
}

- (void) serializeInts:(int*)intBuffer
		 count:(unsigned int)numInts
{
    unsigned i;
    SEL selector = @selector (serializeInt:);
    IMP imp = [self methodForSelector:selector];

    for (i = 0; i < numInts; i++)
	(*imp)(self, selector, intBuffer[i]);
}

- (void) serializeInts:(int*)intBuffer
		 count:(unsigned int)numInts
	       atIndex:(unsigned int)index
{
    unsigned i;
    SEL selector = @selector (serializeInt:atIndex:);
    IMP imp = [self methodForSelector:selector];

    for (i = 0; i < numInts; i++)
	(*imp)(self, selector, intBuffer[i], index++);
}


/*
 *	GNUstep extensions to NSHMutableData
 */
- (void)increaseCapacityBy:(unsigned int)extraCapacity
{
  [self setStreamBufferCapacity:size + extraCapacity];
}

- initOnBuffer: (void*)b                /* data area or nul pointer     */
          size: (unsigned)s             /* size of the data area        */
          type: (NSDataType)t           /* type of storage to use       */
     sharedMem: (int)m                  /* ID of shared memory segment  */
      fileName: (NSString*)n            /* name of mmap file.           */
   eofPosition: (unsigned)l             /* length of data for reading   */
      position: (unsigned)i		/* current pos for read/write   */
        noCopy: (BOOL)f			/* Adopt malloced data?		*/
{
  self = [super initOnBuffer: b
		        size: s
		        type: t
		   sharedMem: m
		    fileName: n
		 eofPosition: l
		    position: i
		      noCopy: f];
  if (self)
    vm_threshold = nsdata_vm_threshold;
  return self;
}

- (BOOL) isWritable
{
  return YES;
}

/*
 *	Warning - this method raises an exception if no memory is available.
 */
- (void) setStreamBufferCapacity: (unsigned)s
{
  BOOL	resize = NO;
  int	newtype = MALLOC_DATA;

  if (s > size)
    resize = YES;
#if SHARED_SUPP
  if (size >= [self vmThreshold])
    newtype = SHARED_DATA;
    if (type == MALLOC_DATA)
      resize = YES;
  if (size < [self vmThreshold])
    newtype = MALLOC_DATA;
    if (type == SHARED_DATA)
      resize = YES;
#endif

  if (resize)
    {
      if (newtype == MALLOC_DATA)
	{
	  if (buffer)
	    {
	      void*	tmp = 0;

	      if (type == MALLOC_DATA)
		tmp = objc_realloc(buffer, s);

	      if (tmp)
		buffer = tmp;	/* It worked. */
	      else
		{
		  tmp = objc_malloc(s);
		  if (tmp == 0)
		    [NSException raise:NSMallocException
			format:@"Unable to malloc data - %s.", strerror(errno)];
		  memcpy(tmp, buffer, position);
  #if	SHARED_SUPP
		  if (type == SHARED_DATA)
		    shmdt(buffer);
		  else
  #endif
  #if	MAPPED_SUPP
		  if (type == MAPPED_DATA)
		    munmap(buffer, size);
		  else
  #endif
		  if (type != STATIC_DATA)
		    objc_free(buffer);
		  buffer = tmp;
		}
	    }
	  else
	    buffer = objc_malloc(s);
	}
#if	SHARED_SUPP
      else
	{
	  struct shmid_ds	buf;
	  int		shmid;
	  char*		b;

	  if (s % VM_CHUNK) s = ((s / VM_CHUNK) + 1) * VM_CHUNK;
	  shmid = shmget(IPC_PRIVATE, s, IPC_CREAT|VM_ACCESS);
	  if (shmid == -1)			/* Created memory? */
	    [NSException raise:NSMallocException
			format:@"Unable to create shared memory segment - %s.",
			strerror(errno)];
	  b = shmat(shmid, 0, 0);
	  shmctl(shmid, IPC_RMID, &buf);	/* Mark for later deletion. */
	  if ((int)b == -1)			/* Attached memory? */
	    [NSException raise:NSMallocException
			format:@"Unable to attach to shared memory segment."];
	  if (eof_position > 0)
	    memcpy(b, buffer, eof_position);
	  if (buffer)
	    if (type == MALLOC_DATA)
	      objc_free(buffer);
#if	MAPPED_SUPP
	    else if (type == MAPPED_DATA)
	      munmap(buffer, size);
#endif
	    else if (type == SHARED_DATA)
	      shmdt(buffer);
	  buffer = b;
	  shm_id = shmid;
	}
#endif
      size = s;
      type = newtype;
    }
}

- (void) setStreamEofPosition: (unsigned)i
{
  if (i >= size)
    [self setStreamBufferCapacity:i];
  [super setStreamEofPosition:i];
}

- (void) setVMThreshold:(unsigned int)s
{
  vm_threshold = s;
  /* Force change in memory allocation if appropriate.	*/
  [self setStreamBufferCapacity:size];
}

- (char*) streamBuffer
{
  return buffer;
}

- (unsigned int)vmThreshold
{
  return vm_threshold;
}

- (int) writeByte: (unsigned char)b
{
  return [self writeBytes:&b length:1];
}

- (int) writeBytes: (const void*)b length: (int)l
{
  if (position+l > size)
    {
      unsigned int	want = MAX(position+l, size*2);

      [self setStreamBufferCapacity: want];
    }
  memcpy(buffer+position, b, l);
  position += l;
  if (position > eof_position)
    eof_position = position;
  return l;
}

#if HAVE_VSPRINTF
- (int) writeFormat: (NSString*)format
	  arguments: (va_list)arg
{
  int ret;

  /* xxx Using this ugliness we at least let ourselves safely print
     formatted strings up to 128 bytes long.
     It's digusting, though, and we need to fix it.
     Using GNU stdio streams would do the trick.
     */
  if (size - position < 128)
    [self setStreamBufferCapacity:position+128];

  ret = VSPRINTF_LENGTH (vsprintf(buffer+position,
				  [format cStringNoCopy], arg));
  position += ret;
  /* xxx Make sure we didn't overrun our buffer.
     As per above kludge, this would happen if we happen to have more than
     128 bytes left in the buffer and we try to write a string longer than
     the num bytes left in the buffer. */
  assert(position <= size);
  if (position > eof_position)
    eof_position = position;
  return ret;
}
#else
- (int) writeFormat: (NSString*)format
	  arguments: (va_list)arg
{
  [self notImplemented:_cmd];
}
#endif

- (int) writeFormat: (NSString*)format, ...
{
  int ret;
  va_list ap;

  va_start(ap, format);
  ret = [self writeFormat: format arguments: ap];
  va_end(ap);
  return ret;
}

- (void) writeLine: (NSString*)l
{
  const char *s = [l cStringNoCopy];
  [self writeBytes:s length:strlen(s)];
  [self writeBytes:"\n" length:1];
}
@end
