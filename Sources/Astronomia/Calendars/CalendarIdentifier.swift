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
	///   See ``JulianGregorianCalendar/julianDayNumber(for:)`` for how out-of-range
	///   values are interpreted in the Julian-Gregorian calendar.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number, possibly outside the closed interval [1, 12].
	///   - D: The day number, possibly outside the days of the month.
	/// - Returns: The Julian day number of the date.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public func julianDayNumber(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> JulianDayNumber {
		try julianDayNumber(for: (Y, M, D))
	}

	/// Returns the Julian day number for the specified date.
	///
	/// - Note: Months less than 1 or greater than 12 roll over into adjacent years.
	///   Out-of-range days are counted forward or backward from the normalized year and month.
	///   See ``JulianGregorianCalendar/julianDayNumber(for:)`` for how out-of-range
	///   values are interpreted in the Julian-Gregorian calendar.
	/// - Parameter date: The year, month, and day, possibly out of range.
	/// - Returns: The Julian day number of the date.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public func julianDayNumber(for date: YearMonthDay) throws(CalendarError) -> JulianDayNumber {
		switch self {
		case .julian:
			return try JulianCalendar.julianDayNumber(for: date)
		case .gregorian:
			return try GregorianCalendar.julianDayNumber(for: date)
		case .julianGregorian:
			return try JulianGregorianCalendar.julianDayNumber(for: date)
		}
	}

	/// Returns the year, month, and day for the specified Julian day number.
	///
	/// - Note: Every ``JulianDayNumber`` value is a valid Julian day number.
	/// - Parameter J: The Julian day number.
	/// - Returns: A valid date in this calendar.
	public func date(julianDayNumber J: JulianDayNumber) -> YearMonthDay {
		switch self {
		case .julian:
			return JulianCalendar.date(julianDayNumber: J)
		case .gregorian:
			return GregorianCalendar.date(julianDayNumber: J)
		case .julianGregorian:
			return JulianGregorianCalendar.date(julianDayNumber: J)
		}
	}
}

extension CalendarIdentifier {
	/// Returns a valid year, month, and day for the specified year and possibly
	/// out-of-range month and day values.
	///
	/// - Note: Out-of-range values are interpreted as by
	///   ``julianDayNumber(year:month:day:)``.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number, possibly outside the closed interval [1, 12].
	///   - D: The day number, possibly outside the days of the month.
	/// - Returns: The equivalent valid date in this calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public func normalizedDate(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> YearMonthDay {
		try normalizedDate((Y, M, D))
	}

	/// Returns a valid year, month, and day for the specified year and possibly
	/// out-of-range month and day values.
	///
	/// - Note: Out-of-range values are interpreted as by ``julianDayNumber(for:)``.
	/// - Parameter date: The year, month, and day, possibly out of range.
	/// - Returns: The equivalent valid date in this calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number
	///   for the date cannot be represented as a ``JulianDayNumber``.
	public func normalizedDate(_ date: YearMonthDay) throws(CalendarError) -> YearMonthDay {
		try self.date(julianDayNumber: self.julianDayNumber(for: date))
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
	public func numberOfDays(inYear Y: Int) -> Int {
		switch self {
		case .julian:
			return JulianCalendar.numberOfDays(inYear: Y)
		case .gregorian:
			return GregorianCalendar.numberOfDays(inYear: Y)
		case .julianGregorian:
			return JulianGregorianCalendar.numberOfDays(inYear: Y)
		}
	}

	/// Returns the number of days in the specified month and year.
	///
	/// - Parameters:
	///   - M: The month number from 1 (January) to 12 (December).
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	/// - Returns: The number of days in the month.
	/// - Throws: ``CalendarError/invalidDate`` if the month is outside the closed interval [1, 12].
	public func numberOfDays(inMonth M: Int, year Y: Int) throws(CalendarError) -> Int {
		switch self {
		case .julian:
			return try JulianCalendar.numberOfDays(inMonth: M, year: Y)
		case .gregorian:
			return try GregorianCalendar.numberOfDays(inMonth: M, year: Y)
		case .julianGregorian:
			return try JulianGregorianCalendar.numberOfDays(inMonth: M, year: Y)
		}
	}
}

extension CalendarIdentifier {
	/// Returns the day of year (ordinal day) for the specified Julian day number, starting at 1.
	///
	/// - Parameter J: The Julian day number.
	/// - Returns: The day of year, from 1 to the number of days in the year.
	public func dayOfYear(julianDayNumber J: JulianDayNumber) -> Int {
		switch self {
		case .julian:
			return JulianCalendar.dayOfYear(julianDayNumber: J)
		case .gregorian:
			return GregorianCalendar.dayOfYear(julianDayNumber: J)
		case .julianGregorian:
			return JulianGregorianCalendar.dayOfYear(julianDayNumber: J)
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
	public func dayOfYear(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> Int {
		switch self {
		case .julian:
			return try JulianCalendar.dayOfYear(year: Y, month: M, day: D)
		case .gregorian:
			return try GregorianCalendar.dayOfYear(year: Y, month: M, day: D)
		case .julianGregorian:
			return try JulianGregorianCalendar.dayOfYear(year: Y, month: M, day: D)
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
	public func date(year Y: Int, dayOfYear N: Int) throws(CalendarError) -> YearMonthDay {
		switch self {
		case .julian:
			return try JulianCalendar.date(year: Y, dayOfYear: N)
		case .gregorian:
			return try GregorianCalendar.date(year: Y, dayOfYear: N)
		case .julianGregorian:
			return try JulianGregorianCalendar.date(year: Y, dayOfYear: N)
		}
	}
}

extension CalendarIdentifier {
	/// Returns the decimal year for the start of the day with the specified Julian day number.
	///
	/// The fraction is the number of whole days elapsed since January 1 divided by the number
	/// of days in the year, so January 1, 1985 is 1985.0 and July 2, 1985 is
	/// 1985 + 182/365 ≈ 1985.4986.
	///
	/// - Note: Decimal years distinguish individual days only when the year's magnitude is
	///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
	/// - Note: This is a calendar-based value, not an astronomical epoch such as a Julian or
	///   Besselian epoch.
	/// - Parameter J: The Julian day number.
	/// - Returns: The decimal year for the start of the day.
	public func decimalYear(julianDayNumber J: JulianDayNumber) -> Double {
		switch self {
		case .julian:
			return JulianCalendar.decimalYear(julianDayNumber: J)
		case .gregorian:
			return GregorianCalendar.decimalYear(julianDayNumber: J)
		case .julianGregorian:
			return JulianGregorianCalendar.decimalYear(julianDayNumber: J)
		}
	}

	/// Returns the Julian day number of the day containing the specified decimal year.
	///
	/// - Note: Decimal years distinguish individual days only when the year's magnitude is
	///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
	/// - Parameter decimalYear: The decimal year. Year number 0 is 1 BCE.
	/// - Returns: The Julian day number of the day containing `decimalYear`.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the decimal year is not finite.
	///   - ``CalendarError/invalidDecimalYear`` if the year cannot be represented as an `Int`.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number for the
	///     day cannot be represented as a ``JulianDayNumber``.
	public func julianDayNumber(decimalYear: Double) throws(CalendarError) -> JulianDayNumber {
		switch self {
		case .julian:
			return try JulianCalendar.julianDayNumber(decimalYear: decimalYear)
		case .gregorian:
			return try GregorianCalendar.julianDayNumber(decimalYear: decimalYear)
		case .julianGregorian:
			return try JulianGregorianCalendar.julianDayNumber(decimalYear: decimalYear)
		}
	}

	/// Returns the decimal year for the start of the specified year, month, and day.
	///
	/// - Note: Decimal years distinguish individual days only when the year's magnitude is
	///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
	/// - Parameters:
	///   - Y: The arithmetic year number. Year number 0 is 1 BCE.
	///   - M: The month number from 1 (January) to 12 (December).
	///   - D: The day number, starting at 1.
	/// - Returns: The decimal year for the start of the day.
	/// - Throws: ``CalendarError/invalidDate`` if the year, month, and day do not form
	///   a valid date.
	public func decimalYear(year Y: Int, month M: Int, day D: Int) throws(CalendarError) -> Double {
		switch self {
		case .julian:
			return try JulianCalendar.decimalYear(year: Y, month: M, day: D)
		case .gregorian:
			return try GregorianCalendar.decimalYear(year: Y, month: M, day: D)
		case .julianGregorian:
			return try JulianGregorianCalendar.decimalYear(year: Y, month: M, day: D)
		}
	}

	/// Returns the year, month, and day containing the specified decimal year.
	///
	/// - Note: Decimal years distinguish individual days only when the year's magnitude is
	///   small enough for `Double` to resolve a fraction of a day, roughly < 2^43.
	/// - Parameter decimalYear: The decimal year. Year number 0 is 1 BCE.
	/// - Returns: The year, month, and day.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the decimal year is not finite.
	///   - ``CalendarError/invalidDecimalYear`` if the year cannot be represented as an `Int`.
	public func date(decimalYear: Double) throws(CalendarError) -> YearMonthDay {
		switch self {
		case .julian:
			return try JulianCalendar.date(decimalYear: decimalYear)
		case .gregorian:
			return try GregorianCalendar.date(decimalYear: decimalYear)
		case .julianGregorian:
			return try JulianGregorianCalendar.date(decimalYear: decimalYear)
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
		isValid((Y, M, D))
	}

	/// Returns `true` if the specified date is valid.
	///
	/// - Parameter date: The year, month, and day to check.
	/// - Returns: `true` if `date` is a valid date in this calendar; otherwise, `false`.
	public func isValid(_ date: YearMonthDay) -> Bool {
		switch self {
		case .julian:
			return JulianCalendar.isValid(date)
		case .gregorian:
			return GregorianCalendar.isValid(date)
		case .julianGregorian:
			return JulianGregorianCalendar.isValid(date)
		}
	}
}
