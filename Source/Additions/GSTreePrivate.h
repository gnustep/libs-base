/* GSTreePrivate.h */

#ifndef __GSTreePrivate_h_GNUSTEP_BASE_INCLUDE
#define __GSTreePrivate_h_GNUSTEP_BASE_INCLUDE

#import "GNUstepBase/GSTree.h"

typedef struct GSTreeNode GSTreeNode;

struct GSTreeNode
{
  GSTreeNode *link[2];
  GSTreeNode *parent;
  uintptr_t   flags;
};

typedef struct
{
  GSTreeNode  base;
  id          object;
} GSTreeWrapperNode;

enum
{
  GSTreeRed   = 1,
  GSTreeBlack = 0
};

static inline BOOL
GSTreeIsRed(const GSTreeNode *node)
{
  return (node->flags & 1) != 0;
}

static inline BOOL
GSTreeIsBlack(const GSTreeNode *node)
{
  return (node->flags & 1) == 0;
}

static inline void
GSTreeSetRed(GSTreeNode *node)
{
  node->flags |= 1;
}

static inline void
GSTreeSetBlack(GSTreeNode *node)
{
  node->flags &= ~(uintptr_t)1;
}
#endif
