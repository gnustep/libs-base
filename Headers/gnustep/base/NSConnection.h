
@interface NSConnection : NSObject
{
}

- init;

+ (NSConnection*) connectionWithRegisteredName: (NSString*)name 
  host: (NSString*)host;
+ (NSConnection*) defaultConnection;
+ (NSDistantObject*) rootProxyForConnectionWithRegisteredName: (NSString*)name;

+ (NSArray*) allConnections;
- (BOOL) isValid;

- (BOOL) registerName: (NSString*)name;

- (id) delegate;
- (void) setDelegate: (id)anObject;

- (id) rootObject;
- (NSDistantObject*) rootProxy;
- (void) setRootObject: (id)anObject;

- (NSString*) requestMode;
- (void) setRequestMode: (NSString*)mode;

- (BOOL) independentConversationQueueing;
- (void) setIndependentConversationQueueing: (BOOL)f;

- (NSTimeInterval) replyTimeout;
- (NSTimeInterval) requestTimeout;
- (void) setReplyTimeout: (NSTimeInterval)i;
- (void) setRequestTimeout: (NSTimeInterval)i;

- (NSDictionary*) statistics;

@end

@interface Object (NSConnection_Delegate)
- (BOOL) makeNewConnection: (NSConnection*)c sender: (NSConnection*)ancester;
@end

