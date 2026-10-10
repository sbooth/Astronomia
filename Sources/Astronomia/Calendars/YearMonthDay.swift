//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A date consisting of a year number, month number, and day number.
///
/// Year numbers are arithmetic and may be positive or negative. Year number 0 is 1 BCE.
///
/// In a valid date, months are numbered from 1 (January) to 12 (December), and day numbers
/// are positive with the first day of a month having day number 1.
///
/// A `YearMonthDay` is not validated. Functions that normalize dates accept month and day
/// numbers outside these ranges; other functions document how they treat invalid dates.
public typealias YearMonthDay = (year: Int, month: Int, day: Int)
