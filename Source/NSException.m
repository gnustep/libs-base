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
#include "Foundation/NSDictionary.h"
#include <stdio.h>

/*
 * Turn off STACKTRACE if we don't have bfd support for it.
 */
#if !(defined(HAVE_BFD_H) && defined(HAVE_LIBBFD) && defined(HAVE_LIBIBERTY))
#if	defined(STACKTRACE)
#undef	STACKTRACE
#endif
#endif

/*
 * Turn off STACKTRACE if we don't have DEBUG defined ... if we are not built
 * with DEBUG then we are probably missing stackframe information etc.
 */
#if !(defined(DEBUG))
#if	defined(STACKTRACE)
#undef	STACKTRACE
#endif
#endif

#if	defined(STACKTRACE)

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
  NSString	*_filename;
  bfd		*_abfd;
  asymbol	**_symbols;
  long		_symbolCount;
}
- (NSString *) filename;
- (GSFunctionInfo *) functionForAddress: (void*) address;
- (id) initWithBinaryFile: (NSString *)filename;
- (id) init; // return info for the current executing process

@end


@interface GSStackTrace : NSObject
{
  NSMutableArray *frames;
}
+ (GSStackTrace*) currentStack;
/*
 * Add some module information to the stack trace information
 * only symbols from the current process's file, GNUstep base library,
 * GNUstep gui library, and any bundles containing code are loaded.
 * All other symbols should be manually added
 */
+ (BOOL) loadModule: (NSString *)filename;

- (NSString*) description;
- (NSEnumerator*) enumerator;
- (GSFunctionInfo*) frameAt: (unsigned)index;
- (unsigned) frameCount;
- (NSEnumerator*) reverseEnumerator;

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
    [_module filename], _address, _functionName, _fileName, _lineNo];
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

+ (GSBinaryFileInfo*) infoWithBinaryFile: (NSString *)filename
{
  return [[[self alloc] initWithBinaryFile: filename] autorelease];
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
  [_filename release];
  _filename = nil;
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

- (NSString *) filename
{
  return _filename;
}

- (id) init
{
  NSString *processName;

  processName = [[[NSProcessInfo processInfo] arguments] objectAtIndex: 0];
  return [self initWithBinaryFile: processName];
}

- (id) initWithBinaryFile: (NSString *)filename
{
  int neededSpace;

  // 1st initialize the bfd
  if ([filename length] == 0)
    {
      NSLog (@"GSBinaryFileInfo: No File");
      [self release];
      return nil;
    }
  _filename = [filename copy];
  _abfd = bfd_openr ([filename cString], NULL);
  if (!_abfd)
    {
      NSLog (@"GSBinaryFileInfo: No Binary Info");
      [self release];
      return nil;
    }
  if (!bfd_check_format_matches (_abfd, bfd_object, NULL))
    {
      NSLog (@"GSBinaryFileInfo: BFD format object error");
      [self release];
      return nil;
    }

  // second read the symbols from it
  if (!(bfd_get_file_flags (_abfd) & HAS_SYMS))
    {
      NSLog (@"GSBinaryFileInfo: BFD does not contain any symbols");
      [self release];
      return nil;
    }

  neededSpace = bfd_get_symtab_upper_bound (_abfd);
  if (neededSpace < 0)
    {
      NSLog (@"GSBinaryFileInfo: BFD error while deducing needed space");
      [self release];
      return nil;
    }
  if (neededSpace == 0)
    {
      NSLog (@"GSBinaryFileInfo: BFD no space for symbols needed");
      [self release];
      return nil;
    }
  _symbols = objc_malloc (neededSpace);
  if (!_symbols)
    {
      NSLog (@"GSBinaryFileInfo: Can't allocate buffer");
      [self release];
      return nil;
    }
  _symbolCount = bfd_canonicalize_symtab (_abfd, _symbols);
  if (_symbolCount < 0)
    {
      NSLog (@"GSBinaryFileInfo: BFD error while reading symbols");
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

  address = (bfd_vma) info->theAddress;

  vma = bfd_get_section_vma (abfd, section);
  size = bfd_get_section_size (section);
  if (address < vma || address >= vma + size)
    {
      return;
    }

  if (bfd_find_nearest_line (abfd, section, info->symbols,
    address - vma, &fileName, &functionName, &line))
    {
      GSFunctionInfo *fi;

      fi = [GSFunctionInfo alloc];
      fi = [fi initWithModule: info->module
		      address: info->theAddress
			 file: [NSString stringWithCString: fileName]
		     function: [NSString stringWithCString: functionName]
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

// this method automatically load the current process + GNUstep base & gui.
static NSMutableDictionary *GetStackModules()
{
  static NSMutableDictionary	*stackModules = nil;

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
	      [GSStackTrace loadModule: [bundle executablePath]];
	    }
	}
    }
  return stackModules;
}

@implementation GSStackTrace : NSObject

static NSNull	*null = nil;

+ (GSStackTrace*) currentStack
{
  return [[[GSStackTrace alloc] init] autorelease];
}

+ (void) initialize
{
  null = RETAIN([NSNull null]);
}

// initialize stack trace info
+ (BOOL) loadModule: (NSString *)filename
{
  if ([filename length] > 0)
    {
      NSMutableDictionary	*modules = GetStackModules();

      if ([modules objectForKey: filename] == nil)
	{
	  GSBinaryFileInfo	*module;

	  module = [GSBinaryFileInfo infoWithBinaryFile: filename];
	  if (module != nil)
	    {
	      [modules setObject: module forKey: filename];
	    }
	  else
	    {
	      [modules setObject: null forKey: filename];
	    }
	}
      if ([modules objectForKey: filename] != null)
	{
	  return YES;
	}
    }
  return NO;
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
      GSFunctionInfo	*line = [frames objectAtIndex: i];

      [result appendFormat: @"%3d: %@\n", i, line];
    }
  return result;
}

- (NSEnumerator*) enumerator
{
  return [frames objectEnumerator];
}

- (GSFunctionInfo*) frameAt: (unsigned)index
{
  return [frames objectAtIndex: index];
}

- (unsigned) frameCount
{
  return [frames count];
}

// grab the current stack 
// this MAX_FRAME comes from NSDebug.h which warn only 100 frames are available
#define MAX_FRAME  100
- (id) init
{
  NSArray *modules;
  int i;
  int j;
  int n;
  int m;

  frames = [[NSMutableArray alloc] init];
  modules = [GetStackModules() allValues];
  n = NSCountFrames();
  m = [modules count];

  for (i = 0; i < n && i < MAX_FRAME; i++)
    {
      GSFunctionInfo	*aFrame = nil;
      void		*address = NSReturnAddress(i);

      for (j = 0; j < m; j++)
  	{
	  GSBinaryFileInfo	*bfi = [modules objectAtIndex: j];

	  if ((id)bfi != (id)null)
	    {
	      aFrame = [bfi functionForAddress: address];
	      if (aFrame)
		{
		  [frames addObject: aFrame];
		  break;
		}
	    }
  	}
      // not found (?!), add an 'unknown' function
      if (!aFrame)
	{
	  aFrame = [GSFunctionInfo alloc];
	  [aFrame initWithModule: nil
			 address: address 
			    file: nil
			function: nil
			    line: 0];
	  [aFrame autorelease];
	  [frames addObject: aFrame];
	}
    }

  return self;
}

- (NSEnumerator*) reverseEnumerator
{
  return [frames reverseObjectEnumerator];
}

@end

#endif	/* STACKTRACE */




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
  shouldAbort = GSEnvironmentFlag("CRASH_ON_ABORT", shouldAbort);
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
  extern const char*	GSArgZero(void);

  fprintf(stderr, "%s: Uncaught exception %s, reason: %s\n", GSArgZero(),
    [[exception name] lossyCString], [[exception reason] lossyCString]);
  fflush(stderr);	/* NEEDED UNDER MINGW */

  _terminate();
}

@implementation NSException

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

#if	defined(STACKTRACE)
  if ([_e_info objectForKey: @"GSStackTraceKey"] == nil)
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
