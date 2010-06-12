/* GSPThread.h
   Copyright (C) 2010 Free Software Foundation, Inc.

   Written by:  Niels Grewe <niels.grewe@halbordnung.de>
   
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
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
   MA 02111 USA.
*/ 
#ifndef _GSPThread_h_
#define _GSPThread_h_

#include <pthread.h>

/*
 * Macro to initialize recursive mutexes in a portable way. Adopted from
 * libobjc2 (lock.h).
 */
# ifdef PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP
#   define GS_INIT_RECURSIVE_MUTEX(x) \
x = (pthread_mutex_t) PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP
# elif defined(PTHREAD_RECURSIVE_MUTEX_INITIALIZER)
#   define GS_INIT_RECURSIVE_MUTEX(x) \
x = (pthread_mutex_t) PTHREAD_RECURSIVE_MUTEX_INITIALIZER
# else
#   define GS_INIT_RECURSIVE_MUTEX(x) GSPThreadInitRecursiveMutex(&(x))

static inline void GSPThreadInitRecursiveMutex(pthread_mutex_t *x)
{
  pthread_mutexattr_t recursiveAttributes;
  pthread_mutexattr_init(&recursiveAttributes);
  pthread_mutexattr_settype(&recursiveAttributes, PTHREAD_MUTEX_RECURSIVE);
  pthread_mutex_init(x, &recursiveAttributes);
  pthread_mutexattr_destroy(&recursiveAttributes);
}
# endif // PTHREAD_RECURSIVE_MUTEX_INITIALIZER(_NP)

#endif // _GSPThread_h_
