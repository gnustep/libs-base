/* Implementation for NSTask for GNUStep
   Copyright (C) 1998,1999 Free Software Foundation, Inc.

   Written by:  Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1998

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

#include <config.h>
#include <base/preface.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSBundle.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSTask.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSDebug.h>

#include <string.h>
#include <unistd.h>
#include <sys/signal.h>
#include <sys/types.h>
#include <sys/param.h>
#include <sys/wait.h>

/*
 *	If we don't have NFILE, default to 256 open descriptors.
 */
#ifndef	NOFILE
#define	NOFILE	256
#endif

NSString *NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

static NSRecursiveLock  *tasksLock = nil;
static NSMapTable       *activeTasks = 0;

@interface NSTask (Private)
- (void) _collectChild;
- (void) _sendNotification;
- (void) _terminatedChild: (int)status;
@end

@implementation NSTask

static void handleSignal(int sig)
{
  int result;
  int status;

  do
    {
      result = waitpid(-1, &status, WNOHANG);
      if (result > 0)
        {
          if (WIFEXITED(status))
            {
              NSTask    *t;

              [tasksLock lock];
              t = (NSTask*)NSMapGet(activeTasks, (void*)result);
              [tasksLock unlock];
              if (t)
                {
                  [t _terminatedChild: WEXITSTATUS(status)];
                }
            }
        }
    }
  while (result > 0);  
}

+ (void) initialize
{
  if (self == [NSTask class])
    {
      [gnustep_global_lock lock];
      if (tasksLock == nil)
        {
          tasksLock = [NSRecursiveLock new];
          activeTasks = NSCreateMapTable(NSIntMapKeyCallBacks,
                NSNonOwnedPointerMapValueCallBacks, 0);
        }
      [gnustep_global_lock unlock];

      signal(SIGCHLD, handleSignal);
    }
}

+ (NSTask*) launchedTaskWithLaunchPath: (NSString*)path
			     arguments: (NSArray*)args
{
  NSTask*	task = [NSTask new];

  [task setLaunchPath: path];
  [task setArguments: args];
  [task launch];
  return AUTORELEASE(task);
}

- (void) gcFinalize
{
  [tasksLock lock];
  NSMapRemove(activeTasks, (void*)taskId);
  [tasksLock unlock];
}

- (void) dealloc
{
  [self gcFinalize];
  RELEASE(arguments);
  RELEASE(environment);
  RELEASE(launchPath);
  RELEASE(currentDirectoryPath);
  RELEASE(standardError);
  RELEASE(standardInput);
  RELEASE(standardOutput);
  [super dealloc];
}


/*
 *	Querying task parameters.
 */

- (NSArray*) arguments
{
  return arguments;
}

- (NSString*) currentDirectoryPath
{
  if (currentDirectoryPath == nil)
    {
      [self setCurrentDirectoryPath:
		[[NSFileManager defaultManager] currentDirectoryPath]];
    }
  return currentDirectoryPath;
}

- (NSDictionary*) environment
{
  if (environment == nil)
    {
      [self setEnvironment: [[NSProcessInfo processInfo] environment]];
    }
  return environment;
}

- (NSString*) launchPath
{
  return launchPath;
}

- (id) standardError
{
  if (standardError == nil)
    {
      [self setStandardError: [NSFileHandle fileHandleWithStandardError]];
    }
  return standardError;
}

- (id) standardInput
{
  if (standardInput == nil)
    {
      [self setStandardInput: [NSFileHandle fileHandleWithStandardInput]];
    }
  return standardInput;
}

- (id) standardOutput
{
  if (standardOutput == nil)
    {
      [self setStandardOutput: [NSFileHandle fileHandleWithStandardOutput]];
    }
  return standardOutput;
}

/*
 *	Setting task parameters.
 */

- (void) setArguments: (NSArray*)args
{
  if (hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(arguments, args);
}

- (void) setCurrentDirectoryPath: (NSString*)path
{
  if (hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(currentDirectoryPath, path);
}

- (void) setEnvironment: (NSDictionary*)env
{
  if (hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(environment, env);
}

- (void) setLaunchPath: (NSString*)path
{
  if (hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(launchPath, path);
}

- (void) setStandardError: (id)hdl
{
  NSAssert([hdl isKindOfClass: [NSFileHandle class]] ||
	   [hdl isKindOfClass: [NSPipe class]], NSInvalidArgumentException);
  if (hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(standardError, hdl);
}

- (void) setStandardInput: (NSFileHandle*)hdl
{
  NSAssert([hdl isKindOfClass: [NSFileHandle class]] ||
	   [hdl isKindOfClass: [NSPipe class]], NSInvalidArgumentException);
  if (hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(standardInput, hdl);
}

- (void) setStandardOutput: (NSFileHandle*)hdl
{
  NSAssert([hdl isKindOfClass: [NSFileHandle class]] ||
	   [hdl isKindOfClass: [NSPipe class]], NSInvalidArgumentException);
  if (hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(standardOutput, hdl);
}

/*
 *	Obtaining task state
 */

- (BOOL) isRunning
{
  if (hasLaunched == NO)
    {
      return NO;
    }
  if (hasCollected == NO)
    {
      [self _collectChild];
    }
  if (hasTerminated == YES)
    {
      return NO;
    }
  return YES;
}

- (int) terminationStatus
{
  if (hasLaunched == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
  if (hasCollected == NO)
    {
      [self _collectChild];
    }
  if (hasTerminated == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet terminated"];
    }
  return terminationStatus;
}

/*
 *	Handling a task.
 */
- (void) interrupt
{
  [self notImplemented: _cmd];	/* Undocumented as yet	*/
}

/* Declaration from find_exec.c */
extern char *objc_find_executable(const char *name);

- (void) launch
{
  NSMutableArray	*toClose;
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSString	*libs = [NSBundle _library_combo];
  NSString	*arch = [NSBundle _gnustep_target_dir];
  NSString	*prog;
  NSString	*lpath;
  NSString	*base_path;
  NSString	*arch_path;
  NSString	*full_path;
  int		pid;
  const char	*executable;
  const char	*path;
  int		idesc;
  int		odesc;
  int		edesc;
  NSDictionary	*e = [self environment];
  NSArray	*k = [e allKeys];
  NSArray	*a = [self arguments];
  int		ec = [e count];
  int		ac = [a count];
  const char	*args[ac+2];
  const char	*envl[ec+1];
  id		hdl;
  int		i;

  if (hasLaunched)
    {
      return;
    }

  if (launchPath == nil)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - no launch path set"];
    }

  /*
   *	Set lpath to the actual path to use for the executable.
   *	First choice - base_path/architecture/library_combo/prog.
   *	Second choice - base_path/architecture/prog.
   *	Third choice - base_path/prog.
   *	Otherwise - try using PATH environment variable if possible.
   */
  prog = [launchPath lastPathComponent];
  base_path = [launchPath stringByDeletingLastPathComponent];
  if ([[base_path lastPathComponent] isEqualToString: libs] == YES)
    base_path = [base_path stringByDeletingLastPathComponent];
  if ([[base_path lastPathComponent] isEqualToString: arch] == YES)
    base_path = [base_path stringByDeletingLastPathComponent];
  arch_path = [base_path stringByAppendingPathComponent: arch];
  full_path = [arch_path stringByAppendingPathComponent: libs];

  lpath = [full_path stringByAppendingPathComponent: prog];
  if ([mgr isExecutableFileAtPath: lpath] == NO)
    {
      lpath = [arch_path stringByAppendingPathComponent: prog];
      if ([mgr isExecutableFileAtPath: lpath] == NO)
	{
	  lpath = [base_path stringByAppendingPathComponent: prog];
	  if ([mgr isExecutableFileAtPath: lpath] == NO)
	    {
	      const char	*cpath = 0;

	      /*
	       * Last resort - if the launch path was simply a program name
	       * get objc_find_executable() to try using the PATH environment
	       * variable to find the executable.
	       */
	      if ([base_path isEqualToString: @""] == YES)
		{

		  cpath = objc_find_executable([prog cString]);
		}
	      if (cpath == 0)
		{
		  [NSException raise: NSInvalidArgumentException
			      format: @"NSTask - launch path is not valid"];
		}
	      else
		{
		  lpath = [NSString stringWithCString: cpath];
		  OBJC_FREE((void*)cpath);
		}
	    }
	}
    }
  /*
   *	Make sure we have a standardised absolute path to pass to execve()
   */
  if ([lpath isAbsolutePath] == NO)
    {
      NSString	*current = [mgr currentDirectoryPath];

      lpath = [current stringByAppendingPathComponent: lpath];
    }
  lpath = [lpath stringByStandardizingPath];

  executable = [lpath cString];
  args[0] = [prog cString];

  for (i = 0; i < ac; i++)
    {
      args[i+1] = [[[a objectAtIndex: i] description] cString];
    }
  args[ac+1] = 0;

  for (i = 0; i < ec; i++)
    {
      NSString	*s;
      id	key = [k objectAtIndex: i];
      id	val = [e objectForKey: key];

      if (val)
	{
	  s = [NSString stringWithFormat: @"%@=%@", key, val];
	}
      else
	{
	  s = [NSString stringWithFormat: @"%@=", key];
	}
      envl[i] = [s cString];
    }
  envl[ec] = 0;

  path = [[self currentDirectoryPath] cString];

  toClose = [NSMutableArray arrayWithCapacity: 3];
  hdl = [self standardInput];
  if ([hdl isKindOfClass: [NSPipe class]])
    {
      hdl = [hdl fileHandleForReading];
      [toClose addObject: hdl];
    }
  idesc = [hdl fileDescriptor];

  hdl = [self standardOutput];
  if ([hdl isKindOfClass: [NSPipe class]])
    {
      hdl = [hdl fileHandleForWriting];
      [toClose addObject: hdl];
    }
  odesc = [hdl fileDescriptor];

  hdl = [self standardError];
  if ([hdl isKindOfClass: [NSPipe class]])
    {
      hdl = [hdl fileHandleForWriting];
      /*
       * If we have the same pipe twice we don't want to close it twice
       */
      if ([toClose indexOfObjectIdenticalTo: hdl] == NSNotFound)
	{
	  [toClose addObject: hdl];
	}
    }
  edesc = [hdl fileDescriptor];

  pid = fork();
  if (pid < 0)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - failed to create child process"];
    }
  if (pid == 0)
    {
      int	i;

      /*
       * Make sure the task gets default signal setup.
       */
      for (i = 0; i < 32; i++)
	{
	  signal(i, SIG_DFL);
	}

      /*
       * Make sure task is run in it's own process group.
       */
#if     HAVE_SETPGRP
#ifdef	SETPGRP_VOID
      setpgrp();
#else
      setpgrp(getpid(), getpid());
#endif
#else
#if defined(__WIN32__)
      pid = (int)GetCurrentProcessId(),
#else
      pid = (int)getpid();
#endif
#if     HAVE_SETPGID
      setpgid(pid, pid);
#endif
#endif

      /*
       * Set up stdin, stdout and stderr by duplicating descriptors as
       * necessary and closing the originals (to ensure we won't have a
       * pipe left with two write descriptors etc).
       */
      if (idesc != 0)
	{
	  dup2(idesc, 0);
	}
      if (odesc != 1)
	{
	  dup2(odesc, 1);
	}
      if (edesc != 2)
	{
	  dup2(edesc, 2);
	}

      for (i = 3; i < NOFILE; i++)
	{
	  (void) close(i);
	}

      chdir(path);
      execve(executable, (char**)args, (char**)envl);
      exit(-1);
    }
  else
    {
      taskId = pid;
      hasLaunched = YES;
      ASSIGN(launchPath, lpath);	// Actual path used.

      [tasksLock lock];
      NSMapInsert(activeTasks, (void*)taskId, (void*)self);
      [tasksLock unlock];

      /*
       *	Close the ends of any pipes used by the child.
       */
      while ([toClose count] > 0)
	{
	  hdl = [toClose objectAtIndex: 0];
	  [hdl closeFile];
	  [toClose removeObjectAtIndex: 0];
	}
    }
}

- (void) terminate
{
  if (hasLaunched == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
  if (hasTerminated)
    {
      return;
    }

  hasTerminated = YES;
#ifdef	HAVE_KILLPG
  killpg(taskId, SIGTERM);
#else
  kill(-taskId, SIGTERM);
#endif
}

- (void) waitUntilExit
{
  while ([self isRunning])
    {
      NSDate	*limit;

      /*
       *	Poll at 0.1 second intervals.
       */
      limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 0.1];
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: limit];
      RELEASE(limit);
    }
}
@end

@implementation	NSTask (Private)

- (void) _collectChild
{
  if (hasCollected == NO)
    {
      int       result;

      errno = 0;
      result = waitpid(taskId, &terminationStatus, WNOHANG);
      if (result < 0)
        {
          NSLog(@"waitpid %d, result %d, error %s",
                taskId, result, strerror(errno));
          [self _terminatedChild: -1];
        }
      else if (result == taskId || (result == 0 && errno == 0))
	{
	  if (WIFEXITED(terminationStatus))
	    {
#ifdef  WAITDEBUG
              NSLog(@"waitpid %d, termination status = %d",
                        taskId, terminationStatus);
#endif
              [self _terminatedChild: WEXITSTATUS(terminationStatus)];
	    }
#ifdef  WAITDEBUG
          else
            NSLog(@"waitpid %d, event status = %d",
                        taskId, terminationStatus);
#endif
	}
#ifdef  WAITDEBUG
      else
        NSLog(@"waitpid %d, result %d, error %s",
                taskId, result, strerror(errno));
#endif
    }
}

- (void) _sendNotification
{
  if (hasNotified == NO)
    {
      NSNotification	*n;

      hasNotified = YES;
      n = [NSNotification notificationWithName: NSTaskDidTerminateNotification
					object: self
				      userInfo: nil];

      [[NSNotificationQueue defaultQueue] enqueueNotification: n
		    postingStyle: NSPostASAP
		    coalesceMask: NSNotificationNoCoalescing
			forModes: nil];
    }
}

- (void) _terminatedChild: (int)status
{
  [tasksLock lock];
  NSMapRemove(activeTasks, (void*)taskId);
  [tasksLock unlock];
  terminationStatus = status;
  hasCollected = YES;
  hasTerminated = YES;
  if (hasNotified == NO)
    {
      [self _sendNotification];
    }
}

@end

