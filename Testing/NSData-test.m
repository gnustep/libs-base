/******************************************************************************
* Module    :   NSMutableData(NSData) --- Black Box test module for the
*               *Data classes to make sure that methods that raise exceptions
*               do so, and that the exceptions are raised properly.
*
* Author    :   John W. M. Stevens

  Notes     :   See below by date.

...............................................................................
15 April 1997

NSRange.m

1) NSMakeRange does an implicit type cast from a float to an
   unsigned long.  This is a nasty spot for hard to find errors.

2) NSMakeRange, in doing the above, automatically converts negative
   numbers to unsigned ints, and (of course) produces some very large
   ints if one of the numbers happens to be a negative number.

NSData.m

1) To properly throw an NSRangeException Error in the NSMutableRange
   replaceBytesInRange method, the NSRange location and length values
   must be checked against the NSMutableData size attribute.

   Unfortunately, we once again have a type mismatch (see the notes
   on NSRange.m), as the NSMutableData size attribute is a signed int.
   Is there any reason not to convert the NSMutableData (NSData) size
   attribute to an unsigned int?  Should the NSRange values be converted
   to signed ints?

2) Checking only the summation of location and length (NSMaxRange)
   against the size of the NSData buffer could generate some false
   OK's, as the summation of 2's complement -2.0 and 2.0 converted
   to unsigned ints is of course zero, yet the location value is
   clearly out of range (being less than zero).

3) Note that with the current implementation of NSData's getBytes
   family of methods, the methods getBytes and getBytes:length could
   throw the NSRangeException.  Obviously, it is highly unlikely that
   getBytes would throw this exception, but it is possible that
   getBytes:length could, and the documentation does not specify
   that getBytes:length should return any exceptions.  In my opinion,
   this is an acceptable deviation from the standard.
******************************************************************************/

#include    <stdio.h>
#include    <objc/NSData.h>
#include    <objc/NSException.h>
#include    <objc/NSRange.h>
#include    <objc/NSSerialization.h>

/*  Data for stuffing into *Data objects.  I like printable data, as it
*   gives a quick visual check mechanism, but it has the disadvantage
*   of not checking for 8 bit cleanliness.
*/
char    *testString = "Test string for mutable data and archiver classes.";
char    *subString  = "Sub String";

/*-----------------------------------------------------------------------------
| Routine   :   TestNSMutableData() --- Create an instance of an NSMutableData
|               class, initialize it with a C string (to have something
|               printable for tests) and invoke the two methods that
|               should raise NSRangeException exceptions using ranges that
|               cross both edges of the buffer boundary.
|
| Notes     :   Please see work logs for discussion.
-----------------------------------------------------------------------------*/

void
TestNSMutableData(void)
{
    auto    NSMutableData   *nsMutData;
    auto    char            *str;
    auto    NSRange         range;

    /*  Allocate and initialize an instance of an NSMutableData
    *   class.
    */
    nsMutData = [NSMutableData dataWithLength: strlen( testString ) + 1];
    str = (char *) [nsMutData mutableBytes];
    strcpy(str, testString);

    /*  Get contents, display.  */
    str = NULL;
    str = (char *) [nsMutData mutableBytes];
    printf("NSMutableData Test ---------------------------------------------"
           "---------------\n"
           "1) String: (%s)\n", str);

    /*  Attempt to force Range exception by having range start before
    *   zero.
    */
NS_DURING
    range = NSMakeRange(-2.0, (float) strlen( subString ));
    [nsMutData replaceBytesInRange: range
               withBytes          : subString ];
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force another Range exception.   */
NS_DURING
    range = NSMakeRange(41.0, (float) strlen( subString ));
    [nsMutData replaceBytesInRange: range
               withBytes          : subString ];
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force another Range exception.   */
NS_DURING
    range = NSMakeRange(42.0, (float) strlen( subString ));
    [nsMutData replaceBytesInRange: range
               withBytes          : subString ];
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  How about a length that is less than zero?  */
NS_DURING
    range = NSMakeRange(6, -3.0);
    [nsMutData replaceBytesInRange: range
               withBytes          : subString ];
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force Range exception by having range start before
    *   zero.
    */
NS_DURING
    range = NSMakeRange(-2.0, (float) strlen( subString ));
    [nsMutData resetBytesInRange: range];
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force another Range exception.   */
NS_DURING
    range = NSMakeRange(41.0, (float) strlen( subString ));
    [nsMutData resetBytesInRange: range];
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force another Range exception.   */
NS_DURING
    range = NSMakeRange(42.0, (float) strlen( subString ));
    [nsMutData resetBytesInRange: range];
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  How about a length less than zero?  */
NS_DURING
    range = NSMakeRange(6.0, -3.0);
    [nsMutData resetBytesInRange: range];
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Get contents, display.  */
    str = NULL;
    str = (char *) [nsMutData mutableBytes];
    printf("2) String: (%s)\n", str);

    /*  Attempt to force an out of memory exception.    */
#if 0
    for ( ; ; )
    {
        /*  Append. */
        [nsMutData appendBytes: testString
                   length     : strlen( testString ) + 1];

        /*  Show current value. */
        printf("%9u\r", [nsMutData length]);
    }
#endif
}

/*-----------------------------------------------------------------------------
| Routine   :   TestNSData() --- Create an instance of an NSData
|               class, initialize it with a C string (to have something
|               printable for tests) and invoke the two methods that
|               should raise NSRangeException exceptions using ranges that
|               cross both edges of the buffer boundary.
|
| Notes     :   Please see work logs for discussion.
-----------------------------------------------------------------------------*/

void
TestNSData(void)
{
    auto    NSData          *nsData;
    auto    NSData          *newNsData;
    auto    char            *str;
    auto    char            bfr[128];
    auto    NSRange         range;

    /*  Allocate and initialize an instance of an NSData
    *   class.
    */
    nsData = [NSData dataWithBytes: testString
                     length       : (unsigned int) strlen( testString ) + 1];

    /*  Get contents, display.  */
    str = (char *) [nsData bytes];
    printf("NSData Test ----------------------------------------------------"
           "---------------\n"
           "1) String: (%s)\n", str);

    /*  Attempt to force Range exception by having range start before
    *   zero.
    */
NS_DURING
    /*  Get buffer piece.   */
    range = NSMakeRange(-2.0, 6.0);
    [nsData getBytes: bfr
            range   : range];

    /*  Print buffer piece. */
    bfr[6] = '\0';
    printf("    A) Buffer: (%s)\n", bfr);
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force another Range exception.   */
NS_DURING
    /*  Get piece.  */
    range = NSMakeRange(41.0, (float) strlen( subString ));
    [nsData getBytes: bfr
            range   : range];

    /*  Print buffer piece. */
    bfr[strlen( subString )] = '\0';
    printf("    B) Buffer: (%s)\n", bfr);
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force another Range exception.   */
NS_DURING
    range = NSMakeRange(42.0, (float) strlen( subString ));
    [nsData getBytes: bfr
            range   : range];

    /*  Print buffer piece. */
    bfr[strlen( subString )] = '\0';
    printf("    C) Buffer: (%s)\n", bfr);
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  How about less than zero length?    */
NS_DURING
    range = NSMakeRange(5.0, -4.0);
    [nsData getBytes: bfr
            range   : range];

    /*  Print buffer piece. */
    bfr[strlen( subString )] = '\0';
    printf("    C) Buffer: (%s)\n", bfr);
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

/*=================== subDataWithRange ======================================*/
    /*  Attempt to force Range exception by having range start before
    *   zero.
    */
NS_DURING
    /*  Get buffer piece.   */
    range = NSMakeRange(-2.0, 6.0);
    newNsData = [nsData subdataWithRange: range];

    /*  Print buffer piece. */
    [newNsData getBytes: bfr];
    bfr[6] = '\0';
    printf("    D) Buffer: (%s)\n", bfr);
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force another Range exception.   */
NS_DURING
    /*  Get buffer piece.   */
    range = NSMakeRange(41.0, (float) strlen( subString ));
    newNsData = [nsData subdataWithRange: range];

    /*  Print buffer piece. */
    [newNsData getBytes: bfr];
    bfr[strlen( subString )] = '\0';
    printf("    E) Buffer: (%s)\n", bfr);
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Attempt to force another Range exception.   */
NS_DURING
    /*  Get buffer piece.   */
    range = NSMakeRange(42.0, (float) strlen( subString ));
    newNsData = [nsData subdataWithRange: range];

    /*  Print buffer piece. */
    [newNsData getBytes: bfr];
    bfr[strlen( subString )] = '\0';
    printf("    F) Buffer: (%s)\n", bfr);
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  How about a length less than zero?  */
NS_DURING
    /*  Get buffer piece.   */
    range = NSMakeRange(9.0, -6.0);
    newNsData = [nsData subdataWithRange: range];

    /*  Print buffer piece. */
    [newNsData getBytes: bfr];
    bfr[strlen( subString )] = '\0';
    printf("    F) Buffer: (%s)\n", bfr);
NS_HANDLER
    fprintf(stderr,
            "%s %d : Exception %s - %s\n",
            __FILE__,
            __LINE__,
            [[localException name]   cString],
            [[localException reason] cString]);
NS_ENDHANDLER

    /*  Get contents, display.  */
    str = NULL;
    str = (char *) [nsData bytes];
    printf("2) String: (%s)\n", str);
}

void
main(int    argc,
     char   **argv)
{
    /*  Test NSMutableData. */
    TestNSMutableData();

    /*  Test NSData.    */
    TestNSData();
}
