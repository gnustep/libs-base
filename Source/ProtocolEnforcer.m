
@interface ProtocolEnforcer
{
  id target;
  Protocol *protocol;
}

- initWithProtocol: aProtocol target: anObj;

- (BOOL) conformsTo: aProtocol;
- forward: (SEL)sel :(arglist_t)frame;

@end

@implementation ProtocolEnforcer

- initWithProtocol: aProtocol target: anObj
{
  [super init];
  protocol = aProtocol;
  target = anObj;
  return self;
}

- (BOOL) conformsTo: aProtocol
{
  if (aProtocol == protocol)
    return YES;
  else
    return NO;
}

- (retval_t) forward: (SEL)sel :(arglist_t)frame
{
  if ([protocol descriptionForInstanceMethod:sel])
    return [target performv:sel :frame];
  else
#warning Fix this
    return 
      [self error:"We should punish the remote connection not the local one"];
}

@end
