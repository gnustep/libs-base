#ifndef __NSURLSession_h_GNUSTEP_BASE_INCLUDE
#define __NSURLSession_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSHTTPCookieStorage.h>

#if GS_HAVE_NSURLSESSION
#if OS_API_VERSION(MAC_OS_X_VERSION_10_9,GS_API_LATEST)
@protocol NSURLSessionDelegate;
@protocol NSURLSessionTaskDelegate;

@class GSMultiHandle;
@class GSURLSessionTaskBody;
@class NSError;
@class NSHTTPURLResponse;
@class NSOperationQueue;
@class NSURL;
@class NSURLAuthenticationChallenge;
@class NSURLCache;
@class NSURLCredential;
@class NSURLCredentialStorage;
@class NSURLRequest;
@class NSURLResponse;
@class NSURLSessionConfiguration;
@class NSURLSessionTask;
@class NSURLSessionDataTask;
@class NSURLSessionUploadTask;
@class NSURLSessionDownloadTask;


/**
 * NSURLSession is a replacement API for NSURLConnection.  It provides
 * options that affect the policy of, and various aspects of the
 * mechanism by which NSURLRequest objects are retrieved from the
 * network.<br />
 *
 * An NSURLSession may be bound to a delegate object.  The delegate is
 * invoked for certain events during the lifetime of a session.
 * 
 * NSURLSession instances are threadsafe.
 *
 * An NSURLSession creates NSURLSessionTask objects which represent the
 * action of a resource being loaded.
 * 
 * NSURLSessionTask objects are always created in a suspended state and
 * must be sent the -resume message before they will execute.
 *
 * Subclasses of NSURLSessionTask are used to syntactically
 * differentiate between data and file downloads.
 * 
 * An NSURLSessionDataTask receives the resource as a series of calls to
 * the URLSession:dataTask:didReceiveData: delegate method.  This is type of
 * task most commonly associated with retrieving objects for immediate parsing
 * by the consumer.
 */
GS_EXPORT_CLASS
@interface NSURLSession : NSObject
{
  NSOperationQueue           *_delegateQueue;
  id <NSURLSessionDelegate>  _delegate;
  NSURLSessionConfiguration  *_configuration;
  NSString                   *_sessionDescription;
  GSMultiHandle              *_multiHandle;
}

+ (NSURLSession*) sharedSession;

+ (NSURLSession*) sessionWithConfiguration: (NSURLSessionConfiguration*)configuration;

/*
 * Customization of NSURLSession occurs during creation of a new session.
 * If you do specify a delegate, the delegate will be retained until after
 * the delegate has been sent the URLSession:didBecomeInvalidWithError: message.
 */
+ (NSURLSession*) sessionWithConfiguration: (NSURLSessionConfiguration*)configuration 
                                  delegate: (id <NSURLSessionDelegate>)delegate 
                             delegateQueue: (NSOperationQueue*)queue;

- (NSOperationQueue*) delegateQueue;

- (id <NSURLSessionDelegate>) delegate;

- (NSURLSessionConfiguration*) configuration;

- (NSString*) sessionDescription;

- (void) setSessionDescription: (NSString*)sessionDescription;

/* -finishTasksAndInvalidate returns immediately and existing tasks will be 
 * allowed to run to completion.  New tasks may not be created.  The session
 * will continue to make delegate callbacks until 
 * URLSession:didBecomeInvalidWithError: has been issued. 
 *
 * When invalidating a background session, it is not safe to create another 
 * background session with the same identifier until 
 * URLSession:didBecomeInvalidWithError: has been issued.
 */
- (void) finishTasksAndInvalidate;

/* -invalidateAndCancel acts as -finishTasksAndInvalidate, but issues
 * -cancel to all outstanding tasks for this session.  Note task 
 * cancellation is subject to the state of the task, and some tasks may
 * have already have completed at the time they are sent -cancel. 
 */
- (void) invalidateAndCancel;

/* 
 * NSURLSessionTask objects are always created in a suspended state and
 * must be sent the -resume message before they will execute.
 */

/* Creates a data task with the given request. 
 * The request may have a body stream. */
- (NSURLSessionDataTask*) dataTaskWithRequest: (NSURLRequest*)request;

/* Creates a data task to retrieve the contents of the given URL. */
- (NSURLSessionDataTask*) dataTaskWithURL: (NSURL*)url;

/* Not implemented */
- (NSURLSessionUploadTask*) uploadTaskWithRequest: (NSURLRequest*)request
                                          fromFile: (NSURL*)fileURL;

/* Not implemented */
- (NSURLSessionUploadTask*) uploadTaskWithRequest: (NSURLRequest*)request
                                          fromData: (NSData*)bodyData;

/* Not implemented */
- (NSURLSessionUploadTask*) uploadTaskWithStreamedRequest: (NSURLRequest*)request;

/* Creates a download task with the given request. */
- (NSURLSessionDownloadTask*) downloadTaskWithRequest: (NSURLRequest*)request;

/* Creates a download task to download the contents of the given URL. */
- (NSURLSessionDownloadTask*) downloadTaskWithURL: (NSURL*)url;

/* Not implemented */
- (NSURLSessionDownloadTask *) downloadTaskWithResumeData: (NSData *)resumeData;

- (void) getTasksWithCompletionHandler: (void (^)(GS_GENERIC_CLASS(NSArray, NSURLSessionDataTask*) *dataTasks, GS_GENERIC_CLASS(NSArray, NSURLSessionUploadTask*) *uploadTasks, GS_GENERIC_CLASS(NSArray, NSURLSessionDownloadTask*) *downloadTasks))completionHandler;

- (void) getAllTasksWithCompletionHandler: (void (^)(GS_GENERIC_CLASS(NSArray, __kindof NSURLSessionTask*) *tasks))completionHandler;

@end

/*
 * NSURLSession convenience routines deliver results to 
 * a completion handler block.  These convenience routines
 * are not available to NSURLSessions that are configured
 * as background sessions.
 *
 * Task objects are always created in a suspended state and 
 * must be sent the -resume message before they will execute.
 */
@interface NSURLSession (NSURLSessionAsynchronousConvenience)
/*
 * data task convenience methods.  These methods create tasks that
 * bypass the normal delegate calls for response and data delivery,
 * and provide a simple cancelable asynchronous interface to receiving
 * data.  Errors will be returned in the NSURLErrorDomain, 
 * see <Foundation/NSURLError.h>.  The delegate, if any, will still be
 * called for authentication challenges.
 */
- (NSURLSessionDataTask*) dataTaskWithRequest: (NSURLRequest*)request
                            completionHandler: (void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;
- (NSURLSessionDataTask*) dataTaskWithURL: (NSURL*)url
                        completionHandler: (void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;


/* Not implemented */
- (NSURLSessionUploadTask*) uploadTaskWithRequest: (NSURLRequest*)request
                                         fromFile: (NSURL*)fileURL
                                completionHandler: (void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

/* Not implemented */
- (NSURLSessionUploadTask*) uploadTaskWithRequest: (NSURLRequest*)request
                                         fromData: (NSData*)bodyData
                                completionHandler: (void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler;

/*
 * download task convenience methods.  When a download successfully
 * completes, the NSURL will point to a file that must be read or
 * copied during the invocation of the completion routine.  The file
 * will be removed automatically.
 */
- (NSURLSessionDownloadTask*) downloadTaskWithRequest: (NSURLRequest*)request
                                    completionHandler: (void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;
- (NSURLSessionDownloadTask*) downloadTaskWithURL: (NSURL *)url
                                completionHandler: (void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;

/* Not implemented */
- (NSURLSessionDownloadTask*) downloadTaskWithResumeData: (NSData*)resumeData
                                       completionHandler: (void (^)(NSURL *location, NSURLResponse *response, NSError *error))completionHandler;

@end

typedef NS_ENUM(NSUInteger, NSURLSessionTaskState) {
  /* The task is currently being serviced by the session */
  NSURLSessionTaskStateRunning = 0,    
  NSURLSessionTaskStateSuspended = 1,
  /* The task has been told to cancel.  
   * The session will receive URLSession:task:didCompleteWithError:. */
  NSURLSessionTaskStateCanceling = 2,  
  /* The task has completed and the session will receive no more 
   * delegate notifications */
  NSURLSessionTaskStateCompleted = 3,  
};

GS_EXPORT const float NSURLSessionTaskPriorityDefault;
GS_EXPORT const float NSURLSessionTaskPriorityLow;
GS_EXPORT const float NSURLSessionTaskPriorityHigh;

GS_EXPORT const int64_t NSURLSessionTransferSizeUnknown;

/*
 * NSURLSessionTask - a cancelable object that refers to the lifetime
 * of processing a given request.
 */
GS_EXPORT_CLASS
@interface NSURLSessionTask : NSObject <NSCopying>
{
  /** An identifier for this task, assigned by and unique
   * to the owning session
   */
  NSUInteger    _taskIdentifier;

  /** The request this task was created to handle.
   */
  NSURLRequest  *_originalRequest;

  /** The request this task is currently handling.  This may differ from 
   * originalRequest due to http server redirection
   */
  NSURLRequest  *_currentRequest;

  /** The response to the current request, which may be nil if no response
   * has been received
   */
  NSURLResponse *_response;

  /** number of body bytes already received
   */
  int64_t       _countOfBytesReceived;

  /** number of body bytes already sent
   */
  int64_t       _countOfBytesSent;

  /** number of body bytes we expect to send, derived from 
   * the Content-Length of the HTTP request
   */
  int64_t       _countOfBytesExpectedToSend;

  /** number of byte bytes we expect to receive, usually derived from the 
   * Content-Length header of an HTTP response.
   */
  int64_t       _countOfBytesExpectedToReceive;

  /** a description of the current task for diagnostic purposes
   */
  NSString              *_taskDescription;

  /** The current state of the task within the session.
   */
  NSURLSessionTaskState _state;

  /** The error, if any, delivered via -URLSession:task:didCompleteWithError:
   * This is nil until an error has occured.
   */
  NSError               *_error;

  /** The dispatch queue used to handle this request/response.
   * This is actualy a libdispatch queue of type dispatch_queue_t, but on all
   * known implementations this is a pointer, so void* is the correct size.
   */
  void                  *_workQueue;

  NSUInteger            _suspendCount;

  GSURLSessionTaskBody  *_knownBody;

  void                  (^_dataCompletionHandler)(NSData *data, NSURLResponse *response, NSError *error);
  void                  (^_downloadCompletionHandler)(NSURL *location, NSURLResponse *response, NSError *error);
}

- (NSUInteger) taskIdentifier;

- (NSURLRequest*) originalRequest;

- (NSURLRequest*) currentRequest;

- (NSURLResponse*) response;
- (void) setResponse: (NSURLResponse*)response;

- (int64_t) countOfBytesReceived;

- (int64_t) countOfBytesSent;

- (int64_t) countOfBytesExpectedToSend;

- (int64_t) countOfBytesExpectedToReceive;

- (NSString*) taskDescription;

- (void) setTaskDescription: (NSString*)taskDescription;

- (NSURLSessionTaskState) state;

- (NSError*) error;

- (NSURLSession*) session;

/* -cancel returns immediately, but marks a task as being canceled.
 * The task will signal -URLSession:task:didCompleteWithError: with an
 * error value of { NSURLErrorDomain, NSURLErrorCancelled }. In some 
 * cases, the task may signal other work before it acknowledges the 
 * cancelation.  -cancel may be sent to a task that has been suspended.
 */
- (void) cancel;

/*
 * Suspending a task will prevent the NSURLSession from continuing to
 * load data.  There may still be delegate calls made on behalf of
 * this task (for instance, to report data received while suspending)
 * but no further transmissions will be made on behalf of the task
 * until -resume is sent.  The timeout timer associated with the task
 * will be disabled while a task is suspended.
 */
- (void) suspend;
- (void) resume;

- (float) priority;
- (void) setPriority: (float)priority;

@end

GS_EXPORT_CLASS
@interface NSURLSessionDataTask : NSURLSessionTask
@end

GS_EXPORT_CLASS
@interface NSURLSessionUploadTask : NSURLSessionDataTask
@end

GS_EXPORT_CLASS
@interface NSURLSessionDownloadTask : NSURLSessionTask
@end

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11,GS_API_LATEST)
GS_EXPORT_CLASS
@interface NSURLSessionStreamTask : NSURLSessionTask
@end
#endif

/*
 * Configuration options for an NSURLSession.  When a session is
 * created, a copy of the configuration object is made - you cannot
 * modify the configuration of a session after it has been created.
 */
GS_EXPORT_CLASS
@interface NSURLSessionConfiguration : NSObject <NSCopying>
{
  NSString                 *_identifier;
  NSURLCache               *_URLCache;
  NSURLRequestCachePolicy  _requestCachePolicy;
  NSArray                  *_protocolClasses;
  NSInteger                _HTTPMaximumConnectionLifetime;
  NSInteger                _HTTPMaximumConnectionsPerHost;
  BOOL                     _HTTPShouldUsePipelining;
  NSHTTPCookieAcceptPolicy _HTTPCookieAcceptPolicy;
  NSHTTPCookieStorage      *_HTTPCookieStorage;
  NSURLCredentialStorage   *_URLCredentialStorage;
  BOOL                     _HTTPShouldSetCookies;
  NSDictionary             *_HTTPAdditionalHeaders;
}

- (NSURLRequest*) configureRequest: (NSURLRequest*)request;

+ (NSURLSessionConfiguration*) defaultSessionConfiguration;
+ (NSURLSessionConfiguration*) ephemeralSessionConfiguration;
+ (NSURLSessionConfiguration*) backgroundSessionConfigurationWithIdentifier:(NSString*)identifier;

- (NSDictionary*) HTTPAdditionalHeaders;
- (void) setHTTPAdditionalHeaders: (NSDictionary*)headers;

- (NSHTTPCookieAcceptPolicy) HTTPCookieAcceptPolicy;
- (void) setHTTPCookieAcceptPolicy: (NSHTTPCookieAcceptPolicy)policy;

- (NSHTTPCookieStorage*) HTTPCookieStorage;
- (void) setHTTPCookieStorage: (NSHTTPCookieStorage*)storage;

- (NSInteger) HTTPMaximumConnectionsPerHost;
- (void) setHTTPMaximumConnectionsPerHost: (NSInteger)n;

- (BOOL) HTTPShouldSetCookies;
- (void) setHTTPShouldSetCookies: (BOOL)flag;

- (BOOL) HTTPShouldUsePipelining;
- (void) setHTTPShouldUsePipelining: (BOOL)flag;

- (NSString*) identifier;

- (NSArray*) protocolClasses;

- (NSURLRequestCachePolicy) requestCachePolicy;
- (void) setRequestCachePolicy: (NSURLRequestCachePolicy)policy;

- (NSURLCache*) URLCache;
- (void) setURLCache: (NSURLCache*)cache;

- (NSURLCredentialStorage*) URLCredentialStorage;
- (void) setURLCredentialStorage: (NSURLCredentialStorage*)storage;

#if     !NO_GNUSTEP 
/** Permits a session to be configured so that older connections are reused.
 * A value of zero or less uses the default behavior where connections are
 * reused as long as they are not older than 118 seconds, which is reasonable
 * for the vast majority if situations.
 */
- (NSInteger) HTTPMaximumConnectionLifetime;
- (void) setHTTPMaximumConnectionLifetime: (NSInteger)n;
#endif

@end

typedef NS_ENUM(NSInteger, NSURLSessionAuthChallengeDisposition) {
  NSURLSessionAuthChallengeUseCredential = 0,
  NSURLSessionAuthChallengePerformDefaultHandling = 1,
  NSURLSessionAuthChallengeCancelAuthenticationChallenge = 2,
  NSURLSessionAuthChallengeRejectProtectionSpace = 3
};

typedef NS_ENUM(NSInteger, NSURLSessionResponseDisposition) {
  NSURLSessionResponseCancel = 0,
  NSURLSessionResponseAllow = 1,
  NSURLSessionResponseBecomeDownload = 2,
  NSURLSessionResponseBecomeStream  = 3
};

@protocol NSURLSessionDelegate <NSObject>
@optional
/* The last message a session receives.  A session will only become
 * invalid because of a systemic error or when it has been
 * explicitly invalidated, in which case the error parameter will be nil.
 */
- (void)         URLSession: (NSURLSession*)session 
  didBecomeInvalidWithError: (NSError*)error;

/* Implementing this method permits a delegate to provide authentication
 * credentials in response to a challenge from the remote server.
 */
- (void) URLSession: (NSURLSession*)session
didReceiveChallenge: (NSURLAuthenticationChallenge*)challenge
  completionHandler: (void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))handler;

@end

@protocol NSURLSessionTaskDelegate <NSURLSessionDelegate>
@optional
/* Sent as the last message related to a specific task.  Error may be
 * nil, which implies that no error occurred and this task is complete. 
 */
- (void )   URLSession: (NSURLSession*)session 
                  task: (NSURLSessionTask*)task
  didCompleteWithError: (NSError*)error;
     
/* Called to request authentication credentials from the delegate when
 * an authentication request is received from the server which is specific
 * to this task.
 */
- (void) URLSession: (NSURLSession*)session 
	       task: (NSURLSessionTask*)task 
didReceiveChallenge: (NSURLAuthenticationChallenge*)challenge 
  completionHandler: (void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))handler;

/* Periodically informs the delegate of the progress of sending body content 
 * to the server.
 */
- (void)       URLSession: (NSURLSession*)session 
                     task: (NSURLSessionTask*)task 
          didSendBodyData: (int64_t)bytesSent 
           totalBytesSent: (int64_t)totalBytesSent 
 totalBytesExpectedToSend: (int64_t)totalBytesExpectedToSend;

/* An HTTP request is attempting to perform a redirection to a different
 * URL. You must invoke the completion routine to allow the
 * redirection, allow the redirection with a modified request, or
 * pass nil to the completionHandler to cause the body of the redirection 
 * response to be delivered as the payload of this request. The default
 * is to follow redirections. 
 *
 */
- (void)          URLSession: (NSURLSession*)session 
                        task: (NSURLSessionTask*)task
  willPerformHTTPRedirection: (NSHTTPURLResponse*)response
                  newRequest: (NSURLRequest*)request
           completionHandler: (void (^)(NSURLRequest*))completionHandler;

@end

@protocol NSURLSessionDataDelegate <NSURLSessionTaskDelegate>
@optional
/* Sent when data is available for the delegate to consume.
 */
- (void) URLSession: (NSURLSession*)session 
           dataTask: (NSURLSessionDataTask*)dataTask
     didReceiveData: (NSData*)data;

/** Informs the delegate of a response.  This message is sent when all the
 * response headers have arrived, before the body of the response arrives.
 */
- (void) URLSession: (NSURLSession*)session
           dataTask: (NSURLSessionDataTask*)dataTask
 didReceiveResponse: (NSURLResponse*)response
  completionHandler: (void (^)(NSURLSessionResponseDisposition disposition))completionHandler;

@end

@protocol NSURLSessionDownloadDelegate <NSURLSessionTaskDelegate>

/* Sent when a download task that has completed a download.  The delegate should 
 * copy or move the file at the given location to a new location as it will be 
 * removed when the delegate message returns. URLSession:task:didCompleteWithError: will
 * still be called.
 */
- (void)         URLSession: (NSURLSession *)session
               downloadTask: (NSURLSessionDownloadTask *)downloadTask
  didFinishDownloadingToURL: (NSURL *)location;

@optional
/* Sent periodically to notify the delegate of download progress. */
- (void)         URLSession: (NSURLSession *)session
               downloadTask: (NSURLSessionDownloadTask *)downloadTask
               didWriteData: (int64_t)bytesWritten
          totalBytesWritten: (int64_t)totalBytesWritten
  totalBytesExpectedToWrite: (int64_t)totalBytesExpectedToWrite;

/* Sent when a download has been resumed. If a download failed with an
 * error, the -userInfo dictionary of the error will contain an
 * NSURLSessionDownloadTaskResumeData key, whose value is the resume
 * data. 
 */
- (void)  URLSession: (NSURLSession *)session
        downloadTask: (NSURLSessionDownloadTask *)downloadTask
   didResumeAtOffset: (int64_t)fileOffset
  expectedTotalBytes: (int64_t)expectedTotalBytes;

@end

#endif
#endif
#endif
