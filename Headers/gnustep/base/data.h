/* A modular data encapsulator for use with Libobjects.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Fri Nov 24 21:50:01 EST 1995
 * Updated: Sat Feb 10 15:40:21 EST 1996
 * Serial: 96.02.10.01
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

#ifndef __data_h_GNUSTEP_BASE_INCLUDE
#define __data_h_GNUSTEP_BASE_INCLUDE 1

/**** Included Headers *******************************************************/

#include <gnustep/base/allocs.h>
#include <gnustep/base/callbacks.h>

/**** Type, Constant, and Macro Definitions **********************************/

typedef enum _o_data_encoding o_data_encoding_t;

enum _o_data_encoding
  {
    o_data_encoding_unknown = -1,
    o_data_encoding_binary,
    o_data_encoding_7bit,
    o_data_encoding_8bit,
    o_data_encoding_base64,
    o_data_encoding_quoted_printable,
    o_data_encoding_x_uuencode
  };

typedef struct _o_data o_data_t;

struct _o_data
  {
    int magic;
    size_t number;
    const char *name;
    const void *extra;
    o_callbacks_t extra_callbacks;
    o_allocs_t allocs;

    /* Necessary information about the data. */
    void *buffer;		/* Where the stuff really is. */
    size_t length;		/* How much stuff there is. */
    size_t capacity;		/* How much room for stuff there is. */
  };

/* Creating temporary data.  This is *so* cool.  GCC is awesome! */
#define OBJECTS_DATA(P, L) \
  (o_data_t *(&({OBJECTS_MAGIC_DATA, (size_t) -1, 0, \
                        0, 0, __o_callbacks_standard, 0, 0, 0, \
                      __o_allocs_standard, (P), (L), (L)})))

/**** Function Prototypes ****************************************************/

/** Basics **/

#include <gnustep/base/data-bas.h>

/** Hashing **/

size_t o_data_hash (o_data_t * data);

/** Creating **/

o_data_t * o_data_alloc (void);

o_data_t * o_data_alloc_with_allocs (o_allocs_t allocs);

o_data_t * o_data_new (void);

o_data_t * o_data_new_with_allocs (o_allocs_t allocs);

o_data_t * _o_data_with_allocs_with_contents_of_file (o_allocs_t allocs, const char *file);

o_data_t * _o_data_with_contents_of_file (const char *file);

o_data_t * o_data_with_buffer_of_length (void *buffer, size_t length);

o_data_t * o_data_with_allocs_with_buffer_of_length (o_allocs_t allocs, void *buffer, size_t length);

/** Initializing **/

o_data_t * o_data_init (o_data_t * data);

o_data_t * _o_data_init_with_contents_of_file (o_data_t * data, const char *file);

o_data_t * o_data_init_with_buffer_of_length (o_data_t * data, void *buffer, size_t length);

/** Statistics **/

size_t o_data_capacity (o_data_t * data);

/* Obtain DATA's length. */
size_t o_data_length (o_data_t * data);

/* Obtain a read-only copy of DATA's buffer. */
const void *o_data_buffer (o_data_t * data);

/* Obtain DATA's capacity through reference. */
size_t o_data_get_capacity (o_data_t * data, size_t * capacity);

/* Obtain DATA's length through reference. */
size_t o_data_get_length (o_data_t * data, size_t * length);

/* Copy DATA's buffer into BUFFER.  It is assumed that BUFFER is large
 * enough to contain DATA's buffer. */
size_t o_data_get_buffer (o_data_t * data, void *buffer);

/* Copy no more that LENGTH of DATA's buffer into BUFFER.  Returns the
 * amount actually copied. */
size_t o_data_get_buffer_of_length (o_data_t * data, void *buffer, size_t length);

/* Copy a subrange of DATA's buffer into BUFFER.  As always, it is
 * assumed that BUFFER is large enough to contain everything.  We
 * return the size of the data actually copied into BUFFER. */
size_t o_data_get_buffer_of_subrange (o_data_t * data, void *buffer, size_t location, size_t length);

size_t o_data_set_capacity (o_data_t * data, size_t capacity);

size_t o_data_increase_capacity (o_data_t * data, size_t capacity);

size_t o_data_decrease_capacity (o_data_t * data, size_t capacity);

size_t o_data_set_length (o_data_t * data, size_t length);

size_t o_data_set_buffer_of_subrange (o_data_t * data, void *buffer, size_t location, size_t length);

size_t o_data_set_buffer_of_length (o_data_t * data, void *buffer, size_t length);

void o_data_get_md5_checksum (o_data_t * data, char *buffer);

/** Copying **/

o_data_t * o_data_copy (o_data_t * data);

o_data_t * o_data_copy_of_subrange (o_data_t * data, size_t location, size_t length);

o_data_t * o_data_copy_with_allocs (o_data_t * data, o_allocs_t allocs);

o_data_t * o_data_copy_of_subrange_with_allocs (o_data_t * data, size_t location, size_t length, o_allocs_t allocs);

/** Replacing **/

/* Note that we cannot do any bounds checking on BUFFER. */
o_data_t * o_data_replace_subrange_with_subrange_of_buffer (o_data_t * data, size_t location, size_t length, size_t buf_location, size_t buf_length, void *buffer);

o_data_t * o_data_replace_subrange_with_subrange_of_data (o_data_t * data, size_t location, size_t length, size_t other_location, size_t other_length, o_data_t * other_data);

o_data_t * o_data_replace_subrange_with_data (o_data_t * data, size_t location, size_t length, o_data_t * other_data);

/** Appending **/

o_data_t * o_data_append_data (o_data_t * data, o_data_t * other_data);

o_data_t * o_data_append_subrange_of_data (o_data_t * data, size_t location, size_t length, o_data_t * other_data);

o_data_t * o_data_append_data_repeatedly (o_data_t * data, o_data_t * other_data, size_t num_times);

o_data_t * o_data_append_subrange_of_data_repeatedly (o_data_t * data, size_t location, size_t length, o_data_t * other_data, size_t num_times);

/** Prepending **/

o_data_t * o_data_prepend_data (o_data_t * data, o_data_t * other_data);

o_data_t * o_data_prepend_subrange_of_data (o_data_t * data, size_t location, size_t length, o_data_t * other_data);

o_data_t * o_data_prepend_data_repeatedly (o_data_t * data, o_data_t * other_data, size_t num_times);

o_data_t * o_data_prepend_subrange_of_data_repeatedly (o_data_t * data, size_t location, size_t length, o_data_t * other_data, size_t num_times);

/** Concatenating **/

o_data_t * o_data_concatenate_data (o_data_t * data, o_data_t * other_data);

o_data_t * o_data_concatenate_data_with_allocs (o_data_t * data, o_data_t * other_data, o_allocs_t allocs);

o_data_t * o_data_concatenate_subrange_of_data (o_data_t * data, size_t location, size_t length, o_data_t * other_data);

o_data_t * o_data_concatenate_subrange_of_data_with_allocs (o_data_t * data, size_t location, size_t length, o_data_t * other_data, o_allocs_t allocs);

/** Reversing **/

o_data_t * o_data_reverse_with_granularity (o_data_t * data, size_t granularity);

o_data_t * o_data_reverse_by_int (o_data_t * data);

o_data_t * o_data_reverse_by_char (o_data_t * data);

o_data_t * o_data_reverse_by_void_p (o_data_t * data);

/** Permuting **/

o_data_t * o_data_permute_with_granularity (o_data_t * data, size_t granularity);

o_data_t * o_data_permute_with_no_fixed_points_with_granularity (o_data_t * data, size_t granularity);

/** Writing **/

int _o_data_write_to_file (o_data_t * data, const char *file);

/** Encoding **/

o_data_encoding_t o_data_guess_data_encoding (o_data_t * data);

o_data_t * _o_data_encode_with_base64 (o_data_t * data);

o_data_t * _o_data_encode_with_quoted_printable (o_data_t * data);

o_data_t * _o_data_encode_with_x_uuencode (o_data_t * data);

o_data_t * o_data_encode_with_encoding (o_data_t * data, o_data_encoding_t enc);

o_data_t * _o_data_decode_with_base64 (o_data_t * data);

o_data_t * _o_data_decode_with_quoted_printable (o_data_t * data);

o_data_t * _o_data_decode_with_x_uuencode (o_data_t * data);

o_data_t * o_data_decode_with_encoding (o_data_t * data, o_data_encoding_t enc);

#endif /* __data_h_GNUSTEP_BASE_INCLUDE */
