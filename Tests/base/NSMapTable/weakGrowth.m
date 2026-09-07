#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

/* Insert enough entries to force the table to resize several times, keeping
 * the keys and values alive externally, then check that every entry can
 * still be found, replaced and removed through equal keys.
 */
int main(void)
{
  START_SET("NSMapTable growth with weak references")
    NSPointerFunctionsOptions options[] = {
      NSPointerFunctionsStrongMemory,
      NSPointerFunctionsWeakMemory
    };
    const char *names[] = { "strong", "weak" };
    NSUInteger k, v;

    for (k = 0; k < 2; k++)
      {
        for (v = 0; v < 2; v++)
          {
            NSAutoreleasePool *pool = [NSAutoreleasePool new];
            NSAutoreleasePool *operations;
            NSMapTable *table;
            NSMutableArray *keys = [NSMutableArray new];
            NSMutableArray *values = [NSMutableArray new];
            NSUInteger i;
            NSUInteger expected;
            BOOL ok;

            table = [[NSMapTable alloc] initWithKeyOptions: options[k]
                                             valueOptions: options[v]
                                                 capacity: 0];
            for (i = 0; i < 256; i++)
              {
                NSString *key = [[NSString alloc] initWithFormat:
                  @"group-%lu", (unsigned long)i];
                NSObject *value = [NSObject new];

                [keys addObject: key];
                [values addObject: value];
                [table setObject: value forKey: key];
                [key release];
                [value release];
              }

            operations = [NSAutoreleasePool new];
            PASS([table count] == 256,
              "%s keys / %s values: growth preserves the count",
              names[k], names[v]);
            ok = YES;
            for (i = 0; i < 256; i++)
              {
                NSString *key = [[keys objectAtIndex: i] mutableCopy];

                if ([table objectForKey: key] != [values objectAtIndex: i])
                  ok = NO;
                [key release];
              }
            PASS(ok,
              "%s keys / %s values: equal keys find all values after growth",
              names[k], names[v]);

            ok = YES;
            for (i = 0; i < 256; i++)
              {
                NSObject *replacement = [NSObject new];

                [table setObject: replacement forKey: [keys objectAtIndex: i]];
                [values replaceObjectAtIndex: i withObject: replacement];
                if ([table objectForKey: [keys objectAtIndex: i]] != replacement)
                  ok = NO;
                [replacement release];
              }
            PASS(ok && [table count] == 256,
              "%s keys / %s values: replacing all values keeps the count",
              names[k], names[v]);
            [operations release];

            if (v == 1)
              [values replaceObjectAtIndex: 0 withObject: [NSNull null]];
            if (k == 1)
              [keys replaceObjectAtIndex: 1 withObject: [NSNull null]];

            operations = [NSAutoreleasePool new];
            if (v == 1)
              PASS([table objectForKey: [keys objectAtIndex: 0]] == nil,
                "%s keys / weak values: values remain weak after growth",
                names[k]);
            if (k == 1)
              PASS([table objectForKey: @"group-1"] == nil,
                "weak keys / %s values: keys remain weak after growth",
                names[v]);

            for (i = 256; i < 1024; i++)
              {
                NSString *key = [[NSString alloc] initWithFormat:
                  @"group-%lu", (unsigned long)i];
                NSObject *value = [NSObject new];

                [keys addObject: key];
                [values addObject: value];
                [table setObject: value forKey: key];
                [key release];
                [value release];
              }
            ok = YES;
            expected = 0;
            for (i = 0; i < 1024; i++)
              {
                NSString *key = [keys objectAtIndex: i];
                NSObject *value = [values objectAtIndex: i];

                if ([key isKindOfClass: [NSNull class]]
                  || [value isKindOfClass: [NSNull class]])
                  continue;
                expected++;
                key = [key mutableCopy];
                if ([table objectForKey: key] != value)
                  ok = NO;
                [key release];
              }
            PASS(ok,
              "%s keys / %s values: surviving entries remain accessible after further growth",
              names[k], names[v]);

            for (i = 0; i < 1024; i++)
              {
                NSString *key = [keys objectAtIndex: i];

                if ([key isKindOfClass: [NSNull class]])
                  continue;
                key = [key mutableCopy];
                [table removeObjectForKey: key];
                [key release];
              }
            PASS([table count] == 0,
              "%s keys / %s values: removing all entries empties the table",
              names[k], names[v]);
            [operations release];

            [table release];
            [keys release];
            [values release];
            [pool release];
          }
      }
  END_SET("NSMapTable growth with weak references")
  return 0;
}
