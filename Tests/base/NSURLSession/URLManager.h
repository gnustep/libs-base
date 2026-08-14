#import <Foundation/NSURLSession.h>
#import <Foundation/NSData.h>
#import <GNUstepBase/GSBlocks.h>

@class URLManager;

DEFINE_BLOCK_TYPE(URLManagerCheckBlock, void, URLManager *);

@interface URLManager
  : NSObject <NSURLSessionDataDelegate, NSURLSessionTaskDelegate,
              NSURLSessionDelegate, NSURLSessionDownloadDelegate>
{
  URLManagerCheckBlock _checkBlock;
  id                   _checkTarget;
  SEL                  _checkSelector;

@public
  NSURLSession                   *currentSession;
  NSURLSessionResponseDisposition responseAnswer;

  NSInteger numberOfExpectedTasksBeforeCheck;

  NSInteger         didCreateTaskCount;
  NSURLSessionTask *didCreateTask;

  NSInteger didBecomeInvalidCount;
  NSError  *didBecomeInvalidError;

  NSInteger          httpRedirectionCount;
  NSURLSessionTask  *httpRedirectionTask;
  NSHTTPURLResponse *httpRedirectionResponse;
  NSURLRequest      *httpRedirectionRequest;

  NSInteger         didCompleteCount;
  NSURLSessionTask *didCompleteTask;
  NSError          *didCompleteError;

  NSInteger                 didWriteDataCount;
  NSURLSessionDownloadTask *didWriteDataTask;
  int64_t                   downloadBytesWritten;
  int64_t                   downloadTotalBytesWritten;
  int64_t                   downloadTotalBytesExpectedToWrite;

  NSInteger                 didFinishDownloadingCount;
  NSURLSessionDownloadTask *didFinishDownloadingTask;
  NSURL                    *didFinishDownloadingURL;

  NSInteger             didReceiveResponseCount;
  NSURLSessionDataTask *didReceiveResponseTask;
  NSURLResponse        *didReceiveResponse;

  NSInteger             didReceiveDataCount;
  NSURLSessionDataTask *didReceiveDataTask;
  NSMutableData        *accumulatedData;

  BOOL cancelRedirect;
}

- (void)setCheckBlock:(URLManagerCheckBlock)block;

/* The check to run once the expected number of tasks has completed, stated
 * without a block.  aSelector takes the URLManager.
 */
- (void)setCheckTarget:(id)target selector:(SEL)aSelector;

@end

@implementation URLManager

- (instancetype)init
{
  self = [super init];
  if (self)
    {
      responseAnswer = NSURLSessionResponseAllow;
      accumulatedData = [[NSMutableData alloc] init];
    }

  return self;
}

- (void)setCheckBlock:(URLManagerCheckBlock)block
{
  if (NULL != block)
    {
      _checkBlock = Block_copy(block);
    }
}

- (void)setCheckTarget:(id)target selector:(SEL)aSelector
{
  /* The check runs later, from a delegate callback, so the target is held. */
  ASSIGN(_checkTarget, target);
  _checkSelector = aSelector;
}

#pragma mark - Session Lifecycle

- (void)URLSession:(NSURLSession *)session
     didCreateTask:(NSURLSessionTask *)task
{
  ASSIGN(currentSession, session);

  didCreateTaskCount += 1;
  ASSIGN(didCreateTask, task);
}
- (void)URLSession:(NSURLSession *)session
  didBecomeInvalidWithError:(NSError *)error
{
  ASSIGN(currentSession, session);
  ASSIGN(didBecomeInvalidError, error);

  didBecomeInvalidCount += 1;
}

#pragma mark - Task Updates

- (void)URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
  willRedirectToResponse:(NSHTTPURLResponse *)response
              newRequest:(NSURLRequest *)request
{
  ASSIGN(currentSession, session);
  ASSIGN(httpRedirectionTask, task);
  ASSIGN(httpRedirectionResponse, response);
  ASSIGN(httpRedirectionRequest, request);

  if (cancelRedirect)
    {
      [task resumeWithRedirectRequest:nil];
    }
  else
    {
      [task resumeWithRedirectRequest:request];
    }

  httpRedirectionCount += 1;
}

- (void)URLSession:(NSURLSession *)session
                  task:(NSURLSessionTask *)task
  didCompleteWithError:(NSError * _Nullable)error
{
  ASSIGN(currentSession, session);
  ASSIGN(didCompleteTask, task);
  ASSIGN(didCompleteError, error);

  didCompleteCount += 1;
  if (didCompleteCount == numberOfExpectedTasksBeforeCheck)
    {
      if (nil != _checkTarget)
        {
          [_checkTarget performSelector:_checkSelector withObject:self];
        }
      else
        {
          CALL_BLOCK(_checkBlock, self);
        }
    }
}

#pragma mark - Data Updates

- (void)URLSession:(NSURLSession *)session
            dataTask:(NSURLSessionDataTask *)dataTask
  didReceiveResponse:(NSURLResponse *)response
{
  ASSIGN(currentSession, session);
  ASSIGN(didReceiveResponseTask, dataTask);
  ASSIGN(didReceiveResponse, response);

  didReceiveResponseCount += 1;

  [dataTask resumeWithResponseDisposition:responseAnswer];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
  ASSIGN(currentSession, session);
  ASSIGN(didReceiveResponseTask, dataTask);

  didReceiveDataCount += 1;

  [accumulatedData appendData:data];
}

#pragma mark - Download Updates

- (void)URLSession:(NSURLSession *)session
               downloadTask:(NSURLSessionDownloadTask *)downloadTask
               didWriteData:(int64_t)bytesWritten
          totalBytesWritten:(int64_t)totalBytesWritten
  totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite
{
  ASSIGN(currentSession, session);

  didWriteDataCount += 1;
  downloadBytesWritten = bytesWritten;
  downloadTotalBytesExpectedToWrite = totalBytesExpectedToWrite;
  downloadTotalBytesExpectedToWrite = totalBytesExpectedToWrite;
}

- (void)URLSession:(NSURLSession *)session
               downloadTask:(NSURLSessionDownloadTask *)downloadTask
  didFinishDownloadingToURL:(NSURL *)location
{
  ASSIGN(currentSession, session);
  ASSIGN(didFinishDownloadingTask, downloadTask);
  ASSIGN(didFinishDownloadingURL, location);

  didFinishDownloadingCount += 1;
}

- (void)dealloc
{
  RELEASE(currentSession);

  RELEASE(didCreateTask);
  RELEASE(didBecomeInvalidError);

  RELEASE(httpRedirectionTask);
  RELEASE(httpRedirectionResponse);
  RELEASE(httpRedirectionRequest);

  RELEASE(didCompleteTask);
  RELEASE(didCompleteError);

  RELEASE(didWriteDataTask);

  RELEASE(didFinishDownloadingTask);
  RELEASE(didFinishDownloadingURL);

  RELEASE(didReceiveResponseTask);
  RELEASE(didReceiveResponse);

  RELEASE(didReceiveDataTask);
  RELEASE(accumulatedData);

  RELEASE(_checkTarget);
  if (NULL != _checkBlock)
    {
      Block_release(_checkBlock);
    }
  [super dealloc];
}

@end
