/* A (pretty good) implementation of a self-contained data object,
 * complete with checksum and encoding/decoding capability.
 * Copyright (C) 1995, 1996  Free Software Foundation, Inc.
 * 
 * Author: Albin L. Jones <Albin.L.Jones@Dartmouth.EDU>
 * Created: Fri Nov 24 21:46:14 EST 1995
 * Updated: Sat Feb 10 16:12:17 EST 1996
 * Serial: 96.02.10.07
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

/**** Included Headers *******************************************************/

#include <gnustep/base/bitops.h>
#include <gnustep/base/minmax.h>
#include <gnustep/base/abort.h>
#include <gnustep/base/data.h>
#include <md5.h>

/**** Type, Constant, and Macro Definitions **********************************/

/**** Function Implementations ***********************************************/

/** Hashing **/

size_t
objects_data_hash (objects_data_t * data)
{
  /* FIXME: Code this. */
  return 0;
}

/** Creating **/

objects_data_t *
objects_data_alloc (void)
{
  return objects_data_alloc_with_allocs (objects_allocs_standard ());
}

objects_data_t *
objects_data_alloc_with_allocs (objects_allocs_t allocs)
{
  objects_data_t *data;

  /* Make a new data structure. */
  data = _objects_data_alloc_with_allocs (allocs);

  return data;
}

objects_data_t *
objects_data_new (void)
{
  return objects_data_new_with_allocs (objects_allocs_standard ());
}

objects_data_t *
objects_data_new_with_allocs (objects_allocs_t allocs)
{
  return objects_data_init (objects_data_alloc_with_allocs (allocs));
}

objects_data_t *
_objects_data_with_allocs_with_contents_of_file (objects_allocs_t allocs,
						 const char *file)
{
  return _objects_data_init_with_contents_of_file (objects_data_alloc_with_allocs (allocs),
						   file);
}

objects_data_t *
_objects_data_with_contents_of_file (const char *file)
{
  return _objects_data_with_allocs_with_contents_of_file (objects_allocs_standard (),
							  file);
}

objects_data_t *
objects_data_with_buffer_of_length (void *buffer, size_t length)
{
  return objects_data_with_allocs_with_buffer_of_length (objects_allocs_standard (),
							 buffer, length);
}

objects_data_t *
objects_data_with_allocs_with_buffer_of_length (objects_allocs_t allocs,
						void *buffer,
						size_t length)
{
  return objects_data_init_with_buffer_of_length (objects_data_alloc_with_allocs (allocs),
						  buffer, length);
}

/** Destroying **/

void
objects_data_dealloc (objects_data_t * data)
{
  if (data != NULL)
    {
      /* Free up DATA's buffer if we've used it. */
      if (data->buffer != NULL)
	objects_free (objects_data_allocs (data), data->buffer);

      /* Free up DATA itself. */
      _objects_data_dealloc (data);
    }

  return;
}

/** Initializing **/

objects_data_t *
objects_data_init (objects_data_t * data)
{
  return objects_data_init_with_buffer_of_length (data, NULL, 0);
}

objects_data_t *
_objects_data_init_with_contents_of_file (objects_data_t * data, const char *file)
{
  objects_data_t *new_data;
  void *buffer;
  FILE *f;
  long int length;
  long int d;
  int c;

  f = fopen (file, "r");

  if (f == NULL)		/* We failed to open the file. */
    goto failure;

  /* Seek to the end of the file. */
  c = fseek (f, 0L, SEEK_END);

  if (c != 0)			/* Something went wrong; though I
				 * don't know what. */
    goto failure;

  /* Determine the length of the file (having seeked to the end of the
   * file) by calling ftell(). */
  length = ftell (f);

  if (length == -1)		/* I can't imagine what could go
				 * wrong, but here we are. */
    goto failure;

  /* Set aside the space we'll need. */
  buffer = objects_malloc (objects_data_allocs (data), length);

  if (buffer == NULL)		/* Out of memory, I guess. */
    goto failure;

  /* Rewind the file pointer to the beginning, preparing to read in
   * the file. */
  c = fseek (f, 0L, SEEK_SET);

  if (c != 0)			/* Oh, No. */
    goto failure;

  /* Update the change time. */
  _objects_data_set_change_time (data);

  /* Now we read FILE into BUFFER one (unsigned) byte at a time.
   * FIXME: We should probably be more careful to check that we don't
   * get an EOF.  But what would this mean?  That the file had been
   * changed in the middle of all this.  FIXME: So maybe we should
   * think about locking the file? */
  for (d = 0; d < length; d++)
    ((unsigned char *) buffer)[d] = (unsigned char) fgetc (f);

  /* success: */
  new_data = objects_data_init_with_buffer_of_length (data, buffer, length);

  /* Free up BUFFER, since we're done with it. */
  objects_free (objects_data_allocs (data), buffer);

  return new_data;

  /* Just in case the failure action needs to be changed. */
failure:
  return NULL;
}

objects_data_t *
objects_data_init_with_buffer_of_length (objects_data_t * data,
					 void *buffer,
					 size_t length)
{
  if (data != NULL)
    {
      data->buffer = NULL;
      data->length = 0;
      data->capacity = 0;

      objects_data_set_buffer_of_length (data, buffer, length);
    }

  return data;
}

objects_data_t *
objects_data_init_with_subrange_of_data (objects_data_t * data,
					 size_t location,
					 size_t length,
					 objects_data_t * old_data)
{
  if (data != NULL)
    {
      /* Make sure we don't step out of bounds. */
      location = MIN (location, old_data->length);
      length = MIN (old_data->length - location, length);

      /* Copy over the contents. */
      objects_data_init_with_buffer_of_length (data, old_data->buffer + location,
					       old_data->length);
    }

  return data;
}

/** Statistics **/

size_t
objects_data_capacity (objects_data_t * data)
{
  /* Update the access time. */
  _objects_data_set_access_time (data);

  return data->capacity;
}

/* Obtain DATA's length. */
size_t
objects_data_length (objects_data_t * data)
{
  /* Update the access time. */
  _objects_data_set_access_time (data);

  return data->length;
}

/* Obtain a read-only copy of DATA's buffer. */
const void *
objects_data_buffer (objects_data_t * data)
{
  /* Update the access time. */
  _objects_data_set_access_time (data);

  return data->buffer;
}

/* Obtain DATA's capacity through reference. */
size_t
objects_data_get_capacity (objects_data_t * data, size_t * capacity)
{
  /* Update the access time. */
  _objects_data_set_access_time (data);

  if (capacity != NULL)
    *capacity = data->capacity;

  return data->capacity;
}

/* Obtain DATA's length through reference. */
size_t
objects_data_get_length (objects_data_t * data, size_t * length)
{
  /* Update the access time. */
  _objects_data_set_access_time (data);

  if (length != NULL)
    *length = data->length;

  return data->length;
}

/* Copy DATA's buffer into BUFFER.  It is assumed that BUFFER is large
 * enough to contain DATA's buffer. */
size_t
objects_data_get_buffer (objects_data_t * data, void *buffer)
{
  return objects_data_get_buffer_of_subrange (data, buffer, 0, data->length);
}

/* Copy no more that LENGTH of DATA's buffer into BUFFER.  Returns the
 * amount actually copied. */
size_t
objects_data_get_buffer_of_length (objects_data_t * data, void *buffer, size_t length)
{
  return objects_data_get_buffer_of_subrange (data, buffer, 0, length);
}

/* Copy a subrange of DATA's buffer into BUFFER.  As always, it is
 * assumed that BUFFER is large enough to contain everything.  We
 * return the size of the data actually copied into BUFFER. */
size_t
objects_data_get_buffer_of_subrange (objects_data_t * data,
				     void *buffer,
				     size_t location,
				     size_t length)
{
  size_t real_length;

  /* Update the access time. */
  _objects_data_set_access_time (data);

  /* Figure out how much we really can copy. */
  real_length = MIN (data->length - location, length);

  /* Copy over the data. */
  memmove (buffer, data->buffer + location, real_length);

  /* Tell how much we actually copied. */
  return real_length;
}

size_t
objects_data_set_capacity (objects_data_t * data, size_t capacity)
{
  size_t cap;

  /* Update the change time. */
  _objects_data_set_change_time (data);

  /* Over shoot a little. */
  cap = objects_next_power_of_two (capacity);

  if (data->buffer == NULL)
    data->buffer = objects_malloc (objects_data_allocs (data), cap);
  else				/* (data->buffer != NULL) */
    data->buffer = objects_realloc (objects_data_allocs (data), data->buffer, cap);

  /* FIXME: Check for failure of the allocs above. */

  /* DATA needs to know that it can hold CAP's worth of stuff. */
  data->capacity = cap;

  /* Make sure that DATA's length is no greater than its capacity. */
  data->length = MIN (data->length, data->capacity);

  return cap;
}

size_t
objects_data_increase_capacity (objects_data_t * data, size_t capacity)
{
  return objects_data_set_capacity (data, objects_data_capacity (data) + capacity);
}

size_t
objects_data_decrease_capacity (objects_data_t * data, size_t capacity)
{
  size_t old_capacity = objects_data_capacity (data);

  return objects_data_set_capacity (data, old_capacity - MIN (capacity,
							      old_capacity));
}

size_t
objects_data_set_length (objects_data_t * data, size_t length)
{
  /* Update the change time. */
  _objects_data_set_change_time (data);

  /* The only thing we need to be careful of is that DATA's length is
   * no greater than its capacity. */
  return data->length = MIN (length, objects_data_capacity (data));
}

size_t
objects_data_set_buffer_of_subrange (objects_data_t * data,
				     void *buffer,
				     size_t location,
				     size_t length)
{
  /* Arrange for DATA to have space for LENGTH amount of information. */
  objects_data_set_capacity (data, length);

  /* Copy the stuff in BUFFER over to DATA. */
  memmove (data->buffer, buffer + location, length);

  /* Make sure DATA knows how much it's holding. */
  objects_data_set_length (data, length);

  return length;
}

size_t
objects_data_set_buffer_of_length (objects_data_t * data, void *buffer, size_t length)
{
  return objects_data_set_buffer_of_subrange (data, buffer, 0, length);
}

void
objects_data_get_md5_checksum (objects_data_t * data, char *buffer)
{
  if (buffer != NULL)
    {
      char cksum[17];

      /* Perform the MD5 checksum on DATA's buffer. */
      md5_buffer ((const char *) (data->buffer), data->length, cksum);

      /* Copy CKSUM into BUFFER. */
      strcpy (buffer, cksum);
    }

  return;
}

/** Copying **/

objects_data_t *
objects_data_copy (objects_data_t * data)
{
  return objects_data_copy_with_allocs (data, objects_data_allocs (data));
}

objects_data_t *
objects_data_copy_of_subrange (objects_data_t * data, size_t location, size_t length)
{
  return objects_data_copy_of_subrange_with_allocs (data, location, length,
						objects_data_allocs (data));
}

objects_data_t *
objects_data_copy_with_allocs (objects_data_t * data, objects_allocs_t allocs)
{
  return objects_data_copy_of_subrange_with_allocs (data, 0, data->length, allocs);
}

objects_data_t *
objects_data_copy_of_subrange_with_allocs (objects_data_t * data,
					   size_t location,
					   size_t length,
					   objects_allocs_t allocs)
{
  objects_data_t *copy;

  /* Make a low-level copy. */
  copy = _objects_data_copy_with_allocs (data, allocs);

  objects_data_init_with_subrange_of_data (copy, location, length, data);

  return copy;
}

/** Replacing **/

/* Note that we cannot do any bounds checking on BUFFER. */
objects_data_t *
objects_data_replace_subrange_with_subrange_of_buffer (objects_data_t * data,
						       size_t location,
						       size_t length,
						       size_t buf_location,
						       size_t buf_length,
						       void *buffer)
{
  /* Update the change time. */
  _objects_data_set_change_time (data);

  /* Make sure we're inside DATA. */
  location = MIN (location, data->length);
  length = MIN (data->length - location, length);

  if (buf_length > length)
    {
      /* Increase DATA's capacity. */
      objects_data_increase_capacity (data, buf_length - length);

      /* Move the tail of DATA's buffer over BUF_LENGTH. */
      memmove (data->buffer + location + buf_length,
	       data->buffer + location + length,
	       data->length - location - length);

      /* Copy the subrange of BUFFER into DATA. */
      memmove (data->buffer + location, buffer + buf_location, buf_length);

      /* Update DATA's length. */
      objects_data_set_length (data, data->length + buf_length - length);
    }
  else
    /* (buf_length <= length) */
    {
      /* Copy the subrange of BUFFER into DATA. */
      memmove (data->buffer + location, buffer + buf_location, buf_length);

      /* Move the tail of DATA's buffer over BUF_LENGTH. */
      memmove (data->buffer + location + buf_length,
	       data->buffer + location + length,
	       data->length - location - length);

      /* Decrease DATA's length to accomodate BUF_LENGTH's worth of BUFFER. */
      objects_data_decrease_capacity (data, length - buf_length);

      /* Update DATA's length. */
      objects_data_set_length (data, data->length - length + buf_length);
    }

  return data;
}

objects_data_t *
objects_data_replace_subrange_with_subrange_of_data (objects_data_t * data,
						     size_t location,
						     size_t length,
						     size_t other_location,
						     size_t other_length,
						objects_data_t * other_data)
{
  /* Update OTHER_DATA's access time. */
  _objects_data_set_access_time (other_data);

  /* Make sure we're inside DATA. */
  other_location = MIN (other_location, other_data->length);
  other_length = MIN (other_data->length - other_location, other_length);

  /* Copy away. */
  return objects_data_replace_subrange_with_subrange_of_buffer (data, location,
								length,
							     other_location,
								other_length,
							other_data->buffer);
}

objects_data_t *
objects_data_replace_subrange_with_data (objects_data_t * data,
					 size_t location,
					 size_t length,
					 objects_data_t * other_data)
{
  /* Update OTHER_DATA's access time. */
  _objects_data_set_access_time (other_data);

  /* Copy away. */
  return objects_data_replace_subrange_with_subrange_of_buffer (data, location,
								length,
								0,
							 other_data->length,
							other_data->buffer);
}

/** Appending **/

objects_data_t *
objects_data_append_data (objects_data_t * data, objects_data_t * other_data)
{
  return objects_data_replace_subrange_with_subrange_of_data (data,
							      data->length,
							      0, 0,
							 other_data->length,
							      other_data);
}

objects_data_t *
objects_data_append_subrange_of_data (objects_data_t * data,
				      size_t location,
				      size_t length,
				      objects_data_t * other_data)
{
  return objects_data_replace_subrange_with_subrange_of_data (data, data->length,
							0, location, length,
							      other_data);
}

objects_data_t *
objects_data_append_data_repeatedly (objects_data_t * data,
				     objects_data_t * other_data,
				     size_t num_times)
{
  /* FIXME: Do this more efficiently.  You know how. */
  while (num_times--)
    objects_data_append_data (data, other_data);

  return data;
}

objects_data_t *
objects_data_append_subrange_of_data_repeatedly (objects_data_t * data,
						 size_t location,
						 size_t length,
						 objects_data_t * other_data,
						 size_t num_times)
{
  /* FIXME: Do this more efficiently.  You know how. */
  while (num_times--)
    objects_data_append_subrange_of_data (data, location, length, other_data);

  return data;
}

/** Prepending **/

objects_data_t *
objects_data_prepend_data (objects_data_t * data, objects_data_t * other_data)
{
  return objects_data_replace_subrange_with_subrange_of_data (data,
							      0, 0, 0,
							 other_data->length,
							      other_data);
}

objects_data_t *
objects_data_prepend_subrange_of_data (objects_data_t * data,
				       size_t location,
				       size_t length,
				       objects_data_t * other_data)
{
  return objects_data_replace_subrange_with_subrange_of_data (data,
							      0, 0, location,
							      length,
							      other_data);
}

objects_data_t *
objects_data_prepend_data_repeatedly (objects_data_t * data,
				      objects_data_t * other_data,
				      size_t num_times)
{
  /* FIXME: Do this more efficiently.  You know how. */
  while (num_times--)
    objects_data_prepend_data (data, other_data);

  return data;
}

objects_data_t *
objects_data_prepend_subrange_of_data_repeatedly (objects_data_t * data,
						  size_t location,
						  size_t length,
						objects_data_t * other_data,
						  size_t num_times)
{
  /* FIXME: Do this more efficiently.  You know how. */
  while (num_times--)
    objects_data_prepend_subrange_of_data (data, location, length, other_data);

  return data;
}

/** Concatenating **/

objects_data_t *
objects_data_concatenate_data (objects_data_t * data,
			       objects_data_t * other_data)
{
  return objects_data_concatenate_data_with_allocs (data, other_data,
						objects_data_allocs (data));
}

objects_data_t *
objects_data_concatenate_data_with_allocs (objects_data_t * data,
					   objects_data_t * other_data,
					   objects_allocs_t allocs)
{
  objects_data_t *new_data;

  /* Make a copy of DATA. */
  new_data = objects_data_copy_with_allocs (data, allocs);

  /* Append OTHER_DATA to DATA. */
  objects_data_append_data (data, other_data);

  /* Return the concatenation. */
  return new_data;
}

objects_data_t *
objects_data_concatenate_subrange_of_data (objects_data_t * data,
					   size_t location,
					   size_t length,
					   objects_data_t * other_data)
{
  return objects_data_concatenate_subrange_of_data_with_allocs (data, location,
								length,
								other_data,
						objects_data_allocs (data));
}

objects_data_t *
objects_data_concatenate_subrange_of_data_with_allocs (objects_data_t * data,
						       size_t location,
						       size_t length,
						objects_data_t * other_data,
						    objects_allocs_t allocs)
{
  objects_data_t *new_data;

  /* Make a copy of DATA. */
  new_data = objects_data_copy_with_allocs (data, allocs);

  /* Append the subrange of OTHER_DATA to DATA. */
  objects_data_append_subrange_of_data (data, location, length, other_data);

  /* Return the concatenation. */
  return new_data;
}

/** Reversing **/

objects_data_t *
objects_data_reverse_with_granularity (objects_data_t * data, size_t granularity)
{
  /* Update the change time. */
  _objects_data_set_change_time (data);

  if ((data->length % granularity) == 0)
    {
      size_t i;
      objects_allocs_t allocs;
      void *buffer;

      /* Remember the allocs that DATA use. */
      allocs = objects_data_allocs (data);

      /* Create a temporary buffer for to play wif. */
      buffer = objects_malloc (allocs, data->length);

      /* FIXME: Do some checking here, good man. */

      /* Make a flipped copy of DATA in BUFFER. */
      for (i = 0; i < data->length; i += granularity)
	memcpy (data->buffer + i,
		data->buffer + data->length - (i + granularity),
		granularity);

      /* Copy the reversed version back into DATA. */
      memcpy (data->buffer, buffer, data->length);

      /* Free the temporary buffer. */
      objects_free (allocs, buffer);
    }

  return data;
}

objects_data_t *
objects_data_reverse_by_int (objects_data_t * data)
{
  return objects_data_reverse_with_granularity (data, sizeof (int));
}

objects_data_t *
objects_data_reverse_by_char (objects_data_t * data)
{
  return objects_data_reverse_with_granularity (data, sizeof (char));
}

objects_data_t *
objects_data_reverse_by_void_p (objects_data_t * data)
{
  return objects_data_reverse_with_granularity (data, sizeof (void *));
}

/** Permuting **/

objects_data_t *
objects_data_permute_with_granularity (objects_data_t * data, size_t granularity)
{
  /* FIXME: Code this. */
}

objects_data_t *
objects_data_permute_with_no_fixed_points_with_granularity (objects_data_t * data,
							 size_t granularity)
{
  /* FIXME: Code this. */
}

/** Writing **/

int
_objects_data_write_to_file (objects_data_t * data, const char *file)
{
  FILE *f;
  int c;

  /* Open the file (whether temp or real) for writing. */
  f = fopen (file, "w");

  if (f == NULL)		/* Something went wrong; we weren't
				 * even able to open the file. */
    goto failure;

  /* Update the access time. */
  _objects_data_set_access_time (data);

  /* Now we try and write DATA's buffer to the file.  Here C is the
   * number of bytes which were successfully written to the file in
   * the fwrite() call. */
  /* FIXME: Do we need the `sizeof(char)' here? Is there any system
   * where sizeof(char) isn't just 1?  Or is it guaranteed to be 8
   * bits? */
  c = fwrite (data->buffer, sizeof (char), data->length, f);

  if (c < data->length)		/* We failed to write everything for
				 * some reason. */
    goto failure;

  /* We're done, so close everything up. */
  c = fclose (f);

  if (c != 0)			/* I can't imagine what went wrong
				 * closing the file, but we got here,
				 * so we need to deal with it. */
    goto failure;

  /* success: */
  return 1;

  /* Just in case the failure action needs to be changed. */
failure:
  return 0;
}

/** Encoding **/

objects_data_encoding_t
objects_data_guess_data_encoding (objects_data_t * data)
{
}

/* FIXME: I don't quite know how to deal with the following paragraph
 * of the base64 specification from RFC 1521: "Care must be taken to
 * use the proper octets for line breaks if base64 encoding is applied
 * directly to text material that has not been converted to canonical
 * form.  In particular, text line breaks must be converted into CRLF
 * sequences prior to base64 encoding.  The important thing to note is
 * that this may be done directly by the encoder rather than in a
 * prior canonicalization step in some implementations."  I think that
 * what I am doing is acceptable, but just wanted to note this
 * possible glitch for my sanity's sake. */
objects_data_t *
_objects_data_encode_with_base64 (objects_data_t * data)
{
  unsigned char *buffer;
  unsigned char *d_buffer;
  size_t d_length, length, blocks, extras;
  size_t c, i, j;
  unsigned char base64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=";

  void do_base64_block (unsigned char *in, unsigned char *out)
  {
    out[0] = base64[(in[0] >> 2)];
    out[1] = base64[((in[0] & 0x03) << 4) + (in[1] >> 4)];
    out[2] = base64[((in[1] & 0x0f) << 2) + (in[2] << 6)];
    out[3] = base64[(in[2] & 0x3f)];
  }

  /* Do some figuring.  WARNING: We assume throughout that there are
   * precisely eight bits in an unsigned char.  Is this ever a
   * problem?  FIXME: Can we assume that `sizeof(unsigned char)' is
   * one? */
  d_length = (data->length) / sizeof (unsigned char);
  blocks = d_length / 3;
  extras = d_length % 3;
  length = (blocks + ((extras + 1) / 2)) * 4;

  /* Make room to put the encoded information temporarily. */
  buffer = (unsigned char *) objects_malloc (objects_data_allocs (data), length);
  d_buffer = (unsigned char *) (data->buffer);

  /* Translate blocks of three eights into blocks of four sixes. */
  for (c = 0; c < blocks; ++c, j += 4, i += 3)
    do_base64_block (d_buffer + i, buffer + j);

  /* Now we need to worry about any stragglers... */
  if (extras != 0)
    {
      /* Pad with zeros. */
      unsigned char in_block[3] =
      {0x00, 0x00, 0x00};

      /* Copy over the stragglers into our temporary buffer. */
      for (c = 0; c < extras; ++c)
	in_block[c] = d_buffer[i + c];

      /* Base64-ize the temporary buffer into the end of BUFFER. */
      do_base64_block (in_block, buffer + j);

      /* Pad the end of BUFFER with the base64 pad character '='. */
      for (c = 3; c > extras; --c)
	buffer[j + c] = base64[64];
    }

  /* Copy the encoded buffer back into DATA. */
  objects_data_set_buffer_of_length (data, buffer, length);

  return data;
}

objects_data_t *
_objects_data_encode_with_quoted_printable (objects_data_t * data)
{
  objects_data_t *other_data;
  unsigned char *d_buffer;
  size_t d_length, c;

  /* Remember DATA's characteristics. */
  d_buffer = (unsigned char *) (data->buffer);
  d_length = (data->length) / sizeof (unsigned char);

  /* Create another flexible buffer. */
  other_data = objects_data_new_with_allocs (objects_data_allocs (data));

  for (c = 0; c < d_length; ++c)
    {
      switch (d_buffer[c])
	{
	case 0x21 ... 0x3c:
	case 0x3e ... 0xfe:
	  break;
	case 0x0a:
	default:
	}
    }

  /* Get rid of our temporary storage. */
  objects_data_dealloc (other_data);

  /* FIXME: Finish this. */

  return data;
}

objects_data_t *
_objects_data_encode_with_x_uuencode (objects_data_t * data)
{
  /* FIXME: Code this. */
  return data;
}

objects_data_t *
objects_data_encode_with_data_encoding (objects_data_t * data, objects_data_encoding_t enc)
{
  switch (enc)
    {
    case objects_data_encoding_base64:
      return _objects_data_encode_with_base64 (data);
      break;
    case objects_data_encoding_quoted_printable:
      return _objects_data_encode_with_quoted_printable (data);
      break;
    case objects_data_encoding_x_uuencode:
      return _objects_data_encode_with_x_uuencode (data);
      break;
    case objects_data_encoding_unknown:
    case objects_data_encoding_binary:
    case objects_data_encoding_7bit:
    case objects_data_encoding_8bit:
    default:
      return data;
      break;
    }

  return data;
}

objects_data_t *
_objects_data_decode_with_base64 (objects_data_t * data)
{
  /* FIXME: Code this. */
  return data;
}

objects_data_t *
_objects_data_decode_with_quoted_printable (objects_data_t * data)
{
  /* FIXME: Code this. */
  return data;
}

objects_data_t *
_objects_data_decode_with_x_uuencode (objects_data_t * data)
{
  /* FIXME: Code this. */
  return data;
}

objects_data_t *
objects_data_decode_with_data_encoding (objects_data_t * data, objects_data_encoding_t enc)
{
  switch (enc)
    {
    case objects_data_encoding_base64:
      return _objects_data_decode_with_base64 (data);
      break;
    case objects_data_encoding_quoted_printable:
      return _objects_data_decode_with_quoted_printable (data);
      break;
    case objects_data_encoding_x_uuencode:
      return _objects_data_decode_with_x_uuencode (data);
      break;
    case objects_data_encoding_unknown:
    case objects_data_encoding_binary:
    case objects_data_encoding_7bit:
    case objects_data_encoding_8bit:
    default:
      return data;
      break;
    }

  return data;
}

