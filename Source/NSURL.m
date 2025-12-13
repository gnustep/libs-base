/** NSURL.m - Class NSURL
   Copyright (C) 1999 Free Software Foundation, Inc.

   Written by: 	Manuel Guesdon <mguesdon@sbuilders.com>
   Date: 	Jan 1999

   Rewrite by: 	Richard Frith-Macdonald <rfm@gnu.org>
   Date: 	Jun 2002

   Add'l by:    Gregory John Casamento <greg.casamento@gmail.com>  
   Date: 	Jan 2020

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

   <title>NSURL class reference</title>
*/

/*
Note from Manuel Guesdon:
* I've made some test to compare apple NSURL results
and GNUstep NSURL results but as there this class is not very documented, some
function may be incorrect
* I've put 2 functions to make tests. You can add your own tests
* Some functions are not implemented
*/

#if defined(_WIN32)
#ifdef HAVE_WS2TCPIP_H
#include <ws2tcpip.h>
#endif // HAVE_WS2TCPIP_H
#if !defined(HAVE_INET_NTOP)
extern const char* WSAAPI inet_ntop(int, const void *, char *, size_t);
#endif
#if !defined(HAVE_INET_NTOP)
extern int WSAAPI inet_pton(int , const char *, void *);
#endif
#else /* !_WIN32 */
#include <netdb.h>
#include <sys/param.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#endif /* !_WIN32 */



#define	GS_NSURLQueryItem_IVARS \
  NSString *_name; \
  NSString *_value; 

#define	GS_NSURLComponents_IVARS \
  NSString *_string; \
  NSString *_fragment; \
  NSString *_host; \
  NSString *_password; \
  NSString *_path; \
  NSNumber *_port; \
  NSArray  *_queryItems; \
  NSString *_scheme; \
  NSString *_user; \
  NSRange   _rangeOfFragment; \
  NSRange   _rangeOfHost; \
  NSRange   _rangeOfPassword; \
  NSRange   _rangeOfPath; \
  NSRange   _rangeOfPort; \
  NSRange   _rangeOfQuery; \
  NSRange   _rangeOfQueryItems; \
  NSRange   _rangeOfScheme; \
  NSRange   _rangeOfUser; \
  BOOL      _dirty;

#import "common.h"
#define	EXPOSE_NSURL_IVARS	1
#import "Foundation/NSArray.h"
#import "Foundation/NSAutoreleasePool.h"
#import "Foundation/NSCoder.h"
#import "Foundation/NSData.h"
#import "Foundation/NSDictionary.h"
#import "Foundation/NSError.h"
#import "Foundation/NSException.h"
#import "Foundation/NSFileManager.h"
#import "Foundation/NSLock.h"
#import "Foundation/NSMapTable.h"
#import "Foundation/NSPortCoder.h"
#import "Foundation/NSRunLoop.h"
#import "Foundation/NSURL.h"
#import "Foundation/NSURLHandle.h"
#import "Foundation/NSValue.h"
#import "Foundation/NSCharacterSet.h"
#import "Foundation/NSString.h"

#import "GNUstepBase/NSURL+GNUstepBase.h"

@interface	NSURL (GSPrivate)
- (NSURL*) _URLBySettingPath: (NSString*)newPath; 
@end

@implementation	NSURL (GSPrivate)
- (NSURL*) _URLBySettingPath: (NSString*)newPath 
{
  NSAssert([newPath isKindOfClass: [NSString class]],
    NSInvalidArgumentException);
  if ([self isFileURL]) 
    {
      return [NSURL fileURLWithPath: newPath];
    }
  else
    {
      NSURL	*u;
      NSString	*params;
      NSRange	r = [newPath rangeOfString: @";"];

      if (r.length > 0)
	{
	  params = [newPath substringFromIndex: NSMaxRange(r)];
	  newPath = [newPath substringToIndex: r.location];
	}
      else
	{
	  params = [self parameterString];
	}

      u = [[NSURL alloc] initWithScheme: [self scheme]
				   user: [self user]
			       password: [self password]
				   host: [self host]
				   port: [self port]
			       fullPath: newPath
			parameterString: params
				  query: [self query]
			       fragment: [self fragment]];
      return [u autorelease];
    }
}
@end

@implementation	NSURL (Private)
/* This method should return the full (and correctly escaped) ASCII string
 * of the path of an http/https request, as it should appear in the first
 * line of the request sent over the wire.
 * The withoutQuery option may be used to return a truncated request which
 * does not include the query string part, so it can be used for digest
 * authentication where the path is needed to establish the authentication
 * domain.
 * Neither of these include the fragment part of the URL, as that is only
 * for use within the browser and never sent to the server.
 */
- (NSString*) _requestPath: (BOOL)withoutQuery
{
  NSString	*params = [self parameterString];
  NSString	*path = [self pathWithEscapes];

  if ([path length] == 0)
    {
      path = @"/";
    }
  if ([params length])
    {
      path = [path stringByAppendingFormat: @";%@", params];
    }
  if (NO == withoutQuery)
    {
      NSString	*query = [self query];

      if ([query length])
	{
	  path = [path stringByAppendingFormat: @"?%@", query];
	}
    }
  return path;
}
@end

/*
 * Structure describing a URL.
 * All the char* fields may be NULL pointers, except path, which
 * is *always* non-null (though it may be an empty string).
 * The sgtored values are percent escaped and must be unescaped when used
 * to return an unescaped part of the URL.
 */
typedef struct {
  id	absolute;		// Cache absolute string or nil
  char	*scheme;
  char	*user;
  char	*password;
  char	*host;
  char	*port;
  char	*path;			// May never be NULL
  char	*parameters;
  char	*query;
  char	*fragment;
  BOOL	pathIsAbsolute;
  BOOL	emptyPath;
  BOOL	hasNoPath;
  BOOL	isGeneric;
  BOOL	isFile;
} parsedURL;

#define	myData ((parsedURL*)(self->_data))
#define	baseData ((self->_baseURL == 0)?0:((parsedURL*)(self->_baseURL->_data)))

static NSLock	*clientsLock = nil;

/*
 * Local utility functions.
 */
static char *buildURL(parsedURL *base, parsedURL *rel, BOOL standardize);
static id clientForHandle(void *data, NSURLHandle *hdl);
static char *findUp(char *str);
static char *unescape(const char *from, char * to);

static const char	*rfc3986ok = "!#$&'()*+,/:;=?@[]ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz 0123456789-_~.";
static NSCharacterSet	*okCharSet = nil;

/**
 * Build an absolute URL as a C string
 */
static char *buildURL(parsedURL *base, parsedURL *rel, BOOL standardize)
{
  const char	*rpath;
  char		*buf;
  char		*ptr;
  char		*tmp;
  int		l;
  int		e;
  unsigned int	len = 1;

  if (NO == rel->hasNoPath)
    {
      len += 1;                         // trailing '/' to be added
    }
  if (rel->scheme != 0)
    {
      len += strlen(rel->scheme) + 3;	// scheme://
    }
  else if (YES == rel->isGeneric)
    {
      len += 2;                         // need '//' even if no scheme
    }
  if (rel->user != 0)
    {
      len += strlen(rel->user) + 1;	// user...@
    }
  if (rel->password != 0)
    {
      len += strlen(rel->password) + 1;	// :password
    }
  if (rel->host != 0)
    {
      len += strlen(rel->host) + 1;	// host.../
    }
  if (rel->port != 0)
    {
      len += strlen(rel->port) + 1;	// :port
    }
  if (rel->path != 0)
    {
      rpath = rel->path;
    }
  else
    {
      rpath = "";
    }
  len += strlen(rpath) + 1;	// path
  if (base != 0 && base->path != 0)
    {
      len += strlen(base->path) + 1;	// path
    }
  if (rel->parameters != 0)
    {
      len += strlen(rel->parameters) + 1;	// ;parameters
    }
  if (rel->query != 0)
    {
      len += strlen(rel->query) + 1;		// ?query
    }
  if (rel->fragment != 0)
    {
      len += strlen(rel->fragment) + 1;		// #fragment
    }

  ptr = buf = (char*)NSZoneMalloc(NSDefaultMallocZone(), len);

  if (rel->scheme != 0)
    {
      l = strlen(rel->scheme);
      memcpy(ptr, rel->scheme, l);
      ptr += l;
      *ptr++ = ':';
    }
  if (rel->isGeneric == YES
    || rel->user != 0 || rel->password != 0 || rel->host != 0 || rel->port != 0)
    {
      *ptr++ = '/';
      *ptr++ = '/';
      if (rel->user != 0 || rel->password != 0)
	{
	  if (rel->user != 0)
	    {
	      l = strlen(rel->user);
	      memcpy(ptr, rel->user, l);
	      ptr += l;
	    }
	  if (rel->password != 0)
	    {
	      *ptr++ = ':';
	      l = strlen(rel->password);
	      memcpy(ptr, rel->password, l);
	      ptr += l;
	    }
	  if (rel->host != 0 || rel->port != 0)
	    {
	      *ptr++ = '@';
	    }
	}
      if (rel->host != 0)
	{
	  l = strlen(rel->host);
	  memcpy(ptr, rel->host, l);
	  ptr += l;
	}
      if (rel->port != 0)
	{
	  *ptr++ = ':';
	  l = strlen(rel->port);
	  memcpy(ptr, rel->port, l);
	  ptr += l;
	}
    }

  /*
   * Now build path.
   */

  tmp = ptr;
  if (rel->pathIsAbsolute == YES)
    {
      if (rel->hasNoPath == NO)
	{
	  *tmp++ = '/';
	}
      l = strlen(rpath);
      memcpy(tmp, rpath, l);
      tmp += l;
    }
  else if (base == 0)
    {
      l = strlen(rpath);
      memcpy(tmp, rpath, l);
      tmp += l;
    }
  else if (rpath[0] == 0)
    {
      if (base->hasNoPath == NO)
	{
	  *tmp++ = '/';
	}
      if (base->path)
	{
	  l = strlen(base->path);
	  memcpy(tmp, base->path, l);
	  tmp += l;
	}
    }
  else
    {
      char	*start = base->path;

      if (start != 0)
        {
          char	*end = strrchr(start, '/');

          if (end != 0)
            {
              *tmp++ = '/';
              memcpy(tmp, start, end - start);
              tmp += (end - start);
            }
        }
      *tmp++ = '/';
      l = strlen(rpath);
      memcpy(tmp, rpath, l);
      tmp += l;
    }
  *tmp = '\0';

  if (standardize == YES)
    {
      /*
       * Compact '/./'  to '/' and strip any trailing '/.'
       */
      tmp = ptr;
      while (*tmp != '\0')
	{
	  if (tmp[0] == '/' && tmp[1] == '.'
	    && (tmp[2] == '/' || tmp[2] == '\0'))
	    {
	      /*
	       * Ensure we don't remove the leading '/'
	       */
	      if (tmp == ptr && tmp[2] == '\0')
		{
		  tmp[1] = '\0';
		}
	      else
		{
		  l = strlen(&tmp[2]) + 1;
		  memmove(tmp, &tmp[2], l);
		}
	    }
	  else
	    {
	      tmp++;
	    }
	}
      /*
       * Reduce any sequence of '/' characters to a single '/'
       */
      tmp = ptr;
      while (*tmp != '\0')
	{
	  if (tmp[0] == '/' && tmp[1] == '/')
	    {
	      l = strlen(&tmp[1]) + 1;
	      memmove(tmp, &tmp[1], l);
	    }
	  else
	    {
	      tmp++;
	    }
	}
      /*
       * Reduce any '/something/../' sequence to '/' and a trailing
       * "/something/.." to ""
       */
      tmp = ptr;
      while ((tmp = findUp(tmp)) != 0)
	{
	  char	*next = &tmp[3];

	  while (tmp > ptr)
	    {
	      if (*--tmp == '/')
		{
		  break;
		}
	    }
	  /*
	   * Ensure we don't remove the leading '/'
	   */
	  if (tmp == ptr && *next == '\0')
	    {
	      tmp[1] = '\0';
	    }
	  else
	    {
	      l = strlen(next) + 1;
	      memmove(tmp, next, l);
	    }
	}
      /*
       * if we have an empty path, we standardize to a single slash.
       */
      tmp = ptr;
      if (*tmp == '\0')
	{
	  memcpy(tmp, "/", 2);
	}
    }
  ptr = &ptr[strlen(ptr)];

  if (rel->parameters != 0)
    {
      *ptr++ = ';';
      l = strlen(rel->parameters);
      memcpy(ptr, rel->parameters, l);
      ptr += l;
    }
  if (rel->query != 0)
    {
      *ptr++ = '?';
      l = strlen(rel->query);
      memcpy(ptr, rel->query, l);
      ptr += l;
    }
  if (rel->fragment != 0)
    {
      *ptr++ = '#';
      l = strlen(rel->fragment);
      memcpy(ptr, rel->fragment, l);
      ptr += l;
    }
  *ptr = '\0';

  /* Check for characters which shoudl be escaped.
   */
  e = ptr - buf;
  for (l = 0; l < e; l++)
    {
      if (NULL == strchr(rfc3986ok, buf[l]))
	{
	  break;
	}
    }
  if (l < e)
    {
      ENTER_POOL
      NSString	*s = [NSString stringWithUTF8String: buf];
      NSData	*d;

      s = [s stringByAddingPercentEncodingWithAllowedCharacters: okCharSet];
      d = [s dataUsingEncoding: NSASCIIStringEncoding];
      len = [d length];
      buf = (char*)NSZoneRealloc(NSDefaultMallocZone(), buf, len + 1);
      memcpy(buf, [d bytes], len);
      buf[len] = '\0';
      LEAVE_POOL
    }
  return buf;
}

static id clientForHandle(void *data, NSURLHandle *hdl)
{
  id	client = nil;

  if (data != 0)
    {
      [clientsLock lock];
      client = RETAIN((id)NSMapGet((NSMapTable*)data, hdl));
      [clientsLock unlock];
    }
  return AUTORELEASE(client);
}

/**
 * Locate a '/../ or trailing '/..'
 */
static char *findUp(char *str)
{
  while (*str != '\0')
    {
      if (str[0] == '/' && str[1] == '.' && str[2] == '.'
	&& (str[3] == '/' || str[3] == '\0'))
	{
	  return str;
	}
      str++;
    }
  return 0;
}

/*
 * Check a bounded string (up to end pointer) to see if it contains only
 * legal data characters or percent escape sequences.
 */
static BOOL legal_bounded(const char *str, const char *end, const char *extras)
{
  const char	*mark = "-_.!~*'()";

  if (str != 0)
    {
      while (str < end)
	{
	  if (*str == '%' && str + 2 < end
	    && isxdigit(str[1]) && isxdigit(str[2]))
	    {
	      str += 3;
	    }
	  else if (isalnum(*str))
	    {
	      str++;
	    }
	  else if (strchr(mark, *str) != 0)
	    {
	      str++;
	    }
	  else if (strchr(extras, *str) != 0)
	    {
	      str++;
	    }
	  else
	    {
	      return NO;
	    }
	}
    }
  return YES;
}

/*
 * Check a string to see if it contains only legal data characters
 * or percent escape sequences. Wrapper around legal_bounded.
 */
static BOOL legal(const char *str, const char *extras)
{
  if (str == 0)
    return YES;
  return legal_bounded(str, str + strlen(str), extras);
}

/*
 * Convert percent escape sequences to individual characters.
 */
static char *unescape(const char *from, char * to)
{
  while (*from != '\0')
    {
      if (*from == '%')
	{
	  unsigned char	c;

	  from++;
	  if (isxdigit(*from))
	    {
	      if (*from <= '9')
		{
		  c = *from - '0';
		}
	      else if (*from <= 'F')
		{
		  c = *from - 'A' + 10;
		}
	      else
		{
		  c = *from - 'a' + 10;
		}
	      from++;
	    }
	  else
	    {
	      c = 0;	// Avoid compiler warning
	      [NSException raise: NSGenericException
			  format: @"Bad percent escape sequence in URL string"];
	    }
	  c <<= 4;
	  if (isxdigit(*from))
	    {
	      if (*from <= '9')
		{
		  c |= *from - '0';
		}
	      else if (*from <= 'F')
		{
		  c |= *from - 'A' + 10;
		}
	      else
		{
		  c |= *from - 'a' + 10;
		}
	      from++;
	      *to++ = c;
	    }
	  else
	    {
	      [NSException raise: NSGenericException
			  format: @"Bad percent escape sequence in URL string"];
	    }
	}
      else
	{
	  *to++ = *from++;
	}
    }
  *to = '\0';
  return to;
}



@implementation NSURL


static NSCharacterSet	*fileCharSet = nil;
static NSUInteger	urlAlign;

+ (id) fileURLWithPath: (NSString*)aPath
{
  return AUTORELEASE([[NSURL alloc] initFileURLWithPath: aPath]);
}

+ (id) fileURLWithPath: (NSString*)aPath isDirectory: (BOOL)isDir
{
  return AUTORELEASE([[NSURL alloc] initFileURLWithPath: aPath
					    isDirectory: isDir]);
}

+ (id) fileURLWithPath: (NSString*)aPath
	   isDirectory: (BOOL)isDir
	 relativeToURL: (NSURL*)baseURL
{
  return AUTORELEASE([[NSURL alloc] initFileURLWithPath: aPath
					    isDirectory: isDir
					  relativeToURL: baseURL]);
}

+ (id) fileURLWithPath: (NSString*)aPath relativeToURL: (NSURL*)baseURL
{
  return AUTORELEASE([[NSURL alloc] initFileURLWithPath: aPath
					  relativeToURL: baseURL]);
}

+ (id) fileURLWithPathComponents: (NSArray*)components
{
  return [self fileURLWithPath: [NSString pathWithComponents: components]];
}

+ (void) initialize
{
  if (clientsLock == nil)
    {
      NSGetSizeAndAlignment(@encode(parsedURL), NULL, &urlAlign);
      clientsLock = [NSLock new];
      [[NSObject leakAt: &clientsLock] release];
      ASSIGN(fileCharSet, [NSCharacterSet characterSetWithCharactersInString:
        @"!$&'()*+,-./0123456789:=@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~"]);
      ASSIGN(okCharSet, [NSCharacterSet characterSetWithCharactersInString:
	[NSString stringWithUTF8String: rfc3986ok]]);
    }
}

+ (id) URLWithString: (NSString*)aUrlString
{
  return AUTORELEASE([[NSURL alloc] initWithString: aUrlString]);
}

+ (id) URLWithString: (NSString*)aUrlString
       relativeToURL: (NSURL*)aBaseUrl
{
  return AUTORELEASE([[NSURL alloc] initWithString: aUrlString
				     relativeToURL: aBaseUrl]);
}

+ (id) URLByResolvingAliasFileAtURL: (NSURL*)url 
                            options: (NSURLBookmarkResolutionOptions)options 
                              error: (NSError**)error
{
  // TODO: unimplemented
  return nil;
}

- (id) initFileURLWithPath: (NSString *)aPath
{
  /* isDirectory flag will be overwritten if a directory exists. */
  return [self initFileURLWithPath: aPath isDirectory: NO relativeToURL: nil];
}

- (id) initFileURLWithPath: (NSString *)aPath isDirectory: (BOOL)isDir
{
  return [self initFileURLWithPath: aPath
                       isDirectory: isDir
                     relativeToURL: nil];
}

- (id) initFileURLWithPath: (NSString *)aPath relativeToURL: (NSURL *)baseURL
{
  /* isDirectory flag will be overwritten if a directory exists. */
  return [self initFileURLWithPath: aPath
                       isDirectory: NO
                     relativeToURL: baseURL];
}

- (id) initFileURLWithPath: (NSString *)aPath
	       isDirectory: (BOOL)isDir
	     relativeToURL: (NSURL *)baseURL
{
  NSFileManager	*mgr = [NSFileManager defaultManager];
  BOOL		flag = NO;

  if (nil == aPath)
    {
      NSString	*name = NSStringFromClass([self class]);

      RELEASE(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@ %@] nil string parameter",
	name, NSStringFromSelector(_cmd)];
    }
  if ([aPath isAbsolutePath] == NO)
    {
      if (baseURL)
        {
          /* Append aPath to baseURL */
          aPath
	    = [[baseURL relativePath] stringByAppendingPathComponent: aPath];
        }
      else
        {
          aPath =
            [[mgr currentDirectoryPath] stringByAppendingPathComponent: aPath];
        }
    }
  if ([mgr fileExistsAtPath: aPath isDirectory: &flag] == YES)
    {
      if ([aPath isAbsolutePath] == NO)
        {
          aPath = [aPath stringByStandardizingPath];
        }
      isDir = flag;
    }
  if (isDir == YES && [aPath hasSuffix:@"/"] == NO)
    {
      aPath = [aPath stringByAppendingString: @"/"];
    }
  return [self initWithScheme: NSURLFileScheme host: @"" path: aPath];
}

- (id) initWithScheme: (NSString*)aScheme
		 host: (NSString*)aHost
		 path: (NSString*)aPath
{
  NSRange	r;
  NSString	*auth = nil;
  NSString	*aUrlString = [NSString alloc];

  if ([aScheme isEqualToString: @"file"])
    {
      aPath = [aPath stringByAddingPercentEncodingWithAllowedCharacters:
	fileCharSet];
    }
  else
    {
      aPath = [aPath
	stringByAddingPercentEscapesUsingEncoding: NSUTF8StringEncoding];
    }

  r = [aHost rangeOfString: @"@"];

  /* Allow for authentication (username:password) before actual host.
   */
  if (r.length > 0)
    {
      auth = [aHost substringToIndex: r.location];
      aHost = [aHost substringFromIndex: NSMaxRange(r)];
    }

  /* Add square brackets around ipv6 address if necessary
   */
  if ([[aHost componentsSeparatedByString: @":"] count] > 2
    && [aHost hasPrefix: @"["] == NO)
    {
      aHost = [NSString stringWithFormat: @"[%@]", aHost];
    }

  if (auth != nil)
    {
      aHost = [NSString stringWithFormat: @"%@@%@", auth, aHost];
    }

  if ([aPath length] > 0)
    {
      /*
       * For MacOS-X compatibility, assume a path component with
       * a leading slash is intended to have that slash separating
       * the host from the path as specified in the RFC1738
       */
      if ([aPath hasPrefix: @"/"] == YES)
        {
          aUrlString = [aUrlString initWithFormat: @"%@://%@%@",
            aScheme, aHost, aPath];
        }
#if  defined(_WIN32)
      /* On Windows file systems, an absolute file path can begin with
       * a drive letter. The first component in an absolute path
       * (e.g. C:) has to be enclosed by a leading slash.
       *
       * "file:///c:/path/to/file"
       */
      else if ([aScheme isEqualToString: @"file"]
        && [aPath characterAtIndex:1] == ':')
        {
          aUrlString = [aUrlString initWithFormat: @"%@:///%@%@",
            aScheme, aHost, aPath];
        }
#endif
      else
        {
          aUrlString = [aUrlString initWithFormat: @"%@://%@/%@",
            aScheme, aHost, aPath];
        }
    }
  else
    {
      aUrlString = [aUrlString initWithFormat: @"%@://%@/",
        aScheme, aHost];
    }
  self = [self initWithString: aUrlString relativeToURL: nil];
  RELEASE(aUrlString);
  return self;
}

- (id) initWithString: (NSString*)aUrlString
{
  self = [self initWithString: aUrlString relativeToURL: nil];
  return self;
}

- (id) initWithString: (NSString*)aUrlString
	relativeToURL: (NSURL*)aBaseUrl
{
  /* RFC 2396 'eeserved' characters ...
   * as modified by RFC2732
   * static const char *reserved = ";/?:@&=+$,[]";
   */
  /* Same as reserved set but allow the hash character in a path too.
   */
  static const char *filepath = ";/?:@&=+$,[]#";

  if (nil == aUrlString)
    {
      RELEASE(self);
      return nil;       // OSX behavior is to give up.
    }
  if ([aUrlString isKindOfClass: [NSString class]] == NO)
    {
      NSString	*name = NSStringFromClass([self class]);

      RELEASE(self);
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@ %@] bad string parameter",
	name, NSStringFromSelector(_cmd)];
    }
  if (aBaseUrl != nil
    && [aBaseUrl isKindOfClass: [NSURL class]] == NO)
    {
      NSString	*name = NSStringFromClass([self class]);
      RELEASE(self);

      [NSException raise: NSInvalidArgumentException
		  format: @"[%@ %@] bad base URL parameter",
	name, NSStringFromSelector(_cmd)];
    }
  ASSIGNCOPY(_urlString, aUrlString);
  ASSIGN(_baseURL, [aBaseUrl absoluteURL]);
  NS_DURING
    {
      parsedURL	*buf;
      parsedURL	*base = baseData;
      const char	*utf8ptr = [_urlString UTF8String];
      unsigned	utf8len = strlen(utf8ptr);
      unsigned	size = utf8len;
      char	*end;
      char	*start;
      char	*ptr;
      BOOL	usesFragments = YES;
      BOOL	usesParameters = YES;
      BOOL	usesQueries = YES;
      BOOL	canBeGeneric = YES;

      size += sizeof(parsedURL) + urlAlign + 1;
      buf = _data = (parsedURL*)NSZoneMalloc(NSDefaultMallocZone(), size);
      memset(buf, '\0', sizeof(parsedURL));
      start = end = (char*)&buf[1];

      memcpy(start, utf8ptr, utf8len);
      start[utf8len] = '\0';

      /*
       * Parse the scheme if possible.
       */
      ptr = start;
      if (isalpha(*ptr))
	{
	  ptr++;
	  while (isalnum(*ptr) || *ptr == '+' || *ptr == '-' || *ptr == '.')
	    {
	      ptr++;
	    }
	  if (*ptr == ':')
	    {
	      buf->scheme = start;		// Got scheme.
	      *ptr = '\0';			// Terminate it.
	      end = &ptr[1];
	      /*
	       * Standardise uppercase to lower.
	       */
	      while (--ptr > start)
		{
		  if (isupper(*ptr))
		    {
		      *ptr = tolower(*ptr);
		    }
		}
	    }
	}
      start = end;

      if (buf->scheme != 0 && base != 0
        && 0 != strcmp(buf->scheme, base->scheme))
        {
          /* The relative URL is of a different scheme to the base ...
           * so it's actually an absolute URL without a base.
           */
          DESTROY(_baseURL);
          base = 0;
        }

      if (buf->scheme == 0 && base != 0)
	{
	  buf->scheme = base->scheme;
	}

      /*
       * Set up scheme specific parsing options.
       */
      if (buf->scheme != 0)
        {
          if (strcmp(buf->scheme, "file") == 0)
	    {
	      buf->isFile = YES;
	    }
	  else if (strcmp(buf->scheme, "data") == 0)
            {
	      canBeGeneric = NO;
              DESTROY(_baseURL);
              base = 0;
            }
          else if (strcmp(buf->scheme, "mailto") == 0)
	    {
	      usesFragments = NO;
	      usesParameters = NO;
	      usesQueries = NO;
	    }
          else if (strcmp(buf->scheme, "http") == 0
            || strcmp(buf->scheme, "https") == 0)
	    {
	      buf->emptyPath = YES;
	    }
        }

      if (canBeGeneric == YES)
	{
	  /*
	   * Parse the 'authority'
	   * //user:password@host:port
	   */
	  if (start[0] == '/' && start[1] == '/')
	    {
	      char	*authEnd;       // End of authority section
	      char 	*hostEnd;
	      char	*pathStart;	// Where path/query/fragment starts

	      buf->isGeneric = YES;
	      start = &end[2];

	      /*
	       * Set 'end' to point to the start of the path, or just past
	       * the 'authority' if there is no path.
	       * Check for delimiters in order: '/' (path), '?' (query),
               * '#' (fragment).
	       * We find the authority end without modifying the string,
               * using legal_bounded() for validation (RFC 3986).
	       */
	      pathStart = NULL;
	      end = strchr(start, '/');
	      if (end == 0)
		{
		  char	*alt = strchr(start, '?');

		  buf->hasNoPath = YES;
		  if (alt == 0)
		    {
		      alt = strchr(start, '#');
		    }
		  if (alt == 0)
		    {
		      authEnd = &start[strlen(start)];
		      pathStart = authEnd;
		    }
		  else
		    {
		      authEnd = alt;
		      pathStart = alt;
		    }
		}
	      else
		{
		  authEnd = end;
		  pathStart = end + 1;  // Skip the '/' we found
		  *end++ = '\0';
		}

	      /*
	       * Parser username:password part within authority bounds
	       */
	      ptr = strchr(start, '@');
	      if (ptr != 0 && ptr < authEnd)
		{
		  char	*userEnd = ptr;
		  char 	*colonPos;

		  buf->user = start;
		  *ptr++ = '\0';
		  start = ptr;
		  /* Validate user[:password] without the null terminator
                   * at ':'
                   */
		  colonPos = strchr(buf->user, ':');
		  if (colonPos != 0 && colonPos < userEnd)
		    {
		      if (!legal_bounded(buf->user, colonPos, ";:&=+$,")
			|| !legal_bounded(colonPos + 1, userEnd, ";:&=+$,"))
			{
			  [NSException raise: NSInvalidArgumentException
				      format: @"[%@ %@](%@, %@) "
			    @"illegal character in user/password part",
			    NSStringFromClass([self class]),
			    NSStringFromSelector(_cmd),
			    aUrlString, aBaseUrl];
			}
		      *colonPos = '\0';
		      buf->password = colonPos + 1;
		    }
		  else
		    {
		      if (legal_bounded(buf->user, userEnd, ";:&=+$,") == NO)
			{
			  [NSException raise: NSInvalidArgumentException
				      format: @"[%@ %@](%@, %@) "
			    @"illegal character in user/password part",
			    NSStringFromClass([self class]),
			    NSStringFromSelector(_cmd),
			    aUrlString, aBaseUrl];
			}
		    }
		}

	      /*
	       * Parse host:port part
	       */
	      buf->host = start;
	      if (*start == '[')
		{
	          ptr = strchr(buf->host, ']');
		  if (ptr == 0)
		    {
		      [NSException raise: NSInvalidArgumentException
			format: @"[%@ %@](%@, %@) "
			@"illegal ipv6 host address",
			NSStringFromClass([self class]),
			NSStringFromSelector(_cmd),
			aUrlString, aBaseUrl];
		    }
		  else
		    {
		      ptr = start + 1;
		      while (*ptr != ']')
			{
			  if (*ptr != ':' && *ptr != '.' && !isxdigit(*ptr))
			    {
			      [NSException raise: NSInvalidArgumentException
				format: @"[%@ %@](%@, %@) "
				@"illegal ipv6 host address",
				NSStringFromClass([self class]),
				NSStringFromSelector(_cmd),
				aUrlString, aBaseUrl];
			    }
			  ptr++;
			}
		    }
	          ptr = strchr(ptr, ':');
		}
	      else
		{
	          ptr = strchr(buf->host, ':');
		}
	      if (ptr != 0)
		{
		  const char	*str;

		  *ptr++ = '\0';
		  buf->port = ptr;
		  str = buf->port;
		  while (*str != 0)
		    {
		      if (*str == '%' && isxdigit(str[1]) && isxdigit(str[2]))
			{
			  unsigned char	c;

			  str++;
			  if (*str <= '9')
			    {
			      c = *str - '0';
			    }
			  else if (*str <= 'F')
			    {
			      c = *str - 'A' + 10;
			    }
			  else
			    {
			      c = *str - 'a' + 10;
			    }
			  c <<= 4;
			  str++;
			  if (*str <= '9')
			    {
			      c |= *str - '0';
			    }
			  else if (*str <= 'F')
			    {
			      c |= *str - 'A' + 10;
			    }
			  else
			    {
			      c |= *str - 'a' + 10;
			    }

			  if (isdigit(c))
			    {
			      str++;
			    }
			  else
			    {
			      [NSException raise: NSInvalidArgumentException
                                format: @"[%@ %@](%@, %@) "
				@"illegal port part",
                                NSStringFromClass([self class]),
                                NSStringFromSelector(_cmd),
                                aUrlString, aBaseUrl];
			    }
			}
		      else if (isdigit(*str))
			{
			  str++;
			}
		      else
			{
			  [NSException raise: NSInvalidArgumentException
                            format: @"[%@ %@](%@, %@) "
			    @"illegal character in port part",
                            NSStringFromClass([self class]),
                            NSStringFromSelector(_cmd),
                            aUrlString, aBaseUrl];
			}
		    }
		}
	      start = pathStart;
	      /* Check for a legal host, unless it's an ipv6 address
	       * (which would have been checked earlier).
	       * Use legal_bounded to validate only the host portion
               * without modifying the string.
	       */
	      hostEnd = authEnd;
	      /* Account for port if present */
	      if (*buf->host != '[')
		{
		  char *colon = strchr(buf->host, ':');
		  if (colon != 0 && colon < authEnd)
		    {
		      hostEnd = colon;
		    }
		}
	      if (*buf->host != '['
                && legal_bounded(buf->host, hostEnd, "-") == NO)
		{
		  [NSException raise: NSInvalidArgumentException
                    format: @"[%@ %@](%@, %@) "
		    @"illegal character in host part",
                    NSStringFromClass([self class]),
                    NSStringFromSelector(_cmd),
                    aUrlString, aBaseUrl];
		}

	      /*
	       * If we have an authority component,
	       * this must be an absolute URL
	       */
	      buf->pathIsAbsolute = YES;
	      base = 0;
	    }
	  else
	    {
	      if (base != 0)
		{
		  buf->isGeneric = base->isGeneric;
		}
	      if (*start == '/')
		{
		  buf->pathIsAbsolute = YES;
		  start++;
		}
	    }

	  if (usesFragments == YES)
	    {
	      /*
	       * Strip fragment string from end of url.
	       */
	      ptr = strchr(start, '#');
	      if (ptr != 0)
		{
		  *ptr++ = '\0';
		  if (*ptr != 0)
		    {
		      buf->fragment = ptr;
		    }
		}
	      if (buf->fragment == 0 && base != 0)
		{
		  buf->fragment = base->fragment;
		}
	      if (legal(buf->fragment, filepath) == NO)
		{
		  [NSException raise: NSInvalidArgumentException
		    format: @"[%@ %@](%@, %@) "
		    @"illegal character in fragment part",
		    NSStringFromClass([self class]),
		    NSStringFromSelector(_cmd),
		    aUrlString, aBaseUrl];
		}
	    }

	  if (usesQueries == YES)
	    {
	      /*
	       * Strip query string from end of url.
	       */
	      ptr = strchr(start, '?');
	      if (ptr != 0)
		{
		  *ptr++ = '\0';
		  if (*ptr != 0)
		    {
		      buf->query = ptr;
		    }
		}
	      if (buf->query == 0 && base != 0)
		{
		  buf->query = base->query;
		}
	      if (legal(buf->query, filepath) == NO)
		{
		  [NSException raise: NSInvalidArgumentException
		    format: @"[%@ %@](%@, %@) "
		    @"illegal character in query part",
		    NSStringFromClass([self class]),
		    NSStringFromSelector(_cmd),
		    aUrlString, aBaseUrl];
		}
	    }

	  if (usesParameters == YES)
	    {
	      /*
	       * Strip parameters string from end of url.
	       */
	      ptr = strchr(start, ';');
	      if (ptr != 0)
		{
		  *ptr++ = '\0';
		  if (*ptr != 0)
		    {
		      buf->parameters = ptr;
		    }
		}
	      if (buf->parameters == 0 && base != 0)
		{
		  buf->parameters = base->parameters;
		}
	      if (legal(buf->parameters, filepath) == NO)
		{
		  [NSException raise: NSInvalidArgumentException
		    format: @"[%@ %@](%@, %@) "
		    @"illegal character in parameters part",
		    NSStringFromClass([self class]),
		    NSStringFromSelector(_cmd),
		    aUrlString, aBaseUrl];
		}
	    }

	  if (buf->isFile == YES)
	    {
	      buf->user = 0;
	      buf->password = 0;
	      if (base != 0 && base->host != 0)
		{
		  buf->host = base->host;
		}
	      else if (buf->host != 0 && *buf->host == 0)
		{
		  buf->host = 0;
		}
	      buf->port = 0;
	      buf->isGeneric = YES;
	    }
	  else if (base != 0
	    && buf->user == 0 && buf->password == 0
	    && buf->host == 0 && buf->port == 0)
	    {
	      buf->user = base->user;
	      buf->password = base->password;
	      buf->host = base->host;
	      buf->port = base->port;
	    }
	}
      /*
       * Store the path.
       */
      buf->path = start;
      if (0 == base && '\0' == *buf->path && NO == buf->pathIsAbsolute)
	{
	  buf->hasNoPath = YES;
	}
      if (legal(buf->path, filepath) == NO)
	{
	  [NSException raise: NSInvalidArgumentException
            format: @"[%@ %@](%@, %@) "
	    @"illegal character in path part",
            NSStringFromClass([self class]),
            NSStringFromSelector(_cmd),
            aUrlString, aBaseUrl];
	}
    }
  NS_HANDLER
    {
      NSDebugLog(@"%@", localException);
      DESTROY(self);
    }
  NS_ENDHANDLER
  return self;
}

- (void) dealloc
{
  if (_clients != 0)
    {
      NSFreeMapTable(_clients);
      _clients = 0;
    }
  if (_data != 0)
    {
      DESTROY(myData->absolute);
      NSZoneFree([self zone], _data);
      _data = 0;
    }
  DESTROY(_urlString);
  DESTROY(_baseURL);
  DEALLOC
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone) == NO)
    {
      return [[[self class] allocWithZone: zone] initWithString: _urlString
						  relativeToURL: _baseURL];
    }
  else
    {
      return RETAIN(self);
    }
}

- (NSString*) description
{
  NSString	*dscr = _urlString;

  if (_baseURL != nil)
    {
      dscr = [dscr stringByAppendingFormat: @" -- %@", _baseURL];
    }
  return dscr;
}

- (void) encodeWithCoder: (NSCoder*)aCoder
{
  if ([aCoder allowsKeyedCoding])
    {
      [aCoder encodeObject: _baseURL forKey: @"NS.base"];
      [aCoder encodeObject: _urlString forKey: @"NS.relative"];
    }
  else
    {
      [aCoder encodeObject: _urlString];
      [aCoder encodeObject: _baseURL];
    }
}

- (NSUInteger) hash
{
  return [[self absoluteString] hash];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSURL		*base;
  NSString	*rel;

  if ([aCoder allowsKeyedCoding])
    {
      base = [aCoder decodeObjectForKey: @"NS.base"];
      rel = [aCoder decodeObjectForKey: @"NS.relative"];
    }
  else
    {
      rel = [aCoder decodeObject];
      base = [aCoder decodeObject];
    }
  if (nil == rel)
    {
      rel = @"";
    }
  self = [self initWithString: rel relativeToURL: base];
  return self;
}

- (BOOL) isEqual: (id)other
{
  if (other == nil || [other isKindOfClass: [NSURL class]] == NO)
    {
      return NO;
    }
  return [[self absoluteString] isEqualToString: [other absoluteString]];
}

- (NSString*) absoluteString
{
  NSString	*absString = myData->absolute;

  if (absString == nil)
    {
      char	*url = buildURL(baseData, myData, NO);
      unsigned	len = strlen(url);

      absString = [[NSString alloc] initWithCStringNoCopy: url
						   length: len
					     freeWhenDone: YES];
      myData->absolute = absString;
    }
  return absString;
}

- (NSURL*) absoluteURL
{
  if (_baseURL == nil)
    {
      return self;
    }
  else
    {
      return [NSURL URLWithString: [self absoluteString]];
    }
}

- (NSURL*) baseURL
{
  return _baseURL;
}

- (BOOL) checkResourceIsReachableAndReturnError: (NSError **)error
{
  NSString *errorStr = nil;

  if ([self isFileURL])
    {
      NSFileManager *mgr = [NSFileManager defaultManager];
      NSString *path = [self path];
      
      if ([mgr fileExistsAtPath: path])
        {
          if (![mgr isReadableFileAtPath: path])
            {
              errorStr = @"File not readable";
            }
        }
      else
        {
          errorStr = @"File does not exist";
        }
    }
  else
    {
      errorStr = @"No file URL";
    }

  if ((errorStr != nil) && (error != NULL))
    {
      NSDictionary	*info;

      info = [NSDictionary dictionaryWithObjectsAndKeys:
	errorStr, NSLocalizedDescriptionKey, nil];
      *error = [NSError errorWithDomain: @"NSURLError"
                                   code: 0 
                               userInfo: info];
    }
  return nil == errorStr ? YES : NO;
}

- (NSString*) fragment
{
  NSString	*fragment = nil;

  if (myData->fragment != 0)
    {
      fragment = [NSString stringWithUTF8String: myData->fragment];
    }
  return fragment;
}

- (char*) _path: (char*)buf withEscapes: (BOOL)withEscapes
{
  char	*ptr = buf;
  char	*tmp = buf;
  int	l;

  *buf = '\0';
  if (myData->pathIsAbsolute == YES)
    {
      if (myData->hasNoPath == NO)
	{
	  *tmp++ = '/';
	  *tmp = '\0';
	}
      if (myData->path != 0)
	{
	  l = strlen(myData->path);
          memcpy(tmp, myData->path, l + 1);
	}
    }
  else if (nil == _baseURL)
    {
      if (myData->path != 0)
	{
	  l = strlen(myData->path);
          memcpy(tmp, myData->path, l + 1);
	}
    }
  else if (0 == myData->path || 0 == *myData->path)
    {
      if (baseData->hasNoPath == NO)
	{
	  *tmp++ = '/';
	  *tmp = '\0';
	}
      if (baseData->path != 0)
	{
	  l = strlen(baseData->path);
          memcpy(tmp, baseData->path, l + 1);
	}
    }
  else
    {
      char	*start = baseData->path;
      char	*end = (start == 0) ? 0 : strrchr(start, '/');

      if (end != 0)
	{
	  *tmp++ = '/';
	  strncpy(tmp, start, end - start);
	  tmp += end - start;
	}
      *tmp++ = '/';
      *tmp = '\0';
      if (myData->path != 0)
	{
	  l = strlen(myData->path);
          memcpy(tmp, myData->path, l + 1);
	}
    }

  if (!withEscapes)
    {
      unescape(buf, buf);
    }

#if	defined(_WIN32)
  /* On Windows a file URL path may be of the form C:\xxx or \\xxx,
   * and in both cases we should not insert the leading slash.
   * Also the vertical bar symbol may have been used instead of the
   * colon, so we need to convert that.
   */
  if (myData->isFile == YES)
    {
      if ((ptr[1] && isalpha(ptr[1]))
	&& (ptr[2] == ':' || ptr[2] == '|')
	&& (ptr[3] == '\0' || ptr[3] == '/' || ptr[3] == '\\'))
        {
          ptr[2] = ':';
          ptr++; // remove leading slash
        }
      else if (ptr[1] == '\\' && ptr[2] == '\\')
        {
          ptr++; // remove leading slash
        }
    }
#endif
  return ptr;
}

- (NSString*) host
{
  NSString	*host = nil;

  if (myData->host != 0)
    {
      char	buf[strlen(myData->host)+1];

      if (*myData->host == '[')
	{
	  char	*end = unescape(myData->host + 1, buf);

	  if (end > buf && end[-1] == ']')
	    {
	      end[-1] = '\0';
	    }
	}
      else
	{
          unescape(myData->host, buf);
	}
      host = [NSString stringWithUTF8String: buf];
    }
  return host;
}

- (BOOL) isFileURL
{
  return myData->isFile;
}

- (NSString*) lastPathComponent
{
  return [[self path] lastPathComponent];
}

- (BOOL) isFileReferenceURL
{
  return NO;
}

- (NSURL *) fileReferenceURL
{
  if ([self isFileURL]) 
    {
      return self;
    }
  return nil;
}

- (NSURL *) filePathURL
{
  if ([self isFileURL]) 
    {
      return self;
    }
  return nil;
}

- (BOOL) getResourceValue: (id*)value 
                   forKey: (NSString *)key 
                    error: (NSError**)error
{
  // TODO: unimplemented
  return NO;
}

- (void) loadResourceDataNotifyingClient: (id)client
			      usingCache: (BOOL)shouldUseCache
{
  NSURLHandle	*handle = [self URLHandleUsingCache: shouldUseCache];
  NSData	*d;

  if (shouldUseCache == YES && (d = [handle availableResourceData]) != nil)
    {
      /*
       * We already have cached data we should use.
       */
      if ([client respondsToSelector:
	@selector(URL:resourceDataDidBecomeAvailable:)])
	{
	  [client URL: self resourceDataDidBecomeAvailable: d];
	}
      if ([client respondsToSelector: @selector(URLResourceDidFinishLoading:)])
	{
	  [client URLResourceDidFinishLoading: self];
	}
    }
  else
    {
      if (client != nil)
	{
	  [clientsLock lock];
	  if (_clients == 0)
	    {
	      _clients = NSCreateMapTable (NSObjectMapKeyCallBacks,
		NSNonRetainedObjectMapValueCallBacks, 0);
	    }
	  NSMapInsert((NSMapTable*)_clients, (void*)handle, (void*)client);
	  [clientsLock unlock];
	  [handle addClient: self];
	}

      /*
       * Kick off the load process.
       */
      [handle loadInBackground];
    }
}

- (NSString*) parameterString
{
  NSString	*parameters = nil;

  if (myData->parameters != 0)
    {
      parameters = [NSString stringWithUTF8String: myData->parameters];
    }
  return parameters;
}

- (NSString*) password
{
  NSString	*password = nil;

  if (myData->password != 0)
    {
      char	buf[strlen(myData->password)+1];

      unescape(myData->password, buf);
      password = [NSString stringWithUTF8String: buf];
    }
  return password;
}

- (NSString*) _pathWithEscapes: (BOOL)withEscapes
{
  NSString	*path = nil;

  if (YES == myData->isGeneric || 0 == myData->scheme)
    {
      unsigned int	len = 3;

      if (_baseURL != nil)
        {
          if (baseData->path && *baseData->path)
            {
              len += strlen(baseData->path);
            }
          else if (baseData->hasNoPath == NO)
            {
              len++;
            }
        }
      if (myData->path && *myData->path)
        {
          len += strlen(myData->path);
        }
      else if (myData->hasNoPath == NO)
        {
          len++;
        }
      if (len > 3)
        {
          char		buf[len];
          char		*ptr;
          char		*tmp;

          ptr = [self _path: buf withEscapes: withEscapes];

          /* Remove any trailing '/' from the path for MacOS-X compatibility.
           */
          tmp = ptr + strlen(ptr) - 1;
          if (tmp > ptr && *tmp == '/')
            {
              *tmp = '\0';
            }

          path = [NSString stringWithUTF8String: ptr];
        }
      else if (YES == myData->emptyPath)
        {
          /* OSX seems to use an empty string for some schemes,
           * though it normally uses nil.
           */
          path = @"";
        }
    }
  return path;
}

- (NSString*) path
{
  return [self _pathWithEscapes: NO];
}

- (NSArray*) pathComponents 
{
  return [[self path] pathComponents];
}

- (NSString*) pathExtension 
{
  return [[self path] pathExtension];
}

- (NSNumber*) port
{
  NSNumber	*port = nil;

  if (myData->port != 0)
    {
      char	buf[strlen(myData->port)+1];

      unescape(myData->port, buf);
      port = [NSNumber numberWithUnsignedShort: atol(buf)];
    }
  return port;
}

- (id) propertyForKey: (NSString*)propertyKey
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];

  return [handle propertyForKey: propertyKey];
}

- (NSString*) query
{
  NSString	*query = nil;

  if (myData->query != 0)
    {
      query = [NSString stringWithUTF8String: myData->query];
    }
  return query;
}

- (NSString*) relativePath
{
  if (nil == _baseURL)
    {
      return [self path];
    }
  else
    {
      NSString	*path = nil;

      if (myData->path != 0)
	{
          char		buf[strlen(myData->path) + 1];

          strcpy(buf, myData->path);
          unescape(buf, buf);
	  path = [NSString stringWithUTF8String: buf];
	}
      return path;
    }
}

- (NSString*) relativeString
{
  return _urlString;
}

/* Encode bycopy unless explicitly requested otherwise.
 */
- (id) replacementObjectForPortCoder: (NSPortCoder*)aCoder
{
  if ([aCoder isByref] == NO)
    return self;
  return [super replacementObjectForPortCoder: aCoder];
}

- (NSData*) resourceDataUsingCache: (BOOL)shouldUseCache
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];
  NSData	*data = nil;

  if ([handle status] == NSURLHandleLoadSucceeded)
    {
      data = [handle availableResourceData];
    }
  if (shouldUseCache == NO || [handle status] != NSURLHandleLoadSucceeded)
    {
      data = [handle loadInForeground];
    }
  if (nil == data)
    {
      data = [handle availableResourceData];
    }
  return data;
}

- (NSString*) resourceSpecifier
{
  if (YES == myData->isGeneric)
    {
      NSRange	range = [_urlString rangeOfString: @"://"];

      if (range.length > 0)
        {
          NSString *specifier;

          /* MacOSX compatibility - in the case where there is no
           * host in the URL, just return the path (without the "//").
           * For all other cases we return the whole specifier.
           */
          if (nil == [self host])
            {
              specifier = [_urlString substringFromIndex: NSMaxRange(range)];
            }
          else
            {
              specifier = [_urlString substringFromIndex: range.location+1];
            }
          return specifier;
        }
      else
        {
          /*
           * Cope with URLs missing net_path info -  <scheme>:/<path>...
           */
          range = [_urlString rangeOfString: @":"];
          if (range.length > 0)
            {
              return [_urlString substringFromIndex: range.location + 1];
            }
          else
            {
              return _urlString;
            }
        }
    }
  else
    {
      return [NSString stringWithUTF8String: myData->path];
    }
}

- (NSString*) scheme
{
  NSString	*scheme = nil;

  if (myData->scheme != 0)
    {
      scheme = [NSString stringWithUTF8String: myData->scheme];
    }
  return scheme;
}

- (BOOL) setProperty: (id)property
	      forKey: (NSString*)propertyKey
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];

  return [handle writeProperty: property forKey: propertyKey];
}

- (BOOL) setResourceData: (NSData*)data
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];

  if (handle == nil)
    {
      return NO;
    }
  if ([handle writeData: data] == NO)
    {
      return NO;
    }
  if ([handle loadInForeground] == nil)
    {
      return NO;
    }
  return YES;
}

- (NSURL*) standardizedURL
{
  char		*url = buildURL(baseData, myData, YES);
  unsigned	len = strlen(url);
  NSString	*str;
  NSURL		*tmp;

  str = [[NSString alloc] initWithCStringNoCopy: url
					 length: len
				   freeWhenDone: YES];
  tmp = [NSURL URLWithString: str];
  RELEASE(str);
  return tmp;
}

- (NSURLHandle*) URLHandleUsingCache: (BOOL)shouldUseCache
{
  NSURLHandle	*handle = nil;

  if (shouldUseCache)
    {
      handle = [NSURLHandle cachedHandleForURL: self];
    }
  if (handle == nil)
    {
      Class	c = [NSURLHandle URLHandleClassForURL: self];

      if (c != 0)
	{
	  handle = [[c alloc] initWithURL: self cached: shouldUseCache];
	  IF_NO_ARC([handle autorelease];)
	}
    }
  return handle;
}

- (NSString*) user
{
  NSString	*user = nil;

  if (myData->user != 0)
    {
      char	buf[strlen(myData->user)+1];

      unescape(myData->user, buf);
      user = [NSString stringWithUTF8String: buf];
    }
  return user;
}

- (NSURL*) URLByAppendingPathComponent: (NSString*)pathComponent 
{
  return [self _URLBySettingPath:
    [[self path] stringByAppendingPathComponent: pathComponent]];
}

- (NSURL*) URLByAppendingPathExtension: (NSString*)pathExtension
{
  return [self _URLBySettingPath:
    [[self path] stringByAppendingPathExtension: pathExtension]];
}

- (NSURL*) URLByDeletingLastPathComponent 
{
  return [self _URLBySettingPath:
    [[self path] stringByDeletingLastPathComponent]];
}

- (NSURL*) URLByDeletingPathExtension 
{
  return [self _URLBySettingPath:
    [[self path] stringByDeletingPathExtension]];
}

- (NSURL*) URLByResolvingSymlinksInPath 
{
  if ([self isFileURL]) 
    {
      return [NSURL fileURLWithPath:
	[[self path] stringByResolvingSymlinksInPath]];
    }
  return self;
}

- (NSURL*) URLByStandardizingPath 
{
  if ([self isFileURL]) 
    {
      return [NSURL fileURLWithPath: [[self path] stringByStandardizingPath]];
    }
  return self;
}

- (NSURL *) URLByAppendingPathComponent: (NSString *)pathComponent
                            isDirectory: (BOOL)isDirectory
{
  NSString *path = [[self path] stringByAppendingPathComponent: pathComponent];
  if (isDirectory)
    {
      path = [path stringByAppendingString: @"/"];
    }
  return [self _URLBySettingPath: path];
}

- (void) URLHandle: (NSURLHandle*)sender
  resourceDataDidBecomeAvailable: (NSData*)newData
{
  id	c = clientForHandle(_clients, sender);

  if ([c respondsToSelector: @selector(URL:resourceDataDidBecomeAvailable:)])
    {
      [c URL: self resourceDataDidBecomeAvailable: newData];
    }
}

- (void) URLHandle: (NSURLHandle*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason
{
  id	c = clientForHandle(_clients, sender);

  RETAIN(self);
  [sender removeClient: self];
  if (c != nil)
    {
      [clientsLock lock];
      NSMapRemove((NSMapTable*)_clients, (void*)sender);
      [clientsLock unlock];
      if ([c respondsToSelector:
	@selector(URL:resourceDidFailLoadingWithReason:)])
	{
	  [c URL: self resourceDidFailLoadingWithReason: reason];
	}
    }
  RELEASE(self);
}

- (void) URLHandleResourceDidBeginLoading: (NSURLHandle*)sender
{
}

- (void) URLHandleResourceDidCancelLoading: (NSURLHandle*)sender
{
  id	c = clientForHandle(_clients, sender);

  RETAIN(self);
  [sender removeClient: self];
  if (c != nil)
    {
      [clientsLock lock];
      NSMapRemove((NSMapTable*)_clients, (void*)sender);
      [clientsLock unlock];
      if ([c respondsToSelector: @selector(URLResourceDidCancelLoading:)])
	{
	  [c URLResourceDidCancelLoading: self];
	}
    }
  RELEASE(self);
}

- (void) URLHandleResourceDidFinishLoading: (NSURLHandle*)sender
{
  id	c = clientForHandle(_clients, sender);

  RETAIN(self);
  [sender removeClient: self];
  if (c != nil)
    {
      [clientsLock lock];
      NSMapRemove((NSMapTable*)_clients, (void*)sender);
      [clientsLock unlock];
      if ([c respondsToSelector: @selector(URLResourceDidFinishLoading:)])
	{
	  [c URLResourceDidFinishLoading: self];
	}
    }
  RELEASE(self);
}

@end



/**
 * An informal protocol to which clients may conform if they wish to be
 * notified of the progress in loading a URL for them.  NSURL conforms to
 * this protocol but all methods are implemented as no-ops.  See also
 * the [(NSURLHandleClient)] protocol.
 */
@implementation NSObject (NSURLClient)

- (void) URL: (NSURL*)sender
  resourceDataDidBecomeAvailable: (NSData*)newBytes
{
}

- (void) URL: (NSURL*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason
{
}

- (void) URLResourceDidCancelLoading: (NSURL*)sender
{
}

- (void) URLResourceDidFinishLoading: (NSURL*)sender
{
}

@end

@implementation NSURL (GNUstepBase)
- (NSString*) fullPath
{
  NSString	*path = nil;

  if (YES == myData->isGeneric || 0 == myData->scheme)
    {
      unsigned int	len = 3;

      if (_baseURL != nil)
        {
          if (baseData->path && *baseData->path)
            {
              len += strlen(baseData->path);
            }
          else if (baseData->hasNoPath == NO)
            {
              len++;
            }
        }
      if (myData->path && *myData->path)
        {
          len += strlen(myData->path);
        }
      else if (myData->hasNoPath == NO)
        {
          len++;
        }
      if (len > 3)
        {
          char		buf[len];
          char		*ptr;

          ptr = [self _path: buf withEscapes: NO];
          path = [NSString stringWithUTF8String: ptr];
        }
    }
  return path;
}

- (NSString*) pathWithEscapes
{
  NSString	*path = nil;

  if (YES == myData->isGeneric || 0 == myData->scheme)
    {
      unsigned int	len = 3;

      if (_baseURL != nil)
        {
          if (baseData->path && *baseData->path)
            {
              len += strlen(baseData->path);
            }
          else if (baseData->hasNoPath == NO)
            {
              len++;
            }
        }
      if (myData->path && *myData->path)
        {
          len += strlen(myData->path);
        }
      else if (myData->hasNoPath == NO)
        {
          len++;
        }
      if (len > 3)
        {
          char		buf[len];
          char		*ptr;

          ptr = [self _path: buf withEscapes: YES];
          path = [NSString stringWithUTF8String: ptr];
        }
    }
  return path;
}
@end


#define	GSInternal	NSURLQueryItemInternal
#include	"GSInternal.h"
GS_PRIVATE_INTERNAL(NSURLQueryItem)


@implementation NSURLQueryItem

// Creating query items.
+ (instancetype) queryItemWithName: (NSString*)name 
                             value: (NSString*)value
{
  NSURLQueryItem *newQueryItem = [[NSURLQueryItem alloc] initWithName: name
                                                                value: value];
  return AUTORELEASE(newQueryItem);
}

- (instancetype) init
{
  self = [self initWithName: nil value: nil];
  if (self != nil)
    {
    
    }
  return self;
}

- (instancetype) initWithName: (NSString*)name 
                        value: (NSString*)value
{
  self = [super init];
  if (self != nil)
    {
      GS_CREATE_INTERNAL(NSURLQueryItem);
      if (name)
	{
	  ASSIGNCOPY(internal->_name, name);
	}
      else
	{
	  /* OSX behaviour is to set an empty string for nil name property
	   */
	  ASSIGN(internal->_name, @"");
	}
      ASSIGNCOPY(internal->_value, value);
    }
  return self;
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      RELEASE(internal->_name);
      RELEASE(internal->_value);
      GS_DESTROY_INTERNAL(NSURLQueryItem);
    }
  DEALLOC
}

// Reading a name and value from a query
- (NSString*) name
{
  return internal->_name;
}

- (NSString*) value
{
  return internal->_value;
}

- (id) initWithCoder: (NSCoder*)acoder
{
  if ((self = [super init]) != nil)
    {
      if ([acoder allowsKeyedCoding])
        {
          internal->_name = [acoder decodeObjectForKey: @"NS.name"];
          internal->_value = [acoder decodeObjectForKey: @"NS.value"];
        }
      else
        {
          internal->_name = [acoder decodeObject];
          internal->_value = [acoder decodeObject];
        }
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder*)acoder
{
  if ([acoder allowsKeyedCoding])
    {
      [acoder encodeObject: internal->_name forKey: @"NS.name"];
      [acoder encodeObject: internal->_value forKey: @"NS.value"];
    }
  else
    {
      [acoder encodeObject: internal->_name];
      [acoder encodeObject: internal->_value];
    }
}

- (id) copyWithZone: (NSZone *)zone
{
    return [[[self class] allocWithZone: zone] initWithName: internal->_name
                                                      value: internal->_value];
}

@end


#undef	GSInternal
#define	GSInternal NSURLComponentsInternal
#include "GSInternal.h"
GS_PRIVATE_INTERNAL(NSURLComponents)


@implementation NSURLComponents 

static NSCharacterSet	*queryItemCharSet = nil;

+ (void) initialize
{
  if (nil == queryItemCharSet)
    {
      ENTER_POOL
      NSMutableCharacterSet	*m;

      m = [[NSCharacterSet URLQueryAllowedCharacterSet] mutableCopy];

      /* Rationale: if a query item contained an ampersand we would not be
       * able to tell where one name/value pair ends and the next starts,
       * so we cannot permit that character in an item.  Similarly, if a
       * query item contained an equals sign we would not be able to tell
       * where the name ends and the value starts, so we cannot permit that
       * character either.
       */
      [m removeCharactersInString: @"&="];
      queryItemCharSet = [m copy];
      RELEASE(m);
      LEAVE_POOL
    }
}

// Creating URL components...
+ (instancetype) componentsWithString: (NSString *)urlString
{
  return AUTORELEASE([[NSURLComponents alloc] initWithString: urlString]);
}

+ (instancetype) componentsWithString: (NSString*)URLString
            encodingInvalidCharacters: (BOOL)encodingInvalidCharacters
{
  return AUTORELEASE([[NSURLComponents alloc] initWithString: URLString
    encodingInvalidCharacters: encodingInvalidCharacters]);
}

+ (instancetype) componentsWithURL: (NSURL *)url 
           resolvingAgainstBaseURL: (BOOL)resolve
{
  return AUTORELEASE([[NSURLComponents alloc] initWithURL: url
    resolvingAgainstBaseURL: resolve]);
}

- (instancetype) init
{
  self = [super init];
  if (self != nil)
    {
      GS_CREATE_INTERNAL(NSURLComponents);
      
      internal->_rangeOfFragment = NSMakeRange(NSNotFound, 0);
      internal->_rangeOfHost     = NSMakeRange(NSNotFound, 0);
      internal->_rangeOfPassword = NSMakeRange(NSNotFound, 0);
      internal->_rangeOfPath     = NSMakeRange(NSNotFound, 0);
      internal->_rangeOfPort     = NSMakeRange(NSNotFound, 0);
      internal->_rangeOfQuery    = NSMakeRange(NSNotFound, 0);
      internal->_rangeOfScheme   = NSMakeRange(NSNotFound, 0);
      internal->_rangeOfUser     = NSMakeRange(NSNotFound, 0);
    }
  return self;
}

/* The following function expects a normalised string where hex
 * digits are uppercase.
 */
static inline uint8_t
hexToByte(char u, char l)
{
  uint8_t	byte;

  if (isupper(u))
    byte = u - 'A' + 10;
  else
    byte = u - '0';
  byte <<= 4;
  if (isupper(u))
    byte |= l - 'A' + 10;
  else
    byte |= l - '0';
  return byte;
}


typedef struct {
  NSString	*err;
  NSMutableData	*md;
  const uint8_t	*bytes;
  NSRange	scheme;
  NSRange	user;
  NSRange	password;
  NSRange	host;
  NSRange	port;
  NSRange	path;
  NSRange	query;
  NSRange	fragment;
} ParsedURL;


typedef struct {
  const uint8_t	*start;
  unsigned	cursor;
  unsigned	mark;
  uint8_t	p;
  uint8_t	u;
  uint8_t	l;
} URISource;

/* Get a character, percent encoding any invalid characters (marking position
 * of the first invalid character after the start), using the 'legal' string
 * as a set of extra characters considered valid in the current context.
 * The 'term' string provides an extra set of legal characters which are
 * permitted.
 *
 * NB.
 * Alphanumeric characters are counted as valid.
 * The non-ascii (>127) and non-printable characters (126 or <=32) are
 * counted as invalid.
 * The percent character is a special case which is valid when it introduces
 * two hexadecimal digits encofding a byte, and is invalid otherwise.
 * As a special case, if 'legal' is a null pointer, any character (other than
 * a percent without its following hex digits), is counted valid.
 */
static inline uint8_t
get(URISource *src, const char *legal, const char *term)
{
  uint8_t	c;

  if ((c = src->p) != '\0')
    {
      /* The pushed back character may need further checks to see if
       * it is allowed in the current context.
       */
      src->p = 0;
    }
  else
    {
      /* Hex digits never need further processing and can be returned
       * immediately, avoiding  any additional work.
       */
      if ((c = src->u) != '\0')
	{
	  src->u = 0;
	  return c;
	}
      if ((c = src->l) != '\0')
	{
	  src->l = 0;
	  return c;
	}

      if ((c = src->start[src->cursor]) != '\0')
	{
	  src->cursor++;	// We have read one byte

	  /* A percent is always allowed, but it must either introduce a
	   * hexadecimal percent encoding sequence or it needs to be
	   * encoded itself;
	   */
	  if ('%' == c)
	    {
	      uint8_t	u;
	      uint8_t	l;

	      if ((u = src->start[src->cursor]) > 126 || !isxdigit(u)
		|| (l = src->start[src->cursor + 1]) > 126 || !isxdigit(l))
		{
		  /* Input is too short or the next two characters are not
		   * hexadecimal, so we must escape the percent.
		   */
		  src->u = '2';
		  src->l = '5';
		  if (0 == src->mark)
		    {
		      src->mark = src->cursor - 1;
		    }
		}
	      else
		{
		  uint8_t	byte;

		  if (islower(u))
		    {
		      u = u - 'a' + 'A';
		    }
		  if (islower(l))
		    {
		      l = l - 'a' + 'A';
		    }
		  byte = hexToByte(u, l);
		  if (isalnum(byte) || strchr("-._~", byte))
		    {
		      /* Unreserved character should not be percent encoded
		       * so just return that.
		       */
		      c = byte;
		    }
		  else
		    {
		      /* Cache the next two bytes since we know that they are
		       * parts of a percnt encoding and we have standardised
		       * them to uppercase.
		       */
		      src->u = u;
		      src->l = l;
		    }
		  /* We have read past the next two hex digits, and either used
		   * them to create an unreserved character or cached them for
		   * the next two alls to this function.
		   */
		  src->cursor += 2;
		}
	    }
	}
    }

  if (legal != NULL && c != '%' && c != '\0')
    {
      if (NULL == term) term = "";
      /* Perform checking for valid characters and percent encode any
       * which are not valid in the current context.
       */
      if (c <= ' ' || c > 126
	|| (!isalnum(c) && !strchr(legal, c) && !strchr(term, c)))
	{
	  src->u = "0123456789ABCDEF"[(c & 0xf0) >> 4];
	  src->l = "0123456789ABCDEF"[c & 0x0f];
	  c = '%';
	  if (0 == src->mark)
	    {
	      src->mark = src->cursor - 1;
	    }
	}
    }
  return c;
}

/* Permit a single character pushback onto the input stream.
 * Pushing back a nul character has no effect.
 */
static inline void
push(URISource *src, uint8_t c)
{
  /* We can't push back a percent unless we are actually at the start of
   * a percent encoded sequence.
   */
  NSCAssert(c != '%' || (src->u && src->l), NSInvalidArgumentException);
  NSCAssert('\0' == src->p, NSInternalInconsistencyException);
  src->p = c;
}

static uint8_t
scanComponent(URISource *input, const char *legal, const char *term,
  NSRange *range, NSMutableData *output)
{
  NSRange	r = NSMakeRange([output length], 0);
  uint8_t	c = get(input, legal, term);

  while (c != '\0' && strchr(term, c) == NULL)
    {
      [output appendBytes: &c length: 1];
      c = get(input, legal, term);
    }
  r.length = [output length] - r.location;
  if (range)
    {
      *range = r;
    }
  return c;
}

static uint8_t
scanIpLiteral(URISource *input, NSRange *range, NSMutableData *output,
  NSString **err)
{
  const char    *addrLegal = "-.~%!$&'()*+,;=[:";
  NSRange	r;
  uint8_t	c;
  
  [output appendBytes: "[" length: 1];
  c = scanComponent(input, addrLegal, "]@/?#", &r, output);
  if (c != ']')
    {
      ASSIGN(*err, @"Bad Authority Host component - [...] not terminated");
    }
  else
    {
      [output appendBytes: "]" length: 1];
      r.location -= 1;				// Step back to '['
      r.length += 2;				// Allow for '[' and ']'
      c = get(input, NULL, "");
      if (c != '\0' && strchr(":@/?#", c) == NULL)
	{
	  ASSIGN(*err, @"Bad Authority Host component - character after ']'");
	}
    }
  if (range != NULL)
    {
      *range = r;
    }
  return c;
}

static NSString *
makeAscii(NSRange r, const uint8_t *bytes)
{
  if (r.location != NSNotFound)
    {
      NSString	*s;

      s = [[NSString alloc] initWithBytes: bytes + r.location
				   length: r.length
				 encoding: NSASCIIStringEncoding];
      return AUTORELEASE(s);
    }
  return nil;
}

/*
static NSString *
makeUTF8(NSRange r, const uint8_t *bytes)
{
  if (NSNotFound == r.location)
    {
      return nil;
    }
  else if (0 == r.length)
    {
      return @"";
    }
  else
    {
      NSString		*s;
      uint8_t		dst[r.length];
      const uint8_t	*from = bytes + r.location;
      const uint8_t	*end = from + r.length;
      uint8_t		*to = dst;
      uint8_t		u;
      uint8_t		l;

      while (from < end)
	{
	  if ('%' == from[0] && from + 2 < end
	    && (u = from[1]) < 128 && isxdigit(u)
	    && (l = from[2]) < 128 && isxdigit(l))
	    {
	      *to++ = hexToByte(u, l);
	      from += 3;
	    }
	  else
	    {
	      *to++ = *from++;
	    }
	}

      s = [[NSString alloc] initWithBytes: dst
				   length: to - dst
				 encoding: NSUTF8StringEncoding];
      return AUTORELEASE(s);
    }
  return nil;
}
*/

static NSNumber *
makePort(NSRange r, const uint8_t *bytes)
{
  if (r.location != NSNotFound)
    {
      NSUInteger	i; 
      int		n = 0;

      for (i = r.location; i < NSMaxRange(r); i++)
	{
	  n = n * 10 + bytes[i] - '0';
	}
      return [NSNumber numberWithInt: n];
    }
  return nil;
}

  static BOOL
  parseURL(NSString *str, ParsedURL *parsed, BOOL encodingInvalidCharacters)
  {
    // Unreserved:  -._~
    // Percent-uncoded: %
    // Sub-delims !$&'()*+,;=
    const char	*authLegal = "-.~%!$&'()*+,;=";
    const char	*pathLegal = "-.~%!$&'()*+,;=@:/";
    const char	*queryLegal = "-.~%!$&'()*+,;=@:/?";
    URISource	input;
    uint8_t	c;

    if (NO == [str isKindOfClass: [NSString class]])
      {
	return NO;
      }

    parsed->err = nil;
    parsed->scheme = NSMakeRange(NSNotFound, 0);
    parsed->user = NSMakeRange(NSNotFound, 0);
    parsed->password = NSMakeRange(NSNotFound, 0);
    parsed->host = NSMakeRange(NSNotFound, 0);
    parsed->port = NSMakeRange(NSNotFound, 0);
    parsed->path = NSMakeRange(NSNotFound, 0);
    parsed->query = NSMakeRange(NSNotFound, 0);
    parsed->fragment = NSMakeRange(NSNotFound, 0);

  #define	ERR(X) ({ASSIGN(parsed->err, (X)); goto done;})

    /* RFC3986 parsing
     */

    memset(&input, '\0', sizeof(input));
    input.start = (const uint8_t*)[str UTF8String];

    parsed->md = [[NSMutableData alloc] initWithCapacity: [str length] * 3];

    /* The scheme starts with a letter and is alphanumeric with '+-.' chars.
     * Percent encoded characters are not permitted and it is terminated by
     * a colon.
     */
    c = scanComponent(&input, "+-.", ":%", &parsed->scheme, parsed->md);
    if ('%' == c)
      {
	ERR(@"Bad Scheme component - illegal character present");
      }
    else if ('\0' == c) 
      {
	if (0 == parsed->scheme.length)
	  {
	    ERR(@"Bad Scheme component - empty string");
	  }
	else
	  {
	    ERR(@"Bad Scheme component - no ':' present");
	  }
      }
    else if (0 == parsed->scheme.length)
      {
	ERR(@"Bad Scheme component - empty string ':'");
      }
    [parsed->md appendBytes: ":" length: 1];

    if ((c = get(&input, NULL, "")) != '/')
      {
	// c should be '?' or '#' or '\0'
      }
    else if ((c = get(&input, NULL, "")) != '/')
      {
	push(&input, c);
	c = '/';
      }
    else
      {
	NSRange		one;
	NSRange		two;
	NSUInteger	markOne;
	NSUInteger	markTwo;

	// Start of the Authority found
	[parsed->md appendBytes: "//" length: 2];

	if ((c = get(&input, NULL, "")) == '[')
	  {
	    c = scanIpLiteral(&input, &one, parsed->md, &parsed->err);
	    if (parsed->err)
	      {
		goto done;
	      }
	  }
	else
	  {
	    push(&input, c);
	    c = scanComponent(&input, authLegal, ":@/?#", &one, parsed->md);
	  } 
	markOne = input.mark;
	input.mark = 0;
	if (':' == c)
	  {
	    [parsed->md appendBytes: ":" length: 1];
	    c = scanComponent(&input, authLegal, "@/?#", &two, parsed->md);
	    markTwo = input.mark;
	    input.mark = 0;
	  }
	else
	  {
	    two = NSMakeRange(NSNotFound, 0);
	    markTwo = 0;
	  }
	if ('@' == c)
	  {
	    parsed->user = one;
	    if (markOne && NO == encodingInvalidCharacters)
	      {
		ERR(@"Bad Authority User component - illegal character");
	      }
	    parsed->password = two;
	    if (markTwo && NO == encodingInvalidCharacters)
	      {
		ERR(@"Bad Authority Password component - illegal character");
	      }
	    [parsed->md appendBytes: "@" length: 1];

	    if ((c = get(&input, NULL, "")) == '[')
	      {
		c = scanIpLiteral(&input, &one, parsed->md, &parsed->err);
		if (parsed->err)
		  {
		    goto done;
		  }
	      }
	    else
	      {
		push(&input, c);
		c = scanComponent(&input, authLegal, ":/?#", &one, parsed->md);
	      } 
	    markOne = input.mark;
	    input.mark = 0;

	    if (':' == c)
	      {
		[parsed->md appendBytes: ":" length: 1];
		c = scanComponent(&input, authLegal, "/?#", &two, parsed->md);
		markTwo = input.mark;
		input.mark = 0;
	      }
	    else
	      {
		two = NSMakeRange(NSNotFound, 0);
		markTwo = 0;
	      }
	  }

	parsed->host = one;
	if (0 == parsed->host.length)
	  {
	    ERR(@"Bad Authority Host component - empty string");
	  }
	else
	  {
	    uint8_t	*s;
	    unsigned	len = parsed->host.length;
	    BOOL		isName = NO;
	    uint8_t	save;

	    s = ((uint8_t*)[parsed->md mutableBytes]) + parsed->host.location;
	    if ('[' == *s)
	      {
		uint8_t	dst[sizeof(struct in6_addr)];
		uint8_t	*buf = s + 1;

		len -= 2;
		save = buf[len];
		buf[len] = '\0';
		if ('v' == buf[0])
		  {
		  ERR(@"Bad Host component - unsupported future format");
		}
	      else if (inet_pton(AF_INET6, (const char*)buf, dst) != 1)
		{
		  ERR(@"Bad Host component - malformed IPV6 address");
		}
	      buf[len] = save;
	    }
	  else
	    {
	      uint8_t	dst[sizeof(struct in_addr)];

	      save = s[len];
	      s[len] = '\0';
	      if (inet_pton(AF_INET, (const char*)s, dst) != 1)
		{
		  /* Not an IP address, must be host name
		   */
		  isName = YES;
		}
	      s[len] = save;
	    }
	  if (isName)
	    {
	    }
	}

      parsed->port = two;
      if (NSNotFound != parsed->port.location)
	{
	  if (0 == parsed->port.length)
	    {
	      /* Empty port ... normalise by removing the ':' before it.
	       */
	      [parsed->md setLength: [parsed->md length] - 1];
	    }
	  else
	    {
	      const char	*p;
	      NSUInteger	i;
	      char		buf[12];
	      int		value = 0;

	      p = ((const char*)[parsed->md bytes]) + parsed->port.location;
	      for (i = 0; i < parsed->port.length; i++)
		{
		  if (!isdigit(p[i]))
		    {
		      ERR(@"Bad Authority Port component - non digit found");
		    }
		  value = value * 10 + (p[i] - '0');
		  if (value > 0xffff)
		    {
		      ERR(@"Bad Authority Port component - number too large");
		    }
		}
	      sprintf(buf, "%d", value);
	      i = strlen(buf);
	      if (i != parsed->port.length)
		{
		  [parsed->md replaceBytesInRange: parsed->port 
					withBytes: buf
					   length: i];
		  parsed->port.length = i;
		}
	    }
	}
    }
  /* Unless we have the query string or the fragment, we have the first
   * character of the path (or the path is empty).
   */
  if (c != '?' && c != '#' && c != '\0')
    {
      push(&input, c);
      c = scanComponent(&input, pathLegal, "?#", &parsed->path, parsed->md);
      if (input.mark && NO == encodingInvalidCharacters)
	{
	  ERR(@"Bad Path component - illegal character");
	}
    }
  else
    {
      parsed->path = NSMakeRange([parsed->md length], 0);
    }
  if ('?' == c)
    {
      [parsed->md appendBytes: "?" length: 1];
      c = scanComponent(&input, queryLegal, "#", &parsed->query, parsed->md);
      if (input.mark && NO == encodingInvalidCharacters)
	{
	  ERR(@"Bad Query component - illegal character");
	}
    }
  if ('#' == c)
    {
      /* NB. The set of legal characters inside a fragment is the same
       * as those in the query string ... a fragment must not contain
       * a hash (unless percent encoded of course).
       */
      [parsed->md appendBytes: "#" length: 1];
      c = scanComponent(&input, queryLegal, "", &parsed->fragment, parsed->md);
      if (input.mark && NO == encodingInvalidCharacters)
	{
	  ERR(@"Bad Fragment component - illegal character");
	}
    }

done:
  if (parsed->err)
    {
NSLog(@"%@", parsed->err);
      return NO;
    }
  parsed->bytes = (const uint8_t*)[parsed->md bytes];
  return YES;
}

- (instancetype) initWithString: (NSString*)URLString 
      encodingInvalidCharacters: (BOOL)encodingInvalidCharacters
{
  ParsedURL	parsed;

  if (NO == [URLString isKindOfClass: [NSString class]])
    {
      DESTROY(self);
      return self;
    }
  if (nil == (self = [self init]))
    {
      return self;
    }

  parsed.scheme = NSMakeRange(NSNotFound, 0);
  parsed.user = NSMakeRange(NSNotFound, 0);
  parsed.password = NSMakeRange(NSNotFound, 0);
  parsed.host = NSMakeRange(NSNotFound, 0);
  parsed.port = NSMakeRange(NSNotFound, 0);
  parsed.path = NSMakeRange(NSNotFound, 0);
  parsed.query = NSMakeRange(NSNotFound, 0);
  parsed.fragment = NSMakeRange(NSNotFound, 0);

  if (parseURL(URLString, &parsed, encodingInvalidCharacters))
    {
      [self setScheme: makeAscii(parsed.scheme, parsed.bytes)];
      [self setUser: makeAscii(parsed.user, parsed.bytes)];
      [self setPassword: makeAscii(parsed.password, parsed.bytes)];
      [self setHost: makeAscii(parsed.host, parsed.bytes)];
      [self setPort: makePort(parsed.port, parsed.bytes)];
      [self setPath: makeAscii(parsed.path, parsed.bytes)];
      [self setQuery: makeAscii(parsed.query, parsed.bytes)];
      [self setFragment: makeAscii(parsed.fragment, parsed.bytes)];
      DESTROY(parsed.err);
      DESTROY(parsed.md);
    }
  else
    {
      if (parsed.err)
	{
	  NSLog(@"%@", parsed.err);
	  DESTROY(parsed.err);
	}
      DESTROY(parsed.md);
      DESTROY(self);
    }

  return self;
}

- (instancetype) initWithString: (NSString*)URLString
{
#if 0
  /* OSX behavior is to return nil for a string which cannot be
   * used to initialize valid NSURL object
   */
  NSURL	*url = [NSURL URLWithString: URLString];
  if (url)
    {
      return [self initWithURL: url resolvingAgainstBaseURL: NO];
    }
  else
    {
      RELEASE(self);
      return nil;
    }
#else
  return [self initWithString: URLString 
    encodingInvalidCharacters: NO];
#endif
}

- (instancetype) initWithURL: (NSURL *)url 
     resolvingAgainstBaseURL: (BOOL)resolve
{
  self = [self init];
  if (self != nil)
    {
      NSURL *tempURL = url;

      if (resolve)
        {
          tempURL = [url absoluteURL];
        }
      [self setURL: tempURL];
    }
  return self;
}

- (void) dealloc
{
  if (GS_EXISTS_INTERNAL)
    {
      RELEASE(internal->_string);
      RELEASE(internal->_fragment);
      RELEASE(internal->_host);
      RELEASE(internal->_password);
      RELEASE(internal->_path);
      RELEASE(internal->_port);
      RELEASE(internal->_queryItems);
      RELEASE(internal->_scheme);
      RELEASE(internal->_user);
      GS_DESTROY_INTERNAL(NSURLComponents);
    }
  DEALLOC
}

- (id) copyWithZone: (NSZone *)zone
{
  return [[NSURLComponents allocWithZone: zone] initWithURL: [self URL]
                                    resolvingAgainstBaseURL: NO];
}

// Regenerate URL when components are changed...
- (void) _regenerateURL
{
  NSMutableString	*urlString;
  NSString		*component;
  NSUInteger 	 	location;
  NSUInteger 		len;
  
  if (internal->_dirty == NO)
    {
      return;
    }

  urlString = [[NSMutableString alloc] initWithCapacity: 1000];
  location = 0;
  // Build up the URL from components...
  if (internal->_scheme != nil)
    {
      component = [self scheme];
      [urlString appendString: component];
      len = [component length];
      internal->_rangeOfScheme = NSMakeRange(location, len);
      [urlString appendString: @"://"];
      location += len + 3;
    }
  else
    {
      internal->_rangeOfScheme = NSMakeRange(NSNotFound, 0);
    }

  if (internal->_user != nil) 
    {
      if (internal->_password != nil)
        {
          component = [self percentEncodedUser];
	  len = [component length];
          [urlString appendString: component];
          internal->_rangeOfUser = NSMakeRange(location, len);
          [urlString appendString: @":"];
          location += len + 1;

          component = [self percentEncodedPassword];
	  len = [component length];
          [urlString appendString: component];
          internal->_rangeOfUser = NSMakeRange(location, len);
          [urlString appendString: @"@"];
          location += len + 1;
        }
      else
        {
          component = [self percentEncodedUser];
	  len = [component length];
          [urlString appendString: component];
          internal->_rangeOfUser = NSMakeRange(location, len);
          [urlString appendString: @"@"];
          location += len + 1;
          internal->_rangeOfPassword = NSMakeRange(NSNotFound, 0);
        }
    }
  else
    {
      internal->_rangeOfUser = NSMakeRange(NSNotFound, 0);
      internal->_rangeOfPassword = NSMakeRange(NSNotFound, 0);
    }

  if (internal->_host != nil)
    {
      component = [self percentEncodedHost];
      len = [component length];
      [urlString appendString: component];
      internal->_rangeOfHost = NSMakeRange(location, len);
      location += len;
    }
  else
    {
      internal->_rangeOfHost = NSMakeRange(NSNotFound, 0);
    }

  if (internal->_port != nil)
    {
      component = [[self port] stringValue];
      len = [component length];
      [urlString appendString: @":"];
      location += 1;
      [urlString appendString: component];
      internal->_rangeOfPort = NSMakeRange(location, len);
      location += len;
    }
  else
    {
      internal->_rangeOfPort = NSMakeRange(NSNotFound, 0);
    }

  /* A nil _path indicates that we do not have a '/'.
   */
  if (internal->_path != nil)
    {
      component = [self percentEncodedPath];
      len = [component length];
      [urlString appendString: component];
      internal->_rangeOfPath = NSMakeRange(location, len);
      location += len;
    }
  else
    {
      internal->_rangeOfPath = NSMakeRange(NSNotFound, 0);
    }

  if ([internal->_queryItems count] > 0)
    {
      component = [self percentEncodedQuery];
      len = [component length];
      [urlString appendString: @"?"];
      location += 1;
      [urlString appendString: component];
      internal->_rangeOfQuery = NSMakeRange(location, len);
      location += len;
    }
  else
    {
      internal->_rangeOfQuery = NSMakeRange(NSNotFound, 0);
    }

  if (internal->_fragment != nil)
    {
      component = [self percentEncodedFragment];
      len = [component length];
      [urlString appendString: @"#"];
      location += 1;
      [urlString appendString: component];
      internal->_rangeOfFragment = NSMakeRange(location, len);
    }
  else
    {
      internal->_rangeOfFragment = NSMakeRange(NSNotFound, 0);
    }
    
  ASSIGNCOPY(internal->_string, urlString);
  RELEASE(urlString);
  internal->_dirty = NO;
}

// Getting the URL
- (NSString *) string
{
  [self _regenerateURL];
  return internal->_string;
}

- (void) setString: (NSString *)urlString
{
  NSURL *url = [NSURL URLWithString: urlString];
  [self setURL: url];
}

- (NSURL *) URL
{
  return AUTORELEASE([[NSURL alloc] initWithScheme: [self scheme]
                                              user: [self user]
                                          password: [self password]
                                              host: [self host]
                                              port: [self port]
                                          fullPath: [self path]
                                   parameterString: nil
                                             query: [self query]
                                          fragment: [self fragment]]);
}

- (void) setURL: (NSURL*)url
{
  // Set all the components...
  [self setScheme: [url scheme]];
  [self setHost: [url host]];
  [self setPort: [url port]];
  [self setUser: [url user]];
  [self setPassword: [url password]];
  [self setPath: [url path]];
  [self setPercentEncodedQuery: [url query]];
  [self setFragment: [url fragment]];
}

- (NSURL*) URLRelativeToURL: (NSURL*)baseURL
{
  return nil;
}

// Accessing Components in Native Format
- (NSString*) fragment
{
  return [internal->_fragment stringByRemovingPercentEncoding];
}

- (void) setFragment: (NSString*)fragment
{
  [self setPercentEncodedFragment: [fragment
    stringByAddingPercentEncodingWithAllowedCharacters:
    [NSCharacterSet URLFragmentAllowedCharacterSet]]];
}

- (NSString*) host
{
  return [internal->_host stringByRemovingPercentEncoding];
}

- (void) setHost: (NSString*)host
{
  [self setPercentEncodedHost:
    [host stringByAddingPercentEncodingWithAllowedCharacters:
    [NSCharacterSet URLHostAllowedCharacterSet]]];
}

- (NSString*) password
{
  return [internal->_password stringByRemovingPercentEncoding];
}

- (void) setPassword: (NSString*)password
{
  [self setPercentEncodedPassword: [password
    stringByAddingPercentEncodingWithAllowedCharacters:
    [NSCharacterSet URLPasswordAllowedCharacterSet]]];
}

- (NSString *) path
{
  return [internal->_path stringByRemovingPercentEncoding];
}

- (void) setPath: (NSString *)path
{
  [self setPercentEncodedPath: [path
    stringByAddingPercentEncodingWithAllowedCharacters:
    [NSCharacterSet URLPathAllowedCharacterSet]]];
}

- (NSNumber*) port
{
  return internal->_port;
}

#define	SETIFCHANGED(ivar, value) \
({ \
  if (internal->ivar != value && NO == [internal->ivar isEqual: value]) \
    { \
      ASSIGNCOPY(internal->ivar, value); \
      internal->_dirty = YES; \
    } \
})

- (void) setPort: (NSNumber*)port
{
  SETIFCHANGED(_port, port);
}

- (NSString *) query
{
  NSString	*result = nil;

  if (internal->_queryItems != nil)
    {
      NSMutableString	*query = nil;
      NSURLQueryItem	*item = nil;
      NSEnumerator	*en;

      en = [internal->_queryItems objectEnumerator];
      while ((item = (NSURLQueryItem *)[en nextObject]) != nil)
	{
	  NSString	*name = [item name];
	  NSString	*value = [item value];

	  if (nil == query)
	    {
	      query = [[NSMutableString alloc] initWithCapacity: 1000];
	    }
	  else
	    {
	      [query appendString: @"&"];
	    }
	  [query appendString: name];
	  if (value != nil)
	    {
	      [query appendString: @"="];
	      [query appendString: value];
	    }
	}
      if (nil == query)
	{
	  result = @"";
	}
      else
	{
	  result = AUTORELEASE([query copy]);
	  RELEASE(query);
	}
    }
  return result;
}

- (void) _setQuery: (NSString*)query fromPercentEncodedString: (BOOL)encoded
{
  /* Parse according to https://developer.apple.com/documentation/foundation/nsurlcomponents/1407752-queryitems?language=objc
   */
  if (nil == query)
    {
      [self setQueryItems: nil];
    }
  else if ([query length] == 0)
    {
      [self setQueryItems: [NSArray array]];
    }
  else
    {
      NSMutableArray	*result = [NSMutableArray arrayWithCapacity: 5];
      NSArray 		*items = [query componentsSeparatedByString: @"&"];
      NSEnumerator	*en = [items objectEnumerator];
      id		item = nil;

      while ((item = [en nextObject]) != nil)
        {
          NSURLQueryItem	*qitem;
	  NSString		*name;
	  NSString		*value;

	  if ([item length] == 0)
	    {
	      name = @"";
	      value = nil;
	    }
	  else
	    {
	      NSRange	r = [item rangeOfString: @"="];

	      if (0 == r.length)
		{
		  /* No '=' found in query item.  */
		  name = item;
		  value = nil;
		}
	      else
		{
		  name = [item substringToIndex: r.location];
		  value = [item substringFromIndex: NSMaxRange(r)];
		}
	    }
	  if (encoded)
	    {
	      name = [name stringByRemovingPercentEncoding];
	      value = [value stringByRemovingPercentEncoding];
	    }
          qitem = [NSURLQueryItem queryItemWithName: name value: value];
          [result addObject: qitem];
        }
      [self setQueryItems: result];
    }
}

- (void) setQuery: (NSString*)query
{
  [self _setQuery: query fromPercentEncodedString: NO];
}

- (NSArray *) queryItems
{
  return AUTORELEASE(RETAIN(internal->_queryItems));
}

- (void) setQueryItems: (NSArray*)queryItems
{ 
  SETIFCHANGED(_queryItems, queryItems);
}

- (NSString*) scheme
{
  return internal->_scheme;
}

- (void) setScheme: (NSString*)scheme
{
  SETIFCHANGED(_scheme, scheme);
}

- (NSString*) user
{
  return [internal->_user stringByRemovingPercentEncoding];
}

- (void) setUser: (NSString*)user
{
  [self setPercentEncodedUser: 
    [user stringByAddingPercentEncodingWithAllowedCharacters:
    [NSCharacterSet URLUserAllowedCharacterSet]]];
}

// Accessing Components in PercentEncoded Format
- (NSString *) percentEncodedFragment
{
  return internal->_fragment;
}

- (void) setPercentEncodedFragment: (NSString*)fragment
{
  SETIFCHANGED(_fragment, fragment);
}

- (NSString *) percentEncodedHost
{
  return internal->_host;
}

- (void) setPercentEncodedHost: (NSString*)host
{
  SETIFCHANGED(_host, host);
}

- (NSString *) percentEncodedPassword
{
  return internal->_password;
}

- (void) setPercentEncodedPassword: (NSString*)password
{
  SETIFCHANGED(_password, password);
}

- (NSString *) percentEncodedPath
{
  return internal->_path;
}

- (void) setPercentEncodedPath: (NSString*)path
{
  SETIFCHANGED(_path, path);
}

- (NSString*) percentEncodedQuery
{
  NSString	*result = nil;

  if (internal->_queryItems != nil)
    {
      NSMutableString	*query = nil;
      NSURLQueryItem	*item = nil;
      NSEnumerator	*en;

      en = [[self percentEncodedQueryItems] objectEnumerator];
      while ((item = (NSURLQueryItem *)[en nextObject]) != nil)
	{
	  NSString	*name = [item name];
	  NSString	*value = [item value];

	  if (nil == query)
	    {
	      query = [[NSMutableString alloc] initWithCapacity: 1000];
	    }
	  else
	    {
	      [query appendString: @"&"];
	    }
	  [query appendString: name];
	  if (value != nil)
	    {
	      [query appendString: @"="];
	      [query appendString: value];
	    }
	}
      if (nil == query)
	{
	  result = @"";
	}
      else
	{
	  result = AUTORELEASE([query copy]);
	  RELEASE(query);
	}
    }
  return result;
}

- (void) setPercentEncodedQuery: (NSString*)query
{
  [self _setQuery: query fromPercentEncodedString: YES];
}

- (NSArray*) percentEncodedQueryItems
{
  NSArray	*result = nil;

  if (internal->_queryItems != nil)
    {
      NSMutableArray	*items;
      NSEnumerator 	*en = [internal->_queryItems objectEnumerator];
      NSURLQueryItem	*i = nil;

      items = [[NSMutableArray alloc]
	initWithCapacity: [internal->_queryItems count]];
      while ((i = [en nextObject]) != nil)
	{
	  NSURLQueryItem	*ni;
	  NSString		*name = [i name];
	  NSString		*value = [i value];

	  name = [name stringByAddingPercentEncodingWithAllowedCharacters:
	    queryItemCharSet];
	  value = [value stringByAddingPercentEncodingWithAllowedCharacters:
	    queryItemCharSet];
	  ni = [NSURLQueryItem queryItemWithName: name
					   value: value];
	  [items addObject: ni];
	}
      result = AUTORELEASE([items copy]);
      RELEASE(items);
    }
  return result;
}

- (void) setPercentEncodedQueryItems: (NSArray*)queryItems
{
  NSMutableArray	*items = nil;

  if (queryItems != nil)
    {
      NSEnumerator	*en = [queryItems objectEnumerator];
      NSURLQueryItem 	*i = nil;

      items = [NSMutableArray arrayWithCapacity: [queryItems count]];
      while ((i = [en nextObject]) != nil)
	{
	  NSString		*name;
	  NSString		*value;
	  NSURLQueryItem	*ni;

	  name = [[i name] stringByRemovingPercentEncoding];
	  value = [[i value] stringByRemovingPercentEncoding];
	  ni = [NSURLQueryItem queryItemWithName: name value: value];
	  [items addObject: ni];
	}
    }

  [self setQueryItems: items];
}

- (NSString*) percentEncodedUser
{
  return internal->_user;
}

- (void) setPercentEncodedUser: (NSString*)user
{
  SETIFCHANGED(_user, user);
}

// Locating components of the URL string representation
- (NSRange) rangeOfFragment
{
  [self _regenerateURL];
  return internal->_rangeOfFragment;
}

- (NSRange) rangeOfHost
{
  [self _regenerateURL];
  return internal->_rangeOfHost;
}

- (NSRange) rangeOfPassword
{
  [self _regenerateURL];
  return internal->_rangeOfPassword;
}

- (NSRange) rangeOfPath
{
  [self _regenerateURL];
  return internal->_rangeOfPath;
}

- (NSRange) rangeOfPort
{
  [self _regenerateURL];
  return internal->_rangeOfPort;
}

- (NSRange) rangeOfQuery
{
  [self _regenerateURL];
  return internal->_rangeOfQuery;
}

- (NSRange) rangeOfScheme
{
  [self _regenerateURL];
  return internal->_rangeOfScheme;
}

- (NSRange) rangeOfUser
{
  [self _regenerateURL];
  return internal->_rangeOfUser;
}
  
@end
