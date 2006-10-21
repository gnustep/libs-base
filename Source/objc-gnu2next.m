/* Implementation to allow compilation of GNU objc code with NeXT runtime
   Copyright (C) 1993,1994 Free Software Foundation, Inc.

   Author: Kresten Krab Thorup
   Modified by: Andrew Kachites McCallum <mccallum@gnu.ai.mit.edu>
   Date: Sep 1994

   This file is part of the GNUstep Base Library.

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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#include "config.h"
#include <stdio.h>
#include "GNUstepBase/preface.h"
#include "mframe.h"

id next_objc_msg_sendv(id object, SEL op, void* frame)
{
  arglist_t  argFrame = __builtin_apply_args();
  struct objc_method *m = class_get_instance_method(object->class_pointer, op);
  const char *type;
  void       *result;

  argFrame->arg_ptr = frame;
  *((id*)method_types_get_first_argument (m, argFrame, &type)) = object;
  *((SEL*)method_types_get_next_argument (argFrame, &type)) = op;
  result = __builtin_apply((apply_t)m->method_imp,
                           argFrame,
                           method_get_sizeof_arguments (m));

#if !defined(BROKEN_BUILTIN_APPLY) && defined(i386)
    /* Special hack to avoid pushing the poped float value back to the fp
       stack on i386 machines. This happens with NeXT runtime and 2.7.2
       compiler. If the result value is floating point don't call
       __builtin_return anymore. */
    if (*m->method_types == _C_FLT || *m->method_types == _C_DBL) {
        long double value = *(long double*)(((char*)result) + 8);
        asm("fld %0" : : "f" (value));
    }
    else
#endif
  __builtin_return(result);
}
