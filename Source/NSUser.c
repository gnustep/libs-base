/* Implementation of NSUser functions for GNUStep
   Copyright (C) 1995 Free Software Foundation, Inc.
 
   Author: Martin Michlmayr <tbm@ihq.com>

   Intelligence HeadQuarters has donated this file to the Free
   Software Foundation in the hope that it will be useful for you.

   This file is part of the GNU Objective-C Class Library.

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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

   Description:

   These functions let you request information about users.
   Currently only UNIX is supported, but I am looking forward to add
   OS/2 and Windows NT support.

*/

/* TODO

 * add NSString support instead using char.
 * use the same error return value as NeXT does.
 * add OS/2 support.
 * add Windows NT support.
 * add Windows 95 support.

*/


#include "NSUser.h"
#include <unistd.h>
/*
// This library is being used to get the UID (User ID) of the user who has
// started the program, and thus, is the current user.
*/

#include <pwd.h>
/*
// This library is being used to receive information about users of the
// computer on which the program runs.
*/


  struct passwd * currentPasswd;
/*
// This structure is being used to store information about the current user.
*/


void _get_current_info (void)
{

   uid_t currentUserID;
/*
// This variable is used to store the UID (User ID) of the current user.
*/

   currentUserID = getuid ();   /* // The UID is stored in currenUserID. */
   currentPasswd = getpwuid (currentUserID);
/*
// The function getpwuid from pwd.h is called to get some information about
// the UID.
*/

}

char * NSUserName (void)
/*
// This function returns the username of the user who has started the program.
// It's NOT OpenStep compliant yet, because it should return a NSString, but
// I am currently not able to compile the new version of libobjects that
// supports the NSString class.
// This is true for all of this three functions.
*/

{

   if (currentPasswd == NULL) _get_current_info ();
/*
// This line of code checks if you have already requested information about
// this user before. If not, it starts the function to obtain the information.
// If this, or the NSHomeDirectory, function has been used before you can skip
// the part of requesting information because it's still stored in the
// currentPasswd structure and the current user can't change.
// If you change something in the /etc/passwd file, this functions still
// returns the old information.
// I don't think that this will happen too often as the UID is normally only
// allocated once and you won't change the path of your homedirectory very
// often. On the other side, it saves some processor-cyles.
*/

   return (currentPasswd->pw_name); /* // Finally, returns the username. */

}

char * NSHomeDirectory (void)
/*
// This function returns the path of the homedirectory of the current user.
// The same problems as with NSUserName occur.
*/

{

   if (currentPasswd == NULL) _get_current_info ();
/*
// If this, or the NSUserName, function has not been started before, this
// function gets information about the user who has started the program.
// For a detailed description, look at the NSUserName function.
*/

   return (currentPasswd->pw_dir); /* Returns the homedirectory */

}

char * NSHomeDirectoryForUser (char * userName)
/*
// This information returns the path of the homedirectory of a specific user.
*/

{
  struct passwd * myPasswd;
/*
// Structure to store information about a specific user.
*/

   myPasswd = getpwnam (userName);
/*
// Stores information about the requested user in myPasswd.
*/

   if (myPasswd == NULL) 
    { 

       fprintf (stderr, "GNU Foundation Kit Error in NSHomeDirectoryForUser: "
                 "No such User\n");
       return ("/tmp");
/*
// If there is no such user, /tmp will be returned as homedirectory and an
// error-message will be sent to stderr. 
//
// We should take a look at NeXT's FK implementation so we can return the
// same as they do. There is no note about this error-case in the
// OpenStepSpec. If an error-message should be displayed, we should probably
// use NSLog instead of the fprintf function. -- tbm
*/

    }

   return (myPasswd->pw_dir);
/*
// Returns the homedirectory of the requested user
*/

}

