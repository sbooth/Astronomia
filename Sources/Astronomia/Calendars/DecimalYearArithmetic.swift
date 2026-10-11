//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Returns the decimal year for the start of the specified day of year.
///
/// The fraction is the number of whole days elapsed since January 1 divided by the number
/// of days in the year, so day 1 is exactly `Y` and day 183 of a 365-day year is
/// `Y` + 182/365.
///
/// - Parameters:
///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
///   - N: The day of year, starting at 1.
///   - d: The number of days in year `Y` in the calendar being used.
/// - Returns: The decimal year at the start of day `N` of year `Y`.
/// - Precondition: `N` is in the closed interval [1, `d`].
func decimalYearForStartOfDay(year Y: Int, dayOfYear N: Int, numberOfDaysInYear d: Int) -> Double {
	assert(N >= 1 && N <= d, "Day of year is outside the closed interval [1, \(d)]")
	return Double(Y) + Double(N - 1) / Double(d)
}

/// Returns the greatest day of year whose start is at or before the specified decimal year.
///
/// - Note: This is valid for the Julian, Gregorian, and Julian-Gregorian calendars, including
///   the 355-day year 1582 in the Julian-Gregorian calendar.
/// - Parameters:
///   - decimalYear: The decimal year. Year number 0 is 1 BCE.
///   - Y: The arithmetic year number containing `decimalYear`.
///   - yearFraction: The fraction of the year elapsed at `decimalYear`.
///   - d: The number of days in year `Y` in the calendar being used.
/// - Returns: The day of year, from 1 to `d`, of the latest day whose start is at or before
///   `decimalYear`.
func dayOfYearForDecimalYear(_ decimalYear: Double, year Y: Int, yearFraction: Double, numberOfDaysInYear d: Int) -> Int {
	assert(decimalYear.isFinite, "Decimal year must be finite")
	assert(Double(Y) <= decimalYear, "Decimal year is before the start of year Y")
	assert(yearFraction >= 0 && yearFraction < 1, "Year fraction is outside the right-open interval [0, 1)")
	assert(d > 0, "Number of days in year must be positive")
	var N = Int((yearFraction * Double(d)).rounded(.down)) + 1
	// Correct the estimate for rounding in the decimal year
	while N > 1, decimalYearForStartOfDay(year: Y, dayOfYear: N, numberOfDaysInYear: d) > decimalYear {
		N -= 1
	}
	while N < d, decimalYearForStartOfDay(year: Y, dayOfYear: N + 1, numberOfDaysInYear: d) <= decimalYear {
		N += 1
	}
	return N
}
