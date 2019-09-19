#ifndef __NSURLSession_h_GNUSTEP_BASE_INCLUDE
#define __NSURLSession_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9,GS_API_LATEST)

#import <GNUstepBase/GSBlocks.h>

#if    defined(__cplusplus)
extern "C" {
#endif

@class NSError;
@class NSURL;
@class NSURLRequest;
@class NSURLResponse;
@class NSHTTPURLResponse;
@class NSURLAuthenticationChallenge;
@class NSURLCredential;
@class NSCachedURLResponse;
@class NSInputStream;
@class NSOutputStream;
@class NSData;

typedef NSInteger NSURLSessionAuthChallengeDisposition;
enum {
  NSURLSessionAuthChallengeUseCredential = 0,
  NSURLSessionAuthChallengePerformDefaultHandling = 1,
  NSURLSessionAuthChallengeCancelAuthenticationChallenge = 2,
  NSURLSessionAuthChallengeRejectProtectionSpace = 3,
};

typedef NSInteger NSURLSessionResponseDisposition;
enum {
  NSURLSessionResponseCancel = 0,
  NSURLSessionResponseAllow = 1,
  NSURLSessionResponseBecomeDownload = 2,
#if OS_API_VERSION(MAC_OS_X_VERSION_10_11,GS_API_LATEST)
  NSURLSessionResponseBecomeStream = 3,
#endif
};

typedef NSUInteger NSURLRequestNetworkServiceType;
enum {
  NSURLNetworkServiceTypeDefault = 0,
  NSURLNetworkServiceTypeVoIP = 1,
  NSURLNetworkServiceTypeVideo = 2,
  NSURLNetworkServiceTypeBackground = 3,
  NSURLNetworkServiceTypeVoice = 4,
  NSURLNetworkServiceTypeResponsiveData = 6,
};

typedef NSInteger NSURLSessionTaskState;
enum {
  NSURLSessionTaskStateRunning = 0,
  NSURLSessionTaskStateSuspended = 1,
  NSURLSessionTaskStateCanceling = 2,
  NSURLSessionTaskStateCompleted = 3,
};

extern const float NSURLSessionTaskPriorityDefault;
extern const float NSURLSessionTaskPriorityLow;
extern const float NSURLSessionTaskPriorityHigh;

extern const int64_t NSURLSessionTransferSizeUnknown;

@protocol NSURLSessionDelegate;
@protocol NSURLSessionTaskDelegate;

@interface NSURLSession : NSObject
@end

@interface NSURLSessionConfiguration : NSObject <NSCopying>
@end

@interface NSURLSessionTask : NSObject <NSCopying>
@end

@interface NSURLSessionDataTask : NSURLSessionTask
@end

@interface NSURLSessionUploadTask : NSURLSessionDataTask
@end

@interface NSURLSessionDownloadTask : NSURLSessionTask
@end

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11,GS_API_LATEST)
@interface NSURLSessionStreamTask : NSURLSessionTask
@end
#endif

DEFINE_BLOCK_TYPE(GSURLSessionHTTPRedirectionCompletionHandler, void, NSURLRequest *);
DEFINE_BLOCK_TYPE(GSURLSessionChallengeCompletionHandler, void, NSURLSessionAuthChallengeDisposition, NSURLCredential *);
DEFINE_BLOCK_TYPE(GSURLSessionNewBodyStreamCompletionHandler, void, NSInputStream *);
DEFINE_BLOCK_TYPE(GSURLSessionResponseCompletionHandler, void, NSURLSessionResponseDisposition);
DEFINE_BLOCK_TYPE(GSURLSessionCacheResponseCompletionHandler, void, NSCachedURLResponse *);

@protocol NSURLSessionDelegate <NSObject>
@optional

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error;

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
                                             completionHandler:(GSURLSessionChallengeCompletionHandler)completionHandler;

@end

@protocol NSURLSessionTaskDelegate <NSURLSessionDelegate>
@optional

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                     willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                                     newRequest:(NSURLRequest *)request
                              completionHandler:(GSURLSessionHTTPRedirectionCompletionHandler)completionHandler;

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                            didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
                              completionHandler:(GSURLSessionChallengeCompletionHandler)completionHandler;

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                              needNewBodyStream:(GSURLSessionNewBodyStreamCompletionHandler)completionHandler;

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                didSendBodyData:(int64_t)bytesSent
                                 totalBytesSent:(int64_t)totalBytesSent
                       totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend;

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                           didCompleteWithError:(NSError *)error;

@end

@protocol NSURLSessionDataDelegate <NSURLSessionTaskDelegate>
@optional

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
                                  completionHandler:(GSURLSessionResponseCompletionHandler)completionHandler;

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                              didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask;

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11,GS_API_LATEST)
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                didBecomeStreamTask:(NSURLSessionStreamTask *)streamTask;
#endif

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                     didReceiveData:(NSData *)data;

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                  willCacheResponse:(NSCachedURLResponse *)proposedResponse
                                  completionHandler:(GSURLSessionCacheResponseCompletionHandler)completionHandler;

@end

@protocol NSURLSessionDownloadDelegate <NSURLSessionTaskDelegate>

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                              didFinishDownloadingToURL:(NSURL *)location;

@optional
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                           didWriteData:(int64_t)bytesWritten
                                      totalBytesWritten:(int64_t)totalBytesWritten
                              totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite;

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
                                      didResumeAtOffset:(int64_t)fileOffset
                                     expectedTotalBytes:(int64_t)expectedTotalBytes;

@end

#if OS_API_VERSION(MAC_OS_X_VERSION_10_11,GS_API_LATEST)
@protocol NSURLSessionStreamDelegate <NSURLSessionTaskDelegate>
@optional

- (void)URLSession:(NSURLSession *)session readClosedForStreamTask:(NSURLSessionStreamTask *)streamTask;

- (void)URLSession:(NSURLSession *)session writeClosedForStreamTask:(NSURLSessionStreamTask *)streamTask;

- (void)URLSession:(NSURLSession *)session betterRouteDiscoveredForStreamTask:(NSURLSessionStreamTask *)streamTask;

- (void)URLSession:(NSURLSession *)session streamTask:(NSURLSessionStreamTask *)streamTask
                                 didBecomeInputStream:(NSInputStream *)inputStream
                                         outputStream:(NSOutputStream *)outputStream;

@end
#endif

#if    defined(__cplusplus)
}
#endif

#endif /* OS_API_VERSION */
#endif /* __NSURLSession_h_GNUSTEP_BASE_INCLUDE */
