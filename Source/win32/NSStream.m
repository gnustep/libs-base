/** Implementation for NSStream for GNUStep
   Copyright (C) 2006 Free Software Foundation, Inc.

   Written by:  Derek Zhou <derekzhou@gmail.com>
   Written by:  Richard Frith-Macdonald <rfm@gnu.org>
   Date: 2006

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.

   */
#include "common.h"
#include <winhttp.h>

#import "Foundation/NSData.h"
#import "Foundation/NSArray.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSEnumerator.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSException.h"
#import "Foundation/NSError.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSHost.h"
#import "Foundation/NSProcessInfo.h"
#import "Foundation/NSByteOrder.h"
#import "GNUstepBase/NSObject+GNUstepBase.h"

#import "../GSPrivate.h"
#import "../GSStream.h"
#import "../GSSocketStream.h"

#define    BUFFERSIZE    (BUFSIZ*64)

void PrintLastError(NSString * f) {
  DWORD lastError = GetLastError();
  switch (lastError) {
    case ERROR_WINHTTP_AUTO_PROXY_SERVICE_ERROR:
      NSLog(@"%@: (%d) Returned by WinHttpGetProxyForUrl when a proxy for the specified URL cannot be located.", f, lastError);
      break;
    case ERROR_WINHTTP_BAD_AUTO_PROXY_SCRIPT:
      NSLog(@"%@: (%d) An error occurred executing the script code in the Proxy Auto-Configuration (PAC) file.", f, lastError);
      break;
    case ERROR_WINHTTP_INCORRECT_HANDLE_TYPE:
      NSLog(@"%@: (%d) The type of handle supplied is incorrect for this operation.", f, lastError);
      break;
    case ERROR_WINHTTP_INTERNAL_ERROR:
      NSLog(@"%@: (%d) An internal error has occurred.", f, lastError);
      break;
    case ERROR_WINHTTP_INVALID_URL:
      NSLog(@"%@: (%d) The URL is invalid.", f, lastError);
      break;
    case ERROR_WINHTTP_LOGIN_FAILURE:
      NSLog(@"%@: (%d) The login attempt failed. When this error is encountered, close the request handle with WinHttpCloseHandle. A new request handle must be created before retrying the function that originally produced this error.", f, lastError);
      break;
    case ERROR_WINHTTP_OPERATION_CANCELLED:
      NSLog(@"%@: (%d) The operation was canceled, usually because the handle on which the request was operating was closed before the operation completed.", f, lastError);
      break;
    case ERROR_WINHTTP_UNABLE_TO_DOWNLOAD_SCRIPT:
      NSLog(@"%@: (%d) The PAC file could not be downloaded. For example, the server referenced by the PAC URL may not have been reachable, or the server returned a 404 NOT FOUND response.", f, lastError);
      break;
    case ERROR_WINHTTP_UNRECOGNIZED_SCHEME:
        NSLog(@"%@: (%d) The URL of the PAC file specified a scheme other than \"http:\" or \"https:\".", f, lastError);
        break;
    case ERROR_NOT_ENOUGH_MEMORY:
        NSLog(@"%@: (%d) ERROR_NOT_ENOUGH_MEMORY", f, lastError);
        break;
    case (ERROR_WINHTTP_AUTODETECTION_FAILED):
      NSLog(@"%@: (%d) Returned WinHTTP was unable to discover the URL of the Proxy Auto-Configuration (PAC) file", f, lastError);
      break;
    default:
      NSLog(@"%@: (%d) Unknown Error.", f, lastError);
      break;
  }
}

NSString * normalizeUrl(NSString * url)
{
  if (!url) return nil;

  BOOL prepend = YES;
  NSString * urlFront = nil;
    
  if ([url length] >= 7) {
    // Check that url begins with http://
    urlFront = [url substringToIndex:7];
    if ([urlFront caseInsensitiveCompare:@"http://"] == NSOrderedSame) {
        prepend = NO;
    }
  }
  if ([url length] >= 8) {
    // Check that url begins with https://
      urlFront = [url substringToIndex:8];
      if ([urlFront caseInsensitiveCompare:@"https://"] == NSOrderedSame) {
          prepend = NO;
      }
  }

  // If http[s]:// is omited, slap it on.
  if (prepend) {
    return [NSString stringWithFormat:@"http://%@", url];
  }
  else {
    return url;
  }
}

BOOL ResolveProxy(NSString * url, WINHTTP_CURRENT_USER_IE_PROXY_CONFIG * resultProxyConfig)
{
  NSString * dstUrlString = [NSString stringWithFormat: @"http://%@", url];
  const wchar_t *DestURL = (wchar_t*)[dstUrlString cStringUsingEncoding: NSUTF16StringEncoding];

    WINHTTP_CURRENT_USER_IE_PROXY_CONFIG ProxyConfig;
    WINHTTP_PROXY_INFO ProxyInfo, ProxyInfoTemp;
    WINHTTP_AUTOPROXY_OPTIONS OptPAC;
    DWORD dwOptions = SECURITY_FLAG_IGNORE_CERT_CN_INVALID | SECURITY_FLAG_IGNORE_CERT_DATE_INVALID | SECURITY_FLAG_IGNORE_UNKNOWN_CA | SECURITY_FLAG_IGNORE_CERT_WRONG_USAGE;

    ZeroMemory(&ProxyInfo, sizeof(ProxyInfo));
    ZeroMemory(&ProxyConfig, sizeof(ProxyConfig));
  ZeroMemory(resultProxyConfig, sizeof(*resultProxyConfig));

  BOOL result = false;
  BOOL autoConfigWorked = false;
  BOOL autoDetectWorked = false;

    HINTERNET http_local_session = WinHttpOpen(L"Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko)", WINHTTP_ACCESS_TYPE_NO_PROXY, 0, WINHTTP_NO_PROXY_BYPASS, 0);

    if (http_local_session && WinHttpGetIEProxyConfigForCurrentUser(&ProxyConfig)) {
    NSLog(@"Got proxy config for current user.");
        if (ProxyConfig.lpszProxy) {
            ProxyInfo.lpszProxy = ProxyConfig.lpszProxy;
            ProxyInfo.dwAccessType = WINHTTP_ACCESS_TYPE_NAMED_PROXY;
            ProxyInfo.lpszProxyBypass = NULL;
        }
    memcpy(resultProxyConfig, &ProxyConfig, sizeof(*resultProxyConfig));

        if (ProxyConfig.lpszAutoConfigUrl) {
      size_t len = wcslen(ProxyConfig.lpszAutoConfigUrl);
      NSString * autoConfigUrl = [[NSString alloc] initWithBytes: ProxyConfig.lpszAutoConfigUrl length:len*2 encoding:NSUTF16StringEncoding];
      NSLog(@"trying script proxy pac file: %@.", autoConfigUrl);
            // Script proxy pac
            OptPAC.dwFlags = WINHTTP_AUTOPROXY_CONFIG_URL;
            OptPAC.lpszAutoConfigUrl = ProxyConfig.lpszAutoConfigUrl;
            OptPAC.dwAutoDetectFlags = 0;
            OptPAC.fAutoLogonIfChallenged = TRUE;
            OptPAC.lpvReserved = 0;
            OptPAC.dwReserved = 0;

            if (WinHttpGetProxyForUrl(http_local_session, DestURL, &OptPAC, &ProxyInfoTemp)) {
        NSLog(@"worked");
                memcpy(&ProxyInfo, &ProxyInfoTemp, sizeof(ProxyInfo));

        resultProxyConfig->lpszProxy = ProxyInfoTemp.lpszProxy;
        resultProxyConfig->lpszProxyBypass = ProxyInfoTemp.lpszProxyBypass;
        autoConfigWorked = true;
      }
      else {
        PrintLastError(@"WinHttpGetProxyForUrl");
      }
        }
        else if (ProxyConfig.fAutoDetect) {
      NSLog(@"trying autodetect proxy");
            // Autodetect proxy
            OptPAC.dwFlags = WINHTTP_AUTOPROXY_AUTO_DETECT;
            OptPAC.dwAutoDetectFlags = WINHTTP_AUTO_DETECT_TYPE_DHCP | WINHTTP_AUTO_DETECT_TYPE_DNS_A;
            OptPAC.fAutoLogonIfChallenged = TRUE;
            OptPAC.lpszAutoConfigUrl = NULL;
            OptPAC.lpvReserved = 0;
            OptPAC.dwReserved = 0;

            if (WinHttpGetProxyForUrl(http_local_session, DestURL, &OptPAC, &ProxyInfoTemp)) {
        NSLog(@"worked");
        memcpy(&ProxyInfo, &ProxyInfoTemp, sizeof(ProxyInfo));

        resultProxyConfig->lpszProxy = ProxyInfoTemp.lpszProxy;
        resultProxyConfig->lpszProxyBypass = ProxyInfoTemp.lpszProxyBypass;
        autoDetectWorked = true;
      }
      else {
        PrintLastError(@"WinHttpGetProxyForUrl");
      }
        }

    NSString * autoConfigUrl = @"";
    NSString * proxy = @"";
    NSString * proxyBypass = @"";

    autoConfigUrl = normalizeUrl(autoConfigUrl);
    proxy = normalizeUrl(proxy);

    if (resultProxyConfig->lpszAutoConfigUrl) autoConfigUrl = [[NSString alloc] initWithBytes: resultProxyConfig->lpszAutoConfigUrl length:wcslen(resultProxyConfig->lpszAutoConfigUrl)*2 encoding:NSUTF16StringEncoding];
    if (resultProxyConfig->lpszProxy) proxy = [[NSString alloc] initWithBytes: resultProxyConfig->lpszProxy length:wcslen(resultProxyConfig->lpszProxy)*2 encoding:NSUTF16StringEncoding];
    if (resultProxyConfig->lpszProxyBypass) proxyBypass = [[NSString alloc] initWithBytes: resultProxyConfig->lpszProxyBypass length:wcslen(resultProxyConfig->lpszProxyBypass)*2 encoding:NSUTF16StringEncoding];

    NSLog(@"  autoConfigUrl: %@", autoConfigUrl);
    NSLog(@"  proxy: %@", proxy);
    NSLog(@"  proxyBypass: %@", proxyBypass);

    result = true;
  }
  

  return result;
}

BOOL ResolveProxy_old(NSString * url, WINHTTP_PROXY_INFO * proxyInfo)
{
  BOOL success = false;
  HINTERNET hHttpSession = NULL;

/*
            OptPAC.dwFlags = WINHTTP_AUTOPROXY_CONFIG_URL;
            OptPAC.lpszAutoConfigUrl = ProxyConfig.lpszAutoConfigUrl;
            OptPAC.dwAutoDetectFlags = 0;
            OptPAC.fAutoLogonIfChallenged = TRUE;
            OptPAC.lpvReserved = 0;
            OptPAC.dwReserved = 0;
*/

  ZeroMemory(proxyInfo, sizeof(*proxyInfo));

  WINHTTP_AUTOPROXY_OPTIONS AutoProxyOptions;
  ZeroMemory(&AutoProxyOptions, sizeof(AutoProxyOptions));
  AutoProxyOptions.dwFlags = WINHTTP_AUTOPROXY_AUTO_DETECT;
  AutoProxyOptions.dwAutoDetectFlags =  WINHTTP_AUTO_DETECT_TYPE_DHCP | WINHTTP_AUTO_DETECT_TYPE_DNS_A;
  AutoProxyOptions.fAutoLogonIfChallenged = TRUE;
  
//  wchar_t    urlW[[url length] + 1];
//  mbstowcs(urlW, [url cStringUsingEncoding:NSASCIIStringEncoding] , [url length]);

//  NSString * goodUrl = [NSString stringWithFormat:@"http://%@", url];
  const wchar_t *urlW = (wchar_t*)[url cStringUsingEncoding: NSUTF16StringEncoding];

  NSLog(@"url: %@", url);

  {
    hHttpSession = WinHttpOpen(L"GNUstep",WINHTTP_ACCESS_TYPE_NO_PROXY, WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    if( !hHttpSession ) goto exit;

    BOOL result = WinHttpGetProxyForUrl( hHttpSession, urlW, &AutoProxyOptions, proxyInfo);
    if (!result) {
      PrintLastError(@"WinHttpGetProxyForUrl");

      result = WinHttpGetIEProxyConfigForCurrentUser(proxyInfo);
      if (!result) goto exit;
      NSLog(@"Manual proxy worked.");
    }
    else {
      NSLog(@"Auto proxy worked.");
    }

    success = TRUE;
  }
  exit:

  if(proxyInfo->lpszProxy != NULL) GlobalFree(proxyInfo->lpszProxy);
  if(proxyInfo->lpszProxyBypass != NULL) GlobalFree( proxyInfo->lpszProxyBypass );
  if(hHttpSession != NULL) WinHttpCloseHandle( hHttpSession );

  NSLog(@"%@", success ? @"SUCCESS" : @"FAIL");

  return success;
}

// FIXME: Move this code into System Configuration framework...
CFDictionaryRef SCDynamicStoreCopyProxies(SCDynamicStoreRef store, NSString * forUrl)
{
  NSLog(@"forURL: %@", forUrl);
  NSMutableDictionary *proxyDict = [NSMutableDictionary dictionary];
  WINHTTP_CURRENT_USER_IE_PROXY_CONFIG  proxyInfo = { 0 };
  
  // Initialize...
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"FTPEnable"];
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"HTTPEnable"];
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"HTTPSEnable"];
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"RTSEnable"];
  [proxyDict setObject: [NSNumber numberWithBool: NO] forKey: @"SOCKSEnable"];
  
  // FIXME: add the ExceptionsList array section...
  [proxyDict setObject: [NSArray array] forKey: @"ExceptionsList"];
  
  // FIXME: add the per interface __SCOPED__ dictionary section in the code
  // section(s) below...
  NSDictionary *scopedProxies = @{ @"ExceptionsList" : [NSArray array],
                                   @"FTPEnable"      : [NSNumber numberWithBool: NO],
                                   @"HTTPEnable"     : [NSNumber numberWithBool: NO],
                                   @"HTTPSEnable"    : [NSNumber numberWithBool: NO],
                                   @"RTSEnable"      : [NSNumber numberWithBool: NO],
                                   @"SOCKSEnable"    : [NSNumber numberWithBool: NO] };
  [proxyDict setObject: scopedProxies forKey: @"__SCOPED__"];

  if (ResolveProxy(forUrl, &proxyInfo) == FALSE)
    {
      NSWarnMLog(@"error retrieving windows proxy information - error code: %ld", (long)GetLastError());
    }
  else
    {
      NSWarnMLog(@"fAutoDetect: %ld hosts: %S bypass %S",
                 (long)proxyInfo.fAutoDetect, proxyInfo.lpszProxy, proxyInfo.lpszProxyBypass);
      
      // Proxy host(s) list...
      if (NULL != proxyInfo.lpszProxy)
        {
          NSString            *host = nil;
          NSNumber            *port = nil;
          NSString            *string = AUTORELEASE([[NSString alloc] initWithBytes: proxyInfo.lpszProxy
                                                                             length: wcslen(proxyInfo.lpszProxy)*sizeof(wchar_t)
                                                                           encoding: NSUTF16StringEncoding]);
          
          // Multiple components setup???
          if ([string containsString: @";"] || [string containsString: @"="])
            {
              // Split the components using ';'...
              NSArray   *components = [string componentsSeparatedByString: @";"];
              NSString  *proxy      = nil;
              
              // Find the SOCKS proxy setting...
              for (proxy in components)
                {
                  if ([[proxy lowercaseString] containsString: @"socks="])
                    {
                      // SOCKS available...
                      NSInteger  index      = [proxy rangeOfString: @"="].location + 1;
                      NSArray   *socksProxy = [[proxy substringFromIndex: index] componentsSeparatedByString: @":"];
                      if (0 == [socksProxy count])
                        {
                          NSWarnMLog(@"error processing SOCKS proxy info for (%@)", proxy);
                        }
                      else
                        {
                          host              = [socksProxy objectAtIndex: 0];
                          NSInteger portnum = ([socksProxy count] > 1 ? [[socksProxy objectAtIndex: 1] integerValue] : 8080);
                          port              = [NSNumber numberWithInteger: portnum];
                          NSWarnMLog(@"SOCKS - host: %@ port: %@", host, port);

                          // Setup the proxy dictionary information and...
                          [proxyDict setObject: host forKey: NSStreamSOCKSProxyHostKey];
                          [proxyDict setObject: port forKey: NSStreamSOCKSProxyPortKey];
                          // This key is NOT in the returned dictionary on Cocoa...
                          [proxyDict setObject: NSStreamSOCKSProxyVersion5 forKey: NSStreamSOCKSProxyVersionKey];
                          [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"SOCKSEnable"];
                        }
                    }
                  else if ([[proxy lowercaseString] containsString: @"http="])
                    {
                      // HTTP available...
                      NSInteger  index      = [proxy rangeOfString: @"="].location + 1;
                      NSArray   *socksProxy = [[proxy substringFromIndex: index] componentsSeparatedByString: @":"];
                      if (0 == [socksProxy count])
                        {
                          NSWarnMLog(@"error processing HTTP proxy info for (%@)", proxy);
                        }
                      else
                        {
                          host              = [socksProxy objectAtIndex: 0];
                          NSInteger portnum = ([socksProxy count] > 1 ? [[socksProxy objectAtIndex: 1] integerValue] : 8080);
                          port              = [NSNumber numberWithInteger: portnum];
                          NSWarnMLog(@"HTTP - host: %@ port: %@", host, port);

                          // Setup the proxy dictionary information and...
                          [proxyDict setObject: host forKey: kCFStreamPropertyHTTPProxyHost];
                          [proxyDict setObject: port forKey: kCFStreamPropertyHTTPProxyPort];
                          [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"HTTPEnable"];
                        }
                    }
                  else if ([[proxy lowercaseString] containsString: @"https="])
                    {
                      // HTTPS available...
                      NSInteger  index      = [proxy rangeOfString: @"="].location + 1;
                      NSArray   *socksProxy = [[proxy substringFromIndex: index] componentsSeparatedByString: @":"];
                      if (0 == [socksProxy count])
                        {
                          NSWarnMLog(@"error processing HTTPS proxy info for (%@)", proxy);
                        }
                      else
                        {
                          host              = [socksProxy objectAtIndex: 0];
                          NSInteger portnum = ([socksProxy count] > 1 ? [[socksProxy objectAtIndex: 1] integerValue] : 8080);
                          port              = [NSNumber numberWithInteger: portnum];
                          NSWarnMLog(@"HTTPS - host: %@ port: %@", host, port);

                          // Setup the proxy dictionary information and...
                          [proxyDict setObject: host forKey: kCFStreamPropertyHTTPSProxyHost];
                          [proxyDict setObject: port forKey: kCFStreamPropertyHTTPSProxyPort];
                          [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"HTTPSEnable"];
                        }
                    }
                }
            }
          else
            {
              // Split the components using ':'...
              NSArray   *components = [string componentsSeparatedByString: @":"];
              NSDebugFLLog(@"NSStream", @"component(s): %@", components);
              if (0 != [components count])
                {
                  host              = [components objectAtIndex: 0];
                  NSInteger portnum = ([components count] > 1 ? [[components objectAtIndex: 1] integerValue] : 8080);
                  port              = [NSNumber numberWithInteger: portnum];
                  NSWarnMLog(@"host: %@ port: %@", host, port);

                  // Setup the proxy dictionary information...
                  [proxyDict setObject: host forKey: NSStreamSOCKSProxyHostKey];
                  [proxyDict setObject: port forKey: NSStreamSOCKSProxyPortKey];
                  [proxyDict setObject: NSStreamSOCKSProxyVersion5 forKey: NSStreamSOCKSProxyVersionKey];
                  [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"SOCKSEnable"];

                  [proxyDict setObject: host forKey: kCFStreamPropertyHTTPProxyHost];
                  [proxyDict setObject: port forKey: kCFStreamPropertyHTTPProxyPort];
                  [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"HTTPEnable"];
                  
                  [proxyDict setObject: host forKey: kCFStreamPropertyHTTPSProxyHost];
                  [proxyDict setObject: port forKey: kCFStreamPropertyHTTPSProxyPort];
                  [proxyDict setObject: [NSNumber numberWithBool: YES] forKey: @"HTTPSEnable"];
                }
            }
        }
    }
  
  // Proxy exception(s) list...
  if (NULL != proxyInfo.lpszProxyBypass)
    {
      NSString *bypass  = AUTORELEASE([[NSString alloc] initWithBytes: proxyInfo.lpszProxyBypass
                                                               length: wcslen(proxyInfo.lpszProxyBypass)*sizeof(wchar_t)
                                                             encoding: NSUTF16StringEncoding]);
      NSWarnMLog(@"bypass %@", bypass);
    }
  NSWarnMLog(@"proxies: %@", proxyDict);
  
  return [proxyDict copy];
}

/**
 * The concrete subclass of NSInputStream that reads from a file
 */
@interface GSFileInputStream : GSInputStream
{
@private
  NSString *_path;
}
@end

@class GSPipeOutputStream;

/**
 * The concrete subclass of NSInputStream that reads from a pipe
 */
@interface GSPipeInputStream : GSInputStream
{
  HANDLE    handle;
  OVERLAPPED    ov;
  uint8_t    data[BUFFERSIZE];
  unsigned    offset;    // Read pointer within buffer
  unsigned    length;    // Amount of data in buffer
  unsigned    want;    // Amount of data we want to read.
  DWORD        size;    // Number of bytes returned by read.
  GSPipeOutputStream *_sibling;
  BOOL        hadEOF;
}
- (NSStreamStatus) _check;
- (void) _queue;
- (void) _setHandle: (HANDLE)h;
- (void) _setSibling: (GSPipeOutputStream*)s;
@end

/**
 * The concrete subclass of NSOutputStream that writes to a file
 */
@interface GSFileOutputStream : GSOutputStream
{
@private
  NSString *_path;
  BOOL _shouldAppend;
}
@end

/**
 * The concrete subclass of NSOutputStream that reads from a pipe
 */
@interface GSPipeOutputStream : GSOutputStream
{
  HANDLE    handle;
  OVERLAPPED    ov;
  uint8_t    data[BUFFERSIZE];
  unsigned    offset;
  unsigned    want;
  DWORD        size;
  GSPipeInputStream *_sibling;
  BOOL        closing;
  BOOL        writtenEOF;
}
- (NSStreamStatus) _check;
- (void) _queue;
- (void) _setHandle: (HANDLE)h;
- (void) _setSibling: (GSPipeInputStream*)s;
@end


/**
 * The concrete subclass of NSServerStream that accepts named pipe connection
 */
@interface GSLocalServerStream : GSAbstractServerStream
{
  NSString    *path;
  HANDLE    handle;
  OVERLAPPED    ov;
}
@end

@implementation GSFileInputStream

- (void) close
{
  if (_loopID != (void*)INVALID_HANDLE_VALUE)
    {
      if (CloseHandle((HANDLE)_loopID) == 0)
    {
          [self _recordError];
    }
    }
  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  RELEASE(_path);
  [super dealloc];
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len
{
  return NO;
}

- (BOOL) hasBytesAvailable
{
  if ([self _isOpened] && [self streamStatus] != NSStreamStatusAtEnd)
    return YES;
  return NO;
}

- (id) initWithFileAtPath: (NSString *)path
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
    }
  return self;
}

- (void) open
{
  HANDLE    h;

  h = (void*)CreateFileW((LPCWSTR)[_path fileSystemRepresentation],
                         GENERIC_READ,
                         FILE_SHARE_READ,
                         0,
                         OPEN_EXISTING,
                         0,
                         0);
  if (h == INVALID_HANDLE_VALUE)
    {
      [self _recordError];
      return;
    }
  [self _setLoopID: (void*)h];
  [super open];
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      DWORD offset = 0;

      if ([self _isOpened])
        offset = SetFilePointer((HANDLE)_loopID, 0, 0, FILE_CURRENT);
      return [NSNumber numberWithLong: (long)offset];
    }
  return [super propertyForKey: key];
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  DWORD readLen;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"zero byte length read requested"];
    }

  _events &= ~NSStreamEventHasBytesAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

  if (ReadFile((HANDLE)_loopID, buffer, len, &readLen, NULL) == 0)
    {
      [self _recordError];
      return -1;
    }
  else if (readLen == 0)
    {
      [self _setStatus: NSStreamStatusAtEnd];
    }
  return (NSInteger)readLen;
}


- (void) _dispatch
{
  BOOL av = [self hasBytesAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasBytesAvailable :
    NSStreamEventEndEncountered;
  NSStreamStatus myStatus = av ? NSStreamStatusOpen :
    NSStreamStatusAtEnd;
  
  [self _setStatus: myStatus];
  [self _sendEvent: myEvent];
}

@end

@implementation GSPipeInputStream

- (void) close
{
  length = offset = 0;
  if (_loopID != INVALID_HANDLE_VALUE)
    {
      CloseHandle((HANDLE)_loopID);
    }
  if (handle != INVALID_HANDLE_VALUE)
    {
      /* If we have an outstanding read in progess, we must cancel it
       * before closing the pipe.
       */
      if (want > 0)
    {
      want = 0;
      CancelIo(handle);
    }

      /* We can only close the pipe if there is no sibling using it.
       */
      if ([_sibling _isOpened] == NO)
    {
      if (DisconnectNamedPipe(handle) == 0)
        {
          if ((errno = GetLastError()) != ERROR_PIPE_NOT_CONNECTED)
        {
          [self _recordError];
        }
        }
      if (CloseHandle(handle) == 0)
        {
          [self _recordError];
        }
    }
      handle = INVALID_HANDLE_VALUE;
    }
  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;

}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [_sibling _setSibling: nil];
  _sibling = nil;
  [super dealloc];
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len
{
  if (offset < length)
    {
      *buffer  = data + offset;
      *len = length - offset;
    }
  return NO;
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      handle = INVALID_HANDLE_VALUE;
      _loopID = (void*)INVALID_HANDLE_VALUE;
    }
  return self;
}

- (void) open
{
  if (_loopID == (void*)INVALID_HANDLE_VALUE)
    {
      _loopID = (void*)CreateEvent(NULL, FALSE, FALSE, NULL);
    }
  [super open];
  [self _queue];
}

- (NSStreamStatus) _check
{
  // Must only be called when current status is NSStreamStatusReading.

  if (GetOverlappedResult(handle, &ov, &size, TRUE) == 0)
    {
      if ((errno = GetLastError()) == ERROR_HANDLE_EOF
    || errno == ERROR_PIPE_NOT_CONNECTED
    || errno == ERROR_BROKEN_PIPE)
    {
      /*
       * Got EOF, but we don't want to register it until a
       * -read:maxLength: is called.
       */
      offset = length = want = 0;
      [self _setStatus: NSStreamStatusOpen];
      hadEOF = YES;
    }
      else if (errno != ERROR_IO_PENDING)
    {
      /*
       * Got an error ... record it.
       */
      want = 0;
      [self _recordError];
    }
    }
  else if (size == 0)
    {
      length = want = 0;
      [self _setStatus: NSStreamStatusOpen];
      hadEOF = YES;
    }
  else
    {
      /*
       * Read completed and some data was read.
       */
      length = size;
      [self _setStatus: NSStreamStatusOpen];
    }
  return [self streamStatus];
}

- (void) _queue
{
  if (hadEOF == NO && [self streamStatus] == NSStreamStatusOpen)
    {
      int    rc;

      want = sizeof(data);
      ov.Offset = 0;
      ov.OffsetHigh = 0;
      ov.hEvent = (HANDLE)_loopID;
      rc = ReadFile(handle, data, want, &size, &ov);
      if (rc != 0)
    {
      // Read succeeded
      want = 0;
      length = size;
      if (length == 0)
        {
          hadEOF = YES;
        }
    }
      else if ((errno = GetLastError()) == ERROR_HANDLE_EOF
    || errno == ERROR_PIPE_NOT_CONNECTED
        || errno == ERROR_BROKEN_PIPE)
    {
      hadEOF = YES;
    }
      else if (errno != ERROR_IO_PENDING)
    {
          [self _recordError];
    }
      else
    {
      [self _setStatus: NSStreamStatusReading];
    }
    }
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  NSStreamStatus myStatus;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"zero byte length read requested"];
    }

  _events &= ~NSStreamEventHasBytesAvailable;

  myStatus = [self streamStatus];
  if (myStatus == NSStreamStatusReading)
    {
      myStatus = [self _check];
    }
  if (myStatus == NSStreamStatusClosed)
    {
      return 0;
    }

  if (offset == length)
    {
      if (myStatus == NSStreamStatusError)
    {
      return -1;    // Waiting for read.
    }
      if (myStatus == NSStreamStatusOpen)
    {
      /*
       * There is no buffered data and no read in progress,
       * so we must be at EOF.
       */
      [self _setStatus: NSStreamStatusAtEnd];
    }
      return 0;
    }

  /*
   * We already have data buffered ... return some or all of it.
   */
  if (len > (length - offset))
    {
      len = length - offset;
    }
  memcpy(buffer, data + offset, len);
  offset += len;
  if (offset == length)
    {
      length = 0;
      offset = 0;
      if (myStatus == NSStreamStatusOpen)
    {
          [self _queue];    // Queue another read
    }
    }
  return len;
}

- (void) _setHandle: (HANDLE)h
{
  handle = h;
}

- (void) _setSibling: (GSPipeOutputStream*)s
{
  _sibling = s;
}

- (void) _dispatch
{
  NSStreamEvent myEvent;
  NSStreamStatus oldStatus = [self streamStatus];
  NSStreamStatus myStatus = oldStatus;

  if (myStatus == NSStreamStatusReading
    || myStatus == NSStreamStatusOpening)
    {
      myStatus = [self _check];
    }

  if (myStatus == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else if (myStatus == NSStreamStatusError)
    {
      myEvent = NSStreamEventErrorOccurred;
    }
  else if (oldStatus == NSStreamStatusOpening)
    {
      myEvent = NSStreamEventOpenCompleted;
    }
  else
    {
      myEvent = NSStreamEventHasBytesAvailable;
    }

  [self _sendEvent: myEvent];
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  NSStreamStatus myStatus = [self streamStatus];

  if ([self _unhandledData] == YES || myStatus == NSStreamStatusError)
    {
      *trigger = NO;
      return NO;
    }
  *trigger = YES;
  if (myStatus == NSStreamStatusReading)
    {
      return YES;    // Need to wait for I/O
    }
  return NO;        // Need to signal for an event
}
@end


@implementation GSFileOutputStream

- (void) close
{
  if (_loopID != (void*)INVALID_HANDLE_VALUE)
    {
      if (CloseHandle((HANDLE)_loopID) == 0)
    {
          [self _recordError];
    }
    }
  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  RELEASE(_path);
  [super dealloc];
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  if ((self = [super init]) != nil)
    {
      ASSIGN(_path, path);
      _shouldAppend = shouldAppend;
    }
  return self;
}

- (void) open
{
  HANDLE    h;

  h = (void*)CreateFileW((LPCWSTR)[_path fileSystemRepresentation],
                         GENERIC_WRITE,
                         FILE_SHARE_WRITE,
                         0,
                         OPEN_ALWAYS,
                         0,
                         0);
  if (h == INVALID_HANDLE_VALUE)
    {
      [self _recordError];
      return;
    }
  else if (_shouldAppend == NO)
    {
      if (SetEndOfFile(h) == 0)    // Truncate to current file pointer (0)
    {
          [self _recordError];
          CloseHandle(h);
      return;
    }
    }
  [self _setLoopID: (void*)h];
  [super open];
}

- (id) propertyForKey: (NSString *)key
{
  if ([key isEqualToString: NSStreamFileCurrentOffsetKey])
    {
      DWORD offset = 0;

      if ([self _isOpened])
        offset = SetFilePointer((HANDLE)_loopID, 0, 0, FILE_CURRENT);
      return [NSNumber numberWithLong: (long)offset];
    }
  return [super propertyForKey: key];
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  DWORD writeLen;

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"zero byte length write requested"];
    }

  _events &= ~NSStreamEventHasSpaceAvailable;

  if ([self streamStatus] == NSStreamStatusClosed)
    {
      return 0;
    }

  if (_shouldAppend == YES)
    {
      SetFilePointer((HANDLE)_loopID, 0, 0, FILE_END);
    }
  if (WriteFile((HANDLE)_loopID, buffer, len, &writeLen, NULL) == 0)
    {
      [self _recordError];
      return -1;
    }
  return (NSInteger)writeLen;
}

- (void) _dispatch
{
  BOOL av = [self hasSpaceAvailable];
  NSStreamEvent myEvent = av ? NSStreamEventHasSpaceAvailable :
    NSStreamEventEndEncountered;

  [self _sendEvent: myEvent];
}

@end

@implementation GSPipeOutputStream

- (void) close
{
  /* If we have a write in progress, we must wait for it to complete,
   * so we just set a flag to close as soon as the write finishes.
   */
  if ([self streamStatus] == NSStreamStatusWriting)
    {
      closing = YES;
      return;
    }

  /* Where we have a sibling, we can't close the pipe handle, so the
   * only way to tell the remote end we have finished is to write a
   * zero length packet to it.
   */
  if ([_sibling _isOpened] == YES && writtenEOF == NO)
    {
      int    rc;

      writtenEOF = YES;
      ov.Offset = 0;
      ov.OffsetHigh = 0;
      ov.hEvent = (HANDLE)_loopID;
      size = 0;
      rc = WriteFile(handle, "", 0, &size, &ov);
      if (rc == 0)
    {
      if ((errno = GetLastError()) == ERROR_IO_PENDING)
        {
          [self _setStatus: NSStreamStatusWriting];
          return;        // Wait for write to complete
        }
      [self _recordError];    // Failed to write EOF
    }
    }

  offset = want = 0;
  if (_loopID != INVALID_HANDLE_VALUE)
    {
      CloseHandle((HANDLE)_loopID);
    }
  if (handle != INVALID_HANDLE_VALUE)
    {
      if ([_sibling _isOpened] == NO)
    {
      if (DisconnectNamedPipe(handle) == 0)
        {
          if ((errno = GetLastError()) != ERROR_PIPE_NOT_CONNECTED)
        {
          [self _recordError];
        }
          [self _recordError];
        }
      if (CloseHandle(handle) == 0)
        {
          [self _recordError];
        }
    }
      handle = INVALID_HANDLE_VALUE;
    }

  [super close];
  _loopID = (void*)INVALID_HANDLE_VALUE;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  [_sibling _setSibling: nil];
  _sibling = nil;
  [super dealloc];
}

- (id) init
{
  if ((self = [super init]) != nil)
    {
      handle = INVALID_HANDLE_VALUE;
      _loopID = (void*)INVALID_HANDLE_VALUE;
    }
  return self;
}

- (void) open
{
  if (_loopID == (void*)INVALID_HANDLE_VALUE)
    {
      _loopID = (void*)CreateEvent(NULL, FALSE, FALSE, NULL);
    }
  [super open];
}

- (void) _queue
{
  NSStreamStatus myStatus = [self streamStatus];

  if (myStatus == NSStreamStatusOpen)
    {
      while (offset < want)
    {
      int    rc;

      ov.Offset = 0;
      ov.OffsetHigh = 0;
      ov.hEvent = (HANDLE)_loopID;
      size = 0;
      rc = WriteFile(handle, data + offset, want - offset, &size, &ov);
      if (rc != 0)
        {
          offset += size;
          if (offset == want)
        {
          offset = want = 0;
        }
        }
      else if ((errno = GetLastError()) == ERROR_IO_PENDING)
        {
          [self _setStatus: NSStreamStatusWriting];
          break;
        }
      else
        {
          [self _recordError];
          break;
        }
    }
    }
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  NSStreamStatus myStatus = [self streamStatus];

  if (buffer == 0)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"null pointer for buffer"];
    }
  if (len == 0)
    {
      [NSException raise: NSInvalidArgumentException
          format: @"zero byte length write requested"];
    }

  _events &= ~NSStreamEventHasSpaceAvailable;

  if (myStatus == NSStreamStatusWriting)
    {
      myStatus = [self _check];
    }
  if (myStatus == NSStreamStatusClosed)
    {
      return 0;
    }

  if ((myStatus != NSStreamStatusOpen && myStatus != NSStreamStatusWriting))
    {
      return -1;
    }

  if (len > (sizeof(data) - offset))
    {
      len = sizeof(data) - offset;
    }
  if (len > 0)
    {
      memcpy(data + offset, buffer, len);
      want = offset + len;
      [self _queue];
    }
  return len;
}

- (NSStreamStatus) _check
{
  // Must only be called when current status is NSStreamStatusWriting.
  if (GetOverlappedResult(handle, &ov, &size, TRUE) == 0)
    {
      errno = GetLastError();
      if (errno != ERROR_IO_PENDING)
    {
          offset = 0;
          want = 0;
          [self _recordError];
    }
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      offset += size;
      if (offset < want)
    {
      [self _queue];
    }
      else
    {
      offset = want = 0;
    }
    }
  if (closing == YES && [self streamStatus] != NSStreamStatusWriting)
    {
      [self close];
    }
  return [self streamStatus];
}

- (void) _setHandle: (HANDLE)h
{
  handle = h;
}

- (void) _setSibling: (GSPipeInputStream*)s
{
  _sibling = s;
}

- (void) _dispatch
{
  NSStreamEvent myEvent;
  NSStreamStatus oldStatus = [self streamStatus];
  NSStreamStatus myStatus = oldStatus;

  if (myStatus == NSStreamStatusWriting
    || myStatus == NSStreamStatusOpening)
    {
      myStatus = [self _check];
    }

  if (myStatus == NSStreamStatusAtEnd)
    {
      myEvent = NSStreamEventEndEncountered;
    }
  else if (myStatus == NSStreamStatusError)
    {
      myEvent = NSStreamEventErrorOccurred;
    }
  else if (oldStatus == NSStreamStatusOpening)
    {
      myEvent = NSStreamEventOpenCompleted;
    }
  else
    {
      myEvent = NSStreamEventHasSpaceAvailable;
    }

  [self _sendEvent: myEvent];
}

- (BOOL) runLoopShouldBlock: (BOOL*)trigger
{
  NSStreamStatus myStatus = [self streamStatus];

  if ([self _unhandledData] == YES || myStatus == NSStreamStatusError)
    {
      *trigger = NO;
      return NO;
    }
  *trigger = YES;
  if (myStatus == NSStreamStatusWriting)
    {
      return YES;
    }
  return NO;
}
@end

@implementation NSStream

+ (void) getStreamsToHost: (NSHost *)host
                     port: (NSInteger)port
              inputStream: (NSInputStream **)inputStream
             outputStream: (NSOutputStream **)outputStream
{
  NSString *address = host ? (id)[host address] : (id)@"127.0.0.1";
  GSSocketStream *ins = nil;
  GSSocketStream *outs = nil;
  int sock;

  ins = (GSSocketStream*)AUTORELEASE([[GSInetInputStream alloc] initToAddr: address port: port]);
  outs = (GSSocketStream*)AUTORELEASE([[GSInetOutputStream alloc] initToAddr: address port: port]);
  
#if 0 // TESTPLANT-MAL-03132018: This bypasses the GSSOCKS processing...
  sock = socket(PF_INET, SOCK_STREAM, 0);

  /*
   * Windows only permits a single event to be associated with a socket
   * at any time, but the runloop system only allows an event handle to
   * be added to the loop once, and we have two streams.
   * So we create two events, one for each stream, so that we can have
   * both streams scheduled in the run loop, but we make sure that the
   * _dispatch method in each stream actually handles things for both
   * streams so that whichever stream gets signalled, the correct
   * actions are taken.
   */
  NSAssert(sock != INVALID_SOCKET, @"Cannot open socket");
  [ins _setSock: sock];
  [outs _setSock: sock];
#endif
  
  // Setup proxy information...
  NSString * hostName = [[host name] retain];
  NSDictionary *proxyDict = SCDynamicStoreCopyProxies(NULL, hostName);
  [hostName release];

  // and if available...
  if ([proxyDict count])
    {
      // store in the streams...
      if ([[proxyDict objectForKey: @"SOCKSEnable"] boolValue])
        {
          NSDictionary *proxy = @{ NSStreamSOCKSProxyHostKey : [proxyDict objectForKey: NSStreamSOCKSProxyHostKey],
                                   NSStreamSOCKSProxyPortKey : [proxyDict objectForKey: NSStreamSOCKSProxyPortKey]};
          
          [ins setProperty: proxy forKey: NSStreamSOCKSProxyConfigurationKey];
          [outs setProperty: proxy forKey: NSStreamSOCKSProxyConfigurationKey];
        }
      if ([[proxyDict objectForKey: @"HTTPEnable"] boolValue])
        {
          NSDictionary *proxy = @{ kCFStreamPropertyHTTPProxyHost : [proxyDict objectForKey: kCFStreamPropertyHTTPProxyHost],
                                   kCFStreamPropertyHTTPProxyPort : [proxyDict objectForKey: kCFStreamPropertyHTTPProxyPort]};
          
          [ins setProperty: proxy forKey: kCFStreamPropertyHTTPProxy];
          [outs setProperty: proxy forKey: kCFStreamPropertyHTTPProxy];
        }
      if ([[proxyDict objectForKey: @"HTTPSEnable"] boolValue])
        {
          [ins setProperty: [proxyDict objectForKey: kCFStreamPropertyHTTPSProxyHost] forKey: kCFStreamPropertyHTTPSProxyHost];
          [ins setProperty: [proxyDict objectForKey: kCFStreamPropertyHTTPSProxyHost] forKey: kCFStreamPropertyHTTPSProxyHost];
          [outs setProperty: [proxyDict objectForKey: kCFStreamPropertyHTTPSProxyPort] forKey: kCFStreamPropertyHTTPSProxyPort];
          [outs setProperty: [proxyDict objectForKey: kCFStreamPropertyHTTPSProxyPort] forKey: kCFStreamPropertyHTTPSProxyPort];
        }
    }
  
  // SCDynamicStoreCopyProxies creates a copy so we need to release...
  [proxyDict release];
  
  if (inputStream)
    {
      [ins _setSibling: outs];
      *inputStream = (NSInputStream*)ins;
    }
  if (outputStream)
    {
      [outs _setSibling: ins];
      *outputStream = (NSOutputStream*)outs;
    }
  return;
}

+ (void) getLocalStreamsToPath: (NSString *)path
                   inputStream: (NSInputStream **)inputStream
                  outputStream: (NSOutputStream **)outputStream
{
  const unichar *name;
  GSPipeInputStream *ins = nil;
  GSPipeOutputStream *outs = nil;
  SECURITY_ATTRIBUTES saAttr;
  HANDLE handle;

  if ([path length] == 0)
    {
      NSDebugMLog(@"address nil or empty");
      goto done;
    }
  if ([path length] > 240)
    {
      NSDebugMLog(@"address (%@) too long", path);
      goto done;
    }
  if ([path rangeOfString: @"\\"].length > 0)
    {
      NSDebugMLog(@"illegal backslash in (%@)", path);
      goto done;
    }
  if ([path rangeOfString: @"/"].length > 0)
    {
      NSDebugMLog(@"illegal slash in (%@)", path);
      goto done;
    }

  /*
   * We allocate a new within the local pipe area
   */
  name = (const unichar *)[[@"\\\\.\\pipe\\GSLocal" stringByAppendingString: path]
    fileSystemRepresentation];

  saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle = FALSE;
  saAttr.lpSecurityDescriptor = NULL;

  handle = CreateFileW(name,
                       GENERIC_WRITE|GENERIC_READ,
                       0,
                       &saAttr,
                       OPEN_EXISTING,
                       FILE_FLAG_OVERLAPPED,
                       NULL);
  if (handle == INVALID_HANDLE_VALUE)
    {
      [NSException raise: NSInternalInconsistencyException
          format: @"Unable to open named pipe '%@'... %@",
    path, [NSError _last]];
    }

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSPipeInputStream new]);
  outs = AUTORELEASE([GSPipeOutputStream new]);

  [ins _setHandle: handle];
  [ins _setSibling: outs];
  [outs _setHandle: handle];
  [outs _setSibling: ins];

done:
  if (inputStream)
    {
      *inputStream = ins;
    }
  if (outputStream)
    {
      *outputStream = outs;
    }
}

+ (void) pipeWithInputStream: (NSInputStream **)inputStream
                outputStream: (NSOutputStream **)outputStream
{
  const unichar *name;
  GSPipeInputStream *ins = nil;
  GSPipeOutputStream *outs = nil;
  SECURITY_ATTRIBUTES saAttr;
  HANDLE readh;
  HANDLE writeh;
  HANDLE event;
  OVERLAPPED ov;
  int rc;

  saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle = FALSE;
  saAttr.lpSecurityDescriptor = NULL;

  /*
   * We have to use a named pipe since windows anonymous pipes do not
   * support asynchronous I/O!
   * We allocate a name known to be unique.
   */
  name = (const unichar *)[[@"\\\\.\\pipe\\" stringByAppendingString:
    [[NSProcessInfo processInfo] globallyUniqueString]]
    fileSystemRepresentation];
  readh = CreateNamedPipeW(name,
    PIPE_ACCESS_INBOUND | FILE_FLAG_OVERLAPPED,
    PIPE_TYPE_BYTE,
    1,
    BUFSIZ*64,
    BUFSIZ*64,
    100000,
    &saAttr);

  NSAssert(readh != INVALID_HANDLE_VALUE, @"Cannot create pipe");

  // Start async connect
  event = CreateEvent(NULL, NO, NO, NULL);
  ov.Offset = 0;
  ov.OffsetHigh = 0;
  ov.hEvent = event;
  ConnectNamedPipe(readh, &ov);

  writeh = CreateFileW(name,
                       GENERIC_WRITE,
                       0,
                       &saAttr,
                       OPEN_EXISTING,
                       FILE_FLAG_OVERLAPPED,
                       NULL);
  if (writeh == INVALID_HANDLE_VALUE)
    {
      CloseHandle(event);
      CloseHandle(readh);
      [NSException raise: NSInternalInconsistencyException
          format: @"Unable to create/open write pipe"];
    }

  rc = WaitForSingleObject(event, 10);
  CloseHandle(event);

  if (rc != WAIT_OBJECT_0)
    {
      CloseHandle(readh);
      CloseHandle(writeh);
      [NSException raise: NSInternalInconsistencyException
          format: @"Unable to create/open read pipe"];
    }

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSPipeInputStream new]);
  outs = AUTORELEASE([GSPipeOutputStream new]);

  [ins _setHandle: readh];
  [outs _setHandle: writeh];
  if (inputStream)
    *inputStream = ins;
  if (outputStream)
    *outputStream = outs;
}

- (void) close
{
  [self subclassResponsibility: _cmd];
}

- (void) open
{
  [self subclassResponsibility: _cmd];
}

- (void) setDelegate: (id)delegate
{
  [self subclassResponsibility: _cmd];
}

- (id) delegate
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (BOOL) setProperty: (id)property forKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) propertyForKey: (NSString *)key
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (void) scheduleInRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode
{
  [self subclassResponsibility: _cmd];
}

- (void) removeFromRunLoop: (NSRunLoop *)aRunLoop forMode: (NSString *)mode;
{
  [self subclassResponsibility: _cmd];
}

- (NSError *) streamError
{
  [self subclassResponsibility: _cmd];
  return nil;
}

- (NSStreamStatus) streamStatus
{
  [self subclassResponsibility: _cmd];
  return 0;
}

@end

@implementation NSInputStream

+ (id) inputStreamWithData: (NSData *)data
{
  return AUTORELEASE([[GSDataInputStream alloc] initWithData: data]);
}

+ (id) inputStreamWithFileAtPath: (NSString *)path
{
  return AUTORELEASE([[GSFileInputStream alloc] initWithFileAtPath: path]);
}

+ (id)inputStreamWithURL:(NSURL *)url
{
  return [self inputStreamWithFileAtPath:[url path]];
}

- (BOOL) getBuffer: (uint8_t **)buffer length: (NSUInteger *)len
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (BOOL) hasBytesAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) initWithData: (NSData *)data
{
  DESTROY(self);
  return [[GSDataInputStream alloc] initWithData: data];
}

- (id) initWithFileAtPath: (NSString *)path
{
  DESTROY(self);
  return [[GSFileInputStream alloc] initWithFileAtPath: path];
}

- (NSInteger) read: (uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

@end

@implementation NSOutputStream

+ (id) outputStreamToMemory
{
  return AUTORELEASE([[GSDataOutputStream alloc] init]);
}

+ (id) outputStreamToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
  return AUTORELEASE([[GSBufferOutputStream alloc]
    initToBuffer: buffer capacity: capacity]);
}

+ (id) outputStreamToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  return AUTORELEASE([[GSFileOutputStream alloc]
    initToFileAtPath: path append: shouldAppend]);
}

- (BOOL) hasSpaceAvailable
{
  [self subclassResponsibility: _cmd];
  return NO;
}

- (id) initToBuffer: (uint8_t *)buffer capacity: (NSUInteger)capacity
{
  DESTROY(self);
  return [[GSBufferOutputStream alloc] initToBuffer: buffer capacity: capacity];
}

- (id) initToFileAtPath: (NSString *)path append: (BOOL)shouldAppend
{
  DESTROY(self);
  return [[GSFileOutputStream alloc] initToFileAtPath: path
                           append: shouldAppend];
}

- (id) initToMemory
{
  DESTROY(self);
  return [[GSDataOutputStream alloc] init];
}

- (NSInteger) write: (const uint8_t *)buffer maxLength: (NSUInteger)len
{
  [self subclassResponsibility: _cmd];
  return -1;
}

@end


@implementation GSLocalServerStream

- (id) init
{
  DESTROY(self);
  return self;
}

- (id) initToAddr: (NSString*)addr
{
  if ([addr length] == 0)
    {
      NSDebugMLog(@"address nil or empty");
      DESTROY(self);
    }
  if ([addr length] > 246)
    {
      NSDebugMLog(@"address (%@) too long", addr);
      DESTROY(self);
    }
  if ([addr rangeOfString: @"\\"].length > 0)
    {
      NSDebugMLog(@"illegal backslash in (%@)", addr);
      DESTROY(self);
    }
  if ([addr rangeOfString: @"/"].length > 0)
    {
      NSDebugMLog(@"illegal slash in (%@)", addr);
      DESTROY(self);
    }

  if ((self = [super init]) != nil)
    {
      path = RETAIN([@"\\\\.\\pipe\\GSLocal" stringByAppendingString: addr]);
      _loopID = INVALID_HANDLE_VALUE;
      handle = INVALID_HANDLE_VALUE;
    }
  return self;
}

- (void) dealloc
{
  if ([self _isOpened])
    {
      [self close];
    }
  RELEASE(path);
  [super dealloc];
}

- (void) open
{
  SECURITY_ATTRIBUTES saAttr;
  BOOL alreadyConnected = NO;

  NSAssert(handle == INVALID_HANDLE_VALUE, NSInternalInconsistencyException);

  saAttr.nLength = sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle = FALSE;
  saAttr.lpSecurityDescriptor = NULL;

  handle = CreateNamedPipeW((LPCWSTR)[path fileSystemRepresentation],
                            PIPE_ACCESS_DUPLEX | FILE_FLAG_OVERLAPPED,
                            PIPE_TYPE_MESSAGE,
                            PIPE_UNLIMITED_INSTANCES,
                            BUFSIZ*64,
                            BUFSIZ*64,
                            100000,
                            &saAttr);
  if (handle == INVALID_HANDLE_VALUE)
    {
      [self _recordError];
      return;
    }

  if ([self _loopID] == INVALID_HANDLE_VALUE)
    {
      /* No existing event to use ..,. create a new one.
       */
      [self _setLoopID: CreateEvent(NULL, NO, NO, NULL)];
    }
  ov.Offset = 0;
  ov.OffsetHigh = 0;
  ov.hEvent = [self _loopID];
  if (ConnectNamedPipe(handle, &ov) == 0)
    {
      errno = GetLastError();
      if (errno == ERROR_PIPE_CONNECTED)
    {
      alreadyConnected = YES;
    }
      else if (errno != ERROR_IO_PENDING)
    {
      [self _recordError];
      return;
    }
    }

  if ([self _isOpened] == NO)
    {
      [super open];
    }
  if (alreadyConnected == YES)
    {
      [self _setStatus: NSStreamStatusOpen];
    }
}

- (void) close
{
  if (_loopID != INVALID_HANDLE_VALUE)
    {
      CloseHandle((HANDLE)_loopID);
    }
  if (handle != INVALID_HANDLE_VALUE)
    {
      CancelIo(handle);
      if (CloseHandle(handle) == 0)
    {
      [self _recordError];
    }
      handle = INVALID_HANDLE_VALUE;
    }
  [super close];
  _loopID = INVALID_HANDLE_VALUE;
}

- (void) acceptWithInputStream: (NSInputStream **)inputStream
                  outputStream: (NSOutputStream **)outputStream
{
  GSPipeInputStream *ins = nil;
  GSPipeOutputStream *outs = nil;

  _events &= ~NSStreamEventHasBytesAvailable;

  // the type of the stream does not matter, since we are only using the fd
  ins = AUTORELEASE([GSPipeInputStream new]);
  outs = AUTORELEASE([GSPipeOutputStream new]);

  [ins _setHandle: handle];
  [outs _setHandle: handle];

  handle = INVALID_HANDLE_VALUE;
  [self open];    // Re-open to accept more

  if (inputStream)
    {
      [ins _setSibling: outs];
      *inputStream = ins;
    }
  if (outputStream)
    {
      [outs _setSibling: ins];
      *outputStream = outs;
    }
}

- (void) _dispatch
{
  DWORD        size;

  if (GetOverlappedResult(handle, &ov, &size, TRUE) == 0)
    {
      [self _recordError];
      [self _sendEvent: NSStreamEventErrorOccurred];
    }
  else
    {
      [self _setStatus: NSStreamStatusOpen];
      [self _sendEvent: NSStreamEventHasBytesAvailable];
    }
}

@end

