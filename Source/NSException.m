/** NSException - Object encapsulation of a general exception handler
   Copyright (C) 1993, 1994, 1996, 1997, 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   $Date$ $Revision$
*/

#include "config.h"
#include "GNUstepBase/preface.h"
#include <Foundation/NSDebug.h>
#include <Foundation/NSBundle.h>
#include "Foundation/NSException.h"
#include "Foundation/NSString.h"
#include "Foundation/NSArray.h"
#include "Foundation/NSCoder.h"
#include "Foundation/NSNull.h"
#include "Foundation/NSThread.h"
#include "Foundation/NSLock.h"
#include "Foundation/NSDictionary.h"
#include <stdio.h>

#if	defined(__MINGW32__)
static NSString *
GSPrivateBaseAddress(void *addr, void **base)
{
  return nil;
}
#else	/* __MINGW32__ */

#ifndef GNU_SOURCE
#define GNU_SOURCE
#endif
#ifndef __USE_GNU
#define __USE_GNU
#endif
#include <dlfcn.h>

static NSString *
GSPrivateBaseAddress(void *addr, void **base)
{
#ifdef HAVE_DLADDR
  Dl_info     info;

  if (!dladdr(addr, &info))
    return nil;

  *base = info.dli_fbase;

  return [NSString stringWithUTF8String: info.dli_fname];
#else
  return nil;
#endif
}
#endif	/* __MINGW32__ */


/* This is the GNU name for the CTOR list */

@interface GSStackTrace : NSObject
{
  NSMutableArray *frames;
}
+ (GSStackTrace*) currentStack;

- (NSString*) description;
- (NSEnumerator*) enumerator;
- (id) frameAt: (unsigned)index;
- (unsigned) frameCount;
- (NSEnumerator*) reverseEnumerator;

@end

#define	STACKSYMBOLS	1

/*
 * Turn off STACKSYMBOLS if we don't have bfd support for it.
 */
#if !(defined(HAVE_BFD_H) && defined(HAVE_LIBBFD) && defined(HAVE_LIBIBERTY))
#if	defined(STACKSYMBOLS)
#undef	STACKSYMBOLS
#endif
#endif

/*
 * Turn off STACKSYMBOLS if we don't have DEBUG defined ... if we are not built
 * with DEBUG then we are probably missing stackframe information etc.
 */
#if !(defined(DEBUG))
#if	defined(STACKSYMBOLS)
#undef	STACKSYMBOLS
#endif
#endif

#if	defined(STACKSYMBOLS)

// GSStackTrace inspired by  FYStackTrace.m
// created by Wim Oudshoorn on Mon 11-Apr-2006
// reworked by Lloyd Dupont @ NovaMind.com  on 4-May-2006

#include <bfd.h>

@class GSBinaryFileInfo;

@interface GSFunctionInfo : NSObject
{
  void			*_address;
  NSString		*_fileName;
  NSString		*_functionName;
  int			_lineNo;
  GSBinaryFileInfo	*_module;
}
- (void*) address;
- (NSString *) fileName;
- (NSString *) function;
- (id) initWithModule: (GSBinaryFileInfo*)module
	      address: (void*)address 
		 file: (NSString*)file 
	     function: (NSString*)function 
		 line: (int)lineNo;
- (int) lineNumber;
- (GSBinaryFileInfo*) module;

@end


@interface GSBinaryFileInfo : NSObject
{
  NSString	*_fileName;
  bfd		*_abfd;
  asymbol	**_symbols;
  long		_symbolCount;
}
- (NSString *) fileName;
- (GSFunctionInfo *) functionForAddress: (void*) address;
- (id) initWithBinaryFile: (NSString *)fileName;
- (id) init; // return info for the current executing process

@end



@implementation GSFunctionInfo

- (void*) address
{
  return _address;
}

- (oneway void) dealloc
{
  [_module release];
  _module = nil;
  [_fileName release];
  _fileName = nil;
  [_functionName release];
  _functionName = nil;
  [super dealloc];
}

- (NSString *) description
{
  return [NSString stringWithFormat: @"(%@: %p) %@  %@: %d",
    [_module fileName], _address, _functionName, _fileName, _lineNo];
}

- (NSString *) fileName
{
  return _fileName;
}

- (NSString *) function
{
  return _functionName;
}

- (id) init
{
  [self release];
  return nil;
}

- (id) initWithModule: (GSBinaryFileInfo*)module
	      address: (void*)address 
		 file: (NSString*)file 
	     function: (NSString*)function 
		 line: (int)lineNo
{
  _module = [module retain];
  _address = address;
  _fileName = [file retain];
  _functionName = [function retain];
  _lineNo = lineNo;

  return self;
}

- (int) lineNumber
{
  return _lineNo;
}

- (GSBinaryFileInfo *) module
{
  return _module;
}

@end



@implementation GSBinaryFileInfo

+ (GSBinaryFileInfo*) infoWithBinaryFile: (NSString *)fileName
{
  return [[[self alloc] initWithBinaryFile: fileName] autorelease];
}

+ (void) initialize
{
  static BOOL first = YES;

  if (first == NO)
    {
      return;
    }
  first = NO;
  bfd_init ();
}

- (oneway void) dealloc
{
  [_fileName release];
  _fileName = nil;
  if (_abfd)
    {
      bfd_close (_abfd);
      _abfd = NULL;
    }
  if (_symbols)
    {
      objc_free (_symbols);
      _symbols = NULL;
    }
  [super dealloc];
}

- (NSString *) fileName
{
  return _fileName;
}

- (id) init
{
  NSString *processName;

  processName = [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0];
  return [self initWithBinaryFile: processName];
}

- (id) initWithBinaryFile: (NSString *)fileName
{
  int neededSpace;

  // 1st initialize the bfd
  if ([fileName length] == 0)
    {
      //NSLog (@"GSBinaryFileInfo: No File");
      [self release];
      return nil;
    }
  _fileName = [fileName copy];
  _abfd = bfd_openr ([fileName cString], NULL);
  if (!_abfd)
    {
      //NSLog (@"GSBinaryFileInfo: No Binary Info");
      [self release];
      return nil;
    }
  if (!bfd_check_format_matches (_abfd, bfd_object, NULL))
    {
      //NSLog (@"GSBinaryFileInfo: BFD format object error");
      [self release];
      return nil;
    }

  // second read the symbols from it
  if (!(bfd_get_file_flags (_abfd) & HAS_SYMS))
    {
      //NSLog (@"GSBinaryFileInfo: BFD does not contain any symbols");
      [self release];
      return nil;
    }

  neededSpace = bfd_get_symtab_upper_bound (_abfd);
  if (neededSpace < 0)
    {
      //NSLog (@"GSBinaryFileInfo: BFD error while deducing needed space");
      [self release];
      return nil;
    }
  if (neededSpace == 0)
    {
      //NSLog (@"GSBinaryFileInfo: BFD no space for symbols needed");
      [self release];
      return nil;
    }
  _symbols = objc_malloc (neededSpace);
  if (!_symbols)
    {
      //NSLog (@"GSBinaryFileInfo: Can't allocate buffer");
      [self release];
      return nil;
    }
  _symbolCount = bfd_canonicalize_symtab (_abfd, _symbols);
  if (_symbolCount < 0)
    {
      //NSLog (@"GSBinaryFileInfo: BFD error while reading symbols");
      [self release];
      return nil;
    }

  return self;
}

struct SearchAddressStruct
{
  void			*theAddress;
  GSBinaryFileInfo	*module;
  asymbol		**symbols;
  GSFunctionInfo	*theInfo;
};

static void find_address (bfd *abfd, asection *section,
  struct SearchAddressStruct *info)
{
  bfd_vma	address;
  bfd_vma	vma;
  unsigned	size;
  const char	*fileName;
  const char	*functionName;
  unsigned	line = 0;

  if (info->theInfo)
    {
      return;
    }
  if (!(bfd_get_section_flags (abfd, section) & SEC_ALLOC))
    {
      return;
    }

  address = (bfd_vma) (intptr_t)info->theAddress;

  vma = bfd_get_section_vma (abfd, section);

#if     defined(bfd_get_section_size)
  size = bfd_get_section_size (section);        // recent
#else                                
  size = bfd_section_size (abfd, section);      // older version
#endif                               
     
  if (address < vma || address >= vma + size)
    {
      return;
    }

  if (bfd_find_nearest_line (abfd, section, info->symbols,
    address - vma, &fileName, &functionName, &line))
    {
      GSFunctionInfo	*fi;
      NSString		*file = nil;
      NSString		*func = nil;

      if (fileName != 0)
        {
	  file = [NSString stringWithCString: fileName 
	    encoding: [NSString defaultCStringEncoding]];
	}
      if (functionName != 0)
        {
	  func = [NSString stringWithCString: functionName 
	    encoding: [NSString defaultCStringEncoding]];
	}
      fi = [GSFunctionInfo alloc];
      fi = [fi initWithModule: info->module
		      address: info->theAddress
			 file: file
		     function: func
			 line: line];
      [fi autorelease];
      info->theInfo = fi;
    }
}

- (GSFunctionInfo *) functionForAddress: (void*) address
{
  struct SearchAddressStruct searchInfo = { address, self, _symbols, nil };

  bfd_map_over_sections (_abfd,
    (void (*) (bfd *, asection *, void *)) find_address, &searchInfo);
  return searchInfo.theInfo;
}

@end

static NSRecursiveLock		*modLock = nil;
static NSMutableDictionary	*stackModules = nil;

// initialize stack trace info
static id
GSLoadModule(NSString *fileName)
{
  GSBinaryFileInfo	*module = nil;

  [modLock lock];

  if (stackModules == nil)
    {
      NSEnumerator	*enumerator;
      NSBundle		*bundle;

      stackModules = [NSMutableDictionary new];

      /*
       * Try to ensure we have the main, base and gui library bundles.
       */
      [NSBundle mainBundle];
      [NSBundle bundleForClass: [NSObject class]];
      [NSBundle bundleForClass: NSClassFromString(@"NSView")];

      /*
       * Add file info for all bundles with code.
       */
      enumerator = [[NSBundle allBundles] objectEnumerator];
      while ((bundle = [enumerator nextObject]) != nil)
	{
	  if ([bundle load] == YES)
	    {
	      GSLoadModule([bundle executablePath]);
	    }
	}
    }

  if ([fileName length] > 0)
    {
      module = [stackModules objectForKey: fileName];
      if (module == nil);
	{
	  module = [GSBinaryFileInfo infoWithBinaryFile: fileName];
	  if (module == nil)
	    {
	      module = (id)[NSNull null];
	    }
	  if ([stackModules objectForKey: fileName] == nil)
	    {
	      [stackModules setObject: module forKey: fileName];
	    }
	  else
	    {
	      module = [stackModules objectForKey: fileName];
	    }
	}
    }
  [modLock unlock];

  if (module == (id)[NSNull null])
    {
      module = nil;
    }
  return module;
}

static NSArray*
GSListModules()
{
  NSArray	*result;

  GSLoadModule(nil);	// initialise
  [modLock lock];
  result = [stackModules allValues];
  [modLock unlock];
  return result;
}

#endif	/* STACKSYMBOLS */


@implementation GSStackTrace : NSObject

+ (GSStackTrace*) currentStack
{
  return [[[GSStackTrace alloc] init] autorelease];
}

- (oneway void) dealloc
{
  [frames release];
  frames = nil;

  [super dealloc];
}

- (NSString*) description
{
  NSMutableString *result = [NSMutableString string];
  int i;
  int n;

  n = [frames count];
  for (i = 0; i < n; i++)
    {
      id	line = [frames objectAtIndex: i];

      [result appendFormat: @"%3d: %@\n", i, line];
    }
  return result;
}

- (NSEnumerator*) enumerator
{
  return [frames objectEnumerator];
}

- (id) frameAt: (unsigned)index
{
  return [frames objectAtIndex: index];
}

- (unsigned) frameCount
{
  return [frames count];
}

// grab the current stack 
- (id) init
{
#if	defined(STACKSYMBOLS)
  int i;
  int n;

  frames = [[NSMutableArray alloc] init];
  n = NSCountFrames();

  for (i = 0; i < n; i++)
    {
      GSFunctionInfo	*aFrame = nil;
      void		*address = NSReturnAddress(i);
      void		*base;
      NSString		*modulePath = GSPrivateBaseAddress(address, &base);
      GSBinaryFileInfo	*bfi;

      if (modulePath != nil && (bfi = GSLoadModule(modulePath)) != nil)
        {
	  aFrame = [bfi functionForAddress: (void*)(address - base)];
	  if (aFrame == nil)
	    {
	      /* We know we have the right module be function lookup
	       * failed ... perhaps we need to use the absolute
	       * address rather than offest by 'base' in this case.
	       */
	      aFrame = [bfi functionForAddress: address];
	    }
//if (aFrame == nil) NSLog(@"BFI base for %@ (%p) is %p", modulePath, address, base);
	}
      else
        {
	  NSArray	*modules;
	  int		j;
	  int		m;

//if (modulePath != nil) NSLog(@"BFI not found for %@ (%p)", modulePath, address);

	  modules = GSListModules();
	  m = [modules count];
	  for (j = 0; j < m; j++)
	    {
	      bfi = [modules objectAtIndex: j];

	      if ((id)bfi != (id)[NSNull null])
		{
		  aFrame = [bfi functionForAddress: address];
		  if (aFrame != nil)
		    {
		      break;
		    }
		}
	    }
	}

      // not found (?!), add an 'unknown' function
      if (aFrame == nil)
	{
	  aFrame = [GSFunctionInfo alloc];
	  [aFrame initWithModule: nil
			 address: address 
			    file: nil
			function: nil
			    line: 0];
	  [aFrame autorelease];
	}
      [frames addObject: aFrame];
    }
#else
  int i;
  int n;

  frames = [[NSMutableArray alloc] init];
  n = NSCountFrames();

  for (i = 0; i < n; i++)
    {
      void		*address = NSReturnAddress(i);

      [frames addObject: [NSString stringWithFormat: @"%p", address]];
    }
#endif

  return self;
}

- (NSEnumerator*) reverseEnumerator
{
  return [frames reverseObjectEnumerator];
}

@end





NSString* const NSGenericException
  = @"NSGenericException";

NSString* const NSInternalInconsistencyException
  = @"NSInternalInconsistencyException";

NSString* const NSInvalidArgumentException
  = @"NSInvalidArgumentException";

NSString* const NSMallocException
  = @"NSMallocException";

NSString* const NSRangeException
 = @"NSRangeException";

NSString* const NSCharacterConversionException
  = @"NSCharacterConversionException";

NSString* const NSParseErrorException
  = @"NSParseErrorException";

#include "GSPrivate.h"

static void _terminate()
{
  BOOL			shouldAbort;

#ifdef	DEBUG
  shouldAbort = YES;		// abort() by default.
#else
  shouldAbort = NO;		// exit() by default.
#endif
  shouldAbort = GSPrivateEnvironmentFlag("CRASH_ON_ABORT", shouldAbort);
  if (shouldAbort == YES)
    {
      abort();
    }
  else
    {
      exit(1);
    }
}

static void
_NSFoundationUncaughtExceptionHandler (NSException *exception)
{
  NSString	*stack;

  fprintf(stderr, "%s: Uncaught exception %s, reason: %s\n",
    GSPrivateArgZero(),
    [[exception name] lossyCString], [[exception reason] lossyCString]);
  fflush(stderr);	/* NEEDED UNDER MINGW */
  stack = [[[exception userInfo] objectForKey: @"GSStackTraceKey"] description];
  if (stack != nil)
    {
      fprintf(stderr, "Stack\n%s\n", [stack lossyCString]);
    }
  fflush(stderr);	/* NEEDED UNDER MINGW */

  _terminate();
}

@implementation NSException

#if	defined(STACKSYMBOLS)
+ (void) initialize
{
  if (modLock == nil)
    {
      modLock = [NSRecursiveLock new];
    }
}
#endif	/* STACKSYMBOLS */

+ (NSException*) exceptionWithName: (NSString*)name
			    reason: (NSString*)reason
			  userInfo: (NSDictionary*)userInfo
{
  return AUTORELEASE([[self alloc] initWithName: name reason: reason
				   userInfo: userInfo]);
}

+ (void) raise: (NSString*)name
	format: (NSString*)format,...
{
  va_list args;

  va_start(args, format);
  [self raise: name format: format arguments: args];
  // This probably doesn't matter, but va_end won't get called
  va_end(args);
}

+ (void) raise: (NSString*)name
	format: (NSString*)format
     arguments: (va_list)argList
{
  NSString	*reason;
  NSException	*except;

  reason = [NSString stringWithFormat: format arguments: argList];
  except = [self exceptionWithName: name reason: reason userInfo: nil];
  [except raise];
}

- (id) initWithName: (NSString*)name
	     reason: (NSString*)reason
	   userInfo: (NSDictionary*)userInfo
{
  ASSIGN(_e_name, name);
  ASSIGN(_e_reason, reason);
  ASSIGN(_e_info, userInfo);
  return self;
}

- (void) dealloc
{
  DESTROY(_e_name);
  DESTROY(_e_reason);
  DESTROY(_e_info);
  [super dealloc];
}

- (void) raise
{
#ifndef _NATIVE_OBJC_EXCEPTIONS
  NSThread	*thread;
  NSHandler	*handler;
#endif

#if	defined(DEBUG)
  if (GSPrivateEnvironmentFlag("GNUSTEP_STACK_TRACE", NO) == YES
    && [_e_info objectForKey: @"GSStackTraceKey"] == nil)
    {
      NSMutableDictionary	*m;

      if (_e_info == nil)
	{
	  _e_info = m = [NSMutableDictionary new];
	}
      else if ([_e_info isKindOfClass: [NSMutableDictionary class]] == YES)
        {
	  m = (NSMutableDictionary*)_e_info;
        }
      else
	{
	  m = [_e_info mutableCopy];
	  RELEASE(_e_info);
	  _e_info = m;
	}
      [m setObject: [GSStackTrace currentStack] forKey: @"GSStackTraceKey"];
    }
#endif

#ifdef _NATIVE_OBJC_EXCEPTIONS
  @throw self;
#else
  thread = GSCurrentThread();
  handler = thread->_exception_handler;
  if (handler == NULL)
    {
      static	BOOL	recursion = NO;

      /*
       * Set a flag to prevent recursive uncaught exceptions.
       */
      if (recursion == NO)
	{
	  recursion = YES;
	}
      else
	{
	  fprintf(stderr,
	    "recursion encountered handling uncaught exception\n");
	  fflush(stderr);	/* NEEDED UNDER MINGW */
	  _terminate();
	}

      /*
       * Call the uncaught exception handler (if there is one).
       */
      if (_NSUncaughtExceptionHandler != NULL)
	{
	  (*_NSUncaughtExceptionHandler)(self);
	}

      /*
       * The uncaught exception handler which is set has not
       * exited, so we call the builtin handler, (undocumented
       * behavior of MacOS-X).
       * The standard handler is guaranteed to exit/abort.
       */
      _NSFoundationUncaughtExceptionHandler(self);
    }

  thread->_exception_handler = handler->next;
  handler->exception = self;
  longjmp(handler->jumpState, 1);
#endif
}

- (NSString*) name
{
  if (_e_name != nil)
    {
      return _e_name;
    }
  else
    {
      return NSStringFromClass([self class]);
    }
}

- (NSString*) reason
{
  if (_e_reason != nil)
    {
      return _e_reason;
    }
  else
    {
      return @"unspecified reason";
    }
}

- (NSDictionary*) userInfo
{
  return _e_info;
}

- (Class) classForPortCoder
{
  return [self class];
}

- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  return self;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_name];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_reason];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_info];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_name];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_reason];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_info];
  return self;
}

- (id) deepen
{
  _e_name = [_e_name copyWithZone: [self zone]];
  _e_reason = [_e_reason copyWithZone: [self zone]];
  _e_info = [_e_info copyWithZone: [self zone]];
  return self;
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    return RETAIN(self);
  else
    return [(NSException*)NSCopyObject(self, 0, zone) deepen];
}

- (NSString*) description
{
  if (_e_info)
    return [NSString stringWithFormat: @"%@ NAME:%@ REASON:%@ INFO:%@",
	[super description], _e_name, _e_reason, _e_info];
  else
    return [NSString stringWithFormat: @"%@ NAME:%@ REASON:%@",
	[super description], _e_name, _e_reason];
}

@end


void
_NSAddHandler (NSHandler* handler)
{
  NSThread *thread;

  thread = GSCurrentThread();
#if defined(__MINGW32__) && defined(DEBUG)
  if (thread->_exception_handler
    && IsBadReadPtr(thread->_exception_handler, sizeof(NSHandler)))
    {
      fprintf(stderr, "ERROR: Current exception handler is bogus.\n");
    }
#endif  
  handler->next = thread->_exception_handler;
  thread->_exception_handler = handler;
}

void
_NSRemoveHandler (NSHandler* handler)
{
  NSThread *thread;

  thread = GSCurrentThread();
#if defined(DEBUG)  
  if (thread->_exception_handler != handler)
    {
      fprintf(stderr, "ERROR: Removing exception handler that is not on top "
	"of the stack. (You probably called return in an NS_DURING block.)\n");
    }
#if defined(__MINGW32__)
  if (IsBadReadPtr(handler, sizeof(NSHandler)))
    {
      fprintf(stderr, "ERROR: Could not remove exception handler, "
	"handler is bad pointer.\n");
      thread->_exception_handler = 0;
      return;
    }
  if (handler->next && IsBadReadPtr(handler->next, sizeof(NSHandler)))
    {
      fprintf(stderr, "ERROR: Could not restore exception handler, "
	"handler->next is bad pointer.\n");
      thread->_exception_handler = 0;
      return;
    }
#endif
#endif
  thread->_exception_handler = handler->next;
}
