
#import <Foundation/Foundation.h>

@interface TaskMan : NSObject
{
	NSMutableArray *taskList;
}

-nextTask:(NSNotification *) aNotification;
@end

@implementation TaskMan
-init
{
	NSTask *aTask;

	self = [super init];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(nextTask:)
		name:NSTaskDidTerminateNotification
		object:nil];

	taskList = [[NSMutableArray alloc] init];

	aTask = [[NSTask alloc] init];
	[aTask setLaunchPath:@"/bin/ls"];
	[aTask setArguments:nil];
	[taskList addObject:aTask];

	aTask = [[NSTask alloc] init];
	[aTask setLaunchPath:@"/bin/ps"];
	[aTask setArguments:nil];
	[taskList addObject:aTask];

	aTask = [[NSTask alloc] init];
	[aTask setLaunchPath:@"/bin/pwd"];
	[aTask setArguments:nil];
	[taskList addObject:aTask];

	aTask = [[NSTask alloc] init];
	[aTask setLaunchPath:@"/bin/date"];
	[aTask setArguments:nil];
	[taskList addObject:aTask];

	[[taskList objectAtIndex:0] launch];

	return self;
}

-nextTask:(NSNotification *) aNotification
{
	if ([[aNotification object] terminationStatus] == 0) {
		[NSNotification notificationWithName:@"CommandCompletedSuccessfully"
			object:self];
	} else {
		[NSNotification notificationWithName:@"CommandFailed"
			object:self];
	}
	[taskList removeObjectAtIndex:0];

	if ([taskList count] > 0)
		[[taskList objectAtIndex:0] launch];
	else
		exit(0);

	return self;
}
@end

int main(int argc, char **argv, char** env)
{
	NSAutoreleasePool *pool;
	TaskMan *aTaskMan;
	int i = 0;

	pool = [NSAutoreleasePool new];
	aTaskMan = [[TaskMan alloc] init];

	while(1) {
		[[NSRunLoop currentRunLoop] runOnceBeforeDate:
			[NSDate dateWithTimeIntervalSinceNow: 5]];

/* Uncomment the following line, and the app will complete all tasks */
/* otherwise it will hang */
//printf("%d\n", i++);
//	NSLog(@"");
	}

	exit(0);	
}

