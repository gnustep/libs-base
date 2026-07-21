/* Implementation of class NSAppleEventManager
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Fri Nov  1 00:25:06 EDT 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
*/

#import "Foundation/NSAppleEventManager.h"
#import "Foundation/NSAppleEventDescriptor.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSException.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSString.h"
#import "Foundation/NSValue.h"
#import "common.h"

static NSAppleEventManager *sharedManager = nil;
static NSLock *managerLock = nil;

@interface NSAppleEventManager (Private)
- (NSDictionary *) _handlerInfoForEventClass: (AEEventClass)eventClass
                                  andEventID: (AEEventID)eventID;
- (void) _handleAppleEvent: (NSAppleEventDescriptor *)event
         withReplyEvent: (NSAppleEventDescriptor *)replyEvent;
@end

@implementation NSAppleEventManager

+ (void) initialize
{
  if (self == [NSAppleEventManager class])
    {
      managerLock = [[NSLock alloc] init];
    }
}

+ (NSAppleEventManager *) sharedAppleEventManager
{
  if (sharedManager == nil)
    {
      [managerLock lock];
      if (sharedManager == nil)
        {
          sharedManager = [[self alloc] init];
        }
      [managerLock unlock];
    }
  return sharedManager;
}

- (id) init
{
  if ((self = [super init]))
    {
      _eventHandlers = [[NSMutableDictionary alloc] init];
      _suspendedEvents = [[NSMutableDictionary alloc] init];
    }
  return self;
}

- (void) dealloc
{
  RELEASE(_eventHandlers);
  RELEASE(_currentEvent);
  RELEASE(_currentReply);
  RELEASE(_suspendedEvents);
  [super dealloc];
}

- (NSAppleEventDescriptor *) currentAppleEvent
{
  return _currentEvent;
}

- (NSAppleEventDescriptor *) currentReplyAppleEvent
{
  return _currentReply;
}

- (void) setEventHandler: (id)handler
             andSelector: (SEL)handleEventSelector
           forEventClass: (AEEventClass)eventClass
              andEventID: (AEEventID)eventID
{
  NSString *key;
  NSDictionary *handlerInfo;
  
  if (handler == nil || handleEventSelector == NULL)
    {
      [self removeEventHandlerForEventClass: eventClass andEventID: eventID];
      return;
    }
  
  key = [NSString stringWithFormat: @"%u_%u", 
         (unsigned int)eventClass, (unsigned int)eventID];
  
  handlerInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                   handler, @"handler",
                   NSStringFromSelector(handleEventSelector), @"selector",
                   nil];
  
  if (handlerInfo != nil)
    {
      [_eventHandlers setObject: handlerInfo forKey: key];
    }
}

- (void) removeEventHandlerForEventClass: (AEEventClass)eventClass
                              andEventID: (AEEventID)eventID
{
  NSString *key;
  
  key = [NSString stringWithFormat: @"%u_%u", 
         (unsigned int)eventClass, (unsigned int)eventID];
  if (key != nil)
    {
      [_eventHandlers removeObjectForKey: key];
    }
}

- (NSDictionary *) _handlerInfoForEventClass: (AEEventClass)eventClass
                                  andEventID: (AEEventID)eventID
{
  NSString *key;
  
  key = [NSString stringWithFormat: @"%u_%u", 
         (unsigned int)eventClass, (unsigned int)eventID];
  if (key != nil)
    {
      return [_eventHandlers objectForKey: key];
    }
  return nil;
}

- (void) _handleAppleEvent: (NSAppleEventDescriptor *)event
         withReplyEvent: (NSAppleEventDescriptor *)replyEvent
{
  AEEventClass eventClass;
  AEEventID eventID;
  NSDictionary *handlerInfo;
  id handler;
  SEL selector;
  NSAppleEventDescriptor *oldEvent;
  NSAppleEventDescriptor *oldReply;
  
  eventClass = [event eventClass];
  eventID = [event eventID];
  
  handlerInfo = [self _handlerInfoForEventClass: eventClass andEventID: eventID];
  
  if (handlerInfo == nil)
    {
      return;
    }
  
  handler = [handlerInfo objectForKey: @"handler"];
  selector = NSSelectorFromString([handlerInfo objectForKey: @"selector"]);
  
  if (handler == nil || selector == NULL)
    {
      return;
    }
  
  oldEvent = RETAIN(_currentEvent);
  oldReply = RETAIN(_currentReply);
  
  ASSIGN(_currentEvent, event);
  ASSIGN(_currentReply, replyEvent);
  
  NS_DURING
    {
      if ([handler respondsToSelector: selector])
        {
          [handler performSelector: selector withObject: event withObject: replyEvent];
        }
    }
  NS_HANDLER
    {
      NSLog(@"Exception handling Apple Event: %@", localException);
    }
  NS_ENDHANDLER
  
  ASSIGN(_currentEvent, oldEvent);
  ASSIGN(_currentReply, oldReply);
  RELEASE(oldEvent);
  RELEASE(oldReply);
}

- (NSAppleEventDescriptor *) replyAppleEventForSuspendedAppleEvent: (NSAppleEventDescriptor *)event
{
  NSString *key;
  NSDictionary *suspended;
  
  if (event == nil)
    {
      return nil;
    }
  
  key = [NSString stringWithFormat: @"%p", event];
  if (key != nil)
    {
      suspended = [_suspendedEvents objectForKey: key];
      
      if (suspended != nil)
        {
          return [suspended objectForKey: @"reply"];
        }
    }
  
  return nil;
}

- (void) resumeWithSuspendedAppleEvent: (NSAppleEventDescriptor *)event
{
  NSString *key;
  
  if (event == nil)
    {
      return;
    }
  
  key = [NSString stringWithFormat: @"%p", event];
  if (key != nil)
    {
      [_suspendedEvents removeObjectForKey: key];
    }
}

- (void) setCurrentAppleEventAndReplyEventWithSuspendedAppleEvent: (NSAppleEventDescriptor *)event
{
  NSString *key;
  NSDictionary *suspended;
  NSAppleEventDescriptor *replyEvent;
  
  if (event == nil)
    {
      return;
    }
  
  key = [NSString stringWithFormat: @"%p", event];
  if (key != nil)
    {
      suspended = [_suspendedEvents objectForKey: key];
      
      if (suspended != nil)
        {
          replyEvent = [suspended objectForKey: @"reply"];
          ASSIGN(_currentEvent, event);
          ASSIGN(_currentReply, replyEvent);
        }
    }
}

- (NSAppleEventDescriptor *) suspendCurrentAppleEvent
{
  NSAppleEventDescriptor *event;
  NSString *key;
  NSDictionary *suspended;
  
  event = _currentEvent;
  
  if (event == nil)
    {
      return nil;
    }
  
  key = [NSString stringWithFormat: @"%p", event];
  suspended = [NSDictionary dictionaryWithObjectsAndKeys:
                 event, @"event",
                 _currentReply, @"reply",
                 nil];
  
  if (key != nil && suspended != nil)
    {
      [_suspendedEvents setObject: suspended forKey: key];
    }
  
  return event;
}

@end
