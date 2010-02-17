/* 
   The implementation of synchronization primitives for Objective-C.
   Copyright (C) 2008 Free Software Foundation, Inc.

   This file is part of GNUstep.

   Gregory Casamento <greg.casamento@gmail.com>

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


#include <stdlib.h>
#include "objc/objc.h"
#include "objc/objc-api.h"
#import "GSPThread.h"

/*
 * Node structure...
 */
typedef struct lock_node {
  id obj;
  pthread_mutex_t lock;
  struct lock_node *next;
  struct lock_node *prev;
} lock_node_t;

/*
 * Return types for the locks...
 */
typedef enum { 
  OBJC_SYNC_SUCCESS = 0,
  OBJC_SYNC_NOT_OWNING_THREAD_ERROR = -1,
  OBJC_SYNC_TIMED_OUT = -2,
  OBJC_SYNC_NOT_INITIALIZED = -3		
} sync_return_t;

static lock_node_t *lock_list = NULL;
static pthread_mutex_t table_lock = PTHREAD_MUTEX_INITIALIZER; 

/**
 * Find the node in the list.
 */
static lock_node_t*
sync_find_node(id obj)
{
  lock_node_t *current = lock_list;

  if (lock_list != NULL)
    {
      // iterate over the list looking for the end...
      while (current != NULL)
	{
	  // if the current object is the one, breal and
	  // return that node.
	  if (current->obj == obj)
	    {
	      break;
	    }

	  // get the next one...
	  current = current->next;
	}
    }
  return current;
}

/**
 * Add a node for the object, if one doesn't already exist.
 */
static lock_node_t*
sync_add_node(id obj)
{
  lock_node_t *current = NULL;

  // if the list hasn't been initialized, initialize it.
  if (lock_list == NULL)
    {
      // instantiate the new node and set the list...
      lock_list = malloc(sizeof(lock_node_t));

      // set the current node to the last in the list...
      current = lock_list;

      // set next and prev...
      current->prev = NULL;
      current->next = NULL;
    }
  else 
    {
      lock_node_t *new_node = NULL;
      current = lock_list;

      // look for the end of the list.
      while (current->next)
	{
	  current = current->next;
	}

      // instantiate the new node...
      new_node = malloc(sizeof(lock_node_t));

      if (new_node != NULL)
	{
	  // set next and prev...
	  current->next = new_node;
	  new_node->prev = current;
	  new_node->next = NULL;
	  
	  // set the current node to the last in the list...
	  current = new_node;
	}
    }

  if (current != NULL)
    {
      // add the object and it's lock
      current->obj = obj;
      GS_INIT_RECURSIVE_MUTEX(current->lock);
    }

  return current;
}

/**
 * Add a lock for the object.
 */ 
#ifndef __MINGW32__
int
__attribute__((weak))
#else
int
#endif
objc_sync_enter(id obj)
{
  lock_node_t *node = NULL;
  int status = 0;

  pthread_mutex_lock(&table_lock);

  node = sync_find_node(obj);
  if (node == NULL)
    {
      node = sync_add_node(obj);
      if (node == NULL)
	{
	  // unlock the table....
	  pthread_mutex_unlock(&table_lock);  
	  return OBJC_SYNC_NOT_INITIALIZED;
	}
    }

  // unlock the table....
  pthread_mutex_unlock(&table_lock);  

  status = pthread_mutex_lock(&(node->lock));

  // if the status is more than one, then another thread
  // has this section locked, so we abort.  A status of -1
  // indicates that an error occurred.
  if (status > 1 || status == -1)
    {
      return OBJC_SYNC_NOT_OWNING_THREAD_ERROR;
    }

  return OBJC_SYNC_SUCCESS;
}

/**
 * Remove a lock for the object.
 */
#ifndef __MINGW32__
int
__attribute__((weak))
#else
int
#endif
objc_sync_exit(id obj)
{
  lock_node_t *node = NULL;
  int status = 0;

  pthread_mutex_lock(&table_lock);

  node = sync_find_node(obj);
  if (node == NULL)
    {
      // unlock the table....
      pthread_mutex_unlock(&table_lock);  
      return OBJC_SYNC_NOT_INITIALIZED;
    }

  status = pthread_mutex_unlock(&(node->lock));

  // unlock the table....
  pthread_mutex_unlock(&table_lock);  

  // if the status is not zero, then we are not the sole
  // owner of this node.  Also if -1 is returned, this indicates and error
  // condition.
  if (status > 0 || status == -1)
    {
      return OBJC_SYNC_NOT_OWNING_THREAD_ERROR;      
    }
 
  return OBJC_SYNC_SUCCESS;  
}

