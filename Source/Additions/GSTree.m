
#import	"GNUstepBase/GSTree.h"
#import	"GSTreePrivate.h"

@interface GSTree ()
{
@public
  GSTreeNode		*_root;
  GSTreeNode 		*_sentinel;
  GSTreeConfiguration 	_config;
  NSUInteger 		_count;
}
@end

static inline GSTreeNode *
GSTreeNodeForObject(GSTree *tree, id object)
{
  if (tree->_config.storageType == GSTreeStorageIntrusive)
    {
      return (GSTreeNode *)
        ((char *)object + tree->_config.nodeOffset);
    }

  return NULL;
}

static inline id
GSTreeObjectForNode(GSTree *tree, GSTreeNode *node)
{
  if (tree->_config.storageType == GSTreeStorageIntrusive)
    {
      return (id)
        ((char *)node - tree->_config.nodeOffset);
    }

  return ((GSTreeWrapperNode *)node)->object;
}

static NSComparisonResult
GSTreeDefaultComparator(id lhs, id rhs, void *context)
{
  return (NSComparisonResult)[lhs compare: rhs];
}

static GSTreeWrapperNode *
GSTreeAllocateWrapper(id object)
{
  GSTreeWrapperNode *node;

  node = NSZoneMalloc(NSDefaultMallocZone(),
                      sizeof(GSTreeWrapperNode));

  node->object = RETAIN(object);

  return node;
}

@implementation	GSTree

- (instancetype) initWithConfiguration: (const GSTreeConfiguration *)conf
{
  if (nil != (self = [super init]))
    {
      _config = *conf;
      if (_config.comparator == NULL)
	{
	  _config.comparator = GSTreeDefaultComparator;
	}

      _sentinel = NSZoneCalloc(NSDefaultMallocZone(), 1, sizeof(GSTreeNode));

      GSTreeSetBlack(_sentinel);

      _sentinel->link[0] = _sentinel;
      _sentinel->link[1] = _sentinel;
      _sentinel->parent  = _sentinel;

      _root = _sentinel;
    }
  return self;
}

- (id) findObject: (id)object
{
  GSTreeNode	*node = _root;

  while (node != _sentinel)
    {
      id 			current;
      NSComparisonResult	cmp;

      current = GSTreeObjectForNode(self, node);
      cmp = _config.comparator(object, current, _config.context);

      if (cmp == NSOrderedSame)
	{
	  return current;
	}
      node = node->link[(cmp == NSOrderedDescending) ? 1 : 0];
    }
  return nil;
}

@end

