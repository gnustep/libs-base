/** Implementation for NSTask for GNUStep
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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
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
#include <Foundation/NSTimer.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSDebug.h>

#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#ifdef __FreeBSD__
#include <fcntl.h>
#endif
#ifndef __MINGW__
#include <sys/signal.h>
#include <sys/param.h>
#include <sys/wait.h>
#endif

#if HAVE_WINDOWS_H
#  include <windows.h>
#endif

/*
 *	If we don't have NFILE, default to 256 open descriptors.
 */
#ifndef	NOFILE
#define	NOFILE	256
#endif

NSString *NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

static NSRecursiveLock  *tasksLock = nil;
static NSMapTable       *activeTasks = 0;

static BOOL	hadChildSignal = NO;
static void handleSignal(int sig)
{
  hadChildSignal = YES;
#ifndef __MINGW__
  signal(SIGCHLD, handleSignal);
#endif
}

#ifdef __MINGW__
@interface NSConcreteWindowsTask : NSTask
{
  PROCESS_INFORMATION proc_info;
}
@end
#define NSConcreteTask NSConcreteWindowsTask
#else
@interface NSConcreteUnixTask : NSTask
{
  char	slave_name[32];
  BOOL	_usePseudoTerminal;
}
@end
#define NSConcreteTask NSConcreteUnixTask

#if	HAVE_SIGNAL_H
#include <signal.h>
#endif
#if	HAVE_SYS_FILE_H
#include <sys/file.h>
#endif
#if	HAVE_SYS_FCNTL_H
#include <sys/fcntl.h>
#endif
#if	HAVE_SYS_IOCTL_H
#include <sys/ioctl.h>
#endif
#if	HAVE_SYS_WAIT_H
#include <sys/wait.h>
#endif

/*
 *	If we are on a streams based system, we need to include stropts.h
 *	for definitions needed to set up slave pseudo-terminal stream.
 */
#if	HAVE_SYS_STROPTS_H
#include <sys/stropts.h>
#endif

#ifndef	MAX_OPEN
#define	MAX_OPEN	64
#endif

static int
pty_master(char* name, int len)
{
  int	master;

  /*
   *	If we have grantpt(), assume we are using sysv-style pseudo-terminals,
   *	otherwise assume bsd style.
   */
#if	HAVE_GRANTPT
  master = open("/dev/ptmx", O_RDWR);
  if (master >= 0)
    {
      const char	*slave;

      grantpt(master);                   /* Change permission of slave.  */
      unlockpt(master);                  /* Unlock slave.        */
      slave = (const char*)ptsname(master);
      if (slave == 0 || strlen(slave) >= len)
	{
	  close(master);
	  master = -1;
	}
      else
	{
	  strcpy(name, (char*)slave);
	}
    }
  else
#endif
    {
      const char	*groups = "pqrstuvwxyzPQRSTUVWXYZ";

      master = -1;
      if (len > 10)
        {
	  strcpy(name, "/dev/ptyXX");
	  while (master < 0 && *groups != '\0')
	    {
	      int	i;

	      name[8] = *groups++;
	      for (i = 0; i < 16; i++)
	        {
		  name[9] = "0123456789abcdef"[i];
		  master = open(name, O_RDWR);
		  if (master >= 0)
		    {
		      name[5] = 't';
		      break;
		    }
		}
	    }
	}
    }
  return master;
}

static int
pty_slave(const char* name)
{
  int	slave;

  slave = open(name, O_RDWR);
#if	HAVE_SYS_STROPTS_H
#if	HAVE_PTS_STREAM_MODULES
  if (slave >= 0 && isastream(slave))
    {
      if (ioctl(slave, I_PUSH, "ptem") < 0)
	{
	  perror("unable to push 'ptem' streams module");
	}
      else if (ioctl(slave, I_PUSH, "ldterm") < 0)
	{
	  perror("unable to push 'ldterm' streams module");
	}
    }
#endif
#endif
  return slave;
}

#endif

@interface NSTask (Private)
- (NSString *) _fullLaunchPath;
- (void) _sendNotification;
- (void) _collectChild;
- (void) _terminatedChild: (int)status;
@end


@implementation NSTask

+ (id) allocWithZone: (NSZone*)zone
{
  NSTask *task;

  if (self == [NSTask class])
    task = (NSTask *)NSAllocateObject([NSConcreteTask class], 0, zone);
  else
    task = (NSTask *)NSAllocateObject(self, 0, zone);
  return task;
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

#ifndef __MINGW__
      signal(SIGCHLD, handleSignal);
#endif
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
  NSMapRemove(activeTasks, (void*)_taskId);
  [tasksLock unlock];
}

- (void) dealloc
{
  [self gcFinalize];
  RELEASE(_arguments);
  RELEASE(_environment);
  RELEASE(_launchPath);
  RELEASE(_currentDirectoryPath);
  RELEASE(_standardError);
  RELEASE(_standardInput);
  RELEASE(_standardOutput);
  [super dealloc];
}


/*
 *	Querying task parameters.
 */

- (NSArray*) arguments
{
  return _arguments;
}

- (NSString*) currentDirectoryPath
{
  if (_currentDirectoryPath == nil)
    {
      [self setCurrentDirectoryPath:
		[[NSFileManager defaultManager] currentDirectoryPath]];
    }
  return _currentDirectoryPath;
}

- (NSDictionary*) environment
{
  if (_environment == nil)
    {
      [self setEnvironment: [[NSProcessInfo processInfo] environment]];
    }
  return _environment;
}

- (NSString*) launchPath
{
  return _launchPath;
}

- (id) standardError
{
  if (_standardError == nil)
    {
      [self setStandardError: [NSFileHandle fileHandleWithStandardError]];
    }
  return _standardError;
}

- (id) standardInput
{
  if (_standardInput == nil)
    {
      [self setStandardInput: [NSFileHandle fileHandleWithStandardInput]];
    }
  return _standardInput;
}

- (id) standardOutput
{
  if (_standardOutput == nil)
    {
      [self setStandardOutput: [NSFileHandle fileHandleWithStandardOutput]];
    }
  return _standardOutput;
}

/*
 *	Setting task parameters.
 */

- (void) setArguments: (NSArray*)args
{
  if (_hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(_arguments, args);
}

- (void) setCurrentDirectoryPath: (NSString*)path
{
  if (_hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(_currentDirectoryPath, path);
}

- (void) setEnvironment: (NSDictionary*)env
{
  if (_hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(_environment, env);
}

- (void) setLaunchPath: (NSString*)path
{
  if (_hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(_launchPath, path);
}

- (void) setStandardError: (id)hdl
{
  NSAssert([hdl isKindOfClass: [NSFileHandle class]] ||
	   [hdl isKindOfClass: [NSPipe class]], NSInvalidArgumentException);
  if (_hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(_standardError, hdl);
}

- (void) setStandardInput: (id)hdl
{
  NSAssert([hdl isKindOfClass: [NSFileHandle class]] ||
	   [hdl isKindOfClass: [NSPipe class]], NSInvalidArgumentException);
  if (_hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(_standardInput, hdl);
}

- (void) setStandardOutput: (id)hdl
{
  NSAssert([hdl isKindOfClass: [NSFileHandle class]] ||
	   [hdl isKindOfClass: [NSPipe class]], NSInvalidArgumentException);
  if (_hasLaunched)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
  ASSIGN(_standardOutput, hdl);
}

/*
 *	Obtaining task state
 */

- (BOOL) isRunning
{
  if (_hasLaunched == NO)
    {
      return NO;
    }
  if (_hasCollected == NO)
    {
      [self _collectChild];
    }
  if (_hasTerminated == YES)
    {
      return NO;
    }
  return YES;
}

- (int) processIdentifier
{
  return _taskId;
}

- (int) terminationStatus
{
  if (_hasLaunched == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
  if (_hasCollected == NO)
    {
      [self _collectChild];
    }
  if (_hasTerminated == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet terminated"];
    }
  return _terminationStatus;
}

/*
 *	Handling a task.
 */
- (void) interrupt
{
  if (_hasLaunched == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
  if (_hasTerminated)
    {
      return;
    }

#ifndef __MINGW__
#ifdef	HAVE_KILLPG
  killpg(_taskId, SIGINT);
#else
  kill(-_taskId, SIGINT);
#endif
#endif
}

- (void) launch
{
  [self subclassResponsibility: _cmd];
}

- (BOOL) resume
{
  if (_hasLaunched == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
#ifndef __MINGW__
#ifdef	HAVE_KILLPG
  killpg(_taskId, SIGCONT);
#else
  kill(-_taskId, SIGCONT);
#endif
#endif
  return YES;
}

- (BOOL) suspend
{
  if (_hasLaunched == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
#ifndef __MINGW__
#ifdef	HAVE_KILLPG
  killpg(_taskId, SIGTERM);
#else
  kill(-_taskId, SIGTERM);
#endif
#endif
  return YES;
}

- (void) terminate
{
  if (_hasLaunched == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
  if (_hasTerminated)
    {
      return;
    }

  _hasTerminated = YES;
#ifndef __MINGW__
#ifdef	HAVE_KILLPG
  killpg(_taskId, SIGTERM);
#else
  kill(-_taskId, SIGTERM);
#endif
#endif
}

- (BOOL) usePseudoTerminal
{
  return NO;
}

- (void) waitUntilExit
{
  NSTimer	*timer = nil;

  while ([self isRunning])
    {
      NSDate	*limit;

      /*
       *	Poll at 0.1 second intervals.
       */
      limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 0.1];
      if (timer == nil)
	{
	  timer = [NSTimer scheduledTimerWithTimeInterval: 0.1
						   target: nil
						 selector: @selector(class)
						 userInfo: nil
						  repeats: YES];
	}
      [[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
			       beforeDate: limit];
      RELEASE(limit);
    }
  [timer invalidate];
}
@end

@implementation	NSTask (Private)

- (NSString *) _fullLaunchPath
{
  NSFileManager	*mgr = [NSFileManager defaultManager];
  NSString	*libs = [NSBundle _library_combo];
  NSString	*arch = [NSBundle _gnustep_target_dir];
  NSString	*prog;
  NSString	*lpath;
  NSString	*base_path;
  NSString	*arch_path;
  NSString	*full_path;

  if (_launchPath == nil)
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
  prog = [_launchPath lastPathComponent];
  base_path = [_launchPath stringByDeletingLastPathComponent];
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
	      /*
	       * Last resort - if the launch path was simply a program name
	       * get NSBundle to try using the PATH environment
	       * variable to find the executable.
	       */
	      if ([base_path isEqualToString: @""] == YES)
		{
		   lpath = [NSBundle _absolutePathOfExecutable: prog];
		}
	      if (lpath == nil)
		{
		  [NSException raise: NSInvalidArgumentException
			      format: @"NSTask - launch path (%@) not valid",
				_launchPath];
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

  return lpath;
}

- (void) _sendNotification
{
  if (_hasNotified == NO)
    {
      NSNotification	*n;

      _hasNotified = YES;
      n = [NSNotification notificationWithName: NSTaskDidTerminateNotification
					object: self
				      userInfo: nil];

      [[NSNotificationQueue defaultQueue] enqueueNotification: n
		    postingStyle: NSPostASAP
		    coalesceMask: NSNotificationNoCoalescing
			forModes: nil];
    }
}

- (void) _collectChild
{
  [self subclassResponsibility: _cmd];
}

- (void) _terminatedChild: (int)status
{
  [tasksLock lock];
  NSMapRemove(activeTasks, (void*)_taskId);
  [tasksLock unlock];
  _terminationStatus = status;
  _hasCollected = YES;
  _hasTerminated = YES;
  if (_hasNotified == NO)
    {
      [self _sendNotification];
    }
}

@end

#ifdef __MINGW__
@implementation NSConcreteWindowsTask

BOOL
GSCheckTasks()
{
  /* FIXME: Implement */
  return YES;
}

- (void) gcFinalize
{
  [super gcFinalize];
  if (proc_info.hProcess != NULL)
    CloseHandle(proc_info.hProcess);
  if (proc_info.hThread != NULL)
    CloseHandle(proc_info.hThread);
}

- (void) interrupt
{
}

- (void) terminate
{
  if (_hasLaunched == NO)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
  if (_hasTerminated)
    {
      return;
    }

  _hasTerminated = YES;
  TerminateProcess(proc_info.hProcess, 10);
}

- (void) launch
{
  STARTUPINFO	start_info;
  NSString      *lpath;
  NSString      *arg;
  NSEnumerator  *arg_enum;
  NSMutableString *args;
  char		*c_args;
  int		result;

  if (_hasLaunched)
    {
      return;
    }

  lpath = [self _fullLaunchPath];
  args = [lpath mutableCopy];
  arg_enum = [[self arguments] objectEnumerator];
  while ((arg = [arg_enum nextObject]))
    {
      [args appendString: @" "];
      [args appendString: arg];
    }
  c_args = NSZoneMalloc(NSDefaultMallocZone(), [args cStringLength]+1);
  [args getCString: c_args];

  memset (&start_info, 0, sizeof(start_info));
  start_info.cb = sizeof(start_info);
  start_info.dwFlags |= STARTF_USESTDHANDLES;
  start_info.hStdInput  = GetStdHandle(STD_INPUT_HANDLE);
  start_info.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
  start_info.hStdError  = GetStdHandle(STD_ERROR_HANDLE);

  result = CreateProcess([lpath fileSystemRepresentation],
			 c_args,
			 NULL,      /* proc attrs */
			 NULL,      /* thread attrs */
			 1,         /* inherit handles */
			 0,         /* creation flags */
			 NULL,      /* env block */
			 [[self currentDirectoryPath] fileSystemRepresentation],
			 &start_info,
			 &proc_info);
  NSZoneFree(NSDefaultMallocZone(), c_args);
  if (result == 0)
    {
      NSLog(@"Error launching task: %@", lpath);
      return;
    }
  _taskId = proc_info.dwProcessId;
  _hasLaunched = YES;
  ASSIGN(_launchPath, lpath);	// Actual path used.

  [tasksLock lock];
  NSMapInsert(activeTasks, (void*)_taskId, (void*)self);
  [tasksLock unlock];
}

- (void) _collectChild
{
  if (_hasCollected == NO)
    {
      /* FIXME: Implement */
    }
}

- (int) terminationStatus
{
  DWORD	exit_code;
  int	result;

  [super terminationStatus];
  result = GetExitCodeProcess(proc_info.hProcess, &exit_code);
  _terminationStatus = exit_code;
  if (result == 0)
    {
      NSLog(@"Error getting exit code");
      return -1;
    }
  return exit_code;
}

- (void) waitUntilExit
{
  DWORD result;

  result = WaitForSingleObject(proc_info.hProcess, INFINITE);
}
  
@end

#else /* !MINGW */

@implementation NSConcreteUnixTask

BOOL
GSCheckTasks()
{
  BOOL	found = NO;

  if (hadChildSignal == YES)
    {
      int result;
      int status;

      hadChildSignal = NO;

      do
	{
	  result = waitpid(-1, &status, WNOHANG);
	  if (result > 0)
	    {
	      NSTask    *t;

	      [tasksLock lock];
	      t = (NSTask*)NSMapGet(activeTasks, (void*)result);
	      [tasksLock unlock];
	      if (t != nil)
		{
		  if (WIFEXITED(status))
		    {
		      [t _terminatedChild: WEXITSTATUS(status)];
		      found = YES;
		    }
		  else if (WIFSIGNALED(status))
		    {
		      [t _terminatedChild: WTERMSIG(status)];
		      found = YES;
		    }
		  else
		    {
		      NSLog(@"Warning ... task %d neither exited nor signalled",
			result);
		    }
		}
	    }
	}
      while (result > 0);  
    }
  return found;
}

- (void) launch
{
  NSMutableArray	*toClose;
  NSString      *lpath;
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

  if (_hasLaunched)
    {
      return;
    }

  lpath = [self _fullLaunchPath];
  executable = [lpath fileSystemRepresentation];
  args[0] = executable;

  for (i = 0; i < ac; i++)
    {
      args[i+1] = [[[a objectAtIndex: i] description] lossyCString];
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
      envl[i] = [s lossyCString];
    }
  envl[ec] = 0;

  path = [[self currentDirectoryPath] fileSystemRepresentation];

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
#if defined(__MINGW__)
      pid = (int)GetCurrentProcessId(),
#else
      pid = (int)getpid();
#endif
#if     HAVE_SETPGID
      setpgid(pid, pid);
#endif
#endif

      if (_usePseudoTerminal == YES)
	{
	  int	s;

	  s = pty_slave(slave_name);
	  if (s < 0)
	    {
	      exit(1);			/* Failed to open slave!	*/
	    }

#if	HAVE_SETSID
	  i = setsid();
#endif
#ifdef	TIOCNOTTY
	  i = open("/dev/tty", O_RDWR);
	  if (i >= 0)
	    {
	      (void)ioctl(i, TIOCNOTTY, 0);
	      (void)close(i);
	    }
#endif
	  /*
	   * Set up stdin, stdout and stderr by duplicating descriptors as
	   * necessary and closing the originals (to ensure we won't have a
	   * pipe left with two write descriptors etc).
	   */
	  if (s != 0)
	    {
	      dup2(s, 0);
	    }
	  if (s != 1)
	    {
	      dup2(s, 1);
	    }
	  if (s != 2)
	    {
	      dup2(s, 2);
	    }
	}
      else
	{
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
	}

      /*
       * Close any extra descriptors.
       */
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
      _taskId = pid;
      _hasLaunched = YES;
      ASSIGN(_launchPath, lpath);	// Actual path used.

      [tasksLock lock];
      NSMapInsert(activeTasks, (void*)_taskId, (void*)self);
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

- (void) setStandardError: (id)hdl
{
  if (_usePseudoTerminal == YES)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - set error for task on pseudo terminal"];
    }
  [super setStandardError: hdl];
}

- (void) setStandardInput: (id)hdl
{
  if (_usePseudoTerminal == YES)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - set input for task on pseudo terminal"];
    }
  [super setStandardInput: hdl];
}

- (void) setStandardOutput: (id)hdl
{
  if (_usePseudoTerminal == YES)
    {
      [NSException raise: NSInvalidArgumentException
                  format: @"NSTask - set output for task on pseudo terminal"];
    }
  [super setStandardOutput: hdl];
}

- (void) _collectChild
{
  if (_hasCollected == NO)
    {
      int       result;

      errno = 0;
      result = waitpid(_taskId, &_terminationStatus, WNOHANG);
      if (result < 0)
        {
          NSLog(@"waitpid %d, result %d, error %s",
                _taskId, result, GSLastErrorStr(errno));
          [self _terminatedChild: -1];
        }
      else if (result == _taskId || (result > 0 && errno == 0))
	{
	  if (WIFEXITED(_terminationStatus))
	    {
#ifdef  WAITDEBUG
              NSLog(@"waitpid %d, termination status = %d",
                        _taskId, _terminationStatus);
#endif
              [self _terminatedChild: WEXITSTATUS(_terminationStatus)];
	    }
	  else if (WIFSIGNALED(_terminationStatus))
	    {
#ifdef  WAITDEBUG
              NSLog(@"waitpid %d, termination status = %d",
                        _taskId, _terminationStatus);
#endif
              [self _terminatedChild: WTERMSIG(_terminationStatus)];
	    }
#ifdef  WAITDEBUG
          else
            NSLog(@"waitpid %d, event status = %d",
                        _taskId, _terminationStatus);
#endif
	}
#ifdef  WAITDEBUG
      else
        NSLog(@"waitpid %d, result %d, error %s",
                _taskId, result, GSLastErrorStr(errno));
#endif
    }
}

- (BOOL) usePseudoTerminal
{
  int		master;
  NSFileHandle	*fh;

  if (_usePseudoTerminal == YES)
    {
      return YES;
    }
  master = pty_master(slave_name, sizeof(slave_name));
  if (master < 0)
    {
      return NO;
    }
  fh = [[NSFileHandle alloc] initWithFileDescriptor: master
				     closeOnDealloc: YES];
  [self setStandardInput: fh];
  RELEASE(fh);
  master = dup(master);
  fh = [[NSFileHandle alloc] initWithFileDescriptor: master
				     closeOnDealloc: YES];
  [self setStandardOutput: fh];
  RELEASE(fh);
  master = dup(master);
  fh = [[NSFileHandle alloc] initWithFileDescriptor: master
				     closeOnDealloc: YES];
  [self setStandardError: fh];
  RELEASE(fh);
  _usePseudoTerminal = YES;
  return YES;
}

@end
#endif /* !MINGW */
