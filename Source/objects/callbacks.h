/* Handling various types in a uniform manner.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sun Oct  9 13:18:50 EDT 1994
 * Updated: Mon Mar 11 00:31:13 EST 1996
 * Serial: 96.03.11.01
 * 
 * This file is part of the GNU Objective C Class Library.
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA. */ 

#ifndef __callbacks_h_OBJECTS_INCLUDE
#define __callbacks_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <stdlib.h>
#include <Foundation/NSString.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef size_t (*objects_hash_func_t)(const void *, void *);
typedef int (*objects_compare_func_t)(const void *, const void *, void *);
typedef int (*objects_is_equal_func_t)(const void *, const void *, void *);
typedef const void *(*objects_retain_func_t)(const void *, void *);
typedef void (*objects_release_func_t)(void *, void *);
typedef NSString *(*objects_describe_func_t)(const void *, void *);

typedef struct _objects_callbacks objects_callbacks_t;

struct _objects_callbacks
{
  objects_hash_func_t hash;
  objects_compare_func_t compare;
  objects_is_equal_func_t is_equal;
  objects_retain_func_t retain;
  objects_release_func_t release;
  objects_describe_func_t describe;
  const void *not_an_item_marker;
};

/** Callbacks for various types **/

extern const objects_callbacks_t objects_callbacks_for_int;
extern const objects_callbacks_t objects_callbacks_for_char_p;
extern const objects_callbacks_t objects_callbacks_for_non_owned_void_p;
extern const objects_callbacks_t objects_callbacks_for_owned_void_p;
extern const objects_callbacks_t objects_callbacks_for_int_p;
extern const objects_callbacks_t objects_callbacks_for_id;

/* FIXME: I need to figure out what each of these should be.  Hmmm? */
extern const void *objects_not_an_int_marker;
extern const void *objects_not_a_char_p_marker;
extern const void *objects_not_a_void_p_marker;
extern const void *objects_not_an_int_p_marker;
extern const void *objects_not_an_id_marker;

/* Change this if you need different default callbacks. */
extern objects_callbacks_t __objects_callbacks_standard;

/**** Function Prototypes ****************************************************/

/** Generic callbacks **/

/* Returns the programmer-alterable `__objects_callbacks_standard',
 * defined above. */
objects_callbacks_t
objects_callbacks_standard(void);

/** Standardizing callbacks **/

/* Makes sure that enough of CALLBACKS is defined (i.e., non-zero)
 * to be used.  This is used, rather than local checks for usability,
 * to improve the efficiency of callback use. */
objects_callbacks_t
objects_callbacks_standardize(objects_callbacks_t callbacks);

/** Using callbacks **/

size_t
objects_hash(objects_callbacks_t callbacks,
             const void *thing,
             void *user_data);

int
objects_compare(objects_callbacks_t callbacks,
                const void *thing1,
                const void *thing2,
                void *user_data);

int
objects_is_equal(objects_callbacks_t callbacks,
                 const void *thing1,
                 const void *thing2,
                 void *user_data);

const void *
objects_retain(objects_callbacks_t callbacks,
               const void *thing,
               void *user_data);

void
objects_release(objects_callbacks_t callbacks,
                void *thing,
                void *user_data);

NSString *
objects_describe(objects_callbacks_t callbacks,
                 const void *thing,
                 void *user_data);

const void *
objects_not_an_item_marker(objects_callbacks_t callbacks);

/** Specific callback functions... **/

/* For non-owned `void *' */
size_t objects_non_owned_void_p_hash(const void *ptr);
int objects_non_owned_void_p_compare(const void *ptr, const void *qtr);
int objects_non_owned_void_p_is_equal(const void *ptr, const void *qtr);
const void *objects_non_owned_void_p_retain(const void *ptr);
void objects_non_owned_void_p_release(void *ptr);
NSString *objects_non_owned_void_p_describe(const void *ptr);

/* For owned `void *' */
size_t objects_owned_void_p_hash(const void *ptr);
int objects_owned_void_p_compare(const void *ptr, const void *qtr);
int objects_owned_void_p_is_equal(const void *ptr, const void *qtr);
const void *objects_owned_void_p_retain(const void *ptr);
void objects_owned_void_p_release(void *ptr);
NSString *objects_owned_void_p_describe(const void *ptr);

/* For `int' */
size_t objects_int_hash(int i);
int objects_int_compare(int i, int j);
int objects_int_is_equal(int i, int j);
const void *objects_int_retain(int i);
void objects_int_release(int i);
NSString *objects_int_describe(int i);

/* For `int *' */
size_t objects_int_p_hash(const int *iptr);
int objects_int_p_compare(const int *iptr, const int *jptr);
int objects_int_p_is_equal(const int *iptr, const int *jptr);
const void *objects_int_p_retain(const int *iptr);
void objects_int_p_release(int *iptr);
NSString *objects_int_p_describe(const int *iptr);

/* For `char *' */
size_t objects_char_p_hash(const char *cptr);
int objects_char_p_compare(const char *cptr, const char *dptr);
int objects_char_p_is_equal(const char *cptr, const char *dptr);
const void *objects_char_p_retain(const char *cptr);
void objects_char_p_release(char *cptr);
NSString *objects_char_p_describe(const char *cptr);

/* For `id' */
size_t objects_id_hash(id obj);
int objects_id_compare(id obj, id jbo);
int objects_id_is_equal(id obj, id jbo);
const void *objects_id_retain(id obj);
void objects_id_release(id obj);
NSString *objects_id_describe(id obj);

#endif /* __callbacks_h_OBJECTS_INCLUDE */

