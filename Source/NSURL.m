/** NSUrl.m - Class NSURL
   Copyright (C) 1999 Free Software Foundation, Inc.
   
   Written by: 	Manuel Guesdon <mguesdon@sbuilders.com>
   Date: 	Jan 1999
   
   Rewrite by: 	Richard Frith-Macdonald <rfm@gnu.org>
   Date: 	Jun 2002

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful, 
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Library General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.

   <title>NSURL class reference</title>
   $Date$ $Revision$
*/

/*
Note from Manuel Guesdon: 
* I've made some test to compare apple NSURL results 
and GNUstep NSURL results but as there this class is not very documented, some
function may be incorrect
* I've put 2 functions to make tests. You can add your own tests
* Some functions are not implemented
*/
#include <config.h>
#include <base/behavior.h>
#include <Foundation/NSObject.h>
#include <Foundation/NSCoder.h>
#include <Foundation/NSArray.h>
#include <Foundation/NSDictionary.h>
#include <Foundation/NSString.h>
#include <Foundation/NSException.h>
#include <Foundation/NSConcreteNumber.h>
#include <Foundation/NSLock.h>
#include <Foundation/NSMapTable.h>
#include <Foundation/NSURLHandle.h>
#include <Foundation/NSURL.h>
#include <Foundation/NSRunLoop.h>
#include <Foundation/NSZone.h>

NSString	*NSURLFileScheme = @"file";

/*
 * Structure describing a URL.
 * All the char* fields may be NULL pointers, except path, which
 * is *always* non-null (though it may be an empty string).
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
  BOOL	isGeneric;
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
static void unescape(const char *from, char * to);

/**
 * Build an absolute URL as a C string
 */
static char *buildURL(parsedURL *base, parsedURL *rel, BOOL standardize)
{
  char		*buf;
  char		*ptr;
  char		*tmp;
  unsigned int	len = 1;

  if (rel->scheme != 0)
    {
      len += strlen(rel->scheme) + 3;	// scheme://
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
      len += strlen(rel->path) + 1;	// path
    }
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

  ptr = buf = (char*)NSZoneMalloc(GSAtomicMallocZone(), len);

  if (rel->scheme != 0)
    {
      strcpy(ptr, rel->scheme);
      ptr = &ptr[strlen(ptr)];
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
	      strcpy(ptr, rel->user);
	      ptr = &ptr[strlen(ptr)];
	    }
	  if (rel->password != 0)
	    {
	      *ptr++ = ':';
	      strcpy(ptr, rel->password);
	      ptr = &ptr[strlen(ptr)];
	    }
	  if (rel->host != 0 || rel->port != 0)
	    {
	      *ptr++ = '@';
	    }
	}
      if (rel->host != 0)
	{
	  strcpy(ptr, rel->host);
	  ptr = &ptr[strlen(ptr)];
	}
      if (rel->port != 0)
	{
	  *ptr++ = ':';
	  strcpy(ptr, rel->port);
	  ptr = &ptr[strlen(ptr)];
	}
    }

  /*
   * Now build path.
   */

  tmp = ptr;
  if (rel->pathIsAbsolute == YES)
    {
      *tmp++ = '/';
      strcpy(tmp, rel->path);
    }
  else if (base == 0)
    {
      strcpy(tmp, rel->path);
    }
  else if (rel->path[0] == 0)
    {
      *tmp++ = '/';
      strcpy(tmp, base->path);
    }
  else
    {
      char	*start = base->path;
      char	*end = strrchr(start, '/');

      if (end != 0)
	{
	  *tmp++ = '/';
	  strncpy(tmp, start, end - start);
	  tmp += (end - start);
	}
      *tmp++ = '/';
      strcpy(tmp, rel->path);
    }

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
		  strcpy(tmp, &tmp[2]);
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
	      strcpy(tmp, &tmp[1]);
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
	      strcpy(tmp, next);
	    }
	}
    }
  ptr = &ptr[strlen(ptr)];
  
  if (rel->parameters != 0)
    {
      *ptr++ = ';';
      strcpy(ptr, rel->parameters);
      ptr = &ptr[strlen(ptr)];
    }
  if (rel->query != 0)
    {
      *ptr++ = '?';
      strcpy(ptr, rel->query);
      ptr = &ptr[strlen(ptr)];
    }
  if (rel->fragment != 0)
    {
      *ptr++ = '#';
      strcpy(ptr, rel->fragment);
      ptr = &ptr[strlen(ptr)];
    }

  return buf;
}

static id clientForHandle(void *data, NSURLHandle *hdl)
{
  id	client = nil;

  if (data != 0)
    {
      [clientsLock lock];
      client = (id)NSMapGet((NSMapTable*)data, hdl);
      [clientsLock unlock];
    }
  return client;
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
 * Convert percent escape sequences to individual characters.
 */
static void unescape(const char *from, char * to)
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
	      else if (*from <= 'A')
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
	      else if (*from <= 'A')
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
}



/**
 * This class permits manipulation of URLs and the resources to which they
 * refer.  They can be used to represent absolute URLs or relative URLs
 * which are based upon an absolute URL.  The relevant RFCs describing
 * how a URL is formatted, and what is legal in a URL are -
 * 1808, 1738, and 2396.<br />
 * Handling of the underlying resources is carried out by NSURLHandle
 * objects, but NSURL provides a simoplified API wrapping these objects.
 */
@implementation NSURL

/**
 * Create and return a file URL with the supplied path.<br />
 * The value of aPath must be a valid filesystem path.<br />
 * Calls -initFileURLWithPath:
 */
+ (id) fileURLWithPath: (NSString*)aPath
{
  return AUTORELEASE([[NSURL alloc] initFileURLWithPath: aPath]);
}

+ (void) initialize
{
  if (clientsLock == nil)
    {
      clientsLock = [NSLock new];
    }
}

/**
 * Create and return a URL with the supplied string, which should
 * be a string (containing percent escape codes where necessary)
 * conforming to the description (in RFC2396) of an absolute URL.<br />
 * Calls -initWithString:
 */
+ (id) URLWithString: (NSString*)aUrlString
{
  return AUTORELEASE([[NSURL alloc] initWithString: aUrlString]);
}

/**
 * Create and return a URL with the supplied string, which should
 * be a string (containing percent escape codes where necessary)
 * conforming to the description (in RFC2396) of a relative URL.<br />
 * Calls -initWithString:relativeToURL:
 */
+ (id) URLWithString: (NSString*)aUrlString
       relativeToURL: (NSURL*)aBaseUrl
{
  return AUTORELEASE([[NSURL alloc] initWithString: aUrlString
				     relativeToURL: aBaseUrl]);
}

/**
 * Initialise by building a URL string from the supplied parameters
 * and calling -initWithString:relativeToURL:
 */
- (id) initWithScheme: (NSString*)aScheme
		 host: (NSString*)aHost
		 path: (NSString*)aPath
{
  NSString	*aUrlString = [NSString alloc];

  if ([aHost length] > 0)
    {
      if ([aPath length] > 0)
	{
	  aUrlString = [aUrlString initWithFormat: @"%@://%@/%@",
	    aScheme, aHost, aPath];
	}
      else
	{
	  aUrlString = [aUrlString initWithFormat: @"%@://%@/",
	    aScheme, aHost];
	}
    }
  else
    {
      if ([aPath length] > 0)
	{
	  aUrlString = [aUrlString initWithFormat: @"%@:%@",
	    aScheme, aPath];
	}
      else
	{
	  aUrlString = [aUrlString initWithFormat: @"%@:",
	    aScheme];
	}
    }
  self = [self initWithString: aUrlString relativeToURL: nil];
  RELEASE(aUrlString);
  return self;
}

/**
 * Initialise as a file URL with the specified path.<br />
 * Calls -initWithString:relativeToURL:
 */
- (id) initFileURLWithPath: (NSString*)aPath
{
  self = [self initWithScheme: NSURLFileScheme
			 host: nil
			 path: aPath];
  return self;
}

/**
 * Initialise as an absolute URL.<br />
 * Calls -initWithString:relativeToURL:
 */
- (id) initWithString: (NSString*)aUrlString
{
  self = [self initWithString: aUrlString relativeToURL: nil];
  return self;
}

/** <init />
 * Iinitialised susing aUrlString and aBaseUrl.  The value of aBaseUrl
 * may be nil, but aUrlString must be non-nil.<br />
 * If the string cannot be parsed the method returns nil.
 */
- (id) initWithString: (NSString*)aUrlString
	relativeToURL: (NSURL*)aBaseUrl
{
  if (aUrlString == nil)
    {
      [NSException raise: NSInvalidArgumentException
		  format: @"[%@ %@] nil string parameter",
	NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    }
  ASSIGNCOPY(_urlString, aUrlString);
  ASSIGN(_baseURL, [aBaseUrl absoluteURL]);
  NS_DURING
    {
      parsedURL	*buf;
      parsedURL	*base = baseData;
      unsigned	size = [_urlString cStringLength];
      char	*end;
      char	*start;
      char	*ptr;
      BOOL	usesFragments = YES;
      BOOL	usesParameters = YES;
      BOOL	usesQueries = YES;
      BOOL	canBeGeneric = YES;

      size += sizeof(parsedURL) + __alignof__(parsedURL) + 1;
      buf = _data = (parsedURL*)NSZoneMalloc(GSAtomicMallocZone(), size);
      memset(buf, '\0', size);
      start = end = ptr = (char*)&buf[1];
      [_urlString getCString: start];

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
	       * Standardise upprcase to lower.
	       */
	      while (--ptr > start)
		{
		  if (isupper(*ptr))
		    {
		      *ptr = tolower(*ptr);
		    }
		}
	      if (base != 0 && base->scheme != 0
		&& strcmp(base->scheme, buf->scheme) != 0)
		{
		  [NSException raise: NSGenericException format:
		    @"scheme of base and relative parts does not match"];
		}
	    }
	}
      start = end;

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
	      usesFragments = NO;
	      usesParameters = NO;
	      usesQueries = NO;
	    }
	  else if (strcmp(buf->scheme, "mailto") == 0)
	    {
	      usesFragments = NO;
	      usesParameters = NO;
	      usesQueries = NO;
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
	      buf->isGeneric = YES;
	      start = end = &end[2];
	      end = strchr(start, '/');
	      if (end != 0)
		{
		  *end++ = '\0';
		}

	      /*
	       * Parser username:password part
	       */
	      ptr = strchr(start, '@');
	      if (ptr != 0)
		{
		  buf->user = start;
		  *ptr++ = '\0';
		  start = ptr;
		  ptr = strchr(buf->user, ':');
		  if (ptr != 0)
		    {
		      *ptr++ = '\0';
		      buf->password = ptr;
		    }
		}

	      /*
	       * Parse host:port part
	       */
	      buf->host = start;
	      ptr = strchr(buf->host, ':');
	      if (ptr != 0)
		{
		  *ptr++ = '\0';
		  buf->port = ptr;
		}
	      start = end;

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
	    }

	  if (base != 0
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
    }
  NS_HANDLER
    {
      NSLog(@"%@", localException);
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
      NSZoneFree(GSObjCZone(self), _data);
      _data = 0;
    }
  DESTROY(_urlString);
  DESTROY(_baseURL);
  [super dealloc];
}

- (id) copyWithZone: (NSZone*)zone
{
  if (NSShouldRetainWithZone(self, zone) == NO)
    {
      return [[isa allocWithZone: zone] initWithString: _urlString
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
  [aCoder encodeObject: _urlString];
  [aCoder encodeObject: _baseURL];
}

- (unsigned int) hash
{
  return [[self absoluteString] hash];
}

- (id) initWithCoder: (NSCoder*)aCoder
{
  NSURL		*base;
  NSString	*rel;

  [aCoder decodeValueOfObjCType: @encode(id) at: &rel];
  [aCoder decodeValueOfObjCType: @encode(id) at: &base];
  self = [self initWithString: rel relativeToURL: base];
  RELEASE(rel);
  RELEASE(base);
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

/**
 * Returns the full string describing the receiver resiolved against its base.
 */
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

/**
 * If the receiver is an absolute URL, returns self.  Otherwise returns an
 * absolute URL referring to the same resource as the receiver.
 */
- (NSURL*) absoluteURL
{
  if (_baseURL != nil)
    {
      return self;
    }
  else
    {
      return [NSURL URLWithString: [self absoluteString]];
    }
}

/**
 * If the receiver is a relative URL, returns its base URL.<br />
 * Otherwise, returns nil.
 */
- (NSURL*) baseURL
{
  return _baseURL;
}

/**
 * Returns the fragment portion of the receiver or nil if there is no
 * fragment supplied in the URL.<br />
 * The fragment is everything in the original URL string after a '#'<br />
 * File URLs do not have fragments.
 */
- (NSString*) fragment
{
  NSString	*fragment = nil;

  if (myData->fragment != 0)
    {
      fragment = [NSString stringWithUTF8String: myData->fragment];
    }
  return fragment;
}

/**
 * Returns the host portion of the receiver or nil if there is no
 * host supplied in the URL.<br />
 * Percent escape sequences in the user string are translated and the string
 * treated as UTF8.<br />
 */
- (NSString*) host
{
  NSString	*host = nil;

  if (myData->host != 0)
    {
      char	buf[strlen(myData->host)+1];

      unescape(myData->host, buf);
      host = [NSString stringWithUTF8String: buf];
    }
  return host;
}

/**
 * Returns YES if the recevier is a file URL, NO otherwise.
 */
- (BOOL) isFileURL
{
  if (myData->scheme != 0 && strcmp(myData->scheme, "file") == 0)
    {
      return YES;
    }
  return NO;
}

/**
 * Loads resource data for the specified client.
 * <p>
 *   If shouldUseCache is YES then an attempt
 *   will be made to locate a cached NSURLHandle to provide the
 *   resource data, otherwise a new handle will be created and
 *   cached.
 * </p>
 * <p>
 *   If the handle does not have the data available, it will be
 *   asked to load the data in the background by calling its
 *   loadInBackground  method.
 * </p>
 * <p>
 *   The specified client (if non-nil) will be set up to receive
 *   notifications of the progress of the background load process.
 * </p>
 */
- (void) loadResourceDataNotifyingClient: (id)client
			      usingCache: (BOOL)shouldUseCache
{
  NSURLHandle	*handle = [self URLHandleUsingCache: shouldUseCache];
  NSRunLoop	*loop;
  NSDate	*future;
  
  if (client != nil)
    {
      [clientsLock lock];
      if (_clients == 0)
	{
	  _clients = NSCreateMapTable (NSNonRetainedObjectMapKeyCallBacks,
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

  /*
   * Keep the runloop going until the load has completed (or failed).
   */
  loop = [NSRunLoop currentRunLoop];
  future = [NSDate distantFuture];
  while ([handle status] == NSURLHandleLoadInProgress)
    {
      [loop runMode: NSDefaultRunLoopMode beforeDate: future];
    }

  if (client != nil)
    {
      [handle removeClient: self];
      [clientsLock lock];
      NSMapRemove((NSMapTable*)_clients, (void*)handle);
      [clientsLock unlock];
    }
}

/**
 * Returns the parameter portion of the receiver or nil if there is no
 * parameter supplied in the URL.<br />
 * The parameters are everything in the original URL string after a ';'
 * but before the query.<br />
 * File URLs do not have parameters.
 */
- (NSString*) parameterString
{
  NSString	*parameters = nil;

  if (myData->parameters != 0)
    {
      parameters = [NSString stringWithUTF8String: myData->parameters];
    }
  return parameters;
}

/**
 * Returns the password portion of the receiver or nil if there is no
 * password supplied in the URL.<br />
 * Percent escape sequences in the user string are translated and the string
 * treated as UTF8 in GNUstep but this appears to be broken in MacOS-X.<br />
 * NB. because of its security implications it is recommended that you
 * do not use URLs with users and passwords unless necessary.
 */
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

/**
 * Returns the path portion of the receiver.<br />
 * Replaces percent escapes with unescaped values, interpreting non-ascii
 * character sequences as UTF8.<br />
 * NB. This does not conform strictly to the RFCs, in that it includes a
 * leading slash ('/') character (wheras the path part of a URL strictly
 * should not) and the interpretation of non-ascii character is (strictly
 * speaking) undefined.
 */
- (NSString*) path
{
  NSString	*path = nil;

  /*
   * If this scheme is from a URL without generic format, there is no path.
   */
  if (myData->isGeneric == YES)
    {
      unsigned int	len = (_baseURL ? strlen(baseData->path) : 0)
	+ strlen(myData->path) + 3;
      char		buf[len];
      char		*tmp = buf;

      if (myData->pathIsAbsolute == YES)
	{
	  *tmp++ = '/';
	  strcpy(tmp, myData->path);
	}
      else if (_baseURL == nil)
	{
	  strcpy(tmp, myData->path);
	}
      else if (*myData->path == 0)
	{
	  *tmp++ = '/';
	  strcpy(tmp, baseData->path);
	}
      else
	{
	  char	*start = baseData->path;
	  char	*end = strrchr(start, '/');

	  if (end != 0)
	    {
	      *tmp++ = '/';
	      strncpy(tmp, start, end - start);
	      tmp += end - start;
	    }
	  *tmp++ = '/';
	  strcpy(tmp, myData->path);
	}

      unescape(buf, buf);
      path = [NSString stringWithUTF8String: buf];
    }
  return path;
}

/**
 * Returns the port portion of the receiver or nil if there is no
 * port supplied in the URL.<br />
 * Percent escape sequences in the user string are translated in GNUstep
 * but this appears to be broken in MacOS-X.
 */
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

/**
 * Asks a URL handle to return the property for the specified key and
 * returns the result.
 */
- (id) propertyForKey: (NSString*)propertyKey
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];

  return [handle propertyForKey: propertyKey];
}

/**
 * Returns the query portion of the receiver or nil if there is no
 * query supplied in the URL.<br />
 * The query is everything in the original URL string after a '?'
 * but before the fragment.<br />
 * File URLs do not have queries.
 */
- (NSString*) query
{
  NSString	*query = nil;

  if (myData->query != 0)
    {
      query = [NSString stringWithUTF8String: myData->query];
    }
  return query;
}

/**
 * Returns the path of the receiver, without taking any base URL into account.
 * If the receiver is an absolute URL, -relativePath is the same as -path.<br />
 * Returns nil if there is no path specified for the URL.
 */
- (NSString*) relativePath
{
  NSString	*path = nil;

  if (myData->path != 0)
    {
      path = [NSString stringWithUTF8String: myData->path];
    }
  return path;
}

/**
 * Returns the relative portion of the URL string.  If the receiver is not
 * a relative URL, this returns the same as absoluteString.
 */
- (NSString*) relativeString
{
  return _urlString;
}

/**
 * Loads the resource data for the represented URL and returns the result.
 * The shoulduseCache flag determines whether an existing cached NSURLHandle
 * can be used to provide the data.
 */
- (NSData*) resourceDataUsingCache: (BOOL)shouldUseCache
{
  NSURLHandle	*handle = [self URLHandleUsingCache: shouldUseCache];
  NSData	*data;

  if (shouldUseCache == NO || [handle status] != NSURLHandleLoadSucceeded)
    {
      [self loadResourceDataNotifyingClient: self
				 usingCache: shouldUseCache];
    }
  data = [handle resourceData];
  return data;
}

/**
 * Returns the resource specifier of the URL ... the part which lies
 * after the scheme.
 */
- (NSString*) resourceSpecifier
{
  NSRange	range = [_urlString rangeOfString: @"://"];

  if (range.length > 0)
    {
      return [_urlString substringFromIndex: range.location + 1];
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

/**
 * Returns the scheme of the receiver.
 */
- (NSString*) scheme
{
  NSString	*scheme = nil;

  if (myData->scheme != 0)
    {
      scheme = [NSString stringWithUTF8String: myData->scheme];
    }
  return scheme;
}

/**
 * Calls [NSURLHandle-writeProperty:forKey:] to set the named property.
 */
- (BOOL) setProperty: (id)property
	      forKey: (NSString*)propertyKey
{
  NSURLHandle	*handle = [self URLHandleUsingCache: YES];

  return [handle writeProperty: property forKey: propertyKey];
}

/**
 * Calls [NSURLHandle-writeData:] to write the specified data object
 * to the resource identified by the receiver URL.<br />
 * Returns the result.
 */
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
  [self loadResourceDataNotifyingClient: self
			     usingCache: YES];
  if ([handle resourceData] == nil)
    {
      return NO;
    }
  return YES;
}

/**
 * Returns a URL with '/./' and '/../' sequences resolved etc.
 */
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

/**
 * Returns an NSURLHandle instance which may be used to write data to the
 * resource represented by the receiver URL, or read data from it.<br />
 * The shouldUseCache flag indicates whether a cached handle may be returned
 * or a new one should be created.
 */
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
	  AUTORELEASE(handle);
	}
    }
  return handle;
}

/**
 * Returns the user portion of the receiver or nil if there is no
 * user supplied in the URL.<br />
 * Percent escape sequences in the user string are translated and
 * the whole is treated as UTF8 data.<br />
 * NB. because of its security implications it is recommended that you
 * do not use URLs with users and passwords unless necessary.
 */
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

- (void) URLHandle: (NSURLHandle*)sender
  resourceDataDidBecomeAvailable: (NSData*)newData
{
  [clientForHandle(_clients, sender) URL: self
	  resourceDataDidBecomeAvailable: newData];
}
- (void) URLHandle: (NSURLHandle*)sender
  resourceDidFailLoadingWithReason: (NSString*)reason
{
  [clientForHandle(_clients, sender) URL: self
       resourceDidFailLoadingWithReason: reason];
}

- (void) URLHandleResourceDidBeginLoading: (NSURLHandle*)sender
{
}

- (void) URLHandleResourceDidCancelLoading: (NSURLHandle*)sender
{
  [clientForHandle(_clients, sender) URLResourceDidCancelLoading: self];
}

- (void) URLHandleResourceDidFinishLoading: (NSURLHandle*)sender
{
  [clientForHandle(_clients, sender) URLResourceDidFinishLoading: self];
}


@end



/**
 * An informal protocol to which clients may conform if they wish to be
 * notified of the progress in loading a URL for them.  The default
 * implementations of these methods do nothing.
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
