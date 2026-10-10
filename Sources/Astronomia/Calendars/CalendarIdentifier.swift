//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Identifies the calendar a year, month, and day belong to.
///
/// Each case forwards to the static functions of ``JulianCalendar``, ``GregorianCalendar``, or
/// ``JulianGregorianCalendar``.
public enum CalendarIdentifier: Hashable, Sendable, Codable, CaseIterable {
	/// The Julian calendar.
	case julian
	/// The Gregorian calendar.
	case gregorian
	/// A hybrid calendar that uses the Julian calendar for dates on or before October 4, 1582
	/// and the Gregorian calendar for dates on or after October 15, 1582.
	case julianGregorian
}

extension CalendarIdentifier {
	/// A human-readable name for the calendar.
	public var name: String {
		switch self {
		case .julian:
			return "Julian"
		case .gregorian:
			return "Gregorian"
		case .julianGregorian:
			return "Julian-Gregorian"
		}
	}
}

extension CalendarIdentifier {
	/// Returns the Julian day number for the specified year, month, and day.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years.
	///   Out-of-range days are counted forward or backward from the normalized year and month.
	///   See ``JulianGregorianCalendar/julianDayNumberFromDate(_:)`` for how out-of-range
	///   values are interpreted in the Julian-Gregorian calendar.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number, possibly outside the closed interval [1, 12].
	///   - D: The day number, possibly outside the days of the month.
	/// - Returns: The Julian day number of the date.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public func julianDayNumberFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> JulianDayNumber {
		try julianDayNumberFromDate((Y, M, D))
	}

	/// Returns the Julian day number for the specified date.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years.
	///   Out-of-range days are counted forward or backward from the normalized year and month.
	///   See ``JulianGregorianCalendar/julianDayNumberFromDate(_:)`` for how out-of-range
	///   values are interpreted in the Julian-Gregorian calendar.
	/// - Parameter date: The year, month, and day, possibly out of range.
	/// - Returns: The Julian day number of the date.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public func julianDayNumberFromDate(_ date: YearMonthDay) throws(CalendarError) -> JulianDayNumber {
		switch self {
		case .julian:
			return try JulianCalendar.julianDayNumberFromDate(date)
		case .gregorian:
			return try GregorianCalendar.julianDayNumberFromDate(date)
		case .julianGregorian:
			return try JulianGregorianCalendar.julianDayNumberFromDate(date)
		}
	}

	/// Returns the year, month, and day for the specified Julian day number.
	///
	/// - Note: Every ``JulianDayNumber`` value is a valid Julian day number.
	/// - Parameter J: The Julian day number.
	/// - Returns: A valid date in this calendar.
	public func dateFromJulianDayNumber(_ J: JulianDayNumber) -> YearMonthDay {
		switch self {
		case .julian:
			return JulianCalendar.dateFromJulianDayNumber(J)
		case .gregorian:
			return GregorianCalendar.dateFromJulianDayNumber(J)
		case .julianGregorian:
			return JulianGregorianCalendar.dateFromJulianDayNumber(J)
		}
	}
}

extension CalendarIdentifier {
	/// Returns a valid year, month, and day for the specified year and possibly
	/// out-of-range month and day values.
	///
	/// - Note: Out-of-range values are interpreted as by
	///   ``julianDayNumberFrom(year:month:day:)``.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number, possibly outside the closed interval [1, 12].
	///   - D: The day number, possibly outside the days of the month.
	/// - Returns: The equivalent valid date in this calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public func normalizedDateFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> YearMonthDay {
		try normalizedDate((Y, M, D))
	}

	/// Returns a valid year, month, and day for the specified year and possibly
	/// out-of-range month and day values.
	///
	/// - Note: Out-of-range values are interpreted as by ``julianDayNumberFromDate(_:)``.
	/// - Parameter date: The year, month, and day, possibly out of range.
	/// - Returns: The equivalent valid date in this calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public func normalizedDate(_ date: YearMonthDay) throws(CalendarError) -> YearMonthDay {
		try dateFromJulianDayNumber(julianDayNumberFromDate(date))
	}
}

extension CalendarIdentifier {
	/// Returns `true` if the specified year is a leap year.
	///
	/// - Parameter Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: `true` if `Y` is a leap year in this calendar; otherwise, `false`.
	public func isLeapYear(_ Y: Int) -> Bool {
		switch self {
		case .julian:
			return JulianCalendar.isLeapYear(Y)
		case .gregorian:
			return GregorianCalendar.isLeapYear(Y)
		case .julianGregorian:
			return JulianGregorianCalendar.isLeapYear(Y)
		}
	}
}

extension CalendarIdentifier {
	/// Returns the number of days in the specified year.
	///
	/// - Parameter Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The number of days in year `Y`.
	public func numberOfDaysInYear(_ Y: Int) -> Int {
		switch self {
		case .julian:
			return JulianCalendar.numberOfDaysInYear(Y)
		case .gregorian:
			return GregorianCalendar.numberOfDaysInYear(Y)
		case .julianGregorian:
			return JulianGregorianCalendar.numberOfDaysInYear(Y)
		}
	}

	/// Returns the number of days in the specified month and year.
	///
	/// - Parameters:
	///   - M: The month number from 1 (January) to 12 (December).
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The number of days in the month.
	/// - Throws: ``CalendarError/invalidDate`` if the month is outside the closed interval [1, 12].
	public func numberOfDaysIn(month M: Int, year Y: Int) throws(CalendarError) -> Int {
		switch self {
		case .julian:
			return try JulianCalendar.numberOfDaysIn(month: M, year: Y)
		case .gregorian:
			return try GregorianCalendar.numberOfDaysIn(month: M, year: Y)
		case .julianGregorian:
			return try JulianGregorianCalendar.numberOfDaysIn(month: M, year: Y)
		}
	}
}

extension CalendarIdentifier {
	/// Returns the day of year (ordinal day) for the specified Julian day number, starting at 1.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: The day of year, from 1 to the number of days in the year.
	public func dayOfYearFromJulianDayNumber(_ J: JulianDayNumber) -> Int {
		switch self {
		case .julian:
			return JulianCalendar.dayOfYearFromJulianDayNumber(J)
		case .gregorian:
			return GregorianCalendar.dayOfYearFromJulianDayNumber(J)
		case .julianGregorian:
			return JulianGregorianCalendar.dayOfYearFromJulianDayNumber(J)
		}
	}

	/// Returns the day of year (ordinal day) for the specified year, month, and day,
	/// starting at 1.
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number from 1 (January) to 12 (December).
	///   - D: The day number, starting at 1.
	/// - Returns: The day of year, from 1 to the number of days in the year.
	/// - Throws: ``CalendarError/invalidDate`` if the year, month, and day do not form
	///   a valid date.
	public func dayOfYearFrom(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> Int {
		switch self {
		case .julian:
			return try JulianCalendar.dayOfYearFrom(year: Y, month: M, day: D)
		case .gregorian:
			return try GregorianCalendar.dayOfYearFrom(year: Y, month: M, day: D)
		case .julianGregorian:
			return try JulianGregorianCalendar.dayOfYearFrom(year: Y, month: M, day: D)
		}
	}

	/// Returns the year, month, and day for the specified year and day of year (ordinal day).
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - N: The day of year, starting at 1.
	/// - Returns: The year, month, and day in this calendar.
	/// - Throws: ``CalendarError/invalidDate`` if the year and day of year do not form
	///   a valid date.
	public func dateFrom(year Y: Int, dayOfYear N: Int) throws(CalendarError) -> YearMonthDay {
		switch self {
		case .julian:
			return try JulianCalendar.dateFrom(year: Y, dayOfYear: N)
		case .gregorian:
			return try GregorianCalendar.dateFrom(year: Y, dayOfYear: N)
		case .julianGregorian:
			return try JulianGregorianCalendar.dateFrom(year: Y, dayOfYear: N)
		}
	}
}

extension CalendarIdentifier {
	/// Returns `true` if the specified year, month, and day form a valid date.
	///
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number.
	///   - D: The day number.
	/// - Returns: `true` if the year, month, and day form a valid date in this calendar; otherwise,
	///   `false`.
	public func isValid(year Y: Int, month M: Int, day D: Int) -> Bool {
		isValidDate((Y, M, D))
	}

	/// Returns `true` if the specified date is valid.
	///
	/// - Parameter date: The year, month, and day to check.
	/// - Returns: `true` if `date` is a valid date in this calendar; otherwise, `false`.
	public func isValidDate(_ date: YearMonthDay) -> Bool {
		switch self {
		case .julian:
			return JulianCalendar.isValidDate(date)
		case .gregorian:
			return GregorianCalendar.isValidDate(date)
		case .julianGregorian:
			return JulianGregorianCalendar.isValidDate(date)
		}
	}
}
