//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A hybrid calendar that uses the Julian calendar for dates on or before October 4, 1582 and the Gregorian calendar for dates on or after October 15, 1582.
public struct JulianGregorianCalendar {
	/// The Julian day number for January 1, 1 CE in the Julian calendar.
	public static let epoch = JulianCalendar.epoch

	/// Returns the Julian day number for the specified year, month, and day.
	///
	/// Dates before October 15, 1582 are interpreted in the Julian calendar and later dates in the Gregorian calendar.
	/// - note: Months less than 1 or greater than 12 roll over into adjacent years. The calendar is then chosen by comparing the normalized year and month, together with the unnormalized day, to October 15, 1582, and out-of-range days are counted forward or backward in that calendar. The nonexistent dates October 5–14, 1582 are counted forward from October 4, 1582 in the Julian calendar.
	/// - throws: ``JulianDayNumberOutOfRangeError`` if the Julian day number for the date cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFrom(year Y: Int, month M: Int, day D: Int) throws(JulianDayNumberOutOfRangeError) -> JulianDayNumber {
		try julianDayNumberFromDate((Y, M, D))
	}

	/// Returns the Julian day number for the specified date.
	///
	/// Dates before October 15, 1582 are interpreted in the Julian calendar and later dates in the Gregorian calendar.
	/// - note: Months less than 1 or greater than 12 roll over into adjacent years. The calendar is then chosen by comparing the normalized year and month, together with the unnormalized day, to October 15, 1582, and out-of-range days are counted forward or backward in that calendar. The nonexistent dates October 5–14, 1582 are counted forward from October 4, 1582 in the Julian calendar.
	/// - throws: ``JulianDayNumberOutOfRangeError`` if the Julian day number for the date cannot be represented as a ``JulianDayNumber``.
	public static func julianDayNumberFromDate(_ date: YearMonthDay) throws(JulianDayNumberOutOfRangeError) -> JulianDayNumber {
		// Normalize the month to [1, 12] so no intermediate value can overflow
		let (q, r) = date.month.flooredQuotientAndRemainder(dividingBy: 12)
		let (yc, month) = r == 0 ? (q - 1, 12) : (q, r)

		let (year, yearOverflow) = date.year.addingReportingOverflow(yc)
		guard !yearOverflow else {
			throw JulianDayNumberOutOfRangeError()
		}

		let d: YearMonthDay = (year, month, date.day)
		return try d < firstGregorianCalendarDate ? JulianCalendar.julianDayNumberFromDate(d) : GregorianCalendar.julianDayNumberFromDate(d)
	}

	/// Returns the year, month, and day for the specified Julian day number.
	///
	/// Julian day numbers less than 2,299,161 (October 15, 1582 in the Gregorian calendar) give dates in the Julian calendar and equal or greater Julian day numbers give dates in the Gregorian calendar.
	/// - note: Every ``JulianDayNumber`` value is a valid Julian day number.
	public static func dateFromJulianDayNumber(_ J: JulianDayNumber) -> YearMonthDay {
		J < GregorianCalendar.papalReform ? JulianCalendar.dateFromJulianDayNumber(J) : GregorianCalendar.dateFromJulianDayNumber(J)
	}
}

extension JulianGregorianCalendar {
	/// Returns `true` if the specified Julian day number is less than 2,299,161 (October 15, 1582 in the Gregorian calendar).
	public static func isJulian(_ J: JulianDayNumber) -> Bool {
		J < GregorianCalendar.papalReform
	}

	/// Returns `true` if the specified Julian day number is less than 1,704,987 (January 1, 45 BCE in the Julian calendar).
	public static func isProlepticJulian(_ J: JulianDayNumber) -> Bool {
		J < JulianCalendar.effective
	}
}

extension JulianGregorianCalendar {
	/// Returns `true` if the specified year is a leap year.
	public static func isLeapYear(_ Y: Int) -> Bool {
		// 1582 was not a leap year so there is no need to special-case
		Y < firstGregorianCalendarDate.year ? JulianCalendar.isLeapYear(Y) : GregorianCalendar.isLeapYear(Y)
	}
}

extension JulianGregorianCalendar {
	/// The number of months in one year.
	public static let numberOfMonthsInYear = JulianCalendar.numberOfMonthsInYear

	/// Returns the number of days in the specified year.
	/// - note: This function accounts for the Julian to Gregorian calendar changeover.
	public static func numberOfDaysInYear(_ Y: Int) -> Int {
		if Y > firstGregorianCalendarDate.year {
			return GregorianCalendar.numberOfDaysInYear(Y)
		} else if Y < firstGregorianCalendarDate.year {
			return JulianCalendar.numberOfDaysInYear(Y)
		} else {
			return 355
		}
	}

	/// Returns the number of days in the specified month and year.
	/// - note: This function accounts for the Julian to Gregorian calendar changeover.
	public static func numberOfDaysIn(month M: Int, year Y: Int) -> Int {
		if (Y, M) > (firstGregorianCalendarDate.year, firstGregorianCalendarDate.month) {
			return GregorianCalendar.numberOfDaysIn(month: M, year: Y)
		} else if (Y, M) < (firstGregorianCalendarDate.year, firstGregorianCalendarDate.month) {
			return JulianCalendar.numberOfDaysIn(month: M, year: Y)
		} else {
			return 21
		}
	}
}

extension JulianGregorianCalendar {
	/// The year, month, and day of the last valid Julian calendar date in the hybrid calendar.
	static let lastJulianCalendarDate: YearMonthDay = (year: 1582, month: 10, day: 4)

	/// The year, month, and day of the first valid Gregorian calendar date in the hybrid calendar.
	static let firstGregorianCalendarDate: YearMonthDay = (year: 1582, month: 10, day: 15)

	/// Returns `true` if the specified year, month, and day form a valid date.
	public static func isValid(year Y: Int, month M: Int, day D: Int) -> Bool {
		isValidDate((Y, M, D))
	}

	/// Returns `true` if the specified date is valid.
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
	/// Returns the day of the week from `1` (Sunday) to `7` (Saturday) for the specified Julian day number.
	public static func dayOfWeek(_ J: JulianDayNumber) -> Int {
		JulianCalendar.dayOfWeek(J)
	}
}

extension JulianGregorianCalendar {
	/// Returns the ordinal day (day of year) for the specified year, month, and day.
	/// - throws: ``JulianDayNumberOutOfRangeError`` if the Julian day number for the date cannot be represented as a ``JulianDayNumber``.
	public static func ordinalDayFrom(year Y: Int, month M: Int, day D: Int) throws(JulianDayNumberOutOfRangeError) -> Int {
		try julianDayNumberFrom(year: Y, month: M, day: D) - julianDayNumberFrom(year: Y, month: 1, day: 1) + 1
	}

	/// Returns the year, month, and day for the specified year and ordinal day.
	/// - throws: ``JulianDayNumberOutOfRangeError`` if the Julian day number for the date cannot be represented as a ``JulianDayNumber``.
	public static func dateFrom(year Y: Int, ordinalDay N: Int) throws(JulianDayNumberOutOfRangeError) -> YearMonthDay {
		try dateFromJulianDayNumber(julianDayNumberFrom(year: Y, month: 1, day: 1) + N - 1)
	}
}

extension JulianGregorianCalendar {
	/// Returns the month and day of Easter in the specified year.
	public static func easter(year Y: Int) -> (month: Int, day: Int) {
		Y > firstGregorianCalendarDate.year ? GregorianCalendar.easter(year: Y) : JulianCalendar.easter(year: Y)
	}
}
