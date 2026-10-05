//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Creates a Julian Date from a calendar date.
	///
	/// The day with Julian day number `J` begins at midnight `J − 0.5`, so the conversion is exact:
	/// the calendar date's day fraction becomes this Julian Date's day fraction unchanged.
	///
	/// Neither type records a timescale; the Julian Date is in the calendar date's timescale.
	///
	/// - precondition: The magnitude of the calendar date's Julian day number is less than 2^51.
	public init(_ calendarDate: CalendarDate) {
		guard let date = Self(validatingCalendarDate: calendarDate) else {
			preconditionFailure("Julian day number \(calendarDate.julianDayNumber) is outside the supported range")
		}
		self = date
	}

	/// Creates a Julian Date from a calendar date, returning `nil` if the magnitude of its Julian day number is not less than 2^51.
	public init?(validatingCalendarDate calendarDate: CalendarDate) {
		// Double(J) is exact for |J| < 2^53 and rounds monotonically beyond, so the range check in
		// the checked initializer is correct for any width of JulianDayNumber, including 32-bit Int.
		self.init(dayNumber: Double(calendarDate.julianDayNumber), offset: calendarDate.dayFraction)
	}
}

extension JulianDate {
	/// The Julian Date as a calendar date in the Julian-Gregorian calendar.
	///
	/// The Julian-Gregorian calendar is the conventional choice in astronomy. Use ``calendarDate(_:)`` for another calendar.
	///
	/// Neither type records a timescale; the calendar date is in this Julian Date's timescale.
	///
	/// - throws: `CalendarDateError.julianDayNumberOutOfRange` if the Julian day number of the day containing this Julian Date cannot be represented as a `JulianDayNumber`.
	public var calendarDate: CalendarDate {
		get throws(CalendarDateError) {
			try calendarDate(.julianGregorian)
		}
	}

	/// Returns the Julian Date as a calendar date in the specified calendar.
	///
	/// The conversion is exact: this Julian Date's day fraction becomes the calendar date's day fraction unchanged.
	///
	/// Neither type records a timescale; the calendar date is in this Julian Date's timescale.
	///
	/// - throws: `CalendarDateError.julianDayNumberOutOfRange` if the Julian day number of the day containing this Julian Date cannot be represented as a `JulianDayNumber`.
	///   This can happen only when `JulianDayNumber` is narrower than 52 bits, e.g. on 32-bit platforms.
	public func calendarDate(_ calendar: CalendarIdentifier) throws(CalendarDateError) -> CalendarDate {
		// Exact: midnight is a half-integer with |midnight + 0.5| < 2^51.
		guard let J = JulianDayNumber(exactly: midnight + 0.5) else {
			throw .julianDayNumberOutOfRange
		}
		return try CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar), dayFraction: dayFraction)
	}
}
