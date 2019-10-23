/* Implementation of class NSUnit
   Copyright (C) 2019 Free Software Foundation, Inc.
   
   By: Gregory John Casamento <greg.casamento@gmail.com>
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
  if (self != nil)
    {
    }
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

- (double)baseUnitValueFromValue:(double)value
{
  return ((_coefficient * value) + _constant); 
}

- (double)valueFromBaseUnitValue:(double)baseUnitValue
{
  return ((baseUnitValue / _coefficient) - _constant);
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
  AUTORELEASE(converter);
  AUTORELEASE(result);
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

+ (instancetype) baseUnit
{
  return [self degrees];
}

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
                                                   constant: 0.0];
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

+ (instancetype) baseUnit
{
  return [self squareMeters];
}

// Base unit - squareMeters
+ (NSUnitArea *) squareMegameters
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"Mm^2"
                                              coefficient: 1e12
                                                 constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareKilometers 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"km^2"
                                              coefficient: 1000000.0
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
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"cm^2"
                                               coefficient: 0.0001
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareMillimeters 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"mm^2"
                                               coefficient: 0.000001
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareMicrometers 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"um^2"
                                               coefficient: 1e-12
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareNanometers 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"nm^2"
                                              coefficient: 1e-18
                                                 constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareInches 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"in^2"
                                              coefficient: 0.00064516
                                                 constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareFeet 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"ft^2"
                                              coefficient: 0.092903
                                                 constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareYards 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"yd^2"
                                              coefficient: 0.836127
                                                 constant: 0.0];
  return result;
}

+ (NSUnitArea *) squareMiles 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"mi^2"
                                               coefficient: 2.59e+6
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) acres 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"acres"
                                               coefficient: 4046.86
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) ares 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"ares"
                                               coefficient: 100.0
                                                  constant: 0.0];
  return result;
}

+ (NSUnitArea *) hectares 
{
  NSUnitArea *result = [[NSUnitArea alloc] initWithSymbol: @"hectares"
                                               coefficient: 10000.0
                                                  constant: 0.0];
  return result;
}

@end

@implementation NSUnitConcentrationMass 

+ (instancetype) baseUnit
{
  return [self gramsPerLiter];
}

// Base unit - gramsPerLiter
+ (NSUnitConcentrationMass *) gramsPerLiter
{
  NSUnitConcentrationMass *result = [[NSUnitConcentrationMass alloc] initWithSymbol: @"g/L"
                                                                        coefficient: 1.0
                                                                           constant: 0.0];
  return result;
}

+ (NSUnitConcentrationMass *) milligramsPerDeciliter 
{
  NSUnitConcentrationMass *result = [[NSUnitConcentrationMass alloc] initWithSymbol: @"mg/dL"
                                                                        coefficient: 0.01
                                                                           constant: 0.0];
  return result;
}

+ (NSUnitConcentrationMass *) millimolesPerLiterWithGramsPerMole:(double)gramsPerMole 
{
  NSUnitConcentrationMass *result = [[NSUnitConcentrationMass alloc] initWithSymbol: @"mmol/L"
                                                                        coefficient: 18.0 * gramsPerMole
                                                                           constant: 0.0];
  return result;
}

@end

@implementation NSUnitDispersion 

+ (instancetype) baseUnit
{
  return [self partsPerMillion];
}

// Base unit - partsPerMillion
+ (NSUnitDispersion *) partsPerMillion 
{
  NSUnitDispersion *result = [[NSUnitDispersion alloc] initWithSymbol: @"ppm"
                                                          coefficient: 1.0
                                                             constant: 0.0];
  return result;
}

@end

@implementation NSUnitDuration   

+ (instancetype) baseUnit
{
  return [self seconds];
}

// Base unit - seconds
+ (NSUnitDuration *) seconds 
{
  NSUnitDuration *result = [[NSUnitDuration alloc] initWithSymbol: @"sec"
                                                      coefficient: 1.0
                                                         constant: 0.0];
  return result;
}

+ (NSUnitDuration *) minutes 
{
  NSUnitDuration *result = [[NSUnitDuration alloc] initWithSymbol: @"min"
                                                      coefficient: 60.0
                                                         constant: 0.0];
  return result;
}

+ (NSUnitDuration *) hours 
{
  NSUnitDuration *result = [[NSUnitDuration alloc] initWithSymbol: @"hr"
                                                      coefficient: 3600.0
                                                         constant: 0.0];
  return result;
}

@end

@implementation NSUnitElectricCharge 

+ (instancetype) baseUnit
{
  return [self coulombs];
}

// Base unit - coulombs
+ (NSUnitElectricCharge *) coulombs 
{
  NSUnitElectricCharge *result = [[NSUnitElectricCharge alloc] initWithSymbol: @"C"
                                                                  coefficient: 1.0
                                                                     constant: 0.0];
  return result;
}

+ (NSUnitElectricCharge *) megaampereHours 
{
  NSUnitElectricCharge *result = [[NSUnitElectricCharge alloc] initWithSymbol: @"MAh"
                                                                  coefficient: 3.6e9
                                                                     constant: 0.0];
  return result;
}

+ (NSUnitElectricCharge *) kiloampereHours 
{
  NSUnitElectricCharge *result = [[NSUnitElectricCharge alloc] initWithSymbol: @"kAh"
                                                                  coefficient: 3600000.0
                                                                     constant: 0.0];
  return result;
}

+ (NSUnitElectricCharge *) ampereHours 
{
  NSUnitElectricCharge *result = [[NSUnitElectricCharge alloc] initWithSymbol: @"mAh"
                                                                  coefficient: 3600.0
                                                                     constant: 0.0];
  return result;
}

+ (NSUnitElectricCharge *) milliampereHours 
{
  NSUnitElectricCharge *result = [[NSUnitElectricCharge alloc] initWithSymbol: @"hr"
                                                                  coefficient: 3.6
                                                                     constant: 0.0];
  return result;
}

+ (NSUnitElectricCharge *) microampereHours 
{
  NSUnitElectricCharge *result = [[NSUnitElectricCharge alloc] initWithSymbol: @"uAh"
                                                                  coefficient: 0.0036
                                                                     constant: 0.0];
  return result;
}

@end

@implementation NSUnitElectricCurrent 

+ (instancetype) baseUnit
{
  return [self amperes];
}

// Base unit - amperes
+ (NSUnitElectricCurrent *) megaamperes 
{
  NSUnitElectricCurrent *result = [[NSUnitElectricCurrent alloc] initWithSymbol: @"MA"
                                                                    coefficient: 1000000.0
                                                                       constant: 0.0];
  return result;
}

+ (NSUnitElectricCurrent *) kiloamperes 
{
  NSUnitElectricCurrent *result = [[NSUnitElectricCurrent alloc] initWithSymbol: @"kA"
                                                                    coefficient: 1000.0
                                                                       constant: 0.0];
  return result;
}

+ (NSUnitElectricCurrent *) amperes 
{
  NSUnitElectricCurrent *result = [[NSUnitElectricCurrent alloc] initWithSymbol: @"A"
                                                                    coefficient: 1.0
                                                                       constant: 0.0];
  return result;
}

+ (NSUnitElectricCurrent *) milliamperes
{
  NSUnitElectricCurrent *result = [[NSUnitElectricCurrent alloc] initWithSymbol: @"mA"
                                                                    coefficient: 0.001
                                                                       constant: 0.0];
  return result;
}

+ (NSUnitElectricCurrent *) microamperes
{
  NSUnitElectricCurrent *result = [[NSUnitElectricCurrent alloc] initWithSymbol: @"uA"
                                                                    coefficient: 0.000001                
                                                                       constant: 0.0];
  return result;
}

@end

@implementation NSUnitElectricPotentialDifference 

+ (instancetype) baseUnit
{
  return [self volts];
}

// Base unit - volts
+ (NSUnitElectricPotentialDifference *) megavolts 
{
  NSUnitElectricPotentialDifference *result =
    [[NSUnitElectricPotentialDifference alloc] initWithSymbol: @"MV"
                                                  coefficient: 0.0
                                                     constant: 1000000.0];
  return result;
}

+ (NSUnitElectricPotentialDifference *) kilovolts 
{
  NSUnitElectricPotentialDifference *result =
    [[NSUnitElectricPotentialDifference alloc] initWithSymbol: @"kV"
                                                  coefficient: 0.0
                                                     constant: 1000.0];
  return result;
}

+ (NSUnitElectricPotentialDifference *) volts 
{
  NSUnitElectricPotentialDifference *result =
    [[NSUnitElectricPotentialDifference alloc] initWithSymbol: @"V"
                                                  coefficient: 0.0
                                                     constant: 1.0];
  return result;
}

+ (NSUnitElectricPotentialDifference *) millivolts 
{
  NSUnitElectricPotentialDifference *result =
    [[NSUnitElectricPotentialDifference alloc] initWithSymbol: @"mV"
                                                  coefficient: 0.0
                                                     constant: 0.001];
  return result;
}

+ (NSUnitElectricPotentialDifference *) microvolts 
{
  NSUnitElectricPotentialDifference *result =
    [[NSUnitElectricPotentialDifference alloc] initWithSymbol: @"uV"
                                                  coefficient: 0.0
                                                     constant: 0.000001];
  return result;
}

@end

@implementation NSUnitElectricResistance 

+ (instancetype) baseUnit
{
  return [self ohms];
}

// Base unit - ohms
+ (NSUnitElectricResistance *) megaohms 
{
  NSUnitElectricResistance *result =
    [[NSUnitElectricResistance alloc] initWithSymbol: @"MOhm"
                                         coefficient: 0.0
                                            constant: 100000.0];
  return result;
}

+ (NSUnitElectricResistance *) kiloohms 
{
  NSUnitElectricResistance *result =
    [[NSUnitElectricResistance alloc] initWithSymbol: @"kOhm"
                                         coefficient: 0.0
                                            constant: 1000.000001];
  return result;
}

+ (NSUnitElectricResistance *) ohms 
{
  NSUnitElectricResistance *result =
    [[NSUnitElectricResistance alloc] initWithSymbol: @"Ohm"
                                         coefficient: 0.0
                                            constant: 0.000001];
  return result;
}

+ (NSUnitElectricResistance *) milliohms 
{
  NSUnitElectricResistance *result =
    [[NSUnitElectricResistance alloc] initWithSymbol: @"mOhm"
                                         coefficient: 0.0
                                            constant: 0.000001];
  return result;
}

+ (NSUnitElectricResistance *) microohms 
{
  NSUnitElectricResistance *result =
    [[NSUnitElectricResistance alloc] initWithSymbol: @"uOhm"
                                         coefficient: 0.0
                                            constant: 0.000001];
  return result;
}


@end

@implementation NSUnitEnergy 

+ (instancetype) baseUnit
{
  return [self joules];
}

// Base unit - joules
+ (NSUnitEnergy *) kilojoules
{
  NSUnitEnergy *result = [[NSUnitEnergy alloc] initWithSymbol: @"kJ"
                                              coefficient: 1000.0
                                                 constant: 0.0];
  return result;
}

+ (NSUnitEnergy *) joules 
{
  NSUnitEnergy *result = [[NSUnitEnergy alloc] initWithSymbol: @"J"
                                              coefficient: 1.0
                                                 constant: 0.0];
  return result;
}

+ (NSUnitEnergy *) kilocalories 
{
  NSUnitEnergy *result = [[NSUnitEnergy alloc] initWithSymbol: @"kCal"
                                              coefficient: 4184.0
                                                 constant: 0.0];
  return result;
}

+ (NSUnitEnergy *) calories 
{
  NSUnitEnergy *result = [[NSUnitEnergy alloc] initWithSymbol: @"cal"
                                              coefficient: 4.184
                                                 constant: 0.0];
  return result;
}

+ (NSUnitEnergy *) kilowattHours 
{
  NSUnitEnergy *result = [[NSUnitEnergy alloc] initWithSymbol: @"kWh"
                                              coefficient: 3600000.0
                                                 constant: 0.0];
  return result;
}

@end

@implementation NSUnitFrequency 

+ (instancetype) baseUnit
{
  return [self hertz];
}

// Base unit - hertz

+ (NSUnitFrequency *) terahertz 
{
  NSUnitFrequency *result = [[NSUnitFrequency alloc] initWithSymbol: @"thz"
                                              coefficient: 1e12
                                                 constant: 0.0];
  return result;
}

+ (NSUnitFrequency *) gigahertz 
{
  NSUnitFrequency *result = [[NSUnitFrequency alloc] initWithSymbol: @"ghz"
                                              coefficient: 1e9
                                                 constant: 0.0];
  return result;
}

+ (NSUnitFrequency *) megahertz 
{
  NSUnitFrequency *result = [[NSUnitFrequency alloc] initWithSymbol: @"GHz"
                                              coefficient: 1000000.0
                                                 constant: 0.0];
  return result;
}

+ (NSUnitFrequency *) kilohertz 
{
  NSUnitFrequency *result = [[NSUnitFrequency alloc] initWithSymbol: @"KHz"
                                              coefficient: 1000.0
                                                 constant: 0.0];
  return result;
}

+ (NSUnitFrequency *) hertz 
{
  NSUnitFrequency *result = [[NSUnitFrequency alloc] initWithSymbol: @"Hz"
                                              coefficient: 1.0
                                                 constant: 0.0];
  return result;
}

+ (NSUnitFrequency *) millihertz 
{
  NSUnitFrequency *result = [[NSUnitFrequency alloc] initWithSymbol: @"mHz"
                                              coefficient: 0.001
                                                 constant: 0.0];
  return result;
}

+ (NSUnitFrequency *) microhertz 
{
  NSUnitFrequency *result = [[NSUnitFrequency alloc] initWithSymbol: @"uHz"
                                              coefficient: 0.000001
                                                 constant: 0.0];
  return result;
}

+ (NSUnitFrequency *) nanohertz 
{
  NSUnitFrequency *result = [[NSUnitFrequency alloc] initWithSymbol: @"nHz"
                                              coefficient: 1e-9
                                                 constant: 0.0];
  return result;
}

@end

@implementation NSUnitFuelEfficiency 

+ (instancetype) baseUnit
{
  return [self litersPer100Kilometers];
}

// Base unit - litersPer100Kilometers

+ (NSUnitFuelEfficiency *) litersPer100Kilometers
{
  NSUnitFuelEfficiency *result = [[NSUnitFuelEfficiency alloc] initWithSymbol: @"L/100km"
                                                                  coefficient: 0.0
                                                                     constant: 0.0];
  return result;
}

+ (NSUnitFuelEfficiency *) milesPerImperialGallon
{
  NSUnitFuelEfficiency *result = [[NSUnitFuelEfficiency alloc] initWithSymbol: @"mpg"
                                                                  coefficient: 0.0
                                                                     constant: 0.0];
  return result;
}

+ (NSUnitFuelEfficiency *) milesPerGallon
{
  NSUnitFuelEfficiency *result = [[NSUnitFuelEfficiency alloc] initWithSymbol: @"mpg"
                                                                  coefficient: 0.0
                                                                     constant: 0.0];
  return result;
}

@end

@implementation NSUnitLength 

+ (instancetype) baseUnit
{
  return [self meters];
}

// Base unit - meters

+ (NSUnitLength *) megameters 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"Mm"
                                                  coefficient: 1000000.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) kilometers 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"kM"
                                                  coefficient: 1000.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) hectometers 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"hm"
                                                  coefficient: 100.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) decameters 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"dam"
                                                  coefficient: 10
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) meters 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"meters"
                                                  coefficient: 1.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) decimeters 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"dm"
                                                  coefficient: 0.1
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) centimeters 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"cm"
                                                  coefficient: 0.01
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) millimeters 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"mm"
                                                  coefficient: 0.001
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) micrometers 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"um"
                                                  coefficient: 0.000001
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) nanometers 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"nm"
                                                  coefficient: 1e-9
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) picometers 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"pm"
                                                  coefficient: 1e-12
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) inches 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"in"
                                                  coefficient: 0.254
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) feet 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"ft"
                                                  coefficient: 0.3048
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) yards 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"yd"
                                                  coefficient: 0.9144
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) miles 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"mi"
                                                  coefficient: 1609.34
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) scandinavianMiles 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"smi"
                                                  coefficient: 10000
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) lightyears 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"ly"
                                                  coefficient: 9.461e+15
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) nauticalMiles 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"NM"
                                                  coefficient: 1852.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) fathoms 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"ftm"
                                                  coefficient: 1.8288
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) furlongs 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"fur"
                                                  coefficient: 0.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) astronomicalUnits 
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"ua"
                                                  coefficient: 1.496e+11
                                                     constant: 0.0];
  return result;
}

+ (NSUnitLength *) parsecs
{
  NSUnitLength *result = [[NSUnitLength alloc] initWithSymbol: @"pc"
                                                  coefficient: 3.086e+16
                                                     constant: 0.0];
  return result;
}

@end

@implementation NSUnitIlluminance 

+ (instancetype) baseUnit
{
  return [self lux];
}

// Base unit - lux
+ (NSUnitIlluminance *) lux
{
  NSUnitIlluminance *result = [[NSUnitIlluminance alloc] initWithSymbol: @"lux"
                                                            coefficient: 1.0
                                                               constant: 0.0];
  return result;
}

@end

@implementation NSUnitMass 

+ (instancetype) baseUnit
{
  return [self kilograms];
}

// Base unit - kilograms

+ (NSUnitMass *) kilograms 
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"kg"
                                              coefficient: 1.0
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) grams 
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"g"
                                              coefficient: 0.001
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) decigrams
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"dg"
                                              coefficient: 0.0001
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) centigrams
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"cg"
                                              coefficient: 0.00001
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) milligrams
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"mg"
                                              coefficient: 0.000001
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) micrograms
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"ug"
                                              coefficient: 1e9 
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) nanograms 
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"ng"
                                              coefficient: 1e-12
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) picograms 
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"pg"
                                              coefficient: 1e-15
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) ounces 
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"oz"
                                              coefficient: 0.0283495
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) poundsMass
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"lb"
                                              coefficient: 0.453592
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) stones 
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"st"
                                              coefficient: 0.157473
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) metricTons
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"t"
                                              coefficient: 1000
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) shortTons 
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"ton"
                                              coefficient: 907.185
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) carats
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"ct"
                                              coefficient: 0.0002 
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) ouncesTroy
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"oz t"
                                              coefficient: 0.03110348
                                                 constant: 0.0];
  return result;
}

+ (NSUnitMass *) slugs
{
  NSUnitMass *result = [[NSUnitMass alloc] initWithSymbol: @"slug"
                                              coefficient: 14.5939
                                                 constant: 0.0];
  return result;
}

@end

@implementation NSUnitPower 

+ (instancetype) baseUnit
{
  return [self watts];
}

// Base unit - watts

+ (NSUnitPower *) terawatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"TW"
                                              coefficient: 1e12
                                                 constant: 0.0];
  return result;
}

+ (NSUnitPower *) gigawatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"GW"
                                                coefficient: 1e9
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) megawatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"MW"
                                                coefficient: 1000000.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) kilowatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"kW"
                                                coefficient: 1000.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) watts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"W"
                                                coefficient: 1.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) milliwatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"mW"
                                                coefficient: 0.001
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) microwatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"uW"
                                                coefficient: 0.000001
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) nanowatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"nW"
                                                coefficient: 1e-9
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) picowatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"pW"
                                                coefficient: 1e-12
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) femtowatts 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"fW"
                                                coefficient: 1e-15
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPower *) horsepower 
{
  NSUnitPower *result = [[NSUnitPower alloc] initWithSymbol: @"hp"
                                                coefficient: 745.7
                                                   constant: 0.0];
  return result;
}

@end

@implementation NSUnitPressure

+ (instancetype) baseUnit
{
  return [self newtonsPerMetersSquared];
}

// Base unit - newtonsPerMetersSquared (equivalent to 1 pascal)

+ (NSUnitPressure *) newtonsPerMetersSquared 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"N/m^2"
                                                coefficient: 0.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) gigapascals 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"GPa"
                                                coefficient: 1e9
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) megapascals 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"MPa"
                                                coefficient: 1000000.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) kilopascals 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"kPa"
                                                coefficient: 1000.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) hectopascals 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"hPa"
                                                coefficient: 100.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) inchesOfMercury 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"inHg"
                                                coefficient: 3386.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) bars 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"bars"
                                                coefficient: 100000.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) millibars 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"mbars"
                                                coefficient: 100.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) millimetersOfMercury 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"mmHg"
                                                coefficient: 133.322 
                                                   constant: 0.0];
  return result;
}

+ (NSUnitPressure *) poundsForcePerSquareInch 
{
  NSUnitPressure *result = [[NSUnitPressure alloc] initWithSymbol: @"psi"
                                                coefficient: 6894.76
                                                   constant: 0.0];
  return result;
}


@end

@implementation NSUnitSpeed 
+ (instancetype) baseUnit
{
  return [self metersPerSecond];
}

// Base unit - metersPerSecond
+ (NSUnitSpeed *) metersPerSecond
{
  NSUnitSpeed *result = [[NSUnitSpeed alloc] initWithSymbol: @"m/s"
                                                coefficient: 1.0
                                                   constant: 0.0];
  return result;
}

+ (NSUnitSpeed *) kilometersPerHour
{
  NSUnitSpeed *result = [[NSUnitSpeed alloc] initWithSymbol: @"km/h"
                                                coefficient: 0.277778
                                                   constant: 0.0];
  return result;
}

+ (NSUnitSpeed *) milesPerHour
{
  NSUnitSpeed *result = [[NSUnitSpeed alloc] initWithSymbol: @"mph"
                                                coefficient: 0.44704
                                                   constant: 0.0];
  return result;
}

+ (NSUnitSpeed *) knots
{
  NSUnitSpeed *result = [[NSUnitSpeed alloc] initWithSymbol: @"kn"
                                                coefficient: 0.51444
                                                   constant: 0.0];
  return result;
}

@end

@implementation NSUnitTemperature
+ (instancetype) baseUnit
{
  return [self kelvin];
}

// Base unit - kelvin
+ (NSUnitTemperature *) kelvin
{
  NSUnitTemperature *result = [[NSUnitTemperature alloc] initWithSymbol: @"K"
							    coefficient: 1.0
							       constant: 0.0];
  return result;
}

+ (NSUnitTemperature *) celsius
{
  NSUnitTemperature *result = [[NSUnitTemperature alloc] initWithSymbol: @"C"
							    coefficient: 1.0
							       constant: 273.15];
  return result;
}

+ (NSUnitTemperature *) fahrenheit
{
  NSUnitTemperature *result = [[NSUnitTemperature alloc] initWithSymbol: @"F"
							    coefficient: 0.55555555555556
							       constant: 255.37222222222427];
  return result;
}
@end

@implementation NSUnitVolume
+ (instancetype) baseUnit
{
  return [self liters];
}

// Base unit - liters
+ (NSUnitVolume *) megaliters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"ML"
                                                  coefficient: 1000000.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) kiloliters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"kL"
                                                  coefficient: 1000.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) liters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"L"
                                                  coefficient: 1.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) deciliters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"dL"
                                                  coefficient: 0.1
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) centiliters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"cL"
                                                  coefficient: 0.01
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) milliliters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"mL"
                                                  coefficient: 0.001
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicKilometers 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"km^3"
                                                  coefficient: 1e12
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicMeters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"m^3"
                                                  coefficient: 1000.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicDecimeters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"dm^3"
                                                  coefficient: 1.0
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicCentimeters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"cm^3"
                                                  coefficient: 0.0001
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicMillimeters 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"mm^3"
                                                  coefficient: 0.000001
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicInches 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"in^3"
                                                  coefficient: 0.0163871
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicFeet 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"ft^3"
                                                  coefficient: 28.3168
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicYards 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"yd^3"
                                                  coefficient: 764.555
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cubicMiles 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"mi^3"
                                                  coefficient: 4.168e+12
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) acreFeet 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"af"
                                                  coefficient: 1.233e+6
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) bushels 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"bsh"
                                                  coefficient: 32.2391
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) teaspoons 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"tsp"
                                                  coefficient: 0.00492892
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) tablespoons 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"tbsp"
                                                  coefficient: 0.0147868
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) fluidOunces 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"fl oz"
                                                  coefficient: 0.295735
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) cups 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"cups"
                                                  coefficient: 0.24
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) pints 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"pt"
                                                  coefficient: 0.473176
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) quarts 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"qt"
                                                  coefficient: 0.946353
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) gallons 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"gal"
                                                  coefficient: 3.78541
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) imperialTeaspoons 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"tsp"
                                                  coefficient: 0.00591939
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) imperialTablespoons 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"tbsp"
                                                  coefficient: 0.0177582
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) imperialFluidOunces 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"fl oz"
                                                  coefficient: 0.0284131
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) imperialPints 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"pt"
                                                  coefficient: 0.568261
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) imperialQuarts 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"qt"
                                                  coefficient: 1.13652
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) imperialGallons 
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"gal"
                                                  coefficient: 4.54609
                                                     constant: 0.0];
  return result;
}

+ (NSUnitVolume *) metricCups  
{
  NSUnitVolume *result = [[NSUnitVolume alloc] initWithSymbol: @"metric cup"
                                                  coefficient: 0.25
                                                     constant: 0.0];
  return result;
}


@end
