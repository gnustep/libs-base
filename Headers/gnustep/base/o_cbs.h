/* Handling various types in a uniform manner.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sun Oct  9 13:18:50 EDT 1994
 * Updated: Mon Mar 11 00:31:13 EST 1996
 * Serial: 96.03.11.01
 * 
 * This file is part of the GNUstep Base Library.
 * 
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 * 
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 * 
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the Free
 * Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA. */ 

#ifndef __callbacks_h_GNUSTEP_BASE_INCLUDE
#define __callbacks_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <stdlib.h>
#include <Foundation/NSString.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef size_t (*o_hash_func_t)(const void *, void *);
typedef int (*o_compare_func_t)(const void *, const void *, void *);
typedef int (*o_is_equal_func_t)(const void *, const void *, void *);
typedef const void *(*o_retain_func_t)(const void *, void *);
typedef void (*o_release_func_t)(void *, void *);
typedef NSString *(*o_describe_func_t)(const void *, void *);

typedef struct _o_callbacks o_callbacks_t;

struct _o_callbacks
{
  o_hash_func_t hash;
  o_compare_func_t compare;
  o_is_equal_func_t is_equal;
  o_retain_func_t retain;
  o_release_func_t release;
  o_describe_func_t describe;
  const void *not_an_item_marker;
};

/** Callbacks for various types **/

extern const o_callbacks_t o_callbacks_for_int;
extern const o_callbacks_t o_callbacks_for_char_p;
extern const o_callbacks_t o_callbacks_for_non_owned_void_p;
extern const o_callbacks_t o_callbacks_for_owned_void_p;
extern const o_callbacks_t o_callbacks_for_int_p;
extern const o_callbacks_t o_callbacks_for_id;

/* FIXME: I need to figure out what each of these should be.  Hmmm? */
extern const void *o_not_an_int_marker;
extern const void *o_not_a_char_p_marker;
extern const void *o_not_a_void_p_marker;
extern const void *o_not_an_int_p_marker;
extern const void *o_not_an_id_marker;

/* Change this if you need different default callbacks. */
extern o_callbacks_t __o_callbacks_standard;

/**** Function Prototypes ****************************************************/

/** Generic callbacks **/

/* Returns the programmer-alterable `__o_callbacks_standard',
 * defined above. */
o_callbacks_t
o_callbacks_standard(void);

/** Standardizing callbacks **/

/* Makes sure that enough of CALLBACKS is defined (i.e., non-zero)
 * to be used.  This is used, rather than local checks for usability,
 * to improve the efficiency of callback use. */
o_callbacks_t
o_callbacks_standardize(o_callbacks_t callbacks);

/** Using callbacks **/

size_t
o_hash(o_callbacks_t callbacks,
             const void *thing,
             void *user_data);

int
o_compare(o_callbacks_t callbacks,
                const void *thing1,
                const void *thing2,
                void *user_data);

int
o_is_equal(o_callbacks_t callbacks,
                 const void *thing1,
                 const void *thing2,
                 void *user_data);

const void *
o_retain(o_callbacks_t callbacks,
               const void *thing,
               void *user_data);

void
o_release(o_callbacks_t callbacks,
                void *thing,
                void *user_data);

NSString *
o_describe(o_callbacks_t callbacks,
                 const void *thing,
                 void *user_data);

const void *
o_not_an_item_marker(o_callbacks_t callbacks);

/** Specific callback functions... **/

/* For non-owned `void *' */
size_t o_non_owned_void_p_hash(const void *ptr);
int o_non_owned_void_p_compare(const void *ptr, const void *qtr);
int o_non_owned_void_p_is_equal(const void *ptr, const void *qtr);
const void *o_non_owned_void_p_retain(const void *ptr);
void o_non_owned_void_p_release(void *ptr);
NSString *o_non_owned_void_p_describe(const void *ptr);

/* For owned `void *' */
size_t o_owned_void_p_hash(const void *ptr);
int o_owned_void_p_compare(const void *ptr, const void *qtr);
int o_owned_void_p_is_equal(const void *ptr, const void *qtr);
const void *o_owned_void_p_retain(const void *ptr);
void o_owned_void_p_release(void *ptr);
NSString *o_owned_void_p_describe(const void *ptr);

/* For `int' */
size_t o_int_hash(int i);
int o_int_compare(int i, int j);
int o_int_is_equal(int i, int j);
const void *o_int_retain(int i);
void o_int_release(int i);
NSString *o_int_describe(int i);

/* For `int *' */
size_t o_int_p_hash(const int *iptr);
int o_int_p_compare(const int *iptr, const int *jptr);
int o_int_p_is_equal(const int *iptr, const int *jptr);
const void *o_int_p_retain(const int *iptr);
void o_int_p_release(int *iptr);
NSString *o_int_p_describe(const int *iptr);

/* For `char *' */
size_t o_char_p_hash(const char *cptr);
int o_char_p_compare(const char *cptr, const char *dptr);
int o_char_p_is_equal(const char *cptr, const char *dptr);
const void *o_char_p_retain(const char *cptr);
void o_char_p_release(char *cptr);
NSString *o_char_p_describe(const char *cptr);

/* For `id' */
size_t o_id_hash(id obj);
int o_id_compare(id obj, id jbo);
int o_id_is_equal(id obj, id jbo);
const void *o_id_retain(id obj);
void o_id_release(id obj);
NSString *o_id_describe(id obj);

#endif /* __callbacks_h_GNUSTEP_BASE_INCLUDE */

