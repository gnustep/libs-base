/* Implementation for NSTask for GNUStep
   Copyright (C) 1998 Free Software Foundation, Inc.

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
#include <gnustep/base/preface.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSData.h>
#include <Foundation/NSDate.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSFileHandle.h>
#include <Foundation/NSFileManager.h>
#include <Foundation/NSProcessInfo.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSNotification.h>
#include <Foundation/NSNotificationQueue.h>
#include <Foundation/NSTask.h>

#include <sys/signal.h>
#include <sys/types.h>
#include <sys/wait.h>

NSString *NSTaskDidTerminateNotification = @"NSTaskDidTerminateNotification";

@interface NSTask (Private)
- (void) _collectChild;
- (void) _sendNotification;
@end

@implementation NSTask

+ (NSTask*)launchedTaskWithLaunchPath:(NSString*)path arguments: (NSArray*)args
{
    NSTask*	task = [NSTask new];

    [task setLaunchPath: path];
    [task setArguments: args];
    [task launch];
    return [task autorelease];
}

- (void) dealloc
{
    [arguments release];
    [environment release];
    [launchPath release];
    [currentDirectoryPath release];
    [standardError release];
    [standardInput release];
    [standardOutput release];
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
    if (currentDirectoryPath == nil) {
	[self setCurrentDirectoryPath:
		[[NSFileManager defaultManager] currentDirectoryPath]];
    }
    return currentDirectoryPath;
}

- (NSDictionary*) environment
{
    if (environment == nil) {
	[self setEnvironment: [[NSProcessInfo processInfo] environment]];
    }
    return environment;
}

- (NSString*) launchPath
{
    return launchPath;
}

- (NSFileHandle*) standardError
{
    if (standardError == nil) {
	[self setStandardError: [NSFileHandle fileHandleWithStandardError]];
    }
    return standardError;
}

- (NSFileHandle*) standardInput
{
    if (standardInput == nil) {
	[self setStandardInput: [NSFileHandle fileHandleWithStandardInput]];
    }
    return standardInput;
}

- (NSFileHandle*) standardOutput
{
    if (standardOutput == nil) {
	[self setStandardOutput: [NSFileHandle fileHandleWithStandardOutput]];
    }
    return standardOutput;
}

/*
 *	Setting task parameters.
 */

- (void)setArguments: (NSArray*)args
{
    if (hasLaunched) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
    [args retain];
    [arguments release];
    arguments = args;
}

- (void)setCurrentDirectoryPath: (NSString*)path
{
    if (hasLaunched) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
    [path retain];
    [currentDirectoryPath release];
    currentDirectoryPath = path;
}

- (void)setEnvironment: (NSDictionary*)env
{
    if (hasLaunched) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
    [env retain];
    [environment release];
    environment = env;
}

- (void)setLaunchPath: (NSString*)path
{
    if (hasLaunched) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
    [path retain];
    [launchPath release];
    launchPath = path;
}

- (void)setStandardError: (NSFileHandle*)hdl
{
    if (hasLaunched) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
    [hdl retain];
    [standardError release];
    standardError = hdl;
}

- (void)setStandardInput: (NSFileHandle*)hdl
{
    if (hasLaunched) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
    [hdl retain];
    [standardInput release];
    standardInput = hdl;
}

- (void)setStandardOutput: (NSFileHandle*)hdl
{
    if (hasLaunched) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has been launched"];
    }
    [hdl retain];
    [standardOutput release];
    standardOutput = hdl;
}

/*
 *	Obtaining task state
 */

- (BOOL) isRunning
{
    if (hasLaunched == NO) return NO;
    if (hasCollected == NO) {
	[self _collectChild];
    }
    if (hasTerminated == YES) return NO;
    return YES;
}

- (int) terminationStatus
{
    if (hasLaunched == NO) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
    if (hasCollected == NO) {
	[self _collectChild];
    }
    if (hasTerminated == NO) {
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
}

- (void) launch
{
    int	pid;
    const char*	executable;
    const char*	path;
    int	idesc;
    int	odesc;
    int	edesc;
    NSDictionary	*e = [self environment];
    NSArray		*k = [e allKeys];
    NSArray		*a = [self arguments];
    int			ec = [e count];
    int			ac = [a count];
    const char	*args[ac+2];
    const char	*envl[ec+1];
    int		i;

    if (hasLaunched) {
	return;
    }

    if (launchPath == nil) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - no launch path set"];
    }
    else if ([[NSFileManager defaultManager] isExecutableFileAtPath:
		launchPath] == NO) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - launch path is not valid"];
    }

    executable = [[self launchPath] cString];

    args[0] = [[[self launchPath] lastPathComponent] cString];
    for (i = 0; i < ac; i++) {
	args[i+1] = [[[a objectAtIndex: i] description] cString];
    }
    args[ac+1] = 0;

    for (i = 0; i < ec; i++) {
	NSString	*s;
	id		key = [k objectAtIndex: i];
	id		val = [e objectForKey: key];

	if (val) {
	    s = [NSString stringWithFormat: @"%s=%s",
			[key cString], [val cString]];
	}
	else {
	    s = [NSString stringWithFormat: @"%s=", [key cString]];
	}
	envl[i] = [s cString];
    }
    envl[ec] = 0;

    path = [[self currentDirectoryPath] cString];
    idesc = [[self standardInput] fileDescriptor];
    odesc = [[self standardError] fileDescriptor];
    edesc = [[self standardOutput] fileDescriptor];

    pid = fork();
    if (pid < 0) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - failed to create child process"];
    }
    if (pid == 0) {
	if (idesc != 0) dup2(idesc, 0);
	if (odesc != 1) dup2(odesc, 1);
	if (edesc != 2) dup2(edesc, 2);
	chdir(path);
	execve(executable, args, envl);
	exit(-1);
    }
    else {
	taskId = pid;
	hasLaunched = YES;
    }
}

- (void) terminate
{
    if (hasLaunched == NO) {
	[NSException raise: NSInvalidArgumentException
                  format: @"NSTask - task has not yet launched"];
    }
    if (hasTerminated) {
	return;
    }

    hasTerminated = YES;
#ifdef	HAVE_KILLPG
    killpg(taskId, SIGTERM);
#else
    kill(-taskId, SIGTERM);
#endif

    if (hasNotified == NO) {
	[self _sendNotification];
    }
}

- (void) waitUntilExit
{
    while ([self isRunning]) {
	NSDate	*limit;

	/*
	 *	Poll at 1.0 second intervals.
	 */
	limit = [[NSDate alloc] initWithTimeIntervalSinceNow: 1.0];
	[[NSRunLoop currentRunLoop] runMode: NSDefaultRunLoopMode
				 beforeDate: nil];
	[limit release];
    }
}
@end

@implementation	NSTask (Private)

- (void) _collectChild
{
    if (hasCollected == NO) {
        if (waitpid(taskId, &terminationStatus, WNOHANG) == taskId) {
	    if (WIFEXITED(terminationStatus)) {
		terminationStatus = WEXITSTATUS(terminationStatus);
		hasCollected = YES;
		hasTerminated = YES;
		if (hasNotified == NO) {
		    [self _sendNotification];
		}
	    }
	}
    }
}

- (void) _sendNotification
{
    if (hasNotified == NO) {
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
@end

