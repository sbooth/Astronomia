//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Identifies the calendar a year, month, and day belong to.
public enum CalendarIdentifier: Hashable, Sendable, Codable, CaseIterable {
	/// The Julian calendar.
	case julian
	/// The Gregorian calendar.
	case gregorian
	/// A hybrid calendar that uses the Julian calendar for dates on or before October 4, 1582 and the Gregorian calendar for dates on or after October 15, 1582.
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
	/// Returns the Julian day number for the specified date.
	/// - note: Months less than 1 or greater than 12 roll over into adjacent years. Out-of-range days are counted forward or backward from the normalized year and month.
	/// - throws: `JulianDayNumberOutOfRangeError` if the Julian day number for the date cannot be represented as an `Int`.
	public func julianDayNumberFrom(year Y: Int, month M: Int, day D: Int) throws(JulianDayNumberOutOfRangeError) -> JulianDayNumber {
		try julianDayNumberFromDate((Y, M, D))
	}

	/// Returns the Julian day number for the specified date.
	/// - note: Months less than 1 or greater than 12 roll over into adjacent years. Out-of-range days are counted forward or backward from the normalized year and month.
	/// - throws: `JulianDayNumberOutOfRangeError` if the Julian day number for the date cannot be represented as an `Int`.
	public func julianDayNumberFromDate(_ date: YearMonthDay) throws(JulianDayNumberOutOfRangeError) -> JulianDayNumber {
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
	/// - note: Every `Int` value is a valid Julian day number.
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
	/// Returns a valid year, month, and day for the specified year and possibly out-of-range month and day values.
	/// - throws: `JulianDayNumberOutOfRangeError` if the Julian day number for the date cannot be represented as an `Int`.
	public func normalizedDateFrom(year Y: Int, month M: Int, day D: Int) throws(JulianDayNumberOutOfRangeError) -> YearMonthDay {
		try normalizedDate((Y, M, D))
	}

	/// Returns a valid year, month, and day for the specified year and possibly out-of-range month and day values.
	/// - throws: `JulianDayNumberOutOfRangeError` if the Julian day number for the date cannot be represented as an `Int`.
	public func normalizedDate(_ date: YearMonthDay) throws(JulianDayNumberOutOfRangeError) -> YearMonthDay {
		try dateFromJulianDayNumber(julianDayNumberFromDate(date))
	}
}

extension CalendarIdentifier {
	/// Returns `true` if the specified year is a leap year.
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
	public func numberOfDaysIn(month M: Int, year Y: Int) -> Int {
		switch self {
		case .julian:
			return JulianCalendar.numberOfDaysIn(month: M, year: Y)
		case .gregorian:
			return GregorianCalendar.numberOfDaysIn(month: M, year: Y)
		case .julianGregorian:
			return JulianGregorianCalendar.numberOfDaysIn(month: M, year: Y)
		}
	}
}

extension CalendarIdentifier {
	/// Returns `true` if the specified year, month, and day form a valid date.
	public func isValid(year Y: Int, month M: Int, day D: Int) -> Bool {
		isValidDate((Y, M, D))
	}

	/// Returns `true` if the specified date is valid.
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
