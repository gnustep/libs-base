#import "ObjectTesting.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

/* Private seams: exercise the real signing and merge code without AWS access. */
@interface NSUbiquitousKeyValueStore (AWSTests)

- (NSMutableURLRequest *) requestWithMethod: (NSString *)method
                                      data: (NSData *)data
                                      etag: (NSString *)etag;

@end

static NSMutableArray *replies;
static NSMutableArray *requests;
static BOOL editDuringPut;

static NSString *
Timestamp(id self, SEL selector)
{
  return @"20130524T000000Z";
}

static NSData *
Transfer(id self, SEL selector, NSURLRequest *request,
  NSHTTPURLResponse **response)
{
  NSDictionary *reply;
  NSData *data;

  [requests addObject: request];
  if ([replies count] == 0)
    {
      [NSException raise: NSGenericException format: @"Unexpected request"];
    }
  reply = AUTORELEASE(RETAIN([replies objectAtIndex: 0]));
  [replies removeObjectAtIndex: 0];
  *response = AUTORELEASE([[NSHTTPURLResponse alloc]
    initWithURL: [request URL]
    statusCode: [[reply objectForKey: @"status"] intValue]
    HTTPVersion: @"HTTP/1.1" headerFields: [reply objectForKey: @"headers"]]);
  data = [reply objectForKey: @"data"];
  if (editDuringPut && [[request HTTPMethod] isEqual: @"PUT"])
    {
      editDuringPut = NO;
      [self setString: @"during upload" forKey: @"reentrant"];
      [(NSUbiquitousKeyValueStore *)self synchronize];
    }
  return data;
}

@interface AWSFixtureProtocol : NSURLProtocol
{
  BOOL _stopped;
}

@end

@implementation AWSFixtureProtocol

+ (BOOL) canInitWithRequest: (NSURLRequest *)request
{
  return [[[request URL] host] isEqual: @"examplebucket.s3.us-east-1.amazonaws.com"];
}

+ (NSURLRequest *) canonicalRequestForRequest: (NSURLRequest *)request
{
  return request;
}

- (void) startLoading
{
  NSHTTPURLResponse *response = nil;
  NSData *data = Transfer(nil, NULL, [self request], &response);

  RETAIN(self);
  if ([response statusCode] == 307)
    {
      [[self client] URLProtocol: self wasRedirectedToRequest:
        [NSURLRequest requestWithURL: [NSURL URLWithString: @"https://example.invalid/"]]
        redirectResponse: response];
    }
  else if ([response statusCode] == 599)
    {
      [[self client] URLProtocol: self didFailWithError:
        [NSError errorWithDomain: NSURLErrorDomain code: NSURLErrorCannotConnectToHost
          userInfo: nil]];
    }
  else
    {
      [[self client] URLProtocol: self didReceiveResponse: response
        cacheStoragePolicy: NSURLCacheStorageNotAllowed];
      [[self client] URLProtocol: self didLoadData: data];
      if (!_stopped)
        {
          [[self client] URLProtocolDidFinishLoading: self];
        }
    }
  RELEASE(self);
}

- (void) stopLoading
{
  _stopped = YES;
}

@end

static void
Reply(int status, id plist, NSString *etag)
{
  NSData *data = [NSData data];
  NSDictionary *headers = [NSDictionary dictionary];

  if (plist != nil)
    {
      data = [plist isKindOfClass: [NSData class]] ? plist :
        [NSPropertyListSerialization dataWithPropertyList: plist
          format: NSPropertyListXMLFormat_v1_0 options: 0 error: NULL];
    }
  if (etag != nil)
    {
      headers = [NSDictionary dictionaryWithObject: etag forKey: @"ETag"];
    }
  [replies addObject: [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInt: status], @"status", data, @"data",
    headers, @"headers", nil]];
}

static NSDictionary *
Uploaded(void)
{
  return [NSPropertyListSerialization propertyListWithData:
    [[requests lastObject] HTTPBody] options: NSPropertyListImmutable
    format: NULL error: NULL];
}

int main(void)
{
  CREATE_AUTORELEASE_POOL(pool);
  Class backend = NSClassFromString(@"GSAWSUbiquitousKeyValueStore");
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSProcessInfo *process = [NSProcessInfo processInfo];
  NSUbiquitousKeyValueStore *store;
  NSMutableURLRequest *request;
  NSMutableString *mutable;
  NSDictionary *remote;
  Method transfer;
  Method timestamp;
  IMP oldTransfer;
  IMP oldTimestamp;

  START_SET("NSUbiquitousKeyValueStore AWS");
  if (![backend instancesRespondToSelector:
      @selector(requestWithMethod:data:etag:)])
    {
      SKIP("AWS backend requires GnuTLS");
    }
  [defaults setObject: @"GSAWSUbiquitousKeyValueStore"
              forKey: @"GSUbiquitousKeyValueStoreClass"];
  [defaults setObject: @"examplebucket" forKey: @"GSAWSKeyValueStoreBucket"];
  [defaults setObject: @"us-east-1" forKey: @"GSAWSKeyValueStoreRegion"];
  [defaults setObject: @"test file+é.plist" forKey: @"GSAWSKeyValueStoreKey"];
  [process setValue: @"AKIAIOSFODNN7EXAMPLE" inEnvironment: @"AWS_ACCESS_KEY_ID"];
  [process setValue: @"wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
     inEnvironment: @"AWS_SECRET_ACCESS_KEY"];
  [process setValue: nil inEnvironment: @"AWS_SESSION_TOKEN"];
  replies = [[NSMutableArray alloc] init];
  requests = [[NSMutableArray alloc] init];
  transfer = class_getInstanceMethod(backend, @selector(sendAWSRequest:response:));
  timestamp = class_getInstanceMethod(backend, @selector(awsTimestamp));
  oldTransfer = method_setImplementation(transfer, (IMP)Transfer);
  oldTimestamp = method_setImplementation(timestamp, (IMP)Timestamp);
  store = [NSUbiquitousKeyValueStore defaultStore];
  PASS([store isKindOfClass: backend], "defaults select the AWS backend");
  request = [store requestWithMethod: @"GET" data: nil etag: nil];
  PASS([[[request URL] absoluteString] isEqual:
    @"https://examplebucket.s3.us-east-1.amazonaws.com/test%20file%2B%C3%A9.plist"],
    "S3 key is encoded bytewise as UTF-8");
  /* Independently calculated with Python hashlib/hmac, using the AWS example
   * credentials, fixed date, and the encoded key above. */
  PASS([[request valueForHTTPHeaderField: @"Authorization"] hasSuffix:
    @"Signature=cba7c9bad417dfbb75883ddd9ace88ced2c1e3bb6865084438339a42b2958a9e"],
    "SigV4 signature matches independent reference");
  [process setValue: @"temporary-token" inEnvironment: @"AWS_SESSION_TOKEN"];
  request = [store requestWithMethod: @"GET" data: nil etag: nil];
  PASS([[request valueForHTTPHeaderField: @"x-amz-security-token"]
    isEqual: @"temporary-token"]
    && [[request valueForHTTPHeaderField: @"Authorization"]
      rangeOfString: @";x-amz-security-token"].location != NSNotFound,
    "temporary session token is sent and signed");
  [process setValue: nil inEnvironment: @"AWS_SESSION_TOKEN"];

  mutable = [NSMutableString stringWithString: @"local"];
  [store setString: mutable forKey: @"local"];
  [mutable appendString: @" changed"];
  PASS([[store stringForKey: @"local"] isEqual: @"local"],
    "stored values are independent of mutable inputs");
  Reply(404, nil, nil);
  Reply(200, nil, nil);
  [store synchronize];
  PASS([[[requests lastObject] valueForHTTPHeaderField: @"If-None-Match"] isEqual: @"*"],
    "new objects use conditional creation");
  PASS([[Uploaded() objectForKey: @"local"] isEqual: @"local"],
    "local changes are uploaded as a property list");

  remote = [NSDictionary dictionaryWithObjectsAndKeys:
    @"other device", @"remote", @"old", @"local", @"delete me", @"deleted", nil];
  [store setString: @"new" forKey: @"local"];
  [store removeObjectForKey: @"deleted"];
  Reply(200, remote, @"\"v1\"");
  Reply(412, nil, nil);
  Reply(200, remote, @"\"v2\"");
  Reply(200, nil, nil);
  [store synchronize];
  PASS([[Uploaded() objectForKey: @"remote"] isEqual: @"other device"]
    && [[Uploaded() objectForKey: @"local"] isEqual: @"new"]
    && [Uploaded() objectForKey: @"deleted"] == nil,
    "retry merges remote keys, local updates, and deletions");
  PASS([[[requests lastObject] valueForHTTPHeaderField: @"If-Match"] isEqual: @"\"v2\""],
    "retry uses the latest ETag");

  [store setString: @"retry me" forKey: @"pending"];
  Reply(200, remote, @"\"v2\"");
  Reply(403, nil, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException,
    "failed uploads report an exception");
  Reply(200, remote, @"\"v2\"");
  Reply(200, nil, nil);
  [store synchronize];
  PASS([[Uploaded() objectForKey: @"pending"] isEqual: @"retry me"],
    "failed upload retains pending edits for retry");

  Reply(200, [@"invalid plist" dataUsingEncoding: NSUTF8StringEncoding], @"\"bad\"");
  PASS_EXCEPTION([store synchronize], NSGenericException,
    "malformed remote content is rejected");
  PASS([[store stringForKey: @"pending"] isEqual: @"retry me"],
    "malformed remote content does not discard local state");
  Reply(200, remote, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException,
    "missing ETag is rejected");
  Reply(403, nil, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException,
    "GET permission failures are not treated as an empty store");

  [store setString: @"edit" forKey: @"local"];
  Reply(200, remote, @"\"v2\"");
  Reply(200, nil, nil);
  editDuringPut = YES;
  [store synchronize];
  PASS([[store stringForKey: @"reentrant"] isEqual: @"during upload"],
    "run-loop edits during upload remain visible");
  Reply(200, remote, @"\"v3\"");
  Reply(200, nil, nil);
  [store synchronize];
  PASS([[Uploaded() objectForKey: @"reentrant"] isEqual: @"during upload"],
    "run-loop edits remain pending for the next upload");

  Reply(200, remote, @"\"v4\"");
  [store synchronize];
  PASS([[[requests lastObject] HTTPMethod] isEqual: @"GET"]
    && [[store dictionaryRepresentation] isEqual: remote],
    "clean stores refresh without uploading");
  PASS_EXCEPTION([store setObject: [NSSet set] forKey: @"bad"],
    NSInvalidArgumentException, "non-property-list values are rejected");
  [store setDictionary: [NSDictionary dictionaryWithObject:
    [NSArray arrayWithObjects: [NSNumber numberWithInt: 42],
      [NSDate dateWithTimeIntervalSince1970: 0], [NSData data], nil] forKey: @"types"]
    forKey: @"nested"];
  PASS([[store dictionaryForKey: @"nested"] count] == 1,
    "nested dictionaries and property-list types are supported");
  Reply(200, remote, @"\"v4\"");
  Reply(409, nil, nil);
  Reply(200, remote, @"\"v5\"");
  Reply(412, nil, nil);
  Reply(200, remote, @"\"v6\"");
  Reply(412, nil, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException,
    "conflicts stop after three attempts");
  Reply(200, remote, @"\"v7\"");
  Reply(200, nil, nil);
  [store synchronize];
  PASS([Uploaded() objectForKey: @"nested"] != nil,
    "exhausted conflict retries preserve pending data");
  [process setValue: nil inEnvironment: @"AWS_SECRET_ACCESS_KEY"];
  PASS_EXCEPTION([store synchronize], NSInvalidArgumentException,
    "missing credentials fail before transport");
  [process setValue: @"wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
     inEnvironment: @"AWS_SECRET_ACCESS_KEY"];

  /* R2 uses a path-style bucket and the auto signing region. */
  [defaults setObject: @"https://0123456789abcdef0123456789abcdef.r2.cloudflarestorage.com"
              forKey: @"GSAWSKeyValueStoreEndpoint"];
  [defaults setObject: @"auto" forKey: @"GSAWSKeyValueStoreRegion"];
  {
    NSUbiquitousKeyValueStore *r2 = AUTORELEASE([[backend alloc] init]);
    request = [r2 requestWithMethod: @"GET" data: nil etag: nil];
    PASS([[[request URL] absoluteString] isEqual:
      @"https://0123456789abcdef0123456789abcdef.r2.cloudflarestorage.com/examplebucket/test%20file%2B%C3%A9.plist"],
      "R2 endpoint uses path-style bucket addressing");
    PASS([[request valueForHTTPHeaderField: @"Authorization"] hasSuffix:
      @"Signature=102d851723253ff4faf1882646dee0de6e0b18cddfbfe22ebbde17fcd835e1c7"], "R2 signature matches independent reference");
    [r2 setString: @"R2" forKey: @"provider"];
    Reply(404, nil, nil);
    Reply(200, nil, nil);
    [r2 synchronize];
    PASS([[Uploaded() objectForKey: @"provider"] isEqual: @"R2"]
      && [[[requests lastObject] valueForHTTPHeaderField: @"If-None-Match"] isEqual: @"*"],
      "R2 uses conditional writes and the shared merge logic");
  }
  [defaults setObject: @"http://example.invalid" forKey: @"GSAWSKeyValueStoreEndpoint"];
  PASS_EXCEPTION(AUTORELEASE([[backend alloc] init]), NSInvalidArgumentException,
    "plaintext custom endpoints are rejected");
  [defaults setObject: @"https://example.invalid/path" forKey: @"GSAWSKeyValueStoreEndpoint"];
  PASS_EXCEPTION(AUTORELEASE([[backend alloc] init]), NSInvalidArgumentException,
    "custom endpoint paths are rejected");
  [defaults setObject: @"https://user@example.invalid" forKey: @"GSAWSKeyValueStoreEndpoint"];
  PASS_EXCEPTION(AUTORELEASE([[backend alloc] init]), NSInvalidArgumentException,
    "custom endpoint user information is rejected");
  [defaults removeObjectForKey: @"GSAWSKeyValueStoreEndpoint"];
  [defaults setObject: @"us-east-1" forKey: @"GSAWSKeyValueStoreRegion"];

  /* Exercise the actual connection delegate using an in-process URL protocol. */
  method_setImplementation(transfer, oldTransfer);
  [NSURLProtocol registerClass: [AWSFixtureProtocol class]];
  Reply(200, remote, @"\"v8\"");
  [store synchronize];
  PASS([[store dictionaryRepresentation] isEqual: remote],
    "connection transport delivers the remote dictionary");
  Reply(307, nil, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException,
    "connection transport rejects redirects without forwarding credentials");
  Reply(599, nil, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException,
    "connection transport reports network failures");
  Reply(200, [NSMutableData dataWithLength: 1048577], @"\"large\"");
  PASS_EXCEPTION([store synchronize], NSGenericException,
    "connection transport rejects oversized responses");
  [NSURLProtocol unregisterClass: [AWSFixtureProtocol class]];
  PASS([replies count] == 0, "all expected requests were consumed");
  method_setImplementation(transfer, oldTransfer);
  method_setImplementation(timestamp, oldTimestamp);
  RELEASE(replies);
  RELEASE(requests);
  END_SET("NSUbiquitousKeyValueStore AWS");
  RELEASE(pool);
  return 0;
}

