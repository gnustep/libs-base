#ifndef __NSURLSession_h_GNUSTEP_BASE_INCLUDE
#define __NSURLSession_h_GNUSTEP_BASE_INCLUDE

#import <Foundation/NSObject.h>

#if OS_API_VERSION(MAC_OS_X_VERSION_10_9,GS_API_LATEST)
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

@protocol NSURLSessionDelegate <NSObject>
@end

@protocol NSURLSessionTaskDelegate <NSURLSessionDelegate>
@end

#endif
#endif
