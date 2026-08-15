#import <Foundation/NSArray.h>
#import <Foundation/NSObject.h>
#import <Foundation/NSURLRequest.h>
#import <Foundation/NSURLResponse.h>
#import <GNUstepBase/GSBlocks.h>

DEFINE_BLOCK_TYPE(RequestHandlerBlock, NSData *, NSURLRequest *);

@interface Route : NSObject
{
  NSString	     *_method;
  NSURL		     *_url;
  NSData	     *_response;
  id		      _target;
  SEL		      _selector;
  RequestHandlerBlock _block;
}

/* A route answering with a fixed response. */
+ (instancetype)routeWithURL:(NSURL *)url
                      method:(NSString *)method
                    response:(NSData *)response;

/* A route answering by sending aSelector to target with the request.  The
 * method returns the response data.
 */
+ (instancetype)routeWithURL:(NSURL *)url
                      method:(NSString *)method
                      target:(id)target
                    selector:(SEL)aSelector;

/* As above, for a caller whose compiler has blocks. */
+ (instancetype)routeWithURL:(NSURL *)url
                      method:(NSString *)method
                     handler:(RequestHandlerBlock)block;

- (NSString *)method;
- (NSURL *)url;

/* The response for request, from whichever of the three the route was
 * created with.
 */
- (NSData *)responseForRequest:(NSURLRequest *)request;

- (BOOL)acceptsURL:(NSURL *)url method:(NSString *)method;

@end

@interface HTTPServer : NSObject
{
  volatile BOOL	    _stop;
  int		    _socket;
  NSInteger	    _port;
  NSArray	   *_routes;
}
- initWithPort:(NSInteger)port routes:(NSArray *)routes;

- (NSInteger)port;
- (void)resume;
- (void)suspend;

- (void)setRoutes:(NSArray *)routes;
@end
