/* Test NXStringTable class. */

#include <objc/NXStringTable.h>
#include <stdio.h>

int
main(int argc, char *argv[])
{
    id	 table;
    int  i, times;
    
    if (argc < 2) {
 	fprintf(stderr, "Usage: table_test filename repeat\n");
 	fprintf(stderr, "       filename is a stringtable format file.\n");
 	fprintf(stderr, "       repeat is a number of times to loop\n");
	exit(1);
    }
    if (argc == 3)
	times = atoi(argv[2]);
    else 
	times = 1;
        
    table = [[NXStringTable alloc] init];

    for (i=0; i < times; i++) {
        [table readFromFile:argv[1]];
	printf("-----------------------------------------\n");
        [table writeToStream:stdout];
    }
    return 0;
}
