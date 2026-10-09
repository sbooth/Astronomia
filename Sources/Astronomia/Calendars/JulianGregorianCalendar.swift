//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A hybrid calendar that uses the Julian calendar for dates on or before October 4, 1582
/// and the Gregorian calendar for dates on or after October 15, 1582.
///
/// The dates October 5-14, 1582 do not exist, so 1582 has 355 days and October 1582 has
/// 21 days. Dates before January 1, 45 BCE use the proleptic Julian calendar.
public struct JulianGregorianCalendar {
	/// The Julian day number for January 1, 1 CE in the Julian calendar.
	public static let epoch = JulianCalendar.epoch

	/// Returns the Julian day number for the specified year, month, and day.
	///
	/// Dates before October 15, 1582 are interpreted in the Julian calendar and later
	/// dates in the Gregorian calendar.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years. The
	///   calendar is then chosen by comparing the normalized year and month, together with
	///   the unnormalized day, to October 15, 1582, and out-of-range days are counted forward
	///   or backward in that calendar. The nonexistent dates October 5-14, 1582 are counted
	///   forward from October 4, 1582 in the Julian calendar, so they denote October 15-24,
	///   1582 in the Gregorian calendar.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number, possibly outside the closed interval [1, 12].
	///   - D: The day number, possibly outside the days of the month.
	/// - Returns: The Julian day number of the date.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> JulianDayNumber {
		try julianDayNumberFromDate((Y, M, D))
	}

	/// Returns the Julian day number for the specified date.
	///
	/// Dates before October 15, 1582 are interpreted in the Julian calendar and later
	/// dates in the Gregorian calendar.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years. The
	///   calendar is then chosen by comparing the normalized year and month, together with
	///   the unnormalized day, to October 15, 1582, and out-of-range days are counted forward
	///   or backward in that calendar. The nonexistent dates October 5-14, 1582 are counted
	///   forward from October 4, 1582 in the Julian calendar, so they denote October 15-24,
	///   1582 in the Gregorian calendar.
	/// - Parameter date: The year, month, and day, possibly out of range.
	/// - Returns: The Julian day number of the date.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFromDate(_ date: YearMonthDay) throws(CalendarError) -> JulianDayNumber {
		// Normalize the month to [1, 12] so no intermediate value can overflow
		let (q, r) = date.month.flooredQuotientAndRemainder(dividingBy: 12)
		let (yc, month) = r == 0 ? (q - 1, 12) : (q, r)

		let (year, yearOverflow) = date.year.addingReportingOverflow(yc)
		guard !yearOverflow else { throw .julianDayNumberNotRepresentable }

		let d: YearMonthDay = (year, month, date.day)
		return try d < firstGregorianCalendarDate ? JulianCalendar.julianDayNumberFromDate(d) : GregorianCalendar.julianDayNumberFromDate(d)
	}

	/// Returns the year, month, and day for the specified Julian day number.
	///
	/// Julian day numbers less than 2,299,161 (October 15, 1582 in the Gregorian calendar)
	/// give dates in the Julian calendar and equal or greater Julian day numbers
	/// give dates in the Gregorian calendar.
	///
	/// - Note: Every ``JulianDayNumber`` value is a valid Julian day number.
	/// - Parameter J: The Julian day number.
	/// - Returns: A valid date in the Julian-Gregorian calendar.
	public static func dateFromJulianDayNumber(_ J: JulianDayNumber) -> YearMonthDay {
		J < GregorianCalendar.papalReform ? JulianCalendar.dateFromJulianDayNumber(J) : GregorianCalendar.dateFromJulianDayNumber(J)
	}
}

extension JulianGregorianCalendar {
	/// Returns `true` if the specified Julian day number is less than 2,299,161
	/// (October 15, 1582 in the Gregorian calendar), so its date is in the Julian calendar.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: `true` if the date of `J` is in the Julian calendar; otherwise, `false`.
	public static func isJulian(_ J: JulianDayNumber) -> Bool {
		J < GregorianCalendar.papalReform
	}

	/// Returns `true` if the specified Julian day number is less than 1,704,987
	/// (January 1, 45 BCE in the Julian calendar), so its date is in the proleptic Julian
	/// calendar.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: `true` if `J` is before January 1, 45 BCE in the Julian calendar; otherwise,
	///   `false`.
	public static func isProlepticJulian(_ J: JulianDayNumber) -> Bool {
		J < JulianCalendar.effective
	}
}

extension JulianGregorianCalendar {
	/// Returns `true` if the specified year is a leap year.
	///
	/// Years before 1582 follow the Julian rule and later years the Gregorian rule.
	///
	/// - Parameter Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: `true` if `Y` is a leap year in the Julian-Gregorian calendar; otherwise,
	///   `false`.
	public static func isLeapYear(_ Y: Int) -> Bool {
		// 1582 was not a leap year so there is no need to special-case
		Y < firstGregorianCalendarDate.year ? JulianCalendar.isLeapYear(Y) : GregorianCalendar.isLeapYear(Y)
	}
}

extension JulianGregorianCalendar {
	/// The number of months in one year.
	public static let numberOfMonthsInYear = JulianCalendar.numberOfMonthsInYear

	/// The number of days in the year 1582; October 5-14 do not exist.
	static let numberOfDaysInChangeoverYear: Int = 355

	/// Returns the number of days in the specified year.
	///
	/// - Note: This function accounts for the Julian to Gregorian calendar changeover, so 1582
	///   has 355 days.
	/// - Parameter Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The number of days in year `Y`: 365 or 366, or 355 for 1582.
	public static func numberOfDaysInYear(_ Y: Int) -> Int {
		if Y > firstGregorianCalendarDate.year {
			return GregorianCalendar.numberOfDaysInYear(Y)
		} else if Y < firstGregorianCalendarDate.year {
			return JulianCalendar.numberOfDaysInYear(Y)
		} else {
			return numberOfDaysInChangeoverYear
		}
	}

	/// The number of days in October 1582; October 5-14 do not exist.
	static let numberOfDaysInChangeoverMonth: Int = 21

	/// Returns the number of days in the specified month and year.
	///
	/// - Note: This function accounts for the Julian to Gregorian calendar changeover, so
	///   October 1582 has 21 days.
	/// - Parameters:
	///   - M: The month number from 1 (January) to 12 (December).
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The number of days in the month: from 28 to 31, or 21 for October 1582.
	/// - Throws: ``CalendarError/invalidDate`` if the month is outside the closed interval [1, 12].
	public static func numberOfDaysIn(month M: Int, year Y: Int) throws(CalendarError) -> Int {
		if (Y, M) > (firstGregorianCalendarDate.year, firstGregorianCalendarDate.month) {
			return try GregorianCalendar.numberOfDaysIn(month: M, year: Y)
		} else if (Y, M) < (firstGregorianCalendarDate.year, firstGregorianCalendarDate.month) {
			return try JulianCalendar.numberOfDaysIn(month: M, year: Y)
		} else {
			return numberOfDaysInChangeoverMonth
		}
	}
}

extension JulianGregorianCalendar {
	/// The year, month, and day of the last valid Julian calendar date in the hybrid calendar.
	static let lastJulianCalendarDate: YearMonthDay = (year: 1582, month: 10, day: 4)

	/// The year, month, and day of the first valid Gregorian calendar date in the hybrid
	/// calendar.
	static let firstGregorianCalendarDate: YearMonthDay = (year: 1582, month: 10, day: 15)

	/// Returns `true` if the specified year, month, and day form a valid date.
	///
	/// The dates October 5-14, 1582 are not valid.
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number.
	///   - D: The day number.
	/// - Returns: `true` if the year, month, and day form a valid date in the Julian-Gregorian
	///   calendar; otherwise, `false`.
	public static func isValid(year Y: Int, month M: Int, day D: Int) -> Bool {
		isValidDate((Y, M, D))
	}

	/// Returns `true` if the specified date is valid.
	///
	/// The dates October 5-14, 1582 are not valid.
	///
	/// - Parameter date: The year, month, and day to check.
	/// - Returns: `true` if `date` is a valid date in the Julian-Gregorian calendar; otherwise,
	///   `false`.
	public static func isValidDate(_ date: YearMonthDay) -> Bool {
		if date >= firstGregorianCalendarDate {
			return GregorianCalendar.isValidDate(date)
		} else if date <= lastJulianCalendarDate {
			return JulianCalendar.isValidDate(date)
		} else {
			return false
		}
	}
}

extension JulianGregorianCalendar {
	/// Returns the day of the week from 1 (Sunday) to 7 (Saturday)
	/// for the specified Julian day number.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: The day of the week from 1 (Sunday) to 7 (Saturday).
	public static func dayOfWeek(_ J: JulianDayNumber) -> Int {
		JulianCalendar.dayOfWeek(J)
	}
}

extension JulianGregorianCalendar {
	/// The Julian day number of January 1, 1582 in the Julian calendar.
	static let firstDayOfChangeoverYear: JulianDayNumber = 2_298_884

	/// The Julian day numbers of the days in 1582.
	static let changeoverYear: Range<JulianDayNumber> = firstDayOfChangeoverYear ..< firstDayOfChangeoverYear + numberOfDaysInChangeoverYear

	/// Returns the day of year (ordinal day) for the specified Julian day number, starting at 1.
	///
	/// In 1582, days are counted continuously across the changeover, so October 15, 1582 is
	/// day 278.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: The day of year, from 1 to the number of days in the year.
	public static func dayOfYearFromJulianDayNumber(_ J: JulianDayNumber) -> Int {
		if changeoverYear.contains(J) {
			return J - firstDayOfChangeoverYear + 1
		}
		return J < GregorianCalendar.papalReform ? JulianCalendar.dayOfYearFromJulianDayNumber(J) : GregorianCalendar.dayOfYearFromJulianDayNumber(J)
	}

	/// Returns the day of year (ordinal day) for the specified year, month, and day,
	/// starting at 1.
	///
	/// In 1582, days are counted continuously across the changeover, so October 15, 1582 is
	/// day 278.
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number from 1 (January) to 12 (December).
	///   - D: The day number, starting at 1.
	/// - Returns: The day of year, from 1 to the number of days in the year.
	/// - Throws: ``CalendarError/invalidDate`` if the year, month, and day do not form
	///   a valid date.
	public static func dayOfYearFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> Int {
		if Y < firstGregorianCalendarDate.year {
			return try JulianCalendar.dayOfYearFrom(year: Y, month: M, day: D)
		} else if Y > firstGregorianCalendarDate.year {
			return try GregorianCalendar.dayOfYearFrom(year: Y, month: M, day: D)
		}
		guard isValid(year: Y, month: M, day: D) else { throw .invalidDate }
		// A valid date in 1582 has a small JDN, so neither the conversion nor the subtraction can fail
		return try! julianDayNumberFrom(year: Y, month: M, day: D) - firstDayOfChangeoverYear + 1
	}

	/// Returns the year, month, and day for the specified year and day of year (ordinal day).
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - N: The day of year, starting at 1. In 1582 it is at most 355.
	/// - Returns: The year, month, and day in the Julian-Gregorian calendar.
	/// - Throws: ``CalendarError/invalidDate`` if the year and day of year do not form
	///   a valid date.
	public static func dateFrom(year Y: Int, dayOfYear N: Int) throws(CalendarError) -> YearMonthDay {
		if Y < firstGregorianCalendarDate.year {
			return try JulianCalendar.dateFrom(year: Y, dayOfYear: N)
		} else if Y > firstGregorianCalendarDate.year {
			return try GregorianCalendar.dateFrom(year: Y, dayOfYear: N)
		}
		guard N >= 1, N <= numberOfDaysInChangeoverYear else { throw .invalidDate }
		return dateFromJulianDayNumber(firstDayOfChangeoverYear + N - 1)
	}
}

extension JulianGregorianCalendar {
	/// Returns the month and day of Easter in the specified year.
	///
	/// - Parameter Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The month (3 or 4) and day of Easter Sunday, computed with the Julian
	///   computus and expressed in the Julian calendar for 1582 and earlier, and with the
	///   Gregorian computus in the Gregorian calendar for later years.
	public static func easter(year Y: Int) -> (month: Int, day: Int) {
		Y > firstGregorianCalendarDate.year ? GregorianCalendar.easter(year: Y) : JulianCalendar.easter(year: Y)
	}
}
