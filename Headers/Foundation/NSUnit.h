
/* Definition of class NSUnit
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

#ifndef _NSUnit_h_GNUSTEP_BASE_INCLUDE
#define _NSUnit_h_GNUSTEP_BASE_INCLUDE

#include <Foundation/NSObject.h>

#if	defined(__cplusplus)
extern "C" {
#endif

#if OS_API_VERSION(MAC_OS_X_VERSION_10_12, GS_API_LATEST)

// Unit converter
@interface NSUnitConverter : NSObject
- (double)baseUnitValueFromValue:(double)value;
- (double)valueFromBaseUnitValue:(double)baseUnitValue;
@end

// Linea converter... for things like C <-> F conversion...
@interface NSUnitConverterLinear : NSUnitConverter <NSCoding>
{
  double _coefficient;
  double _constant;
}
- (instancetype) initWithCoefficient: (double)coefficient;
- (instancetype) initWithCoefficient: (double)coefficient
                            constant: (double)constant;
- (double) coefficient;
- (double) constant;
@end

// Units...  abstract...
@interface NSUnit : NSObject <NSCopying, NSCoding>
{
  NSString *_symbol;
}
  
+ (instancetype)new;
- (instancetype)init;
- (instancetype)initWithSymbol:(NSString *)symbol;
- (NSString *)symbol;

@end

// Dimension using units....
@interface NSDimension : NSUnit <NSCoding>
{
    NSUInteger _reserved;
    NSUnitConverter *_converter;
}

- (NSUnitConverter *) converter;
- (instancetype) initWithSymbol: (NSString *)symbol converter: (NSUnitConverter *) converter ;
+ (instancetype) baseUnit;

@end

// Predefined....
@interface NSUnitAcceleration : NSDimension <NSSecureCoding>
/*
 Base unit - metersPerSecondSquared
 */

- (NSUnitAcceleration *)metersPerSecondSquared;
- (NSUnitAcceleration *)gravity;

@end

@interface NSUnitAngle : NSDimension <NSSecureCoding>
/*
 Base unit - degrees
 */

- (NSUnitAngle *)degrees;
- (NSUnitAngle *)arcMinutes;
- (NSUnitAngle *)arcSeconds;
- (NSUnitAngle *)radians;
- (NSUnitAngle *)gradians;
- (NSUnitAngle *)revolutions;

@end

@interface NSUnitArea : NSDimension <NSSecureCoding>
/*
 Base unit - squareMeters
 */

- (NSUnitArea *)squareMegameters;
- (NSUnitArea *)squareKilometers;
- (NSUnitArea *)squareMeters;
- (NSUnitArea *)squareCentimeters;
- (NSUnitArea *)squareMillimeters;
- (NSUnitArea *)squareMicrometers;
- (NSUnitArea *)squareNanometers;
- (NSUnitArea *)squareInches;
- (NSUnitArea *)squareFeet;
- (NSUnitArea *)squareYards;
- (NSUnitArea *)squareMiles;
- (NSUnitArea *)acres;
- (NSUnitArea *)ares;
- (NSUnitArea *)hectares;

@end

@interface NSUnitConcentrationMass : NSDimension <NSSecureCoding>
/*
 Base unit - gramsPerLiter
 */

- (NSUnitConcentrationMass *)gramsPerLiter;
- (NSUnitConcentrationMass *)milligramsPerDeciliter;

+ (NSUnitConcentrationMass *)millimolesPerLiterWithGramsPerMole:(double)gramsPerMole;

@end

@interface NSUnitDispersion : NSDimension <NSSecureCoding>
/*
 Base unit - partsPerMillion
 */
- (NSUnitDispersion *)partsPerMillion;

@end

@interface NSUnitDuration : NSDimension <NSSecureCoding>  
/*
 Base unit - seconds
 */

- (NSUnitDuration *)seconds;
- (NSUnitDuration *)minutes;
- (NSUnitDuration *)hours;

@end

@interface NSUnitElectricCharge : NSDimension <NSSecureCoding>
/*
 Base unit - coulombs
 */

- (NSUnitElectricCharge *)coulombs;
- (NSUnitElectricCharge *)megaampereHours;
- (NSUnitElectricCharge *)kiloampereHours;
- (NSUnitElectricCharge *)ampereHours;
- (NSUnitElectricCharge *)milliampereHours;
- (NSUnitElectricCharge *)microampereHours;

@end

@interface NSUnitElectricCurrent : NSDimension <NSSecureCoding>
/*
 Base unit - amperes
 */

- (NSUnitElectricCurrent *)megaamperes;
- (NSUnitElectricCurrent *)kiloamperes;
- (NSUnitElectricCurrent *)amperes;
- (NSUnitElectricCurrent *)milliamperes;
- (NSUnitElectricCurrent *)microamperes;

@end

@interface NSUnitElectricPotentialDifference : NSDimension <NSSecureCoding>
/*
 Base unit - volts
 */

- (NSUnitElectricPotentialDifference *)megavolts;
- (NSUnitElectricPotentialDifference *)kilovolts;
- (NSUnitElectricPotentialDifference *)volts;
- (NSUnitElectricPotentialDifference *)millivolts;
- (NSUnitElectricPotentialDifference *)microvolts;

@end

@interface NSUnitElectricResistance : NSDimension <NSSecureCoding>
/*
 Base unit - ohms
 */

- (NSUnitElectricResistance *)megaohms;
- (NSUnitElectricResistance *)kiloohms;
- (NSUnitElectricResistance *)ohms;
- (NSUnitElectricResistance *)milliohms;
- (NSUnitElectricResistance *)microohms;

@end

@interface NSUnitEnergy : NSDimension <NSSecureCoding>
/*
 Base unit - joules
 */

- (NSUnitEnergy *)kilojoules;
- (NSUnitEnergy *)joules;
- (NSUnitEnergy *)kilocalories;
- (NSUnitEnergy *)calories;
- (NSUnitEnergy *)kilowattHours;

@end

@interface NSUnitFrequency : NSDimension <NSSecureCoding>
/*
 Base unit - hertz
 */

- (NSUnitFrequency *)terahertz;
- (NSUnitFrequency *)gigahertz;
- (NSUnitFrequency *)megahertz;
- (NSUnitFrequency *)kilohertz;
- (NSUnitFrequency *)hertz;
- (NSUnitFrequency *)millihertz;
- (NSUnitFrequency *)microhertz;
- (NSUnitFrequency *)nanohertz;

@end

@interface NSUnitFuelEfficiency : NSDimension <NSSecureCoding>
/*
 Base unit - litersPer100Kilometers
 */

- (NSUnitFuelEfficiency *)litersPer100Kilometers;
- (NSUnitFuelEfficiency *)milesPerImperialGallon;
- (NSUnitFuelEfficiency *)milesPerGallon;

@end

@interface NSUnitLength : NSDimension <NSSecureCoding>
/*
 Base unit - meters
 */

- (NSUnitLength *)megameters;
- (NSUnitLength *)kilometers;
- (NSUnitLength *)hectometers;
- (NSUnitLength *)decameters;
- (NSUnitLength *)meters;
- (NSUnitLength *)decimeters;
- (NSUnitLength *)centimeters;
- (NSUnitLength *)millimeters;
- (NSUnitLength *)micrometers;
- (NSUnitLength *)nanometers;
- (NSUnitLength *)picometers;
- (NSUnitLength *)inches;
- (NSUnitLength *)feet;
- (NSUnitLength *)yards;
- (NSUnitLength *)miles;
- (NSUnitLength *)scandinavianMiles;
- (NSUnitLength *)lightyears;
- (NSUnitLength *)nauticalMiles;
- (NSUnitLength *)fathoms;
- (NSUnitLength *)furlongs;
- (NSUnitLength *)astronomicalUnits;
- (NSUnitLength *)parsecs;

@end

@interface NSUnitIlluminance : NSDimension <NSSecureCoding>
/*
 Base unit - lux
 */

- (NSUnitIlluminance *)lux;

@end

@interface NSUnitMass : NSDimension <NSSecureCoding>
/*
 Base unit - kilograms
 */

- (NSUnitMass *)kilograms;
- (NSUnitMass *)grams;
- (NSUnitMass *)decigrams;
- (NSUnitMass *)centigrams;
- (NSUnitMass *)milligrams;
- (NSUnitMass *)micrograms;
- (NSUnitMass *)nanograms;
- (NSUnitMass *)picograms;
- (NSUnitMass *)ounces;
- (NSUnitMass *)poundsMass;
- (NSUnitMass *)stones;
- (NSUnitMass *)metricTons;
- (NSUnitMass *)shortTons;
- (NSUnitMass *)carats;
- (NSUnitMass *)ouncesTroy;
- (NSUnitMass *)slugs;

@end

@interface NSUnitPower : NSDimension <NSSecureCoding>
/*
 Base unit - watts
 */

- (NSUnitPower *)terawatts;
- (NSUnitPower *)gigawatts;
- (NSUnitPower *)megawatts;
- (NSUnitPower *)kilowatts;
- (NSUnitPower *)watts;
- (NSUnitPower *)milliwatts;
- (NSUnitPower *)microwatts;
- (NSUnitPower *)nanowatts;
- (NSUnitPower *)picowatts;
- (NSUnitPower *)femtowatts;
- (NSUnitPower *)horsepower;

@end

@interface NSUnitPressure : NSDimension <NSSecureCoding>
/*
 Base unit - newtonsPerMetersSquared (equivalent to 1 pascal)
 */

- (NSUnitPressure *)newtonsPerMetersSquared;
- (NSUnitPressure *)gigapascals;
- (NSUnitPressure *)megapascals;
- (NSUnitPressure *)kilopascals;
- (NSUnitPressure *)hectopascals;
- (NSUnitPressure *)inchesOfMercury;
- (NSUnitPressure *)bars;
- (NSUnitPressure *)millibars;
- (NSUnitPressure *)millimetersOfMercury;
- (NSUnitPressure *)poundsForcePerSquareInch;

@end

@interface NSUnitSpeed : NSDimension <NSSecureCoding>
/*
 Base unit - metersPerSecond
 */

- (NSUnitSpeed *)metersPerSecond;
- (NSUnitSpeed *)kilometersPerHour;
- (NSUnitSpeed *)milesPerHour;
- (NSUnitSpeed *)knots;

@end

@interface NSUnitTemperature : NSDimension <NSSecureCoding>
/*
 Base unit - kelvin
 */
- (NSUnitTemperature *)kelvin;
- (NSUnitTemperature *)celsius; 
- (NSUnitTemperature *)fahrenheit;


@end

@interface NSUnitVolume : NSDimension <NSSecureCoding>
/*
 Base unit - liters
 */

- (NSUnitVolume *)megaliters;
- (NSUnitVolume *)kiloliters;
- (NSUnitVolume *)liters;
- (NSUnitVolume *)deciliters;
- (NSUnitVolume *)centiliters;
- (NSUnitVolume *)milliliters;
- (NSUnitVolume *)cubicKilometers;
- (NSUnitVolume *)cubicMeters;
- (NSUnitVolume *)cubicDecimeters;
- (NSUnitVolume *)cubicCentimeters;
- (NSUnitVolume *)cubicMillimeters;
- (NSUnitVolume *)cubicInches;
- (NSUnitVolume *)cubicFeet;
- (NSUnitVolume *)cubicYards;
- (NSUnitVolume *)cubicMiles;
- (NSUnitVolume *)acreFeet;
- (NSUnitVolume *)bushels;
- (NSUnitVolume *)teaspoons;
- (NSUnitVolume *)tablespoons;
- (NSUnitVolume *)fluidOunces;
- (NSUnitVolume *)cups;
- (NSUnitVolume *)pints;
- (NSUnitVolume *)quarts;
- (NSUnitVolume *)gallons;
- (NSUnitVolume *)imperialTeaspoons;
- (NSUnitVolume *)imperialTablespoons;
- (NSUnitVolume *)imperialFluidOunces;
- (NSUnitVolume *)imperialPints;
- (NSUnitVolume *)imperialQuarts;
- (NSUnitVolume *)imperialGallons;
- (NSUnitVolume *)metricCups;

@end

#if	defined(__cplusplus)
}
#endif

#endif	/* GS_API_MACOSX */

#endif	/* _NSUnit_h_GNUSTEP_BASE_INCLUDE */

