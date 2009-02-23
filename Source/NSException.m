/** NSException - Object encapsulation of a general exception handler
   Copyright (C) 1993, 1994, 1996, 1997, 1999 Free Software Foundation, Inc.

   Written by:  Adam Fedor <fedor@boulder.colorado.edu>
   Date: Mar 1995

   This file is part of the GNUstep Base Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   $Date$ $Revision$
*/

#import "config.h"
#import "GSPrivate.h"
#import "GNUstepBase/preface.h"
#import <Foundation/NSDebug.h>
#import <Foundation/NSBundle.h>
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSException.h"
#import "Foundation/NSString.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSNull.h"
#import "Foundation/NSThread.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSValue.h"
#include <stdio.h>


#define _e_info (((id*)_reserved)[0])
#define _e_stack (((id*)_reserved)[1])

typedef struct { @defs(NSThread) } *TInfo;

/* This is the GNU name for the CTOR list */

@interface GSStackTrace : NSObject
{
  NSMutableArray *frames;
}
+ (GSStackTrace*) currentStack;

- (NSString*) description;
- (NSEnumerator*) enumerator;
- (NSMutableArray*) frames;
- (id) frameAt: (NSUInteger)index;
- (NSUInteger) frameCount;
- (id) initWithAddresses: (NSArray*)stack;
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
 * Turn off STACKSYMBOLS if we have NDEBUG defined ... if we are built
 * with NDEBUG then we are probably missing stackframe information etc.
 */
#if defined(NDEBUG)
#if	defined(STACKSYMBOLS)
#undef	STACKSYMBOLS
#endif
#endif


#if	defined(__MINGW32__)
#if	defined(STACKSYMBOLS)
static NSString *
GSPrivateBaseAddress(void *addr, void **base)
{
  return nil;
}
#endif  /* STACKSYMBOLS */
#else	/* __MINGW32__ */

#ifndef GNU_SOURCE
#define GNU_SOURCE
#endif
#ifndef __USE_GNU
#define __USE_GNU
#endif
#include <dlfcn.h>

#if	defined(STACKSYMBOLS)
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
#endif  /* STACKSYMBOLS */
#endif	/* __MINGW32__ */

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
		 line: (NSInteger)lineNo;
- (NSInteger) lineNumber;
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
  DESTROY(_module);
  DESTROY(_fileName);
  DESTROY(_functionName);
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
		 line: (NSInteger)lineNo
{
  _module = RETAIN(module);
  _address = address;
  _fileName = [file copy];
  _functionName = [function copy];
  _lineNo = lineNo;

  return self;
}

- (NSInteger) lineNumber
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
  DESTROY(_fileName);
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
  struct SearchAddressStruct searchInfo =
    { address, self, _symbols, nil };

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
  DESTROY(frames);
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

- (id) frameAt: (NSUInteger)index
{
  return [frames objectAtIndex: index];
}

- (NSUInteger) frameCount
{
  return [frames count];
}

- (NSMutableArray*) frames
{
  return frames;
}

// grab the current stack 
- (id) init
{
  NSMutableArray        *stack = GSPrivateStackAddresses();

  return [self initWithAddresses: stack];
}

- (id) initWithAddresses: (NSArray*)stack
{
#if	defined(STACKSYMBOLS)
  int i;
  int n;

  n = [stack count];
  frames = [[NSMutableArray alloc] initWithCapacity: n];

  for (i = 0; i < n; i++)
    {
      GSFunctionInfo	*aFrame = nil;
      void		*address = [[stack objectAtIndex: i] pointerValue];
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
  frames = [stack copy];
#endif

  return self;
}

- (NSEnumerator*) reverseEnumerator
{
  return [frames reverseObjectEnumerator];
}

@end


NSString* const NSCharacterConversionException
  = @"NSCharacterConversionException";

NSString* const NSGenericException
  = @"NSGenericException";

NSString* const NSInternalInconsistencyException
  = @"NSInternalInconsistencyException";

NSString* const NSInvalidArgumentException
  = @"NSInvalidArgumentException";

NSString* const NSMallocException
  = @"NSMallocException";

NSString* const NSOldStyleException
  = @"NSOldStyleException";

NSString* const NSParseErrorException
  = @"NSParseErrorException";

NSString* const NSRangeException
 = @"NSRangeException";

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
  CREATE_AUTORELEASE_POOL(pool);
  fprintf(stderr, "%s: Uncaught exception %s, reason: %s\n",
    GSPrivateArgZero(),
    [[exception name] lossyCString], [[exception reason] lossyCString]);
  fflush(stderr);	/* NEEDED UNDER MINGW */
  if (GSPrivateEnvironmentFlag("GNUSTEP_STACK_TRACE", NO) == YES)
    {
      id o = [exception callStackReturnAddresses];

#if     defined(STACKSYMBOLS)
      o = AUTORELEASE([[GSStackTrace alloc] initWithAddresses:  o]);
#endif
      fprintf(stderr, "Stack\n%s\n", [[o description] lossyCString]);
    }
  fflush(stderr);	/* NEEDED UNDER MINGW */
  RELEASE(pool);
  _terminate();
}

static  NSUncaughtExceptionHandler *_NSUncaughtExceptionHandler
  = _NSFoundationUncaughtExceptionHandler;

#if	!defined(_NATIVE_OBJC_EXCEPTIONS) || defined(HAVE_UNEXPECTED)
static void
callUncaughtHandler(id value)
{
  if (_NSUncaughtExceptionHandler != NULL)
    {
      (*_NSUncaughtExceptionHandler)(value);
    }
  _NSFoundationUncaughtExceptionHandler(value);
}
#endif


@implementation NSException

+ (void) initialize
{
#if	defined(STACKSYMBOLS)
  if (modLock == nil)
    {
      modLock = [NSRecursiveLock new];
    }
#endif	/* STACKSYMBOLS */
#if	defined(_NATIVE_OBJC_EXCEPTIONS) && defined(HAVE_UNEXPECTED)
  objc_set_unexpected(callUncaughtHandler);
#endif
  return;
}

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
  if (userInfo != nil)
    {
      if (_reserved == 0)
        {
          _reserved = NSZoneCalloc([self zone], 2, sizeof(id));
        }
      ASSIGN(_e_info, userInfo);
    }
  return self;
}

- (NSArray*) callStackReturnAddresses
{
  if (_reserved == 0)
    {
      return nil;
    }
  return _e_stack;
}

- (void) dealloc
{
  DESTROY(_e_name);
  DESTROY(_e_reason);
  if (_reserved != 0)
    {
      DESTROY(_e_info);
      DESTROY(_e_stack);
      NSZoneFree([self zone], _reserved);
      _reserved = 0;
    }
  [super dealloc];
}

- (void) raise
{
#ifndef _NATIVE_OBJC_EXCEPTIONS
  TInfo         thread;
  NSHandler	*handler;
#endif

  if (_reserved == 0)
    {
      _reserved = NSZoneCalloc([self zone], 2, sizeof(id));
    }

  if (_e_stack == nil
    && GSPrivateEnvironmentFlag("GNUSTEP_STACK_TRACE", YES) == YES)
    {
      ASSIGN(_e_stack, GSPrivateStackAddresses());
    }

#ifdef _NATIVE_OBJC_EXCEPTIONS
  @throw self;
#else
  thread = (TInfo)GSCurrentThread();
  handler = thread->_exception_handler;
  if (handler == NULL)
    {
      static	int	recursion = 0;

      /*
       * Set/check a counter to prevent recursive uncaught exceptions.
       * Allow a little recursion in case we have different handlers
       * being tried.
       */
      if (recursion++ > 3)
	{
	  fprintf(stderr,
	    "recursion encountered handling uncaught exception\n");
	  fflush(stderr);	/* NEEDED UNDER MINGW */
	  _terminate();
	}

      /*
       * Call the uncaught exception handler (if there is one).
       */
      callUncaughtHandler(self);

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
  if (_reserved == 0)
    {
      return nil;
    }
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
  id    info = (_reserved == 0) ? nil : _e_info;

  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_name];
  [aCoder encodeValueOfObjCType: @encode(id) at: &_e_reason];
  [aCoder encodeValueOfObjCType: @encode(id) at: &info];
}

- (id) initWithCoder: (NSCoder*)aDecoder
{
  id    info;

  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_name];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &_e_reason];
  [aDecoder decodeValueOfObjCType: @encode(id) at: &info];
  if (info != nil)
    {
      if (_reserved == 0)
        {
          _reserved = NSZoneCalloc([self zone], 2, sizeof(id));
        }
      _e_info = info;
    }
  return self;
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone))
    {
      return RETAIN(self);
    }
  else
    {
      return [[[self class] alloc] initWithName: [self name]
                                         reason: [self reason]
                                       userInfo: [self userInfo]];
    }
}

- (NSString*) description
{
  CREATE_AUTORELEASE_POOL(pool);
  NSString      *result;

  if (_reserved != 0)
    {
      if (_e_stack != nil
        && GSPrivateEnvironmentFlag("GNUSTEP_STACK_TRACE", NO) == YES)
        {
          id    o = _e_stack;

#if     defined(STACKSYMBOLS)
          /* Convert stack information from an array of addresses
           * to a stacktrace for display.
           */
          o = AUTORELEASE([[GSStackTrace alloc] initWithAddresses:  o]);
#endif
          if (_e_info != nil)
            {
              result = [NSString stringWithFormat:
                @"%@ NAME:%@ REASON:%@ INFO:%@ STACK:%@",
                [super description], _e_name, _e_reason, _e_info, o];
            }
          else
            {
              result = [NSString stringWithFormat:
                @"%@ NAME:%@ REASON:%@ STACK:%@",
                [super description], _e_name, _e_reason, o];
            }
        }
      else
        {
          result = [NSString stringWithFormat:
            @"%@ NAME:%@ REASON:%@ INFO:%@",
            [super description], _e_name, _e_reason, _e_info];
        }
    }
  else
    {
      result = [NSString stringWithFormat: @"%@ NAME:%@ REASON:%@",
        [super description], _e_name, _e_reason];
    }
  IF_NO_GC([result retain];)
  IF_NO_GC(DESTROY(pool);)
  return AUTORELEASE(result);
}

@end


void
_NSAddHandler (NSHandler* handler)
{
  TInfo thread;

  thread = (TInfo)GSCurrentThread();
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
  TInfo         thread;

  thread = (TInfo)GSCurrentThread();
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

NSUncaughtExceptionHandler *
NSGetUncaughtExceptionHandler()
{
  return _NSUncaughtExceptionHandler;
}

void
NSSetUncaughtExceptionHandler(NSUncaughtExceptionHandler *handler)
{
  _NSUncaughtExceptionHandler = handler;
}
