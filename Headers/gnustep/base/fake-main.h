/* LibobjectsMain.h for GNUStep
   Copyright (C) 1995, 1996 Free Software Foundation, Inc.

   Written by:  Georg Tuparev, EMBL & Academia Naturalis, 
                Heidelberg, Germany
                Tuparev@EMBL-Heidelberg.de
   Last update: 05-aug-1995
   
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
   Software Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
   */ 

#ifndef __fake_main_h_GNUSTEP_BASE_INCLUDE
#define __fake_main_h_GNUSTEP_BASE_INCLUDE

/* 
   Several Foundation classes (NSBundle, NSProcessInfo, ...) need access
   to the argc, argv, and env variables of the main() function. The purpose 
   of this (ugly hack) definition is to give the libobjects library the
   oportunity to implement its own main function with private access to the
   global vars. The private main() implementation then will call the user
   defined (now renamed to LibobjectsMain()) function. The libobjects main()
   functions is implemented in NSProcessInfo.m
*/

#if (!defined(SYS_AUTOLOAD)) || defined(__FreeBSD__)
#ifndef __MINGW32__
#define main gnustep_base_user_main
extern int gnustep_base_user_main (/* int argc, char *argv[] */);
#endif
#endif /* __ELF__ */

/*
  NOTE! This is very dirty and dangerous trick. I spend several hours
  on thinking and man pages browsing, but couldn't find better solution.
  I know that I will spend 666 years in the Computer Hell for writing
  this hack, and the master devil (Bully Boy) will send me to write
  Windowz software. 
  BTW, for writing this hack I got personal congratulations from Dennis
  Ritchie and Bjarne Stroustrup sent me a bunch of flowers and asked me 
  to participate in the standardization committee for C-- v.6.0 as 
  responsible for the new Tab-Overriding-Operator and Scope-Sensitive-
  Comments ... but this makes my situation even worse ;-)
  - Georg
*/

#endif /* __fake_main_h_GNUSTEP_BASE_INCLUDE */
