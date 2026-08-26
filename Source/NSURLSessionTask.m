/**
 * NSURLSessionTask.m
 *
 * Copyright (C) 2017-2024 Free Software Foundation, Inc.
 *
 * Written by: Hugo Melder <hugo@algoriddim.com>
 * Date: May 2024
 *
 * This file is part of GNUStep-base
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * If you are interested in a warranty or support for this source code,
 * contact Scott Christley <scottc@net-community.com> for more information.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.
 */

/* The ivar macro below is expanded by Foundation/NSURLSession.h, so the
 * types it names have to be known before that header is imported.
 */
#import "common.h"
#include <curl/curl.h>

/* Where the compiler has no usable _Atomic, GSAtomic.h supplies a fallback
 * for it along with gs_atomic_load and gs_atomic_store.  It has to be seen
 * before the header expands the ivar macro below.
 */
#include "GSAtomic.h"

@class NSProgress;
@class NSURLSession;

#define	GS_NSURLSessionTask_IVARS \
  NSUInteger    _taskIdentifier; \
  NSURLRequest *_originalRequest; \
 \
  id<NSURLSessionTaskDelegate> _delegate; \
  NSURLSessionTaskState        _state; \
  NSURLRequest                *_currentRequest; \
  NSURLResponse               *_response; \
  NSProgress                  *_progress; \
  NSDate                      *_earliestBeginDate; \
 \
  _Atomic(int64_t) _countOfBytesClientExpectsToSend; \
  _Atomic(int64_t) _countOfBytesClientExpectsToReceive; \
  _Atomic(int64_t) _countOfBytesSent; \
  _Atomic(int64_t) _countOfBytesReceived; \
  _Atomic(int64_t) _countOfBytesExpectedToSend; \
  _Atomic(int64_t) _countOfBytesExpectedToReceive; \
  /* Advisory, and only ever read or written by -priority and -setPriority:, \
   * both of which take a float. \
   */ \
  float _priority; \
 \
  NSString *_taskDescription; \
  NSError  *_error; \
 \
  _Atomic(BOOL) _shouldStopTransfer; \
 \
  /* Set while an intercepted 3xx response is being handled by the delegate \
   * (or automatically) and the easy handle is about to be re-added for the \
   * new location.  libcurl reports the intercepted response as a completed \
   * transfer (CURLOPT_FOLLOWLOCATION is off), so completion must be held \
   * back until the redirect resolves; otherwise the task delivers a spurious \
   * early -URLSession:task:didCompleteWithError:. */ \
  _Atomic(BOOL) _redirectInProgress; \
 \
  /* Set while the handle is paused waiting for the delegate to answer \
   * -URLSession:dataTask:didReceiveResponse:completionHandler:.  libcurl can \
   * report the already-buffered response as complete before the delegate \
   * answers, so completion is held back (its CURLcode saved in \
   * _heldCompletionCode) and delivered once the disposition is known. */ \
  _Atomic(BOOL) _awaitingResponseDisposition; \
  /* The CURLcode of a completion held back while _awaitingResponseDisposition, \
   * or -1 if none has been held. */ \
  int _heldCompletionCode; \
 \
  /* Opaque value for storing task specific properties */ \
  NSInteger _properties; \
 \
  /* Internal task data */ \
  NSMutableDictionary	*_taskData; \
  NSInteger 		_numberOfRedirects; \
  NSInteger 		_headerCallbackCount; \
  NSUInteger 		_suspendCount; \
 \
  char _curlErrorBuffer[CURL_ERROR_SIZE]; \
  struct curl_slist	*_headerList; \
 \
  CURL			*_easyHandle; \
  NSURLSession 		*_session;

#import "NSURLSessionPrivate.h"
#include <curl/curl.h>
#import "NSURLSessionTaskPrivate.h"

#import "Foundation/NSOperation.h"
#import "Foundation/NSPathUtilities.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSFileHandle.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSData.h"
#import "Foundation/NSUUID.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSURLError.h"
#import "Foundation/NSURLResponse.h"
#import "Foundation/NSHTTPCookie.h"
#import "Foundation/NSStream.h"
#import "Foundation/NSInvocation.h"
#import "Foundation/NSMethodSignature.h"

#import "GNUstepBase/NSDebug+GNUstepBase.h"  /* For NSDebugMLLog */
#import "GNUstepBase/NSObject+GNUstepBase.h" /* For -[NSObject notImplemented] */

#import "GSURLPrivate.h"

#define	GSInternal	NSURLSessionTaskInternal
#include "GSInternal.h"
GS_PRIVATE_INTERNAL(NSURLSessionTask)


@interface _GSInsensitiveDictionary : NSDictionary
@end

@interface _GSMutableInsensitiveDictionary : NSMutableDictionary
@end

GS_DECLARE const float NSURLSessionTaskPriorityDefault = 0.5;
GS_DECLARE const float NSURLSessionTaskPriorityLow = 0.0;
GS_DECLARE const float NSURLSessionTaskPriorityHigh = 1.0;

GS_DECLARE const int64_t NSURLSessionTransferSizeUnknown = -1;

/* Initialised in +[NSURLSessionTask initialize] */
static Class dataTaskClass;
static Class downloadTaskClass;
static SEL didReceiveDataSel;
static SEL didReceiveResponseSel;
static SEL didCompleteWithErrorSel;
static SEL didFinishDownloadingToURLSel;
static SEL didWriteDataSel;
static SEL needNewBodyStreamSel;
static SEL willPerformHTTPRedirectionSel;

/* The replacements for the three delegate methods which answer through a
 * completion handler.  A delegate implementing one of these is sent it
 * instead, and replies by messaging the task.
 */
static SEL taskNeedsNewBodyStreamSel;
static SEL willRedirectSel;
static SEL didReceiveResponseNoHandlerSel;

/* A deprecated selector is (SEL)0 where the compiler has no blocks. */
static inline BOOL
respondsToDeprecated(id delegate, SEL aSelector)
{
  return ((SEL)0 != aSelector && [delegate respondsToSelector: aSelector])
    ? YES : NO;
}

static NSString *taskTransferDataKey = @"transferData";
static NSString *taskTemporaryFileLocationKey = @"tempFileLocation";
static NSString *taskTemporaryFileHandleKey = @"tempFileHandle";
static NSString *taskInputStreamKey = @"inputStream";
static NSString *taskUploadData = @"uploadData";

/* Translate WinSock2 Error Codes */
#ifdef _WIN32
static inline NSInteger
translateWinSockToPOSIXError(NSInteger err)
{
  switch (err)
    {
      case WSAEADDRINUSE:
        err = EADDRINUSE;
        break;
      case WSAEADDRNOTAVAIL:
        err = EADDRNOTAVAIL;
        break;
      case WSAEINPROGRESS:
        err = EINPROGRESS;
        break;
      case WSAECONNRESET:
        err = ECONNRESET;
        break;
      case WSAECONNABORTED:
        err = ECONNABORTED;
        break;
      case WSAECONNREFUSED:
        err = ECONNREFUSED;
        break;
      case WSAEHOSTUNREACH:
        err = EHOSTUNREACH;
        break;
      case WSAENETUNREACH:
        err = ENETUNREACH;
        break;
      case WSAETIMEDOUT:
        err = ETIMEDOUT;
        break;
      default:
        break;
    } /* switch */

  return err;
} /* translateWinSockToPOSIXError */
#endif /* ifdef _WIN32 */

static inline NSError *
errorForCURLcode(CURL *handle, CURLcode code, char errorBuffer[CURL_ERROR_SIZE])
{
  NSString	*curlErrorString;
  NSString	*errorString;
  NSDictionary	*userInfo;
  NSError	*error;
  NSInteger 	urlError = NSURLErrorUnknown;
  NSInteger 	posixError;
  NSInteger 	osError = 0;

  if (NULL == handle || CURLE_OK == code)
    {
      return NULL;
    }

  errorString = [NSString stringWithCString: errorBuffer];
  curlErrorString = [NSString stringWithCString: curl_easy_strerror(code)];

  /* Get errno number from the last connect failure.
   *
   * libcurl errors that may have saved errno are:
   * - CURLE_COULDNT_CONNECT
   * - CURLE_FAILED_INIT
   * - CURLE_INTERFACE_FAILED
   * - CURLE_OPERATION_TIMEDOUT
   * - CURLE_RECV_ERROR
   * - CURLE_SEND_ERROR
   */
  curl_easy_getinfo(handle, CURLINFO_OS_ERRNO, &osError);
#ifdef _WIN32
  posixError = translateWinSockToPOSIXError(osError);
#else
  posixError = osError;
#endif

  /* Translate libcurl to NSURLError codes */
  switch (code)
    {
      case CURLE_UNSUPPORTED_PROTOCOL:
        urlError = NSURLErrorUnsupportedURL;
        break;
      case CURLE_URL_MALFORMAT:
        urlError = NSURLErrorBadURL;
        break;

      /* Connection Errors */
      case CURLE_COULDNT_RESOLVE_PROXY:
      case CURLE_COULDNT_RESOLVE_HOST:
        urlError = NSURLErrorDNSLookupFailed;
        break;
#if CURL_AT_LEAST_VERSION(7, 69, 0)
      case CURLE_QUIC_CONNECT_ERROR:
#endif
      case CURLE_COULDNT_CONNECT:
        urlError = NSURLErrorCannotConnectToHost;
        break;
      case CURLE_OPERATION_TIMEDOUT:
        urlError = NSURLErrorTimedOut;
        break;
      case CURLE_FILESIZE_EXCEEDED:
        urlError = NSURLErrorDataLengthExceedsMaximum;
        break;
      case CURLE_LOGIN_DENIED:
        urlError = NSURLErrorUserAuthenticationRequired;
        break;

      /* Response Errors */
      case CURLE_WEIRD_SERVER_REPLY:
        urlError = NSURLErrorBadServerResponse;
        break;
      case CURLE_REMOTE_ACCESS_DENIED:
        urlError = NSURLErrorNoPermissionsToReadFile;
        break;
      case CURLE_GOT_NOTHING:
        urlError = NSURLErrorZeroByteResource;
        break;
      case CURLE_RECV_ERROR:
        urlError = NSURLErrorResourceUnavailable;
        break;

      /* Callback Errors */
      case CURLE_ABORTED_BY_CALLBACK:
      case CURLE_WRITE_ERROR:
        errorString = @"Transfer aborted by user";
        urlError = NSURLErrorCancelled;
        break;

      /* SSL Errors */
      case CURLE_SSL_CACERT_BADFILE:
      case CURLE_SSL_PINNEDPUBKEYNOTMATCH:
      case CURLE_SSL_CONNECT_ERROR:
        urlError = NSURLErrorSecureConnectionFailed;
        break;
      case CURLE_SSL_CERTPROBLEM:
        urlError = NSURLErrorClientCertificateRejected;
        break;
      case CURLE_SSL_INVALIDCERTSTATUS:
      case CURLE_SSL_ISSUER_ERROR:
        urlError = NSURLErrorServerCertificateUntrusted;
        break;

      default:
        urlError = NSURLErrorUnknown;
        break;
    } /* switch */

  /* Adjust error based on underlying OS error if available */
  if (code == CURLE_COULDNT_CONNECT || code == CURLE_RECV_ERROR
      || code == CURLE_SEND_ERROR)
    {
      switch (posixError)
        {
          case EADDRINUSE:
            urlError = NSURLErrorCannotConnectToHost;
            break;
          case EADDRNOTAVAIL:
            urlError = NSURLErrorCannotFindHost;
            break;
          case ECONNREFUSED:
            urlError = NSURLErrorCannotConnectToHost;
            break;
          case ENETUNREACH:
            urlError = NSURLErrorDNSLookupFailed;
            break;
          case ETIMEDOUT:
            urlError = NSURLErrorTimedOut;
            break;
          default: /* Do not alter urlError if we have no match */
            break;
        }
    }

  userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
    [NSNumber numberWithInteger: code], @"_curlErrorCode",
    curlErrorString, @"_curlErrorString",
    /* This is the raw POSIX error or WinSock2 Error Code depending on OS */
    [NSNumber numberWithInteger: osError], @"_errno",
    errorString, NSLocalizedDescriptionKey,
    nil];

  error = [NSError errorWithDomain: NSURLErrorDomain
                              code: urlError
                          userInfo: userInfo];

  return error;
} /* errorForCURLcode */

/* CURLOPT_PROGRESSFUNCTION: progress reports by libcurl */
static int
progress_callback(void *clientp, curl_off_t dltotal, curl_off_t dlnow,
  curl_off_t ultotal, curl_off_t ulnow)
{
  NSURLSessionTask	*task = clientp;

  /* Returning -1 from this callback makes libcurl abort the transfer and return
   * CURLE_ABORTED_BY_CALLBACK.
   */
  if (YES == [task _shouldStopTransfer])
    {
      return -1;
    }

  [task _setCountOfBytesReceived: dlnow];
  [task _setCountOfBytesSent: ulnow];
  [task _setCountOfBytesExpectedToSend: ultotal];
  [task _setCountOfBytesExpectedToReceive: dltotal];

  return 0;
}

/* CURLOPT_HEADERFUNCTION: callback for received headers
 *
 * This function is called for each header line and is called
 * again when a redirect or authentication occurs.
 *
 * Prior to 8.18.0 libcurl did not unfold HTTP "folded headers".
 */
static size_t
header_callback(char *ptr, size_t size, size_t nitems, void *userdata)
{
  NSURLSessionTask	*task;
  NSMutableDictionary	*taskData;
  NSMutableDictionary	*headerFields;
  NSString 		*headerLine;
  NSInteger 		headerCallbackCount;
  NSRange 		range;
  NSCharacterSet 	*set;

  task = (NSURLSessionTask *)userdata;
  taskData = [task _taskData];
  headerFields = [taskData objectForKey: @"headers"];
  headerCallbackCount = [task _headerCallbackCount] + 1;
  set = [NSCharacterSet whitespaceAndNewlineCharacterSet];

  [task _setHeaderCallbackCount: headerCallbackCount];

  if (nil == headerFields)
    {
      NSDebugLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"task=%@ Could not find 'headers' key in taskData",
        task);
      return 0;
    }

  headerLine = AUTORELEASE([[NSString alloc]
    initWithBytes: ptr
    length: nitems
    encoding: NSUTF8StringEncoding]);

  // First line is the HTTP Version
  if (1 == headerCallbackCount)
    {
      [taskData setObject: headerLine forKey: @"version"];

      return size * nitems;
    }

#if !CURL_AT_LEAST_VERSION(8, 18, 0)
  /* Header fields can be extended over multiple lines by preceding
   * each extra line with at least one SP or HT (RFC 2616 line folding).
   *
   * RFC 7230 (3.2.4) requires a recipient to replace each such fold with a
   * single SP before interpreting the value, so append the continuation to
   * the previous header's value separated by one space.  This also matches
   * newer libcurl, which unfolds the header to a single space before the
   * callback sees it.
   */
  if ((ptr[0] == ' ') || (ptr[0] == '\t'))
    {
      NSString	*key;

      if (nil != (key = [taskData objectForKey: @"lastHeaderKey"]))
        {
          NSString	*value;
          NSString	*trimmedLine;

          value = [headerFields objectForKey: key];
          if (!value)
            {
              NSError	*error;
              NSString	*errorDescription;

              errorDescription = [NSString
                                  stringWithFormat:
                                  @"Header is line folded but previous header "
                                  @"key '%@' does not have an entry",
                                  key];
              error = [NSError errorWithDomain: NSURLErrorDomain
					  code: NSURLErrorCancelled
				      userInfo:
		[NSDictionary dictionaryWithObjectsAndKeys:
                  errorDescription, NSLocalizedDescriptionKey,
		  nil]];

              [taskData setObject: error forKey: NSUnderlyingErrorKey];

              return 0;
            }

          trimmedLine = [headerLine stringByTrimmingCharactersInSet: set];
          value = [value stringByAppendingFormat: @" %@", trimmedLine];

          [headerFields setObject: value forKey: key];
        }

      return size * nitems;
    }
#endif

  range = [headerLine rangeOfString: @":"];
  if (NSNotFound != range.location)
    {
      NSString	*key;
      NSString 	*value;

      key = [headerLine substringToIndex: range.location];
      value = [headerLine substringFromIndex: range.location + 1];

      /* Remove LWS from key and value */
      key = [key stringByTrimmingCharactersInSet: set];
      value = [value stringByTrimmingCharactersInSet: set];

      [headerFields setObject: value forKey: key];
#if !CURL_AT_LEAST_VERSION(8, 18, 0)
      /* Used for line unfolding */
      [taskData setObject: key forKey: @"lastHeaderKey"];
#endif
      return size * nitems;
    }

  /* Final Header Line:
   *
   * If this is the initial request (not a redirect) and delegate updates are
   * enabled, notify the delegate about the initial response.
   */
  if (nitems > 1 && (ptr[0] == '\r') && (ptr[1] == '\n'))
    {
      NSURLSession	*session;
      id 		delegate;
      NSHTTPURLResponse *response;
      NSString		*version;
      NSString 		*urlString;
      NSURL 		*url;
      CURL 		*handle;
      char 		*effURL;
      NSDictionary 	*fields;
      NSInteger 	numberOfRedirects = 0;
      NSInteger 	statusCode = 0;

      session = [task _session];
      delegate = [task delegate];
      handle = [task _easyHandle];
      numberOfRedirects = [task _numberOfRedirects] + 1;

      [task _setNumberOfRedirects: numberOfRedirects];
      [task _setHeaderCallbackCount: 0];

      curl_easy_getinfo(handle, CURLINFO_RESPONSE_CODE, &statusCode);
      curl_easy_getinfo(handle, CURLINFO_EFFECTIVE_URL, &effURL);

      if (nil == (version = [taskData objectForKey: @"version"]))
        {
          /* Default to HTTP/1.0 if no data is available */
          version = @"HTTP/1.0";
        }

      NSDebugLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"task=%@ version=%@ status=%ld found %ld headers",
        task,
        version,
        statusCode,
        [headerFields count]);

      urlString = [NSString stringWithCString: effURL];
      url = [NSURL URLWithString: urlString];
      fields = [headerFields copy];
      response = [[NSHTTPURLResponse alloc] initWithURL: url
                                             statusCode: statusCode
                                            HTTPVersion: version
                                           headerFields: fields];
      AUTORELEASE(response);
      RELEASE(fields);

      [task _setCookiesFromHeaders: headerFields];
      [task _setResponse: response];

#if GS_HAVE_NSURLSESSION_WEBSOCKETS
      if ([task isKindOfClass: [NSURLSessionWebSocketTask class]]
          && statusCode == 101)
        {
          NSString *protocol;

          protocol = [headerFields objectForKey: @"Sec-WebSocket-Protocol"];
          [(NSURLSessionWebSocketTask *)task
            _notifyDidOpenWithProtocol: protocol];
        }
#endif

      /* Assume this response is final; the redirection handling below sets
       * this again if the handle is going to be re-added for a new location. */
      [task _setRedirectInProgress: NO];

      /* URL redirection handling for 3xx status codes, if delegate updates are
       * enabled.
       *
       * NOTE: The URLSession API does not provide a way to limit redirection
       * attempts.
       */
      if ([task _properties] & GSURLSessionUpdatesDelegate && statusCode >= 300
        && statusCode < 400)
        {
          NSString	*location;

          /*
           * RFC 7231: 7.1.2  Location [Header]
           * Location = URI-reference
           *
           * The field value consists of a single URI-reference.  When it has
           * the form of a relative reference ([RFC3986], Section 4.2), the
           * final value is computed by resolving it against the effective
           * request URI
           * ([RFC3986], Section 5).
           */
          location = [headerFields objectForKey: @"Location"];
          if (nil != location)
            {
              NSURL			*redirectURL;
              NSMutableURLRequest 	*newRequest;

              /* baseURL is only used, if location is a relative reference */
              redirectURL = [NSURL URLWithString: location relativeToURL: url];
              newRequest = AUTORELEASE([[task originalRequest] mutableCopy]);
              [newRequest setURL: redirectURL];

              NSDebugLLog(
                GS_NSURLSESSION_DEBUG_KEY,
                @"task=%@ status=%ld has Location header. Prepare "
                @"for redirection with url=%@",
                task,
                statusCode,
                redirectURL);

              if ([delegate respondsToSelector: willRedirectSel]
		|| respondsToDeprecated(delegate,
		  willPerformHTTPRedirectionSel))
                {
                  NSInvocation	*inv;

                  NSDebugLLog(
                    GS_NSURLSESSION_DEBUG_KEY,
                    @"task=%@ ask delegate for redirection "
                    @"permission. Pausing handle.",
                    task);

                  curl_easy_pause(handle, CURLPAUSE_ALL);

                  /* libcurl treats the intercepted 3xx as a finished transfer
                   * (CURLOPT_FOLLOWLOCATION is off), so hold back completion
                   * until the delegate resolves the redirect. */
                  [task _setRedirectInProgress: YES];

                  if ([delegate respondsToSelector: willRedirectSel])
                    {
                      inv = GSURLSessionInvocation(delegate, willRedirectSel);
                      [inv setArgument: &session atIndex: 2];
                      [inv setArgument: &task atIndex: 3];
                      [inv setArgument: &response atIndex: 4];
                      [inv setArgument: &newRequest atIndex: 5];
                    }
                  else
                    {
                      /* The delegate only has the deprecated method, which
                       * answers through a block.  Ask the task to send it. */
                      inv = GSURLSessionInvocation(task,
			@selector(_askDelegateToRedirectTo:newRequest:));
                      [inv setArgument: &response atIndex: 2];
                      [inv setArgument: &newRequest atIndex: 3];
                    }
                  [session _enqueueDelegateInvocation: inv];

                  [headerFields removeAllObjects];
                  return size * nitems;
                }
              else
                {
                  NSDebugLLog(
                    GS_NSURLSESSION_DEBUG_KEY,
                    @"task=%@ status=%ld has Location header but "
                    @"delegate does not respond to "
                    @"willPerformHTTPRedirection:. Redirecting to Location %@",
                    task,
                    statusCode,
                    redirectURL);

                  /* Remove handle for reconfiguration */
                  [session _removeHandle: handle];

                  curl_easy_setopt(
                    handle,
                    CURLOPT_URL,
                    [[redirectURL absoluteString] UTF8String]);

                  /* Reset statistics */
                  [task _setCountOfBytesReceived: 0];
                  [task _setCountOfBytesSent: 0];
                  [task _setCountOfBytesExpectedToReceive: 0];
                  [task _setCountOfBytesExpectedToSend: 0];

                  [task _setCurrentRequest: newRequest];

                  /* Re-add handle to session */
                  [session _addHandle: handle];
                }

              [headerFields removeAllObjects];
              return size * nitems;
            }
          else
            {
              NSError	*error;
              NSString	*errorString;

              errorString = [NSString
                             stringWithFormat:
                             @"task=%@ status=%ld has no Location header",
                             task, statusCode];
              error = [NSError errorWithDomain: NSURLErrorDomain
					  code: NSURLErrorBadServerResponse
				      userInfo:
		[NSDictionary dictionaryWithObjectsAndKeys:
		  errorString, NSLocalizedDescriptionKey,
		  nil]];

              NSDebugLLog(GS_NSURLSESSION_DEBUG_KEY, @"%@", errorString);

              [taskData setObject: error forKey: NSUnderlyingErrorKey];

              return 0;
            }
        }

      [headerFields removeAllObjects];

      /* URLSession:dataTask:didReceiveResponse:completionHandler:
       * is called *after* all potential redirections are handled.
       *
       * FIXME: Enforce this and implement a custom redirect system
       */
      if ([task _properties] & GSURLSessionUpdatesDelegate
	&& [task isKindOfClass: dataTaskClass]
	&& ([delegate respondsToSelector: didReceiveResponseNoHandlerSel]
	  || respondsToDeprecated(delegate, didReceiveResponseSel)))
        {
          NSInvocation	*inv;

          /* Pause until the delegate answers.  libcurl may report the
           * buffered response as complete before that happens, so hold that
           * completion back (see -_checkForCompletion) until we know the
           * disposition. */
          [task _setAwaitingResponseDisposition: YES];
          curl_easy_pause(handle, CURLPAUSE_ALL);

          if ([delegate respondsToSelector: didReceiveResponseNoHandlerSel])
            {
              inv = GSURLSessionInvocation(delegate,
		didReceiveResponseNoHandlerSel);
              [inv setArgument: &session atIndex: 2];
              [inv setArgument: &task atIndex: 3];
              [inv setArgument: &response atIndex: 4];
            }
          else
            {
              /* The delegate only has the deprecated method, which answers
               * through a block.  Ask the task to send it. */
              inv = GSURLSessionInvocation(task,
		@selector(_askDelegateAboutResponse:));
              [inv setArgument: &response atIndex: 2];
            }
          [session _enqueueDelegateInvocation: inv];
        }
    }

  return size * nitems;
} /* header_callback */

/* CURLOPT_READFUNCTION: read callback for data uploads */
static size_t
read_callback(char *buffer, size_t size, size_t nitems, void *userdata)
{
  NSURLSession 		*session;
  NSURLSessionTask 	*task;
  NSMutableDictionary	*taskData;
  NSInputStream		*stream;
  NSInteger 		bytesWritten;

  task = (NSURLSessionTask *)userdata;
  session = [task _session];
  taskData = [task _taskData];
  stream = [taskData objectForKey: taskInputStreamKey];

  if (nil == stream)
    {
      id<NSURLSessionTaskDelegate> delegate = [task delegate];

      NSDebugLLog(
        GS_NSURLSESSION_DEBUG_KEY,
        @"task=%@ requesting new body stream from delegate",
        task);

      if ([delegate respondsToSelector: taskNeedsNewBodyStreamSel]
	|| respondsToDeprecated(delegate, needNewBodyStreamSel))
        {
          NSInvocation	*inv;

          if ([delegate respondsToSelector: taskNeedsNewBodyStreamSel])
            {
              inv = GSURLSessionInvocation(delegate,
		taskNeedsNewBodyStreamSel);
              [inv setArgument: &session atIndex: 2];
              [inv setArgument: &task atIndex: 3];
            }
          else
            {
              /* The delegate only has the deprecated method, which answers
               * through a block.  Ask the task to send it. */
              inv = GSURLSessionInvocation(task,
		@selector(_askDelegateForNewBodyStream));
            }
          [session _enqueueDelegateInvocation: inv];

          return CURL_READFUNC_PAUSE;
        }
      else
        {
          NSDebugLLog(
            GS_NSURLSESSION_DEBUG_KEY,
            @"task=%@ no input stream was given and delegate does "
            @"not respond to URLSession:taskNeedsNewBodyStream:",
            task);

          return CURL_READFUNC_ABORT;
        }
    }

  bytesWritten = [stream read: (uint8_t *)buffer maxLength: (size * nitems)];
  /* An error occured while reading from the inputStream */
  if (bytesWritten < 0)
    {
      NSError	*error;

      error = [NSError errorWithDomain: NSURLErrorDomain
				  code: NSURLErrorCancelled
			      userInfo:
	[NSDictionary dictionaryWithObjectsAndKeys:
	  @"An error occured while reading from the body stream",
          NSLocalizedDescriptionKey,
	 [stream streamError],
	 NSUnderlyingErrorKey,
	 nil]];

      [taskData setObject: error forKey: NSUnderlyingErrorKey];
      return CURL_READFUNC_ABORT;
    }

  return bytesWritten;
} /* read_callback */

/* CURLOPT_WRITEFUNCTION: callback for writing received data from easy handle */
static size_t
write_callback(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  NSURLSessionTask	*task;
  NSURLSession 		*session;
  NSMutableDictionary 	*taskData;
  NSData 		*dataFragment;
  NSInteger 		properties;

  task = (NSURLSessionTask *)userdata;
  session = [task _session];
  taskData = [task _taskData];
  dataFragment = [[NSData alloc] initWithBytes: ptr length: (size * nmemb)];
  properties = [task _properties];

  if (properties & GSURLSessionStoresDataInMemory)
    {
      NSMutableData	*data;

      data = [taskData objectForKey: taskTransferDataKey];
      if (!data)
        {
          data = [[NSMutableData alloc] init];
          /* Strong reference maintained by taskData */
          [taskData setObject: data forKey: taskTransferDataKey];
          [data release];
        }

      [data appendData: dataFragment];
    }
  else if (properties & GSURLSessionWritesDataToFile)
    {
      NSFileHandle	*handle;
      NSError 		*error = NULL;

      // Get a temporary file path and create a file handle
      if (nil == (handle = [taskData objectForKey: taskTemporaryFileHandleKey]))
        {
          handle = [task _createTemporaryFileHandleWithError: &error];

          /* We add the error to taskData as an underlying error */
          if (NULL != error)
            {
              [taskData setObject: error forKey: NSUnderlyingErrorKey];
              [dataFragment release];
              return 0;
            }
        }

      [handle writeData: dataFragment];
    }

  /* Notify delegate */
  if (properties & GSURLSessionUpdatesDelegate)
    {
      id delegate = [task delegate];

      if ([task isKindOfClass: dataTaskClass] &&
          [delegate respondsToSelector: didReceiveDataSel])
        {
          NSInvocation		*inv;

          inv = GSURLSessionInvocation(delegate, didReceiveDataSel);
          [inv setArgument: &session atIndex: 2];
          [inv setArgument: &task atIndex: 3];
          [inv setArgument: &dataFragment atIndex: 4];
          [session _enqueueDelegateInvocation: inv];
        }

      /* Notify delegate about the download process */
      if ([task isKindOfClass: downloadTaskClass] &&
          [delegate respondsToSelector: didWriteDataSel])
        {
          NSURLSessionDownloadTask	*downloadTask;
          int64_t bytesWritten;
          int64_t totalBytesWritten;
          int64_t totalBytesExpectedToReceive;
          NSInvocation		*inv;

          downloadTask = (NSURLSessionDownloadTask *)task;
          bytesWritten = [dataFragment length];

          [downloadTask _updateCountOfBytesWritten: bytesWritten];

          totalBytesWritten = [downloadTask _countOfBytesWritten];
          totalBytesExpectedToReceive =
            [downloadTask countOfBytesExpectedToReceive];

          inv = GSURLSessionInvocation(delegate, didWriteDataSel);
          [inv setArgument: &session atIndex: 2];
          [inv setArgument: &downloadTask atIndex: 3];
          [inv setArgument: &bytesWritten atIndex: 4];
          [inv setArgument: &totalBytesWritten atIndex: 5];
          [inv setArgument: &totalBytesExpectedToReceive atIndex: 6];
          [session _enqueueDelegateInvocation: inv];
        }
    }

  [dataFragment release];
  return size * nmemb;
} /* write_callback */

@implementation NSURLSessionTask

+ (void) initialize
{
  dataTaskClass = [NSURLSessionDataTask class];
  downloadTaskClass = [NSURLSessionDownloadTask class];
  didReceiveDataSel = @selector(URLSession:dataTask:didReceiveData:);
  didCompleteWithErrorSel = @selector(URLSession:task:didCompleteWithError:);
  didFinishDownloadingToURLSel =
    @selector(URLSession:downloadTask:didFinishDownloadingToURL:);
  didWriteDataSel = @selector
    (URLSession:
     downloadTask:didWriteData:totalBytesWritten:totalBytesExpectedToWrite:);
  taskNeedsNewBodyStreamSel = @selector(URLSession:taskNeedsNewBodyStream:);
  willRedirectSel = @selector
    (URLSession:task:willRedirectToResponse:newRequest:);
  didReceiveResponseNoHandlerSel =
    @selector(URLSession:dataTask:didReceiveResponse:);

  /* The deprecated delegate methods answer through a completion handler, so
   * they are only usable where the compiler can build one to pass. */
#if __has_feature(blocks)
  didReceiveResponseSel =
    @selector(URLSession:dataTask:didReceiveResponse:completionHandler:);
  needNewBodyStreamSel = @selector(URLSession:task:needNewBodyStream:);
  willPerformHTTPRedirectionSel = @selector
    (URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:);
#else
  didReceiveResponseSel = (SEL)0;
  needNewBodyStreamSel = (SEL)0;
  willPerformHTTPRedirectionSel = (SEL)0;
#endif
}

/* -copyWithZone: makes its copy with a plain -init, so the internal ivars
 * have to be created here too. */
- (instancetype) init
{
  if (nil != (self = [super init]))
    {
      GS_CREATE_INTERNAL(NSURLSessionTask);
    }
  return self;
}

- (instancetype) initWithSession: (NSURLSession *)session
  request: (NSURLRequest *)request
  taskIdentifier: (NSUInteger)identifier
{
  self = [super init];

  if (self)
    {
      ENTER_POOL
      NSString			*httpMethod;
      NSData 			*certificateBlob;
      NSURL 			*url;
      NSDictionary 		*immConfigHeaders;
      NSURLSessionConfiguration *configuration;
      NSHTTPCookieStorage 	*storage;

      _GSMutableInsensitiveDictionary	*requestHeaders = nil;
      _GSMutableInsensitiveDictionary	*configHeaders = nil;

      GS_CREATE_INTERNAL(NSURLSessionTask);

      internal->_taskIdentifier = identifier;
      internal->_taskData = [[NSMutableDictionary alloc] init];
      gs_atomic_store(&internal->_shouldStopTransfer, NO);
      gs_atomic_store(&internal->_redirectInProgress, NO);
      gs_atomic_store(&internal->_awaitingResponseDisposition, NO);
      internal->_heldCompletionCode = -1;
      internal->_numberOfRedirects = -1;
      internal->_headerCallbackCount = 0;

      ASSIGNCOPY(internal->_originalRequest, request);
      ASSIGNCOPY(internal->_currentRequest, request);

      httpMethod = [[internal->_originalRequest HTTPMethod] lowercaseString];
      url = [internal->_originalRequest URL];
      requestHeaders
	= AUTORELEASE([[internal->_originalRequest _insensitiveHeaders] mutableCopy]);
      configuration = [session configuration];

      /* Only retain the session once the -resume method is called
       * and release the session as the last thing done once the
       * task has completed. This avoids a retain loop causing
       * session and tasks to be leaked.
       */
      internal->_session = session;
      internal->_suspendCount = 0;
      internal->_state = NSURLSessionTaskStateSuspended;
      internal->_curlErrorBuffer[0] = '\0';

      /* Configure initial task data
       */
      [internal->_taskData setObject: [NSMutableDictionary dictionary]
		    forKey: @"headers"];

      /* Easy Handle Configuration
       */
      internal->_easyHandle = curl_easy_init();

      if ([@"head" isEqualToString: httpMethod])
        {
          curl_easy_setopt(internal->_easyHandle, CURLOPT_NOBODY, 1L);
        }

      /* Setup upload data if a HTTPBody or HTTPBodyStream is present in the
       * URLRequest
       */
      if (nil != [internal->_originalRequest HTTPBody])
        {
          NSData	*body = [internal->_originalRequest HTTPBody];

          curl_easy_setopt(internal->_easyHandle, CURLOPT_UPLOAD, 1L);
          curl_easy_setopt(
            internal->_easyHandle,
            CURLOPT_POSTFIELDSIZE_LARGE,
            (curl_off_t)[body length]);
          curl_easy_setopt(internal->_easyHandle, CURLOPT_POSTFIELDS, [body bytes]);
        }
      else if (nil != [internal->_originalRequest HTTPBodyStream])
        {
          NSInputStream	*stream = [internal->_originalRequest HTTPBodyStream];

          [internal->_taskData setObject: stream forKey: taskInputStreamKey];

          curl_easy_setopt(internal->_easyHandle, CURLOPT_READFUNCTION, read_callback);
          curl_easy_setopt(internal->_easyHandle, CURLOPT_READDATA, self);

          curl_easy_setopt(internal->_easyHandle, CURLOPT_UPLOAD, 1L);
          curl_easy_setopt(internal->_easyHandle, CURLOPT_POSTFIELDSIZE, (curl_off_t)-1);
        }

      /* Configure HTTP method and URL */
      curl_easy_setopt(
        internal->_easyHandle,
        CURLOPT_CUSTOMREQUEST,
        [[internal->_originalRequest HTTPMethod] UTF8String]);

      curl_easy_setopt(
        internal->_easyHandle,
        CURLOPT_URL,
        [[url absoluteString] UTF8String]);

      /* This callback function gets called by libcurl as soon as there is data
       * received that needs to be saved. For most transfers, this callback gets
       * called many times and each invoke delivers another chunk of data.
       *
       * This is directly mapped to -[NSURLSessionDataDelegate
       * URLSession:dataTask:didReceiveData:].
       */
      curl_easy_setopt(internal->_easyHandle, CURLOPT_WRITEFUNCTION, write_callback);
      curl_easy_setopt(internal->_easyHandle, CURLOPT_WRITEDATA, self);

      /* Retrieve the header data
       *
       * If the delegate conforms to the NSURLSessionDataDelegate
       * - URLSession:dataTask:didReceiveResponse:completionHandler:
       * we can notify it about the header response.
       */
      curl_easy_setopt(internal->_easyHandle, CURLOPT_HEADERFUNCTION, header_callback);
      curl_easy_setopt(internal->_easyHandle, CURLOPT_HEADERDATA, self);

      curl_easy_setopt(internal->_easyHandle, CURLOPT_ERRORBUFFER, internal->_curlErrorBuffer);

      /* The task is now associated with the easy handle and can be accessed
       * using curl_easy_getinfo with CURLINFO_PRIVATE.
       */
      curl_easy_setopt(internal->_easyHandle, CURLOPT_PRIVATE, self);

      /* Disable libcurl's build-in progress reporting */
      curl_easy_setopt(internal->_easyHandle, CURLOPT_NOPROGRESS, 0L);
      /* Specifiy our own progress function with the user pointer being the
       * current object
       */
      curl_easy_setopt(
        internal->_easyHandle,
        CURLOPT_XFERINFOFUNCTION,
        progress_callback);
      curl_easy_setopt(internal->_easyHandle, CURLOPT_XFERINFODATA, self);

      /* Do not Follow redirects by default
       *
       * libcurl does not provide a direct interface
       * for redirect notification. We have implemented our own redirection
       * system in header_callback.
       */
      curl_easy_setopt(internal->_easyHandle, CURLOPT_FOLLOWLOCATION, 0L);

      /* Set timeout in connect phase */
      curl_easy_setopt(
        internal->_easyHandle,
        CURLOPT_CONNECTTIMEOUT,
        (NSInteger)[request timeoutInterval]);

      /* Set overall timeout */
      curl_easy_setopt(
        internal->_easyHandle,
        CURLOPT_TIMEOUT,
        (curl_off_t)[configuration timeoutIntervalForResource]);

      /* Set to HTTP/3 if requested */
      if ([request assumesHTTP3Capable])
        {
#if CURL_AT_LEAST_VERSION(7, 66, 0)
          curl_easy_setopt(
            internal->_easyHandle,
            CURLOPT_HTTP_VERSION,
            CURL_HTTP_VERSION_3);
#endif
        }

      /* Configure the custom CA certificate if available */
      if (nil != (certificateBlob = [internal->_session _certificateBlob]))
        {
// CURLOPT_CAINFO_BLOB was added in 7.77.0
#if LIBCURL_VERSION_NUM >= 0x074D00
          struct curl_blob blob;

          blob.data = (void *)[certificateBlob bytes];
          blob.len = [certificateBlob length];
          /* Session becomes a strong reference when task is resumed until the
           * end of transfer. */
          blob.flags = CURL_BLOB_NOCOPY;

          curl_easy_setopt(internal->_easyHandle, CURLOPT_CAINFO_BLOB, &blob);
#else
          curl_easy_setopt(
            internal->_easyHandle,
            CURLOPT_CAINFO,
            [internal->_session _certificatePath]);
#endif
        }

      /* Process config headers */
      immConfigHeaders = [configuration HTTPAdditionalHeaders];
      if (nil != immConfigHeaders)
        {
          configHeaders = AUTORELEASE([[_GSMutableInsensitiveDictionary alloc]
                           initWithDictionary: immConfigHeaders
                                    copyItems: NO]);

          /* Merge Headers.
           *
           * If the same header appears in both the configuration's
           * HTTPAdditionalHeaders and the request object (where applicable),
           * the request object’s value takes precedence.
           */
          [configHeaders
           addEntriesFromDictionary: (NSDictionary *)requestHeaders];
          requestHeaders = configHeaders;
        }

      /* Use stored cookies is instructed to do so
       */
      storage = [configuration HTTPCookieStorage];
      if (nil != storage && [configuration HTTPShouldSetCookies])
        {
          NSDictionary			*cookieHeaders;
          GS_GENERIC_CLASS(NSArray, NSHTTPCookie *)	*cookies;

          /* No headers were set */
          if (nil == requestHeaders)
            {
              requestHeaders = [_GSMutableInsensitiveDictionary dictionary];
            }

          cookies = [storage cookiesForURL: url];
          if ([cookies count] > 0)
            {
              cookieHeaders =
                [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
              [requestHeaders addEntriesFromDictionary: cookieHeaders];
            }
        }

      /* Append Headers to the libcurl header list
       */
      for (id key in requestHeaders)
	{
          NSString	*headerLine;
	  id 		object = [requestHeaders objectForKey: key];

          headerLine = [NSString stringWithFormat: @"%@: %@", key, object];

          /* We have removed all reserved headers in NSURLRequest */
          internal->_headerList = curl_slist_append(internal->_headerList, [headerLine UTF8String]);
        }
      curl_easy_setopt(internal->_easyHandle, CURLOPT_HTTPHEADER, internal->_headerList);
      LEAVE_POOL
    }

  return self;
} /* initWithSession */

- (void) _enableAutomaticRedirects: (BOOL)flag
{
  curl_easy_setopt(internal->_easyHandle, CURLOPT_FOLLOWLOCATION, flag ? 1L : 0L);
}

- (void) _enableUploadWithData: (NSData *)data
{
  curl_easy_setopt(internal->_easyHandle, CURLOPT_UPLOAD, 1L);

  /* Retain data */
  [internal->_taskData setObject: data forKey: taskUploadData];

  curl_easy_setopt(internal->_easyHandle, CURLOPT_POSTFIELDSIZE_LARGE,
    (curl_off_t)[data length]);
  curl_easy_setopt(internal->_easyHandle, CURLOPT_POSTFIELDS, [data bytes]);

  /* The method is overwritten by CURLOPT_UPLOAD. Change it back. */
  curl_easy_setopt(
    internal->_easyHandle,
    CURLOPT_CUSTOMREQUEST,
    [[internal->_originalRequest HTTPMethod] UTF8String]);
}

- (void) _enableUploadWithSize: (NSInteger)size
{
  curl_easy_setopt(internal->_easyHandle, CURLOPT_UPLOAD, 1L);

  curl_easy_setopt(internal->_easyHandle, CURLOPT_READFUNCTION, read_callback);
  curl_easy_setopt(internal->_easyHandle, CURLOPT_READDATA, self);

  if (size > 0)
    {
      curl_easy_setopt(internal->_easyHandle, CURLOPT_POSTFIELDSIZE_LARGE, size);
    }
  else
    {
      curl_easy_setopt(internal->_easyHandle, CURLOPT_POSTFIELDSIZE, (curl_off_t)-1);
    }

  /* The method is overwritten by CURLOPT_UPLOAD. Change it back. */
  curl_easy_setopt(
    internal->_easyHandle,
    CURLOPT_CUSTOMREQUEST,
    [[internal->_originalRequest HTTPMethod] UTF8String]);
} /* _enableUploadWithSize */

- (CURL *) _easyHandle
{
  return internal->_easyHandle;
}

- (void) _setVerbose: (BOOL)flag
{
  [internal->_session _performSelectorOnWorkThread: @selector(_workSetVerbose:)
				  target: self
			      withObject: [NSNumber numberWithBool: flag]];
}

- (void) _workSetVerbose: (NSNumber *)flag
{
  curl_easy_setopt(internal->_easyHandle, CURLOPT_VERBOSE, [flag boolValue] ? 1L : 0L);
}

- (void) _setBodyStream: (NSInputStream *)stream
{
  [internal->_taskData setObject: stream forKey: taskInputStreamKey];
}

- (void) _setOriginalRequest: (NSURLRequest *)request
{
  ASSIGNCOPY(internal->_originalRequest, request);
}

- (void) _setCurrentRequest: (NSURLRequest *)request
{
  ASSIGNCOPY(internal->_currentRequest, request);
}

- (void) _setResponse: (NSURLResponse *)response
{
  NSURLResponse	*oldResponse = internal->_response;

  internal->_response = [response retain];
  [oldResponse release];
}

- (void) _setCountOfBytesSent: (int64_t)count
{
  gs_atomic_store(&internal->_countOfBytesSent, count);
}
- (void) _setCountOfBytesReceived: (int64_t)count
{
  gs_atomic_store(&internal->_countOfBytesReceived, count);
}
- (void) _setCountOfBytesExpectedToSend: (int64_t)count
{
  gs_atomic_store(&internal->_countOfBytesExpectedToSend, count);
}
- (void) _setCountOfBytesExpectedToReceive: (int64_t)count
{
  gs_atomic_store(&internal->_countOfBytesExpectedToReceive, count);
}

- (NSMutableDictionary *) _taskData
{
  return internal->_taskData;
}

- (NSInteger) _properties
{
  return internal->_properties;
}
- (void) _setProperties: (NSInteger)properties
{
  internal->_properties = properties;
}

- (NSURLSession *) _session
{
  return internal->_session;
}

- (BOOL) _shouldStopTransfer
{
  return gs_atomic_load(&internal->_shouldStopTransfer);
}

- (void) _setShouldStopTransfer: (BOOL)flag
{
  gs_atomic_store(&internal->_shouldStopTransfer, flag);
}

- (BOOL) _redirectInProgress
{
  return gs_atomic_load(&internal->_redirectInProgress);
}

- (void) _setRedirectInProgress: (BOOL)flag
{
  gs_atomic_store(&internal->_redirectInProgress, flag);
}

- (BOOL) _awaitingResponseDisposition
{
  return gs_atomic_load(&internal->_awaitingResponseDisposition);
}

- (void) _setAwaitingResponseDisposition: (BOOL)flag
{
  gs_atomic_store(&internal->_awaitingResponseDisposition, flag);
}

/* The delegate replies to URLSession:task:willRedirectToResponse:newRequest:
 * here.  A nil request refuses the redirect. */
- (void) resumeWithRedirectRequest: (NSURLRequest *)request
{
  [internal->_session _performSelectorOnWorkThread:
    @selector(_workResumeWithRedirectRequest:)
				  target: self
			      withObject: request];
}

- (void) _workResumeWithRedirectRequest: (NSURLRequest *)userRequest
{
  if (nil == userRequest)
    {
      /* The delegate refused the redirect.  Remove the intercepted transfer
       * (whose completion was held back) and deliver a cancellation for it. */
      [self _setRedirectInProgress: NO];
      [internal->_session _cancelTaskFromDelegate: self];
      NSDebugLLog(
	GS_NSURLSESSION_DEBUG_KEY,
	@"task=%@ redirect refused by the delegate",
	self);
    }
  else
    {
      NSString	*newURLString = [[userRequest URL] absoluteString];

      NSDebugLLog(
	GS_NSURLSESSION_DEBUG_KEY,
	@"task=%@ redirect accepted by the delegate with new URL %@",
	self,
	newURLString);

      /* Remove handle for reconfiguration */
      [internal->_session _removeHandle: internal->_easyHandle];

      /* Reset statistics */
      [self _setCountOfBytesReceived: 0];
      [self _setCountOfBytesSent: 0];
      [self _setCountOfBytesExpectedToReceive: 0];
      [self _setCountOfBytesExpectedToSend: 0];

      [self _setCurrentRequest: userRequest];

      /* Update URL in easy handle */
      curl_easy_setopt(internal->_easyHandle, CURLOPT_URL, [newURLString UTF8String]);
      curl_easy_pause(internal->_easyHandle, CURLPAUSE_CONT);

      [internal->_session _addHandle: internal->_easyHandle];
    }
}

/* The delegate replies to URLSession:dataTask:didReceiveResponse: here. */
- (void) resumeWithResponseDisposition:
  (NSURLSessionResponseDisposition)disposition
{
  /* FIXME: Implement NSURLSessionResponseBecomeDownload */
  if (NSURLSessionResponseCancel == disposition)
    {
      [self _setShouldStopTransfer: YES];
      [internal->_session _performSelectorOnWorkThread:
	@selector(_workCancelForResponseDisposition)
				      target: self
				  withObject: nil];
    }
  else
    {
      [internal->_session _performSelectorOnWorkThread:
	@selector(_workContinueForResponseDisposition)
				      target: self
				  withObject: nil];
    }
}

- (void) _workCancelForResponseDisposition
{
  /* Deliver a cancellation (any held completion is discarded in favour
   * of it). */
  [self _setAwaitingResponseDisposition: NO];
  [internal->_session _cancelTaskFromDelegate: self];
}

- (void) _workContinueForResponseDisposition
{
  [self _setAwaitingResponseDisposition: NO];
  /* Unpause to flush the buffered body, then deliver any completion that was
   * held while awaiting the delegate. */
  curl_easy_pause(internal->_easyHandle, CURLPAUSE_CONT);
  [internal->_session _deliverHeldCompletionForTask: self];
}

/* The delegate replies to URLSession:taskNeedsNewBodyStream: here. */
- (void) resumeWithBodyStream: (NSInputStream *)bodyStream
{
  if (nil != bodyStream)
    {
      [internal->_taskData setObject: bodyStream forKey: taskInputStreamKey];
    }
  /* Continue with the transfer */
  curl_easy_pause(internal->_easyHandle, CURLPAUSE_CONT);
}

/* The three bridges below send the deprecated form of a delegate method,
 * the one which answers through a completion handler, and forward the answer
 * to the reply method above.  A compiler without blocks cannot build a
 * handler to pass, so the deprecated selectors are not looked for there and
 * these are never reached (see +initialize).
 */
#if __has_feature(blocks)
/* These send the deprecated methods deliberately. */
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

- (void) _askDelegateToRedirectTo: (NSHTTPURLResponse *)response
		       newRequest: (NSURLRequest *)request
{
  NSURLSessionTask	*task = self;

  [[self delegate] URLSession: internal->_session
			 task: self
   willPerformHTTPRedirection: response
		   newRequest: request
	    completionHandler: ^(NSURLRequest *userRequest) {
      [task resumeWithRedirectRequest: userRequest];
    }];
}

- (void) _askDelegateAboutResponse: (NSURLResponse *)response
{
  NSURLSessionDataTask	*task = (NSURLSessionDataTask *)self;

  [(id<NSURLSessionDataDelegate>)[self delegate]
		   URLSession: internal->_session
		     dataTask: task
	   didReceiveResponse: response
	    completionHandler: ^(NSURLSessionResponseDisposition disposition) {
      [task resumeWithResponseDisposition: disposition];
    }];
}

- (void) _askDelegateForNewBodyStream
{
  NSURLSessionTask	*task = self;

  [[self delegate] URLSession: internal->_session
			 task: self
	    needNewBodyStream: ^(NSInputStream *bodyStream) {
      [task resumeWithBodyStream: bodyStream];
    }];
}

#pragma GCC diagnostic pop
#endif

- (int) _heldCompletionCode
{
  return internal->_heldCompletionCode;
}

- (void) _setHeldCompletionCode: (int)code
{
  internal->_heldCompletionCode = code;
}

- (NSInteger) _numberOfRedirects
{
  return internal->_numberOfRedirects;
}
- (void) _setNumberOfRedirects: (NSInteger)redirects
{
  internal->_numberOfRedirects = redirects;
}

- (NSInteger) _headerCallbackCount
{
  return internal->_headerCallbackCount;
}
- (void) _setHeaderCallbackCount: (NSInteger)count
{
  internal->_headerCallbackCount = count;
}

/* Creates a temporary file and opens a file handle for writing */
- (NSFileHandle *) _createTemporaryFileHandleWithError: (NSError **)error
{
  NSFileManager	*mgr;
  NSFileHandle	*handle;
  NSString	*path;
  NSURL		*url;

  mgr = [NSFileManager defaultManager];
  path = NSTemporaryDirectory();
  path = [path stringByAppendingPathComponent: [[NSUUID UUID] UUIDString]];

  url = [NSURL fileURLWithPath: path];
  [internal->_taskData setObject: url forKey: taskTemporaryFileLocationKey];

  if (![mgr createFileAtPath: path contents: nil attributes: nil])
    {
      if (error)
        {
          NSString	*errorDescription = [NSString stringWithFormat:
	    @"Failed to create temporary file at path %@", path];

          *error = [NSError errorWithDomain: NSCocoaErrorDomain
				       code: NSURLErrorCannotCreateFile
				   userInfo:
	    [NSDictionary dictionaryWithObjectsAndKeys:
	      errorDescription, NSLocalizedDescriptionKey,
	      nil]];
        }

      return nil;
    }

  handle = [NSFileHandle fileHandleForWritingAtPath: path];
  [internal->_taskData setObject: handle forKey: taskTemporaryFileHandleKey];

  return handle;
} /* _createTemporaryFileHandleWithError */

/* Called in _checkForCompletion */
- (void) _transferFinishedWithCode: (CURLcode)code
{
  NSError	*error;

  /* The delegate cancelled this task from a callback (a redirect refusal or a
   * NSURLSessionResponseCancel disposition).  libcurl can still report the
   * already-buffered response as completing successfully before the cancel
   * takes effect, so deliver a cancellation rather than that spurious success. */
  if (CURLE_OK == code && [self _shouldStopTransfer])
    {
      code = CURLE_ABORTED_BY_CALLBACK;
    }

  error = errorForCURLcode(internal->_easyHandle, code, internal->_curlErrorBuffer);

  if (internal->_properties & GSURLSessionWritesDataToFile)
    {
      NSFileHandle	*handle;

      if (nil !=
          (handle = [internal->_taskData objectForKey: taskTemporaryFileHandleKey]))
        {
          [handle closeFile];
        }
    }

  if (internal->_properties & GSURLSessionUpdatesDelegate)
    {
      if (internal->_properties & GSURLSessionWritesDataToFile
	&& [internal->_delegate respondsToSelector: didFinishDownloadingToURLSel])
        {
          NSURL	*url = [internal->_taskData objectForKey: taskTemporaryFileLocationKey];
          NSInvocation		*inv;
          NSURLSession		*session = internal->_session;
          NSURLSessionTask	*task = self;

          inv = GSURLSessionInvocation(internal->_delegate, didFinishDownloadingToURLSel);
          [inv setArgument: &session atIndex: 2];
          [inv setArgument: &task atIndex: 3];
          [inv setArgument: &url atIndex: 4];
          [internal->_session _enqueueDelegateInvocation: inv];
        }

      if ([internal->_delegate respondsToSelector: didCompleteWithErrorSel])
        {
          NSInvocation		*inv;
          NSURLSession		*session = internal->_session;
          NSURLSessionTask	*task = self;

          inv = GSURLSessionInvocation(internal->_delegate, didCompleteWithErrorSel);
          [inv setArgument: &session atIndex: 2];
          [inv setArgument: &task atIndex: 3];
          [inv setArgument: &error atIndex: 4];
          [internal->_session _enqueueDelegateInvocation: inv];
        }
    }

  /* NSURLSessionUploadTask is a subclass of a NSURLSessionDataTask with the
   * same completion handler signature. It thus follows the same code path.
   */
  if ((internal->_properties & GSURLSessionStoresDataInMemory)
    && (internal->_properties & GSURLSessionHasCompletionHandler)
    && [self isKindOfClass: dataTaskClass])
    {
      NSURLSessionDataTask	*dataTask;
      NSData 			*data;

      NSInvocation	*inv;
      NSURLResponse	*response = internal->_response;

      dataTask = (NSURLSessionDataTask *)self;
      data = [internal->_taskData objectForKey: taskTransferDataKey];

      inv = GSURLSessionInvocation(dataTask,
	@selector(_callDataCompletionHandlerWithData:response:error:));
      [inv setArgument: &data atIndex: 2];
      [inv setArgument: &response atIndex: 3];
      [inv setArgument: &error atIndex: 4];
      [internal->_session _enqueueDelegateInvocation: inv];
    }
  else if ((internal->_properties & GSURLSessionWritesDataToFile)
    && (internal->_properties & GSURLSessionHasCompletionHandler)
    && [self isKindOfClass: downloadTaskClass])
    {
      NSURLSessionDownloadTask	*downloadTask;
      NSURL			*tempFile;

      NSInvocation	*inv;
      NSURLResponse	*response = internal->_response;

      downloadTask = (NSURLSessionDownloadTask *)self;
      tempFile = [internal->_taskData objectForKey: taskTemporaryFileLocationKey];

      inv = GSURLSessionInvocation(downloadTask,
	@selector(_callDownloadCompletionHandlerWithURL:response:error:));
      [inv setArgument: &tempFile atIndex: 2];
      [inv setArgument: &response atIndex: 3];
      [inv setArgument: &error atIndex: 4];
      [internal->_session _enqueueDelegateInvocation: inv];
    }

  RELEASE(internal->_session);
} /* _transferFinishedWithCode */

/* Called in header_callback */
- (void) _setCookiesFromHeaders: (NSDictionary *)headers
{
  NSURL				*url;
  NSArray 			*cookies;
  NSURLSessionConfiguration 	*config;

  config = [internal->_session configuration];
  url = [internal->_currentRequest URL];

  /* FIXME: Implement NSHTTPCookieAcceptPolicyOnlyFromMainDocumentDomain */
  if (NSHTTPCookieAcceptPolicyNever != [config HTTPCookieAcceptPolicy]
      && nil != [config HTTPCookieStorage])
    {
      cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: headers
                                                       forURL: url];
      if ([cookies count] > 0)
        {
          [[config HTTPCookieStorage] setCookies: cookies
                                          forURL: url
                                 mainDocumentURL: nil];
        }
    }
} /* _setCookiesFromHeaders */

#pragma mark - Public Methods

- (void) suspend
{
  internal->_suspendCount += 1;
  if (internal->_suspendCount == 1)
    {
      /* If there is an active transfer associated with this task, it will be
       * aborted in the next libcurl progress_callback.
       *
       * TODO: Pause the easy handle put do not abort the full transfer!
       * .     What if the handle is currently paused?
       */
      gs_atomic_store(&internal->_shouldStopTransfer, YES);
    }
}
- (void) resume
{
  /* Only resume a transfer if the task is not suspended and in suspended state
   */
  if (internal->_suspendCount == 0 && [self state] == NSURLSessionTaskStateSuspended)
    {
      /*
       * Properly retain the session to keep a reference
       * to the task. This ensures correct API behaviour.
       */
      RETAIN(internal->_session);

      internal->_state = NSURLSessionTaskStateRunning;
      [internal->_session _resumeTask: self];
      return;
    }
  internal->_suspendCount -= 1;
}
- (void) cancel
{
  /* Transfer is aborted in the next libcurl progress_callback
   *
   * If a NSURLSessionTask delegate is set and this is not a convenience task,
   * URLSession:task:didCompleteWithError: is called after receiving
   * CURLMSG_DONE in -[NSURLSessionTask _checkForCompletion].
   */
  [internal->_session _performSelectorOnWorkThread: @selector(_workCancel)
				  target: self
			      withObject: nil];
}

- (void) _workCancel
{
  /* Unpause the easy handle if previously paused */
  curl_easy_pause(internal->_easyHandle, CURLPAUSE_CONT);

  gs_atomic_store(&internal->_shouldStopTransfer, YES);
  internal->_state = NSURLSessionTaskStateCanceling;

  /* If the task was awaiting a didReceiveResponse disposition its completion
   * was being held back; resolve that state so the cancellation is delivered
   * (as a cancellation, since internal->_shouldStopTransfer is set) rather than left
   * pending a disposition that will never arrive. */
  gs_atomic_store(&internal->_awaitingResponseDisposition, NO);
  [internal->_session _deliverHeldCompletionForTask: self];
}

- (float) priority
{
  return internal->_priority;
}
- (void) setPriority: (float)priority
{
  internal->_priority = priority;
}

- (id) copyWithZone: (NSZone *)zone
{
  NSURLSessionTask	*copy = [[[self class] alloc] init];

  if (copy)
    {
      GSIVar(copy, _originalRequest) = [internal->_originalRequest copyWithZone: zone];
      GSIVar(copy, _currentRequest) = [internal->_currentRequest copyWithZone: zone];
      GSIVar(copy, _response) = [internal->_response copyWithZone: zone];
      /* FIXME: Seems like copyWithZone: is not implemented for NSProgress */
      GSIVar(copy, _progress) = [internal->_progress copy];
      GSIVar(copy, _earliestBeginDate) = [internal->_earliestBeginDate copyWithZone: zone];
      GSIVar(copy, _taskDescription) = [internal->_taskDescription copyWithZone: zone];
      GSIVar(copy, _taskData) = [internal->_taskData copyWithZone: zone];
      GSIVar(copy, _easyHandle) = curl_easy_duphandle(internal->_easyHandle);
    }

  return copy;
}

#pragma mark - Getter and Setter

- (NSUInteger) taskIdentifier
{
  return internal->_taskIdentifier;
}

- (NSURLRequest *) originalRequest
{
  return AUTORELEASE([internal->_originalRequest copy]);
}

- (NSURLRequest *) currentRequest
{
  return AUTORELEASE([internal->_currentRequest copy]);
}

- (NSURLResponse *) response
{
  return AUTORELEASE([internal->_response copy]);
}

- (NSURLSessionTaskState) state
{
  return internal->_state;
}

- (NSProgress *) progress
{
  return internal->_progress;
}

- (NSError *) error
{
  return internal->_error;
}

- (id<NSURLSessionTaskDelegate>) delegate
{
  return internal->_delegate;
}

- (void) setDelegate: (id<NSURLSessionTaskDelegate>)delegate
{
  id<NSURLSessionTaskDelegate> oldDelegate = internal->_delegate;

  internal->_delegate = RETAIN(delegate);
  RELEASE(oldDelegate);
}

- (NSDate *) earliestBeginDate
{
  return internal->_earliestBeginDate;
}

- (void) setEarliestBeginDate: (NSDate *)date
{
  NSDate	*oldDate = internal->_earliestBeginDate;

  internal->_earliestBeginDate = RETAIN(date);
  RELEASE(oldDate);
}

- (int64_t) countOfBytesClientExpectsToSend
{
  return gs_atomic_load(&internal->_countOfBytesClientExpectsToSend);
}
- (int64_t) countOfBytesClientExpectsToReceive
{
  return gs_atomic_load(&internal->_countOfBytesClientExpectsToReceive);
}
- (int64_t) countOfBytesSent
{
  return gs_atomic_load(&internal->_countOfBytesSent);
}
- (int64_t) countOfBytesReceived
{
  return gs_atomic_load(&internal->_countOfBytesReceived);
}
- (int64_t) countOfBytesExpectedToSend
{
  return gs_atomic_load(&internal->_countOfBytesExpectedToSend);
}
- (int64_t) countOfBytesExpectedToReceive
{
  return gs_atomic_load(&internal->_countOfBytesExpectedToReceive);
}

- (NSString *) taskDescription
{
  return internal->_taskDescription;
}

- (void) setTaskDescription: (NSString *)description
{
  NSString	*oldDescription = internal->_taskDescription;

  internal->_taskDescription = [description copy];
  RELEASE(oldDescription);
}

- (void) dealloc
{
  /* The session retains this task until the transfer is complete and the easy
   * handle removed from the multi handle.
   *
   * It is save to release the curl handle here.
   */
  curl_easy_cleanup(internal->_easyHandle);
  curl_slist_free_all(internal->_headerList);

  RELEASE(internal->_originalRequest);
  RELEASE(internal->_currentRequest);
  RELEASE(internal->_response);
  RELEASE(internal->_progress);
  RELEASE(internal->_earliestBeginDate);
  RELEASE(internal->_taskDescription);
  RELEASE(internal->_taskData);

  GS_DESTROY_INTERNAL(NSURLSessionTask);
  [super dealloc];
}

@end /* NSURLSessionTask */

@implementation NSURLSessionDataTask

- (GSNSURLSessionDataCompletionHandler) _completionHandler
{
  return _completionHandler;
}

- (void) _setCompletionHandler: (GSNSURLSessionDataCompletionHandler)handler
{
  if (NULL != handler)
    {
      _completionHandler = Block_copy(handler);
    }
}

/* Called on the delegate queue so that the handler runs there, as it did
 * when the queue was given a block to run. */
- (void) _callDataCompletionHandlerWithData: (NSData *)data
				   response: (NSURLResponse *)response
				      error: (NSError *)error
{
  GSNSURLSessionDataCompletionHandler	handler = [self _completionHandler];

  CALL_BLOCK(handler, data, response, error);
}

- (void) dealloc
{
  if (NULL != _completionHandler)
    {
      Block_release(_completionHandler);
    }
  [super dealloc];
}

@end

@implementation NSURLSessionUploadTask
@end

@implementation NSURLSessionDownloadTask

- (GSNSURLSessionDownloadCompletionHandler) _completionHandler
{
  return _completionHandler;
}

- (void) _setCompletionHandler: (GSNSURLSessionDownloadCompletionHandler)handler
{
  if (NULL != handler)
    {
      _completionHandler = Block_copy(handler);
    }
}

/* Called on the delegate queue so that the handler runs there, as it did
 * when the queue was given a block to run. */
- (void) _callDownloadCompletionHandlerWithURL: (NSURL *)location
				      response: (NSURLResponse *)response
					 error: (NSError *)error
{
  GSNSURLSessionDownloadCompletionHandler handler = [self _completionHandler];

  CALL_BLOCK(handler, location, response, error);
}

- (int64_t) _countOfBytesWritten
{
  return _countOfBytesWritten;
};

- (void) _updateCountOfBytesWritten: (int64_t)count
{
  _countOfBytesWritten += count;
}

- (void) dealloc
{
  if (NULL != _completionHandler)
    {
      Block_release(_completionHandler);
    }
  [super dealloc];
}

@end

@implementation NSURLSessionStreamTask
@end
