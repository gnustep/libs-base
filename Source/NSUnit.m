/* Implementation of class NSUnit
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: heron
   Date: Mon Sep 30 15:58:21 EDT 2019

   This file is part of the GNUstep Library.
   
   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.
   
   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.
   
   You should have received a copy of the GNU Lesser General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
   Boston, MA 02111 USA.
*/

#include <Foundation/NSUnit.h>
#include <Foundation/NSArchiver.h>
#include <Foundation/NSKeyedArchiver.h>

// Private methods...
@interface NSDimension (Private)
- (instancetype) initWithSymbol: (NSString *)symbol
                    coefficient: (double)coefficient
                       constant: (double)constant;
@end

// Abstract conversion...
@implementation NSUnitConverter
- (instancetype) init
{
  self = [super init];
  return self;
}

- (double)baseUnitValueFromValue:(double)value
{
  return 0.0;
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
  return 0.0;
}
@end

// Linear conversion...
@implementation NSUnitConverterLinear 
- (instancetype) initWithCoefficient: (double)coefficient
{
  self = [super init];
  if(self != nil)
    {
      _coefficient = coefficient;
      _constant = 0.0;
    }
  return self;
}

- (instancetype) initWithCoefficient: (double)coefficient
                            constant: (double)constant
{
  self = [super init];
  if(self != nil)
    {
      _coefficient = coefficient;
      _constant = constant;
    }
  return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      _coefficient = [coder decodeDoubleForKey: @"coefficient"];
      _constant = [coder decodeDoubleForKey: @"constant"];      
    }
  else
    {
      [coder decodeValueOfObjCType: @encode(double) at: &_coefficient];
      [coder decodeValueOfObjCType: @encode(double) at: &_constant];
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      [coder encodeDouble: _coefficient forKey: @"coefficient"];
      [coder encodeDouble: _constant forKey: @"constant"];
    }
  else
    {
      [coder encodeValueOfObjCType: @encode(double) at: &_coefficient];
      [coder encodeValueOfObjCType: @encode(double) at: &_constant];
    }
}

- (double) coefficient
{
  return _coefficient;
}

- (double) constant
{
  return _constant;
}
@end

// Abstract unit...
@implementation NSUnit
+ (instancetype)new
{
  return [[self alloc] init];
}
           
- (instancetype)init
{
  self = [super init];
  if(self != nil)
    {
      ASSIGNCOPY(_symbol, @"");
    }
  return self;
}
          
- (instancetype)initWithSymbol:(NSString *)symbol
{
  self = [super init];
  if(self != nil)
    {
      ASSIGNCOPY(_symbol, symbol);
    }
  return self;
}

- (id) initWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      _symbol = [coder decodeObjectForKey: @"symbol"];
    }
  else
    {
      _symbol = [coder decodeObject];
    }
  return self;
}

- (void) encodeWithCoder: (NSCoder *)coder
{
  if([coder allowsKeyedCoding])
    {
      [coder encodeObject: _symbol forKey: @"coder"];
    }
  else
    {
      [coder encodeObject: _symbol];
    }
}

- (instancetype) copyWithZone: (NSZone *)zone
{
  NSUnit *u = [[NSUnit allocWithZone: zone] initWithSymbol: [self symbol]];
  return u;
}

- (NSString *)symbol
{
  return _symbol;
}
@end


// Dimension using units....
@implementation NSDimension
- (NSUnitConverter *) converter
{
  return _converter;
}

- (instancetype) initWithSymbol: (NSString *)symbol converter: (NSUnitConverter *) converter
{
  self = [super initWithSymbol: symbol];
  if(self != nil)
    {
      ASSIGN(_converter, converter);
    }
  return self;
}

- (instancetype) initWithSymbol: (NSString *)symbol
                    coefficient: (double)coefficient
                       constant: (double)constant
{
  NSUnitConverterLinear *converter = [[NSUnitConverterLinear alloc] initWithCoefficient: coefficient
                                                                               constant: constant];
  NSDimension *result = [[[self class] alloc] initWithSymbol: symbol
                                                   converter: converter];
  return result;
}


+ (instancetype) baseUnit
{
  return nil;
}
@end


// Predefined....
@implementation NSUnitAcceleration

+ (instancetype) baseUnit
{
  return [self metersPerSecondSquared];
}

// Base unit - metersPerSecondSquared
+ (NSUnitAcceleration *) metersPerSecondSquared
{
  NSUnitAcceleration *result = [[NSUnitAcceleration alloc] initWithSymbol: @"m/s^2"
                                                              coefficient: 1.0
                                                                 constant: 0.0];
  return result;
}

+ (NSUnitAcceleration *) gravity
{
  NSUnitAcceleration *result = [[NSUnitAcceleration alloc] initWithSymbol: @"g"
                                                              coefficient: 9.81
                                                                 constant: 0];
  return result;
}

@end

@implementation NSUnitAngle 

// Base unit - degrees 
+ (NSUnitAngle *) degrees
{
  NSUnitAngle *result = [[NSUnitAngle alloc] initWithSymbol: @"deg"
                                                coefficient: 1.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitAngle *) arcMinutes
{
  NSUnitAngle *result = [[NSUnitAngle alloc] initWithSymbol: @"'"
                                                coefficient: 0.016667
                                                   constant: 0.0];
  return result;
}

+ (NSUnitAngle *) arcSeconds
{
  NSUnitAngle *result = [[NSUnitAngle alloc] initWithSymbol: @"\""
                                                coefficient: 0.00027778
                                                   constant: 9.81];
  return result;
}

+ (NSUnitAngle *) radians 
{
  NSUnitAngle *result = [[NSUnitAngle alloc] initWithSymbol: @"rad"
                                                coefficient: 57.2958
                                                   constant: 0.0];
  return result;
}

+ (NSUnitAngle *) gradians
{
  NSUnitAngle *result = [[NSUnitAngle alloc] initWithSymbol: @"grad"
                                                coefficient: 0.9
                                                   constant: 0.0];
  return result;
}

+ (NSUnitAngle *) revolutions
{
  NSUnitAngle *result = [[NSUnitAngle alloc] initWithSymbol: @"rev"
                                                coefficient: 360.0
                                                   constant: 0.0];
  return result;
}

@end

@implementation NSUnitArea 

// Base unit - squareMeters
+ (NSUnitArea *) squareMegameters
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareKilometers 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareMeters 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"m^2"
                                              coefficient: 1.0
                                                 constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareCentimeters 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareMillimeters 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareMicrometers 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareNanometers 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareInches 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareFeet 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareYards 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareMiles 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) acres 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) ares 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) hectares 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"rev"
                                               coefficient: 360.0
                                                  constant: 0.0];
  return result;
}

@end

@implementation NSUnitConcentrationMass 

// Base unit - gramsPerLiter
+ (NSUnitConcentrationMass *) gramsPerLiter { return nil; }
+ (NSUnitConcentrationMass *) milligramsPerDeciliter { return nil; }

+ (NSUnitConcentrationMass *) millimolesPerLiterWithGramsPerMole:(double)gramsPerMole { return nil; }

@end

@implementation NSUnitDispersion 

// Base unit - partsPerMillion
+ (NSUnitDispersion *) partsPerMillion { return nil; }

@end

@implementation NSUnitDuration   

// Base unit - seconds
+ (NSUnitDuration *) seconds { return nil; }
+ (NSUnitDuration *) minutes { return nil; }
+ (NSUnitDuration *) hours { return nil; }

@end

@implementation NSUnitElectricCharge 

// Base unit - coulombs
+ (NSUnitElectricCharge *) coulombs { return nil; }
+ (NSUnitElectricCharge *) megaampereHours { return nil; }
+ (NSUnitElectricCharge *) kiloampereHours { return nil; }
+ (NSUnitElectricCharge *) ampereHours { return nil; }
+ (NSUnitElectricCharge *) milliampereHours { return nil; }
+ (NSUnitElectricCharge *) microampereHours { return nil; }

@end

@implementation NSUnitElectricCurrent 

// Base unit - amperes
+ (NSUnitElectricCurrent *) megaamperes { return nil; }
+ (NSUnitElectricCurrent *) kiloamperes { return nil; }
+ (NSUnitElectricCurrent *) amperes { return nil; }
+ (NSUnitElectricCurrent *) milliamperes { return nil; }
+ (NSUnitElectricCurrent *) microamperes { return nil; }

@end

@implementation NSUnitElectricPotentialDifference 

// Base unit - volts
+ (NSUnitElectricPotentialDifference *) megavolts { return nil; }
+ (NSUnitElectricPotentialDifference *) kilovolts { return nil; }
+ (NSUnitElectricPotentialDifference *) volts { return nil; }
+ (NSUnitElectricPotentialDifference *) millivolts { return nil; }
+ (NSUnitElectricPotentialDifference *) microvolts { return nil; }

@end

@implementation NSUnitElectricResistance 

// Base unit - ohms
+ (NSUnitElectricResistance *) megaohms { return nil; }
+ (NSUnitElectricResistance *) kiloohms { return nil; }
+ (NSUnitElectricResistance *) ohms { return nil; }
+ (NSUnitElectricResistance *) milliohms { return nil; }
+ (NSUnitElectricResistance *) microohms { return nil; }

@end

@implementation NSUnitEnergy 

// Base unit - joules
+ (NSUnitEnergy *) kilojoules { return nil; }
+ (NSUnitEnergy *) joules { return nil; }
+ (NSUnitEnergy *) kilocalories { return nil; }
+ (NSUnitEnergy *) calories { return nil; }
+ (NSUnitEnergy *) kilowattHours { return nil; }

@end

@implementation NSUnitFrequency 

// Base unit - hertz

+ (NSUnitFrequency *) terahertz { return nil; }
+ (NSUnitFrequency *) gigahertz { return nil; }
+ (NSUnitFrequency *) megahertz { return nil; }
+ (NSUnitFrequency *) kilohertz { return nil; }
+ (NSUnitFrequency *) hertz { return nil; }
+ (NSUnitFrequency *) millihertz { return nil; }
+ (NSUnitFrequency *) microhertz { return nil; }
+ (NSUnitFrequency *) nanohertz { return nil; }

@end

@implementation NSUnitFuelEfficiency 

// Base unit - litersPer100Kilometers

+ (NSUnitFuelEfficiency *) litersPer100Kilometers { return nil; }
+ (NSUnitFuelEfficiency *) milesPerImperialGallon { return nil; }
+ (NSUnitFuelEfficiency *) milesPerGallon { return nil; }

@end

@implementation NSUnitLength 

// Base unit - meters

+ (NSUnitLength *) megameters { return nil; }
+ (NSUnitLength *) kilometers { return nil; }
+ (NSUnitLength *) hectometers { return nil; }
+ (NSUnitLength *) decameters { return nil; }
+ (NSUnitLength *) meters { return nil; }
+ (NSUnitLength *) decimeters { return nil; }
+ (NSUnitLength *) centimeters { return nil; }
+ (NSUnitLength *) millimeters { return nil; }
+ (NSUnitLength *) micrometers { return nil; }
+ (NSUnitLength *) nanometers { return nil; }
+ (NSUnitLength *) picometers { return nil; }
+ (NSUnitLength *) inches { return nil; }
+ (NSUnitLength *) feet { return nil; }
+ (NSUnitLength *) yards { return nil; }
+ (NSUnitLength *) miles { return nil; }
+ (NSUnitLength *) scandinavianMiles { return nil; }
+ (NSUnitLength *) lightyears { return nil; }
+ (NSUnitLength *) nauticalMiles { return nil; }
+ (NSUnitLength *) fathoms { return nil; }
+ (NSUnitLength *) furlongs { return nil; }
+ (NSUnitLength *) astronomicalUnits { return nil; }
+ (NSUnitLength *) parsecs { return nil; }

@end

@implementation NSUnitIlluminance 

// Base unit - lux

+ (NSUnitIlluminance *) lux { return nil; }

@end

@implementation NSUnitMass 

// Base unit - kilograms

+ (NSUnitMass *) kilograms { return nil; }
+ (NSUnitMass *) grams { return nil; }
+ (NSUnitMass *) decigrams { return nil; }
+ (NSUnitMass *) centigrams { return nil; }
+ (NSUnitMass *) milligrams { return nil; }
+ (NSUnitMass *) micrograms { return nil; }
+ (NSUnitMass *) nanograms { return nil; }
+ (NSUnitMass *) picograms { return nil; }
+ (NSUnitMass *) ounces { return nil; }
+ (NSUnitMass *) poundsMass { return nil; }
+ (NSUnitMass *) stones { return nil; }
+ (NSUnitMass *) metricTons { return nil; }
+ (NSUnitMass *) shortTons { return nil; }
+ (NSUnitMass *) carats { return nil; }
+ (NSUnitMass *) ouncesTroy { return nil; }
+ (NSUnitMass *) slugs { return nil; }

@end

@implementation NSUnitPower 

// Base unit - watts

+ (NSUnitPower *) terawatts { return nil; }
+ (NSUnitPower *) gigawatts { return nil; }
+ (NSUnitPower *) megawatts { return nil; }
+ (NSUnitPower *) kilowatts { return nil; }
+ (NSUnitPower *) watts { return nil; }
+ (NSUnitPower *) milliwatts { return nil; }
+ (NSUnitPower *) microwatts { return nil; }
+ (NSUnitPower *) nanowatts { return nil; }
+ (NSUnitPower *) picowatts { return nil; }
+ (NSUnitPower *) femtowatts { return nil; }
+ (NSUnitPower *) horsepower { return nil; }

@end

@implementation NSUnitPressure

// Base unit - newtonsPerMetersSquared (equivalent to 1 pascal)

+ (NSUnitPressure *) newtonsPerMetersSquared { return nil; }
+ (NSUnitPressure *) gigapascals { return nil; }
+ (NSUnitPressure *) megapascals { return nil; }
+ (NSUnitPressure *) kilopascals { return nil; }
+ (NSUnitPressure *) hectopascals { return nil; }
+ (NSUnitPressure *) inchesOfMercury { return nil; }
+ (NSUnitPressure *) bars { return nil; }
+ (NSUnitPressure *) millibars { return nil; }
+ (NSUnitPressure *) millimetersOfMercury { return nil; }
+ (NSUnitPressure *) poundsForcePerSquareInch { return nil; }

@end

@implementation NSUnitSpeed 

// Base unit - metersPerSecond
+ (NSUnitSpeed *) metersPerSecond { return nil; }
+ (NSUnitSpeed *) kilometersPerHour { return nil; }
+ (NSUnitSpeed *) milesPerHour { return nil; }
+ (NSUnitSpeed *) knots { return nil; }

@end

@implementation NSUnitTemperature

// Base unit - kelvin
+ (NSUnitTemperature *) kelvin { return nil; }
+ (NSUnitTemperature *) celsius { return nil; } 
+ (NSUnitTemperature *) fahrenheit { return nil; }

@end

@implementation NSUnitVolume

// Base unit - liters
+ (NSUnitVolume *) megaliters { return nil; }
+ (NSUnitVolume *) kiloliters { return nil; }
+ (NSUnitVolume *) liters { return nil; }
+ (NSUnitVolume *) deciliters { return nil; }
+ (NSUnitVolume *) centiliters { return nil; }
+ (NSUnitVolume *) milliliters { return nil; }
+ (NSUnitVolume *) cubicKilometers { return nil; }
+ (NSUnitVolume *) cubicMeters { return nil; }
+ (NSUnitVolume *) cubicDecimeters { return nil; }
+ (NSUnitVolume *) cubicCentimeters { return nil; }
+ (NSUnitVolume *) cubicMillimeters { return nil; }
+ (NSUnitVolume *) cubicInches { return nil; }
+ (NSUnitVolume *) cubicFeet { return nil; }
+ (NSUnitVolume *) cubicYards { return nil; }
+ (NSUnitVolume *) cubicMiles { return nil; }
+ (NSUnitVolume *) acreFeet { return nil; }
+ (NSUnitVolume *) bushels { return nil; }
+ (NSUnitVolume *) teaspoons { return nil; }
+ (NSUnitVolume *) tablespoons { return nil; }
+ (NSUnitVolume *) fluidOunces { return nil; }
+ (NSUnitVolume *) cups { return nil; }
+ (NSUnitVolume *) pints { return nil; }
+ (NSUnitVolume *) quarts { return nil; }
+ (NSUnitVolume *) gallons { return nil; }
+ (NSUnitVolume *) imperialTeaspoons { return nil; }
+ (NSUnitVolume *) imperialTablespoons { return nil; }
+ (NSUnitVolume *) imperialFluidOunces { return nil; }
+ (NSUnitVolume *) imperialPints { return nil; }
+ (NSUnitVolume *) imperialQuarts { return nil; }
+ (NSUnitVolume *) imperialGallons { return nil; }
+ (NSUnitVolume *) metricCups { return nil; } 

@end
