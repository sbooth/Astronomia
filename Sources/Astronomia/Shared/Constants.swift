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

/// 2π.
let twoPi: Double = 2 * .pi

/// Arcseconds per radian.
let arcsecondsPerRadian: Double = 648_000 / .pi

/// Microarcseconds per radian.
let microarcsecondsPerRadian: Double = 648_000_000_000 / .pi
