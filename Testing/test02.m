
#include <objects/objects.h>


int main()
{
  id dict = [[Dictionary alloc] initWithType:"*"
	     keyType:"*"];
  id translator = [[Dictionary alloc] initWithType:"*"
		   keyType:"*"];
  id mc;

  [dict putElement:"herd" atKey:"cow"];
  [dict putElement:"pack" atKey:"dog"];
  [dict putElement:"school" atKey:"fish"];
  [dict putElement:"flock" atKey:"bird"];
  [dict putElement:"pride" atKey:"cat"];
  [dict putElement:"gaggle" atKey:"goose"];
  [dict printForDebugger];
  printf("removing goose\n");
  [dict removeElementAtKey:"goose"];
  [dict printForDebugger];

  [translator putElement:"cow" atKey:"vache"];
  [translator putElement:"dog" atKey:"chien"];
  [translator putElement:"fish" atKey:"poisson"];
  [translator putElement:"bird" atKey:"oisseau"];
  [translator putElement:"cat" atKey:"chat"];

  mc = [[MappedCollector alloc] initCollection:dict map:translator];
  [mc printForDebugger];

  [mc free];
  [dict free];
  [translator free];

  exit(0);

}


