#include <gnustep/base/all.h>

int main()
{
  id dict = [Dictionary new];

  id translator = [Dictionary new];
  id mc;

  [dict putObject:@"herd" atKey:@"cow"];
  [dict putObject:@"pack" atKey:@"dog"];
  [dict putObject:@"school" atKey:@"fish"];
  [dict putObject:@"flock" atKey:@"bird"];
  [dict putObject:@"pride" atKey:@"cat"];
  [dict putObject:@"gaggle" atKey:@"goose"];
  [dict printForDebugger];
  printf("removing goose\n");
  [dict removeObjectAtKey:@"goose"];
  [dict printForDebugger];

  [translator putObject:@"cow" atKey:@"vache"];
  [translator putObject:@"dog" atKey:@"chien"];
  [translator putObject:@"fish" atKey:@"poisson"];
  [translator putObject:@"bird" atKey:@"oisseau"];
  [translator putObject:@"cat" atKey:@"chat"];

  mc = [[MappedCollector alloc] initWithCollection:dict map:translator];
  [mc printForDebugger];

  [mc release];
  [dict release];
  [translator release];

  exit(0);

}


