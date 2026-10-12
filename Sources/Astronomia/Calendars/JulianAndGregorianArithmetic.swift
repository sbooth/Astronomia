//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Year and month arithmetic shared by ``JulianCalendar`` and ``GregorianCalendar``.
///
/// Both calendars have 365- or 366-day years with the same month lengths and differ only in
/// the leap year rule. These helpers do not apply to ``JulianGregorianCalendar``, whose
/// year 1582 has 355 days and whose October 1582 has 21 days.
enum JulianAndGregorianArithmetic {
	/// Returns the number of days in a year: 365 or 366.
	///
	/// - Parameter isLeap: Whether the year is a leap year.
	/// - Returns: The number of days in the year.
	static func numberOfDays(isLeap: Bool) -> Int {
		isLeap ? 366 : 365
	}

	/// Returns the number of days in the specified month.
	///
	/// - Parameters:
	///   - M: The month number from 1 (January) to 12 (December).
	///   - isLeap: Whether the month's year is a leap year.
	/// - Returns: The number of days in the month, from 28 to 31.
	/// - Throws: ``CalendarError/invalidDate`` if the month is outside the closed interval [1, 12].
	static func numberOfDaysIn(month M: Int, isLeap: Bool) throws(CalendarError) -> Int {
		switch M {
		case 4, 6, 9, 11:
			return 30
		case 2:
			return isLeap ? 29 : 28
		case 1, 3, 5, 7, 8, 10, 12:
			return 31
		default:
			throw .invalidDate
		}
	}

	/// Returns `true` if the specified month and day form a valid date.
	///
	/// - Parameters:
	///   - M: The month number.
	///   - D: The day number.
	///   - isLeap: Whether the date's year is a leap year.
	/// - Returns: `true` if the month and day form a valid date; otherwise, `false`.
	static func isValid(month M: Int, day D: Int, isLeap: Bool) -> Bool {
		guard let daysInMonth = try? numberOfDaysIn(month: M, isLeap: isLeap) else { return false }
		return D >= 1 && D <= daysInMonth
	}

	/// Returns the day of the week from 1 (Sunday) to 7 (Saturday)
	/// for the specified Julian day number.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: The day of the week from 1 (Sunday) to 7 (Saturday).
	static func dayOfWeek(_ J: JulianDayNumber) -> Int {
		1 &+ ((J % 7) &+ 8) % 7
	}

	/// Returns the day of year (ordinal day) for the specified month and day, starting at 1.
	///
	/// - Parameters:
	///   - M: The month number from 1 (January) to 12 (December).
	///   - D: The day number, starting at 1.
	///   - isLeap: Whether the date's year is a leap year.
	/// - Returns: The day of year, starting at 1.
	/// - Precondition: The month and day form a valid date for the supplied leap-year status.
	static func dayOfYear(month M: Int, day D: Int, isLeap: Bool) -> Int {
		assert(isValid(month: M, day: D, isLeap: isLeap), "Month and day do not form a valid date")
		return (367 &* M &- 362) / 12 &- (M <= 2 ? 0 : isLeap ? 1 : 2) &+ D
	}

	/// Returns the month and day for the specified day of year (ordinal day).
	///
	/// - Parameters:
	///   - N: The day of year, starting at 1.
	///   - isLeap: Whether the year is a leap year.
	/// - Returns: The month and day.
	/// - Precondition: `N` is in the closed interval [1, 365] in a common year or
	///   [1, 366] in a leap year.
	static func monthAndDay(dayOfYear N: Int, isLeap: Bool) -> (month: Int, day: Int) {
		assert(N >= 1 && N <= numberOfDays(isLeap: isLeap), "Day of year is outside the closed interval [1, \(numberOfDays(isLeap: isLeap))]")
		// Days in January and February
		let janFeb = isLeap ? 60 : 59
		// March-based day of year in [0, 366) with March 1 = 0: [0, 306) for March through
		// December, [306, 366) for January and February
		let doy = N > janFeb ? N &- 1 &- janFeb : N &- 1 &+ 306
		// Month in [0, 12) with March = 0; 5 × doy + 2 < 1,830
		let mp = (5 &* doy &+ 2) / 153
		return (mp < 10 ? mp &+ 3 : mp &- 9, doy &- (153 &* mp &+ 2) / 5 &+ 1)
	}
}
