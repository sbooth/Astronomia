//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Seconds per day.
///
/// - Important: Leap seconds are deliberately not modeled.
let secondsPerDay: Double = 86_400

/// Seconds per day, for exact integer arithmetic.
///
/// - Important: Leap seconds are deliberately not modeled.
let integerSecondsPerDay: Int = 86_400

/// Days per Julian year.
let daysPerJulianYear: Double = 365.25

/// Days per hundred Julian years.
let daysPerJulianCentury: Double = 36_525

/// Days per thousand Julian years.
let daysPerJulianMillennium: Double = 365_250

/// The offset from a noon-based day count to the midnight-based count of the same
/// instant: midnight-based = noon-based + 0.5.
let noonToMidnightOffset: Double = 0.5

/// Meters per astronomical unit  (IAU 2012 Resolution B2).
let metersPerAstronomicalUnit: Double = 149_597_870_700

/// Kilometers per astronomical unit, 149,597,870.7.
let kilometersPerAstronomicalUnit: Double = 149_597_870.7


/// The speed of light in vacuum, 299,792.458 km/s.
let speedOfLight: Double = 299_792.458

/// The speed of light in vacuum, in astronomical units per day.
let speedOfLightAstronomicalUnitsPerDay: Double = speedOfLight * secondsPerDay / kilometersPerAstronomicalUnit

/// 2π.
let twoPi: Double = 2 * .pi

/// Arcseconds per radian.
let arcsecondsPerRadian: Double = 648_000 / .pi

/// Microarcseconds per radian.
let microarcsecondsPerRadian: Double = 648_000_000_000 / .pi

/// The nominal radius of the Sun, 695,700 km.
///
/// The conversion constant of IAU 2015 Resolution B3, the radius of the photosphere.
let nominalSolarRadius: Distance = .kilometers(695_700)

/// The equatorial radius of Jupiter at the 1 bar level, 71,492 km.
///
/// From the report of the IAU Working Group on Cartographic Coordinates and Rotational
/// Elements, 2015 (Archinal et al. 2018).
let jupiterEquatorialRadius: Distance = .kilometers(71_492)

/// The equatorial radius of Saturn at the 1 bar level, 60,268 km.
///
/// From the report of the IAU Working Group on Cartographic Coordinates and Rotational
/// Elements, 2015 (Archinal et al. 2018).
let saturnEquatorialRadius: Distance = .kilometers(60_268)
