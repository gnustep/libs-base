/*
 * strongObjects.m - tests for the deterministic strong-to-strong NSMapTable
 * operations the other tests do not cover: +strongToStrongObjectsMapTable,
 * overwrite semantics, objectForKey: of an absent key, removeAllObjects,
 * keyEnumerator / objectEnumerator, and dictionaryRepresentation.
 */

#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

int main(void)
{
  START_SET("NSMapTable strong-to-strong basics")
    NSMapTable	*t = [NSMapTable strongToStrongObjectsMapTable];

    PASS([t count] == 0, "a new map table is empty");

    [t setObject: @"v1" forKey: @"k1"];
    [t setObject: @"v2" forKey: @"k2"];
    PASS([t count] == 2, "setObject:forKey: adds entries");
    PASS_EQUAL([t objectForKey: @"k1"], @"v1",
      "objectForKey: returns the stored object");
    PASS([t objectForKey: @"absent"] == nil,
      "objectForKey: of an absent key is nil");

    [t setObject: @"v1b" forKey: @"k1"];
    PASS([t count] == 2 && [[t objectForKey: @"k1"] isEqual: @"v1b"],
      "setObject:forKey: on an existing key replaces the value");

    [t removeObjectForKey: @"k1"];
    PASS([t count] == 1 && [t objectForKey: @"k1"] == nil,
      "removeObjectForKey: removes the entry");

    [t removeAllObjects];
    PASS([t count] == 0, "removeAllObjects empties the table");
  END_SET("NSMapTable strong-to-strong basics")

  START_SET("NSMapTable enumeration and dictionaryRepresentation")
    NSMapTable		*t = [NSMapTable strongToStrongObjectsMapTable];
    NSArray		*keys;
    NSArray		*values;
    NSDictionary	*expected;

    [t setObject: @"v1" forKey: @"k1"];
    [t setObject: @"v2" forKey: @"k2"];
    [t setObject: @"v3" forKey: @"k3"];

    keys = [[t keyEnumerator] allObjects];
    PASS([keys count] == 3
      && [keys containsObject: @"k1"] && [keys containsObject: @"k3"],
      "keyEnumerator yields every key");

    values = [[t objectEnumerator] allObjects];
    PASS([values count] == 3
      && [values containsObject: @"v2"] && [values containsObject: @"v3"],
      "objectEnumerator yields every value");

    expected = [NSDictionary dictionaryWithObjectsAndKeys:
      @"v1", @"k1", @"v2", @"k2", @"v3", @"k3", nil];
    PASS([[t dictionaryRepresentation] isEqualToDictionary: expected],
      "dictionaryRepresentation mirrors the table contents");
  END_SET("NSMapTable enumeration and dictionaryRepresentation")

  return 0;
}
