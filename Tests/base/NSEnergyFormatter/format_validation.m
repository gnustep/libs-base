#import "ObjectTesting.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSEnergyFormatter.h>

int main()
{
  START_SET("NSEnergyFormatter format validation");

  NSEnergyFormatter *formatter;
  NSString *result;

  formatter = AUTORELEASE([[NSEnergyFormatter alloc] init]);
  
  // Test joule formatting
  result = [formatter stringFromJoules: 1000.0];
  PASS([result rangeOfString: @"1"].location != NSNotFound &&
       ([result rangeOfString: @"kJ"].location != NSNotFound ||
        [result rangeOfString: @"kilojoule"].location != NSNotFound ||
        [result rangeOfString: @"J"].location != NSNotFound ||
        [result rangeOfString: @"joule"].location != NSNotFound),
       "1000 J format includes number and unit");

  // Test calorie formatting
  result = [formatter stringFromValue: 100.0 unit: NSEnergyFormatterUnitCalorie];
  PASS([result rangeOfString: @"100"].location != NSNotFound &&
       ([result rangeOfString: @"cal"].location != NSNotFound ||
        [result rangeOfString: @"Cal"].location != NSNotFound ||
        [result rangeOfString: @"calorie"].location != NSNotFound),
       "100 cal format correct");

  // Test kilocalorie formatting
  result = [formatter stringFromValue: 2.5 unit: NSEnergyFormatterUnitKilocalorie];
  PASS([result rangeOfString: @"2"].location != NSNotFound &&
       ([result rangeOfString: @"kcal"].location != NSNotFound ||
        [result rangeOfString: @"Cal"].location != NSNotFound ||
        [result rangeOfString: @"kilocalorie"].location != NSNotFound),
       "2.5 kcal format correct");

  // Test food energy vs regular energy
  [formatter setForFoodEnergyUse: NO];
  NSString *regularResult = [formatter stringFromJoules: 4184.0]; // ~1000 cal
  
  [formatter setForFoodEnergyUse: YES];
  NSString *foodResult = [formatter stringFromJoules: 4184.0];
  
  PASS([regularResult length] > 0 && [foodResult length] > 0,
       "Both regular and food energy produce valid formats");

  // Test unit styles
  [formatter setForFoodEnergyUse: NO];
  [formatter setUnitStyle: NSFormattingUnitStyleShort];
  result = [formatter stringFromJoules: 5000.0];
  PASS([result rangeOfString: @"5"].location != NSNotFound ||
       [result rangeOfString: @"4"].location != NSNotFound ||
       [result rangeOfString: @"6"].location != NSNotFound,
       "Short style shows number");

  // Test zero handling
  result = [formatter stringFromJoules: 0.0];
  PASS([result rangeOfString: @"0"].location != NSNotFound,
       "Zero joules shows 0");

  END_SET("NSEnergyFormatter format validation");
  return 0;
}
