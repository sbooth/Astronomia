//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Decimal year arithmetic shared by ``JulianCalendar``, ``GregorianCalendar``, and
/// ``JulianGregorianCalendar``.
///
/// A decimal year is the year number plus the fraction of the year elapsed at the start of
/// a day. The fraction is the number of whole days elapsed since January 1 divided by the
/// number of days in the year, so day `N` of year `Y` with `d` days is `Y + (N - 1) / d`.
/// For example, January 1, 1985 is 1985.0 and July 2, 1985 is 1985 + 182/365 ≈ 1985.4986.
///
/// The number of days in the year is supplied by the calling calendar, so these helpers also
/// handle the 355-day year 1582 in the Julian-Gregorian calendar.
///
/// - Note: Decimal years distinguish individual days only when the year's magnitude is
///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
/// - Note: This is a calendar-based value, not an astronomical epoch such as a Julian or
///   Besselian epoch.
enum DecimalYearArithmetic {
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
	static func startOfDay(year Y: Int, dayOfYear N: Int, daysInYear d: Int) -> Double {
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
	static func dayOfYear(decimalYear: Double, year Y: Int, yearFraction: Double, daysInYear d: Int) -> Int {
		assert(decimalYear.isFinite, "Decimal year must be finite")
		assert(Double(Y) <= decimalYear, "Decimal year is before the start of year Y")
		assert(yearFraction >= 0 && yearFraction < 1, "Year fraction is outside the right-open interval [0, 1)")
		assert(d > 0, "Number of days in year must be positive")
		var N = Int((yearFraction * Double(d)).rounded(.down)) + 1
		// Correct the estimate for rounding in the decimal year
		while N > 1, startOfDay(year: Y, dayOfYear: N, daysInYear: d) > decimalYear {
			N -= 1
		}
		while N < d, startOfDay(year: Y, dayOfYear: N + 1, daysInYear: d) <= decimalYear {
			N += 1
		}
		return N
	}

	/// Returns the year and day of year containing the specified decimal year.
	///
	/// - Parameters:
	///   - decimalYear: The decimal year. Year number 0 is 1 BCE.
	///   - daysInYear: Returns the number of days in a year in the calendar being used.
	/// - Returns: The year and the day of year, from 1 to the number of days in that year.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the decimal year is not finite.
	///   - ``CalendarError/invalidDecimalYear`` if the year cannot be represented as an `Int`.
	static func yearAndDayOfYear(decimalYear: Double, daysInYear: (Int) -> Int) throws(CalendarError) -> (year: Int, dayOfYear: Int) {
		guard decimalYear.isFinite else { throw .nonFiniteValue }
		guard let (Y, yearFraction) = decimalYear.floorAndFraction else { throw .invalidDecimalYear }
		// Ensure accurate date for decimal years that rounded to 0
		if decimalYear < Double(Y) {
			return (Y - 1, daysInYear(Y - 1))
		}
		let d = daysInYear(Y)
		let dayOfYear = dayOfYear(decimalYear: decimalYear, year: Y, yearFraction: yearFraction, daysInYear: d)
		return (Y, dayOfYear)
	}
}
