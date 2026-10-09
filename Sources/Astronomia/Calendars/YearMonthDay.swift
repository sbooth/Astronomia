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
/// Months are numbered from 1 (January) to 12 (December).
///
/// Day numbers are always positive and the first day of a month has day number 1.
public typealias YearMonthDay = (year: Int, month: Int, day: Int)
