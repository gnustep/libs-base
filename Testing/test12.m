
#include <objects/Random.h>
#include <objects/RNGBerkeley.h>
#include <objects/RNGAdditiveCongruential.h>

int main()
{
  id r;
  id rng;
  int i;

  r = [[Random alloc] init];
  printf("float\n");
  for (i = 0; i < 20; i++)
    printf("%f\n", [r randomFloat]);
  printf("doubles\n");
  for (i = 0; i < 20; i++)
    printf("%f\n", [r randomDouble]);

  rng = [[RNGBerkeley alloc] init];
  printf("%s chi^2 = %f\n", 
	 [rng name], [Random chiSquareOfRandomGenerator:rng]);
  [r free];

  rng = [[RNGAdditiveCongruential alloc] init];
/*
  for (i = 0; i < 50; i++)
    printf("%ld\n", [r nextRandom]);
*/
  printf("%s chi^2 = %f\n", 
	 [rng name], [Random chiSquareOfRandomGenerator:rng]);
  [rng free];

  exit(0);
}
