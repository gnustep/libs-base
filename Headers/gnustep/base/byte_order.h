/*
   byte_order.h

   Copyright (C) 1995, 1996 Ovidiu Predescu and Mircea Oancea.
   All rights reserved.

   Author: Ovidiu Predescu <ovidiu@bx.logicnet.ro>

   This file is part of libFoundation.

   Permission to use, copy, modify, and distribute this software and its
   documentation for any purpose and without fee is hereby granted, provided
   that the above copyright notice appear in all copies and that both that
   copyright notice and this permission notice appear in supporting
   documentation.

   We disclaim all warranties with regard to this software, including all
   implied warranties of merchantability and fitness, in no event shall
   we be liable for any special, indirect or consequential damages or any
   damages whatsoever resulting from loss of use, data or profits, whether in
   an action of contract, negligence or other tortious action, arising out of
   or in connection with the use or performance of this software.
*/

/*
   Conversion routines for doubles and floats in and from the network floating
   format. Assumes the target machine has the IEEE floating point format.

   This file was inspired from architecture/byte_order.h by David E. Bohman
   from NeXT.
 */

#ifndef __byte_order_h__
#define __byte_order_h__

#include <sys/types.h>
#if HAVE_NETINET_IN_H
# include <netinet/in.h>
#endif
#if HAVE_WINDOWS_H
# include <windows.h>
#endif
#if HAVE_WINDOWS32_SOCKETS_H
# include <Windows32/Sockets.h>
#endif

/* BUGS: Assumes the endianism of target machine is either big or little
   endian, format of floating point is IEEE and
	sizeof (long) == 4
	sizeof (long long) == 8
	sizeof (long) == sizeof (float)
	sizeof (long long) == sizeof (double)
 */

#if (__GNUC__ == 2) && (__GNUC_MINOR__ <= 6) && !defined(__attribute__)
#  define __attribute__(x)
#endif

typedef unsigned long network_float;
typedef unsigned long long network_double;


/* Prototypes */

static inline unsigned short
network_short_to_host (unsigned short x) __attribute__((unused));
static inline unsigned short
host_short_to_network (unsigned short x) __attribute__((unused));
static inline unsigned int
network_int_to_host (unsigned int x) __attribute__((unused));
static inline unsigned int
host_int_to_network (unsigned int x) __attribute__((unused));
static inline unsigned long
network_long_to_host (unsigned long x) __attribute__((unused));
static inline unsigned long
host_long_to_network (unsigned long x) __attribute__((unused));
static inline unsigned long long
network_long_long_to_host (unsigned long long x) __attribute__((unused));
static inline unsigned long long
host_long_long_to_network (unsigned long long x) __attribute__((unused));
static inline float
network_float_to_host (network_float x) __attribute__((unused));
static inline network_float
host_float_to_network (float x) __attribute__((unused));
static inline double
network_double_to_host (network_double x) __attribute__((unused));
static inline network_double
host_double_to_network (double x) __attribute__((unused));


/* Public entries */

static inline unsigned short
network_short_to_host (unsigned short x)
{
    return ntohs (x);
}

static inline unsigned short
host_short_to_network (unsigned short x)
{
    return htons (x);
}

static inline unsigned int
network_int_to_host (unsigned int x)
{
    return ntohl (x);
}

static inline unsigned int
host_int_to_network (unsigned int x)
{
    return htonl (x);
}

static inline unsigned long
network_long_to_host (unsigned long x)
{
    return ntohl (x);
}

static inline unsigned long
host_long_to_network (unsigned long x)
{
    return htonl (x);
}

#if WORDS_BIGENDIAN
static inline unsigned long long
network_long_long_to_host (unsigned long long x)
{
    return x;
}

static inline unsigned long long
host_long_long_to_network (unsigned long long x)
{
    return x;
}

#else /* !WORDS_BIGENDIAN */

static inline unsigned long
swap_long (unsigned long x)
{
    union lconv {
	unsigned long ul;
	unsigned char uc[4];
    } *inp, outx;

    inp = (union lconv*)&x;
    outx.uc[0] = inp->uc[3];
    outx.uc[1] = inp->uc[2];
    outx.uc[2] = inp->uc[1];
    outx.uc[3] = inp->uc[0];
    return outx.ul;
}

static inline unsigned long long
swap_long_long (unsigned long long x)
{
    union dconv {
	unsigned long  ul[2];
	network_double ull;
    } *inp, outx;

    inp = (union dconv*)&x;
    outx.ul[0] = swap_long (inp->ul[1]);
    outx.ul[1] = swap_long (inp->ul[0]);
    return outx.ull;
}

static inline unsigned long long
network_long_long_to_host (unsigned long long x)
{
    return swap_long_long (x);
}

static inline unsigned long long
host_long_long_to_network (unsigned long long x)
{
    return swap_long_long (x);
}

#endif /* !WORDS_BIGENDIAN */

static inline float
network_float_to_host (network_float x)
{
    union fconv {
	float number;
	unsigned long ul;
    };
    unsigned long fx = network_long_to_host (x);

    return ((union fconv*)&fx)->number;
}

static inline network_float
host_float_to_network (float x)
{
    union fconv {
	float number;
	unsigned long ul;
    };
    return host_long_to_network (((union fconv*)&x)->ul);
}

static inline double
network_double_to_host (network_double x)
{
    union dconv {
	double number;
	unsigned long long ull;
    };
    unsigned long long dx = network_long_long_to_host (x);

    return ((union dconv*)&dx)->number;
}

static inline network_double
host_double_to_network (double x)
{
    union dconv {
	double number;
	unsigned long long ull;
    };
    return host_long_long_to_network (((union dconv*)&x)->ull);
}

#endif /* __byte_order_h__ */
