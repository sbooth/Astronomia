//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Creates a Julian Date from a calendar date.
	///
	/// The day fraction is shifted from midnight to noon, which rounds by at most 2^-55 days.
	///
	/// Neither type records a timescale; the Julian Date is in the calendar date's timescale.
	public init(_ calendarDate: CalendarDate) {
		self.init(uncheckedDay: Double(calendarDate.julianDayNumber), fraction: calendarDate.dayFraction - 0.5)
	}
}

extension JulianDate {
	/// The Julian Date as a calendar date in the Julian-Gregorian calendar.
	///
	/// The Julian-Gregorian calendar is the conventional choice in astronomy.
	/// Use ``calendarDate(_:)`` for another calendar.
	///
	/// Neither type records a timescale; the calendar date is in this Julian Date's timescale.
	///
	/// - Throws: ``CalendarDateError/julianDayNumberOutOfRange`` if the Julian day number
	///   of the day containing this Julian Date cannot be represented as a ``JulianDayNumber``.
	public var calendarDate: CalendarDate {
		get throws(CalendarDateError) {
			try calendarDate(.julianGregorian)
		}
	}

	/// Returns the Julian Date as a calendar date in the specified calendar.
	///
	/// The day fraction is shifted from noon to midnight, which rounds by at most 2^-54 days.
	/// An instant within that distance of the following midnight becomes
	/// midnight of the following day.
	///
	/// Neither type records a timescale; the calendar date is in this Julian Date's timescale.
	///
	/// - Throws: ``CalendarDateError/julianDayNumberOutOfRange`` if the Julian day number
	///   of the day containing this Julian Date cannot be represented as a ``JulianDayNumber``.
	public func calendarDate(_ calendar: CalendarIdentifier) throws(CalendarDateError) -> CalendarDate {
		var day = self.day
		var dayFraction = fraction + 0.5 // [0, 1]; may round up to 1.
		if dayFraction == 1 {
			day += 1
			dayFraction = 0
		}
		guard let J = JulianDayNumber(exactly: day) else {
			throw .julianDayNumberOutOfRange
		}
		return try CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar), dayFraction: dayFraction)
	}
}
