//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A Julian day number.
///
/// The Julian day number (JDN) is the integer assigned to a whole solar day in the Julian day count starting from noon Universal Time,
/// with JDN 0 assigned to the day starting at noon on Monday, January 1, 4713 BCE in the proleptic Julian calendar.
///
/// - seealso: [Julian day](https://en.wikipedia.org/wiki/Julian_day)
public typealias JulianDayNumber = Int

/// An error indicating that a Julian day number cannot be represented as a ``JulianDayNumber``.
public struct JulianDayNumberOutOfRangeError: Error {}

/// A date consisting of a year number, month number, and day number.
///
/// Year numbers are arithmetic and may be positive or negative. Year number 0 is 1 BCE.
///
/// Months are numbered from `1` (January) to `12` (December).
///
/// Day numbers are always positive and the first day of a month has day number `1`.
public typealias YearMonthDay = (year: Int, month: Int, day: Int)
