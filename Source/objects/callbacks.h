/* Handling various types in a uniform manner.
 * Copyright (C) 1994, 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Sun Oct  9 13:18:50 EDT 1994
 * Updated: Sun Feb 11 01:46:03 EST 1996
 * Serial: 96.02.11.01
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
 * Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 * 
 */ 

#ifndef __callbacks_h_OBJECTS_INCLUDE
#define __callbacks_h_OBJECTS_INCLUDE 1

/**** Included Headers *******************************************************/

#include <stdlib.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef size_t (*objects_hash_func_t) (void *, void *);
typedef int (*objects_compare_func_t) (void *, void *, void *);
typedef int (*objects_is_equal_func_t) (void *, void *, void *);
typedef void *(*objects_retain_func_t) (void *, void *);
typedef void (*objects_release_func_t) (void *, void *);
typedef void *(*objects_describe_func_t) (void *, void *);

typedef struct _objects_callbacks objects_callbacks_t;

struct _objects_callbacks
{
  objects_hash_func_t hash;
  objects_compare_func_t compare;
  objects_is_equal_func_t is_equal;
  objects_retain_func_t retain;
  objects_release_func_t release;
  objects_describe_func_t describe;
  void *not_an_item_marker;
};

/** Callbacks for various types **/

extern const objects_callbacks_t objects_callbacks_for_int;
extern const objects_callbacks_t objects_callbacks_for_char_p;
extern const objects_callbacks_t objects_callbacks_for_void_p;
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

/* Returns `__objects_callbacks_standard', defined above. */
objects_callbacks_t
objects_callbacks_standard (void);

/** Standardizing callbacks **/

objects_callbacks_t
objects_callbacks_standardize (objects_callbacks_t callbacks);

/** Using callbacks **/

size_t objects_hash (objects_callbacks_t callbacks,
                     void *thing,
                     void *user_data);

int objects_compare (objects_callbacks_t callbacks,
                     void *thing1,
                     void *thing2,
                     void *user_data);

int objects_is_equal (objects_callbacks_t callbacks,
                      void *thing1,
                      void *thing2,
                      void *user_data);

void *objects_retain (objects_callbacks_t callbacks,
                      void *thing,
                      void *user_data);

void objects_release (objects_callbacks_t callbacks,
                      void *thing,
                      void *user_data);

/* FIXME: Decide what to do with this describe stuff.  We'd really like
 * them to return Strings?  Or would we rather they be `char *'s?
 * Or something else? */
void *objects_describe (objects_callbacks_t callbacks,
                        void *thing,
                        void *user_data);

void *objects_not_an_item_marker (objects_callbacks_t);

/** Specific callback functions **/

/* For `void *' */
size_t objects_void_p_hash(void *ptr);
int objects_void_p_compare(void *ptr, void *qtr);
int objects_void_p_is_equal(void *ptr, void *qtr);
void *objects_void_p_retain(void *ptr);
void objects_void_p_release(void *ptr);
void *objects_void_p_describe(void *ptr);

/* For `void *' */
size_t objects_owned_void_p_hash(void *ptr);
int objects_owned_void_p_compare(void *ptr, void *qtr);
int objects_owned_void_p_is_equal(void *ptr, void *qtr);
void *objects_owned_void_p_retain(void *ptr);
void objects_owned_void_p_release(void *ptr);
void *objects_owned_void_p_describe(void *ptr);

/* For `int' */
size_t objects_int_hash(void *i);
int objects_int_compare(void *i, void *j);
int objects_int_is_equal(void *i, void *j);
void *objects_int_retain(void *i);
void objects_int_release(void *i);
void *objects_int_describe(void *i);

/* For `int *' */
size_t objects_int_p_hash(void *iptr);
int objects_int_p_compare(void *iptr, void *jptr);
int objects_int_p_is_equal(void *iptr, void *jptr);
void *objects_int_p_retain(void *iptr);
void objects_int_p_release(void *iptr);
void *objects_int_p_describe(void *iptr);

/* For `char *' */
size_t objects_char_p_hash(void *cptr);
int objects_char_p_compare(void *cptr, void *dptr);
int objects_char_p_is_equal(void *cptr, void *dptr);
void *objects_char_p_retain(void *cptr);
void objects_char_p_release(void *cptr);
void *objects_char_p_describe(void *cptr);

/* For `id' */
size_t objects_id_hash(void *obj);
int objects_id_compare(void *obj, void *jbo);
int objects_id_is_equal(void *obj, void *jbo);
void *objects_id_retain(void *obj);
void objects_id_release(void *obj);
void *objects_id_describe(void *obj);

#endif /* __callbacks_h_OBJECTS_INCLUDE */

