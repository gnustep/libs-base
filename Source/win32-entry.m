/* DLL entry routine
   Copyright (C) 1996, 1997 Free Software Foundation, Inc.

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
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/ 

#include <config.h>
#include <base/preface.h>

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

LONG APIENTRY
gnustep_base_socket_handler(HWND hWnd, UINT message,
			    UINT wParam, LONG lParam);

//
// Global variables for socket handler
//
HWND gnustep_base_wnd;

//
// DLL entry function for GNUstep Base Library
// This function gets called everytime a process/thread attaches to DLL
//
WINBOOL WINAPI
DllMain(HANDLE hInst, ULONG ul_reason_for_call,	LPVOID lpReserved)
{
  switch(ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
      {
	WNDCLASS wc;
	WSADATA lpWSAData;

#ifdef __MS_WIN32__
	/* Initialize the Microsoft C stdio DLL */
	_CRT_INIT(hInst, ul_reason_for_call, lpReserved);

	/* Initialize the GNUstep Base Library runtime structures */
	gnustep_base_init_runtime();
#endif /* __MS_WIN32__ */

	// Initialize Windows Sockets
	if (WSAStartup(MAKEWORD(1,1), &lpWSAData))
	  NSLog(@"Error: Could not startup Windows Sockets.\n");

	// Register a window class for the socket handler
	wc.lpszClassName = "GnustepBaseSocketHandler";
	wc.lpfnWndProc = gnustep_base_socket_handler;
	wc.hInstance = hInst;
	wc.hCursor = NULL;
	wc.hIcon = NULL;
	wc.hbrBackground = NULL;
	wc.lpszMenuName = NULL;
	wc.style = 0;
	wc.cbClsExtra = 0;
	wc.cbWndExtra = 0;

	if (!RegisterClass(&wc))
	  NSLog(@"Error: Could not register WIN32 socket handler class.\n");

	// Create a window which will recieve the socket handling events
	gnustep_base_wnd = CreateWindow("GNUstepBaseSocketHandler",
					"", WS_OVERLAPPEDWINDOW,
					CW_USEDEFAULT, CW_USEDEFAULT,
					CW_USEDEFAULT, CW_USEDEFAULT,
					NULL, NULL, hInst, NULL);
	if (!gnustep_base_wnd)
	  NSLog(@"Error: Could not create WIN32 socket handler window.\n");

	break;
      }

    case DLL_PROCESS_DETACH:
      {
	DestroyWindow(gnustep_base_wnd);
	break;
      }

    case DLL_THREAD_ATTACH:
      {
#ifdef __MS_WIN32__
	/* Initialize C stdio DLL */
	_CRT_INIT(hInst, ul_reason_for_call, lpReserved);
#endif /* __MS_WIN32__ */

	break;
      }

    case DLL_THREAD_DETACH:
      {
	break;
      }
    }

  return TRUE;
}

//
// The window procedure for handling sockets
//
LONG APIENTRY
gnustep_base_socket_handler(HWND hWnd, UINT message,
			    UINT wParam, LONG lParam)
{
  WORD wEvent, wError;

  // If not a socket message then call the default window procedure
  if (message != GNUSTEP_BASE_SOCKET_MESSAGE)
    return DefWindowProc(hWnd, message, wParam, lParam);

  // Check for an error code
  wError = WSAGETSELECTERROR(lParam);
  if (wError != 0)
    {
      NSLog(@"Error: received socket error code %d\n", wError);
      return 0;
    }

  // Get the event
  wEvent = WSAGETSELECTEVENT(lParam);
  switch (wEvent)
    {
    case FD_READ:
      NSLog(@"Got an FD_READ\n");
      break;
    case FD_WRITE:
      NSLog(@"Got an FD_WRITE\n");
      break;
    case FD_OOB:
      NSLog(@"Got an FD_OOB\n");
      break;
    case FD_ACCEPT:
      NSLog(@"Got an FD_ACCEPT\n");
      break;
    case FD_CONNECT:
      NSLog(@"Got an FD_CONNECT\n");
      break;
    case FD_CLOSE:
      NSLog(@"Got an FD_CLOSE\n");
      break;
    default:
    }

  return 0;
}

