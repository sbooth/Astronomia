//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Creates a Julian Date from a calendar date.
	/// - Note: The Julian Date is in the calendar date's timescale.
	public init(_ calendarDate: CalendarDate) {
		self.init(uncheckedJDN: calendarDate.julianDayNumber, fraction: calendarDate.dayFraction - 0.5)
	}
}

extension JulianDate {
	/// The Julian Date as a calendar date in the Julian-Gregorian calendar.
	///
	/// The Julian-Gregorian calendar is the conventional choice in astronomy.
	/// Use ``calendarDate(_:)`` for another calendar.
	///
	/// - Note: The calendar date is in this Julian Date's timescale.
	/// - Throws: ``CalendarDateError/julianDayNumberOutOfRange`` if the Julian day number
	///   of the day containing this Julian Date cannot be represented as a ``JulianDayNumber``.
	public var calendarDate: CalendarDate {
		get throws(CalendarDateError) {
			try calendarDate(.julianGregorian)
		}
	}

	/// Returns the Julian Date as a calendar date in the specified calendar.
	/// - Note: The calendar date is in this Julian Date's timescale.
	/// - Throws: ``CalendarDateError/julianDayNumberOutOfRange`` if the Julian day number
	///   of the day containing this Julian Date cannot be represented as a ``JulianDayNumber``.
	public func calendarDate(_ calendar: CalendarIdentifier) throws(CalendarDateError) -> CalendarDate {
		var J = jdn
		var dayFraction = fraction + 0.5
		if dayFraction == 1 {
			let (next, overflow) = J.addingReportingOverflow(1)
			guard !overflow else {
				throw .julianDayNumberOutOfRange
			}
			J = next
			dayFraction = 0
		}
		return try CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar), dayFraction: dayFraction)
	}
}
