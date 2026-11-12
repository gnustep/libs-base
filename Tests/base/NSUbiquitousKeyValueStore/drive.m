#import "ObjectTesting.h"
#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSMutableArray *replies;
static NSMutableArray *requests;
static NSString *storeName = @"settings's \\ app.plist";
static NSUbiquitousKeyValueStore *activeStore;
static BOOL editDuringUpload;
static NSUInteger notifications;
static NSInteger reason;

@interface DriveObserver : NSObject

- (void) changed: (NSNotification *)notification;

@end

@implementation DriveObserver

- (void) changed: (NSNotification *)notification
{
  notifications++;
  reason = [[[notification userInfo]
    objectForKey: NSUbiquitousKeyValueStoreChangeReasonKey] integerValue];
}

@end

static NSData *
Transfer(id self, SEL selector, NSURLRequest *request, NSHTTPURLResponse **response)
{
  NSDictionary *reply;

  [requests addObject: AUTORELEASE([request copy])];
  if ([replies count] == 0)
    {
      [NSException raise: NSGenericException format: @"Unexpected Drive request"];
    }
  reply = AUTORELEASE(RETAIN([replies objectAtIndex: 0]));
  [replies removeObjectAtIndex: 0];
  *response = AUTORELEASE([[NSHTTPURLResponse alloc] initWithURL: [request URL]
    statusCode: [[reply objectForKey: @"status"] integerValue]
    HTTPVersion: @"HTTP/1.1" headerFields: nil]);
  if (editDuringUpload && [[request HTTPMethod] isEqual: @"PUT"])
    {
      editDuringUpload = NO;
      [activeStore setString: @"callback" forKey: @"reentrant"];
      [activeStore synchronize];
    }
  return [reply objectForKey: @"data"];
}

static void
Reply(NSInteger status, id object)
{
  NSData *data = [NSData data];

  if (object != nil)
    {
      data = [object isKindOfClass: [NSData class]] ? object :
        [NSJSONSerialization dataWithJSONObject: object options: 0 error: NULL];
    }
  [replies addObject: [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInteger: status], @"status", data, @"data", nil]];
}

static NSDictionary *
Listing(NSString *identifier)
{
  return [NSDictionary dictionaryWithObject: identifier ?
    [NSArray arrayWithObject: [NSDictionary dictionaryWithObject: identifier forKey: @"id"]]
    : [NSArray array] forKey: @"items"];
}

static NSDictionary *
Metadata(NSString *etag)
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
    @"file-one", @"id", etag, @"etag", storeName, @"title",
    [NSArray arrayWithObject: @"appDataFolder"], @"spaces", nil];
}

static NSData *
Plist(NSDictionary *dictionary)
{
  return [NSPropertyListSerialization dataWithPropertyList: dictionary
    format: NSPropertyListXMLFormat_v1_0 options: 0 error: NULL];
}

static void
Read(NSDictionary *dictionary, NSString *etag)
{
  Reply(200, Listing(@"file-one"));
  Reply(200, Metadata(etag));
  Reply(200, Plist(dictionary));
  Reply(200, Metadata(etag));
}

static NSDictionary *
Uploaded(void)
{
  return [NSPropertyListSerialization propertyListWithData:
    [[requests lastObject] HTTPBody] options: NSPropertyListImmutable
    format: NULL error: NULL];
}

static NSString *
Body(NSURLRequest *request)
{
  return AUTORELEASE([[NSString alloc] initWithData: [request HTTPBody]
    encoding: NSUTF8StringEncoding]);
}

int main(void)
{
  CREATE_AUTORELEASE_POOL(pool);
  Class backend = NSClassFromString(@"GSGoogleDriveUbiquitousKeyValueStore");
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSProcessInfo *process = [NSProcessInfo processInfo];
  NSUbiquitousKeyValueStore *store;
  Method transfer;
  IMP oldTransfer;
  NSDictionary *remote;
  NSDictionary *uploadedID = [NSDictionary dictionaryWithObject: @"file-one" forKey: @"id"];
  DriveObserver *observer = AUTORELEASE([[DriveObserver alloc] init]);
  NSUInteger count;

  START_SET("NSUbiquitousKeyValueStore Google Drive");
  if (![backend instancesRespondToSelector: @selector(sendDriveRequest:response:)])
    {
      SKIP("Google Drive backend requires GnuTLS");
    }
  [defaults setObject: @"GSGoogleDriveUbiquitousKeyValueStore"
              forKey: @"GSUbiquitousKeyValueStoreClass"];
  [defaults setObject: storeName forKey: @"GSGoogleDriveKeyValueStoreName"];
  [defaults removeObjectForKey: @"GSGoogleDriveKeyValueStoreFileID"];
  [process setValue: @"access-one" inEnvironment: @"GOOGLE_DRIVE_ACCESS_TOKEN"];
  [process setValue: nil inEnvironment: @"GOOGLE_DRIVE_REFRESH_TOKEN"];
  [process setValue: nil inEnvironment: @"GOOGLE_DRIVE_CLIENT_ID"];
  [process setValue: nil inEnvironment: @"GOOGLE_DRIVE_CLIENT_SECRET"];
  replies = [[NSMutableArray alloc] init];
  requests = [[NSMutableArray alloc] init];
  transfer = class_getInstanceMethod(backend, @selector(sendDriveRequest:response:));
  oldTransfer = method_setImplementation(transfer, (IMP)Transfer);
  store = [NSUbiquitousKeyValueStore defaultStore];
  activeStore = store;
  PASS([store isKindOfClass: backend], "defaults select the Drive backend");
  [[NSNotificationCenter defaultCenter] addObserver: observer selector: @selector(changed:)
    name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification object: store];

  Reply(200, Listing(nil));
  [store synchronize];
  PASS([requests count] == 1 && [[store dictionaryRepresentation] count] == 0,
    "an empty clean store only lists appDataFolder");
  PASS([[[requests lastObject] valueForHTTPHeaderField: @"Authorization"] isEqual: @"Bearer access-one"],
    "Drive uses OAuth bearer authorization");
  PASS([[[[requests lastObject] URL] absoluteString] rangeOfString:
    @"spaces=appDataFolder"].location != NSNotFound
    && [[[[requests lastObject] URL] absoluteString] rangeOfString:
    @"settings%5C%27s%20%5C%5C%20app.plist"].location != NSNotFound,
    "file discovery restricts its space and escapes the query name");
  [store setString: @"local" forKey: @"local"];
  Reply(200, Listing(nil));
  Reply(200, [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"file-one"] forKey: @"ids"]);
  Reply(200, uploadedID);
  [store synchronize];
  {
    NSURLRequest *request = [requests lastObject];
    NSString *body = Body(request);
    NSRange start = [body rangeOfString: @"\r\n\r\n"];
    NSRange end = [body rangeOfString: @"\r\n--" options: 0
      range: NSMakeRange(NSMaxRange(start), [body length] - NSMaxRange(start))];
    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:
      [[body substringWithRange: NSMakeRange(NSMaxRange(start), end.location - NSMaxRange(start))]
        dataUsingEncoding: NSUTF8StringEncoding] options: 0 error: NULL];
    PASS([[request HTTPMethod] isEqual: @"POST"]
      && [[request valueForHTTPHeaderField: @"Content-Type"] hasPrefix: @"multipart/related;"],
      "new stores use a multipart upload");
    PASS([[json objectForKey: @"id"] isEqual: @"file-one"]
      && [[json objectForKey: @"title"] isEqual: storeName]
      && [[[[json objectForKey: @"parents"] objectAtIndex: 0] objectForKey: @"id"] isEqual: @"appDataFolder"],
      "creation uses a pre-generated ID and the hidden application folder");
    PASS([body rangeOfString: @"<key>local</key>"].location != NSNotFound,
      "the multipart content contains the serialized key-value dictionary");
    PASS(notifications == 0, "uploading local changes does not post an external-change notification");
  }

  remote = [NSDictionary dictionaryWithObjectsAndKeys:
    @"other device", @"remote", @"old", @"local", @"remove me", @"deleted", nil];
  [store setString: @"new" forKey: @"local"];
  [store removeObjectForKey: @"deleted"];
  Read(remote, @"\"v1\"");
  Reply(412, nil);
  Read(remote, @"\"v2\"");
  Reply(200, uploadedID);
  [store synchronize];
  PASS([[Uploaded() objectForKey: @"local"] isEqual: @"new"]
    && [[Uploaded() objectForKey: @"remote"] isEqual: @"other device"]
    && [Uploaded() objectForKey: @"deleted"] == nil,
    "conflict retries merge local changes and preserve remote keys");
  PASS([[[requests lastObject] valueForHTTPHeaderField: @"If-Match"] isEqual: @"\"v2\""],
    "updates use the latest file ETag");
  PASS(notifications == 1 && reason == 0, "server changes post a notification after synchronization");

  [store setString: @"keep me" forKey: @"pending"];
  Read(remote, @"\"v2\"");
  Reply(403, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException, "permission failures preserve pending state");
  Read(remote, @"\"v2\"");
  Reply(200, uploadedID);
  [store synchronize];
  PASS([[Uploaded() objectForKey: @"pending"] isEqual: @"keep me"],
    "a later successful sync uploads edits retained after failure");

  Reply(200, Listing(@"file-one"));
  Reply(200, Metadata(@"\"v3\""));
  Reply(200, Plist(remote));
  Reply(200, Metadata(@"\"v4\""));
  Read(remote, @"\"v4\"");
  [store synchronize];
  PASS([[[requests lastObject] HTTPMethod] isEqual: @"GET"],
    "a file changed during download is re-read without an unconditional upload");

  [store setString: @"upload" forKey: @"local"];
  Read(remote, @"\"v4\"");
  Reply(200, uploadedID);
  editDuringUpload = YES;
  [store synchronize];
  Read(remote, @"\"v5\"");
  Reply(200, uploadedID);
  [store synchronize];
  PASS([[Uploaded() objectForKey: @"reentrant"] isEqual: @"callback"],
    "run-loop edits during a Drive upload remain pending");

  Reply(200, [NSDictionary dictionaryWithObjectsAndKeys: [NSArray array], @"items",
    @"next/page+", @"nextPageToken", nil]);
  Reply(200, Listing(@"file-one"));
  Reply(200, Metadata(@"\"v5\""));
  Reply(200, Plist(remote));
  Reply(200, Metadata(@"\"v5\""));
  count = [requests count];
  [store synchronize];
  PASS([[[[requests objectAtIndex: count + 1] URL] absoluteString]
    rangeOfString: @"pageToken=next%2Fpage%2B"].location != NSNotFound,
    "discovery follows escaped pagination tokens");

  Reply(200, [NSDictionary dictionaryWithObject: [NSArray arrayWithObjects:
    uploadedID, [NSDictionary dictionaryWithObject: @"file-two" forKey: @"id"], nil] forKey: @"items"]);
  PASS_EXCEPTION([store synchronize], NSGenericException, "duplicate names are rejected without choosing a file");
  Reply(200, Listing(nil));
  PASS_EXCEPTION([store synchronize], NSGenericException, "a disappeared store is not silently recreated");
  Reply(401, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException, "an expired access-only token reports failure");
  Reply(429, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException, "rate limits report failure without clearing local state");

  /* Token refresh, form escaping, retry on 401, and reuse of the new token. */
  [process setValue: nil inEnvironment: @"GOOGLE_DRIVE_ACCESS_TOKEN"];
  [process setValue: @"client+id" inEnvironment: @"GOOGLE_DRIVE_CLIENT_ID"];
  [process setValue: @"refresh/&=" inEnvironment: @"GOOGLE_DRIVE_REFRESH_TOKEN"];
  [process setValue: @"secret&value" inEnvironment: @"GOOGLE_DRIVE_CLIENT_SECRET"];
  Reply(200, [NSDictionary dictionaryWithObjectsAndKeys: @"access-two", @"access_token",
    @"Bearer", @"token_type", [NSNumber numberWithInt: 3600], @"expires_in", nil]);
  Read(remote, @"\"v6\"");
  count = [requests count];
  [store synchronize];
  PASS([Body([requests objectAtIndex: count]) rangeOfString:
    @"refresh_token=refresh%2F%26%3D"].location != NSNotFound
    && [Body([requests objectAtIndex: count]) rangeOfString:
    @"client_secret=secret%26value"].location != NSNotFound
    && [[requests objectAtIndex: count] valueForHTTPHeaderField: @"Authorization"] == nil,
    "OAuth refresh uses encoded form fields without forwarding a bearer token");
  PASS([[[requests lastObject] valueForHTTPHeaderField: @"Authorization"] isEqual: @"Bearer access-two"],
    "Drive requests use the refreshed token");
  Reply(401, nil);
  Reply(200, [NSDictionary dictionaryWithObjectsAndKeys: @"access-three", @"access_token",
    @"Bearer", @"token_type", [NSNumber numberWithInt: 3600], @"expires_in", nil]);
  Read(remote, @"\"v6\"");
  [store synchronize];
  PASS([[[requests lastObject] valueForHTTPHeaderField: @"Authorization"] isEqual: @"Bearer access-three"],
    "401 triggers one refresh and request retry");
  Reply(401, nil);
  Reply(400, nil);
  PASS_EXCEPTION([store synchronize], NSGenericException, "revoked refresh tokens report failure");

  /* An explicitly selected app-data file bypasses name discovery. */
  [defaults setObject: @"file-one" forKey: @"GSGoogleDriveKeyValueStoreFileID"];
  [process setValue: @"access-one" inEnvironment: @"GOOGLE_DRIVE_ACCESS_TOKEN"];
  {
    NSUbiquitousKeyValueStore *selected = AUTORELEASE([[backend alloc] init]);
    Reply(200, Metadata(@"\"v7\""));
    Reply(200, Plist(remote));
    Reply(200, Metadata(@"\"v7\""));
    count = [requests count];
    [selected synchronize];
    PASS([requests count] == count + 3 && [[selected dictionaryRepresentation] isEqual: remote],
      "explicit file IDs read the selected store without listing");
    Reply(200, [NSDictionary dictionaryWithObjectsAndKeys: @"file-one", @"id",
      @"\"v7\"", @"etag", [NSArray arrayWithObject: @"drive"], @"spaces", nil]);
    PASS_EXCEPTION([selected synchronize], NSGenericException, "ordinary Drive files cannot be overwritten");
    Reply(200, Metadata(@"\"v7\""));
    Reply(200, [@"malformed" dataUsingEncoding: NSUTF8StringEncoding]);
    Reply(200, Metadata(@"\"v7\""));
    PASS_EXCEPTION([selected synchronize], NSGenericException, "malformed stored property lists are rejected");
    PASS([[selected dictionaryRepresentation] isEqual: remote], "bad remote data leaves the cache unchanged");
  }
  [defaults removeObjectForKey: @"GSGoogleDriveKeyValueStoreFileID"];
  /* A lost creation response must reuse/check the generated ID on retry. */
  {
    NSUbiquitousKeyValueStore *newStore = AUTORELEASE([[backend alloc] init]);
    [newStore setString: @"recover" forKey: @"local"];
    Reply(200, Listing(nil));
    Reply(200, [NSDictionary dictionaryWithObject: [NSArray arrayWithObject: @"file-one"] forKey: @"ids"]);
    Reply(503, nil);
    PASS_EXCEPTION([newStore synchronize], NSGenericException, "an ambiguous creation failure retains edits");
    Reply(200, Listing(nil));
    Reply(200, Metadata(@"\"created\""));
    Reply(200, Plist(remote));
    Reply(200, Metadata(@"\"created\""));
    Reply(200, uploadedID);
    [newStore synchronize];
    PASS([[[requests lastObject] HTTPMethod] isEqual: @"PUT"]
      && [[Uploaded() objectForKey: @"local"] isEqual: @"recover"],
      "retry recovers an existing generated ID instead of creating a duplicate");
  }
  PASS([replies count] == 0, "all scripted Drive requests were consumed");
  [[NSNotificationCenter defaultCenter] removeObserver: observer];
  method_setImplementation(transfer, oldTransfer);
  RELEASE(replies);
  RELEASE(requests);
  END_SET("NSUbiquitousKeyValueStore Google Drive");
  RELEASE(pool);
  return 0;
}

