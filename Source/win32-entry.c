/* DLL entry routine
   Copyright (C) 1996 Free Software Foundation, Inc.

   Original Author:  Scott Christley <scottc@net-community.com>
   Created: 1996
   
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

#include <windows.h>

/* Only if using Microsoft's tools and libraries */
#ifdef __MS_WIN32__
#include <stdio.h>
WINBOOL WINAPI _CRT_INIT( HINSTANCE hinstDLL, DWORD fdwReason,
			  LPVOID lpReserved );

// Global errno isn't defined in Microsoft's thread safe C library
void errno()
{}

int _MB_init_runtime()
{
    return 0;
}
#endif /* __MS_WIN32__ */

int gnustep_base_user_main(int argc, char *argv[], char *env[])
{
    return 0;
}

//
// DLL entry function for GNUstep Base Library
// This function gets called everytime a process/thread attaches to DLL
//
WINBOOL WINAPI DLLMain(HANDLE hInst, ULONG ul_reason_for_call,
		       LPVOID lpReserved)
{
    if (ul_reason_for_call == DLL_PROCESS_ATTACH)
	{
#ifdef __MS_WIN32__
	    /* Initialize C stdio DLL */
	    _CRT_INIT(hInst, ul_reason_for_call, lpReserved);
#endif /* __MS_WIN32__ */

	    /* Initialize the GNUstep Base Library runtime structures */
	    init_gnustep_base_runtime();

	    printf("GNUstep Base Library: process attach\n");
	}

    if (ul_reason_for_call == DLL_PROCESS_DETACH)
	{
	    printf("GNUstep Base Library: process detach\n");
	}

    if (ul_reason_for_call == DLL_THREAD_ATTACH)
	{
#ifdef __MS_WIN32__
	    /* Initialize C stdio DLL */
	    _CRT_INIT(hInst, ul_reason_for_call, lpReserved);
#endif /* __MS_WIN32__ */

	    /* Initialize the Library? -not for threads? */
	    init_gnustep_base_runtime();

	    printf("GNUstep Base Library: thread attach\n");
	}

    if (ul_reason_for_call == DLL_THREAD_DETACH)
	{
	    printf("Objective-C runtime: thread detach\n");
	}

    return TRUE;
}
