/* NSConcreteNumber - Handle preprocessor magic for NSConcreteNumberTemplate 
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Written by: Andrew Ruder <andy@aeruder.net>
   Date: May 2006

   This file is part of the GNUstep Base Library.

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

#import "config.h"
#import "GNUstepBase/preface.h"
#import "GNUstepBase/GSConfig.h"
#import "Foundation/NSObjCRuntime.h"
#import "Foundation/NSString.h"
#import "Foundation/NSException.h"
#import "Foundation/NSCoder.h"
#import "NSConcreteNumber.h"
#import "GSPrivate.h"

#define TYPE_ORDER 0
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 1
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 2
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 3
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 4
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 5
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 6
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 7
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 8
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 9
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 10
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 11
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER

#define TYPE_ORDER 12
#include "NSConcreteNumberTemplate.m"
#undef TYPE_ORDER
