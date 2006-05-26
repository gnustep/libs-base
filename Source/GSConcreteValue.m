#include "config.h"
#include "Foundation/NSValue.h"
#include "Foundation/NSString.h"
#include "Foundation/NSException.h"
#include "Foundation/NSCoder.h"
#include "Foundation/NSObjCRuntime.h"
#include "GNUstepBase/preface.h"

#define TYPE_ORDER 0
#include "GSConcreteValueTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 1
#include "GSConcreteValueTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 2
#include "GSConcreteValueTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 3
#include "GSConcreteValueTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 4
#include "GSConcreteValueTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 5
#include "GSConcreteValueTemplate.m"
#undef TYPE_ORDER

