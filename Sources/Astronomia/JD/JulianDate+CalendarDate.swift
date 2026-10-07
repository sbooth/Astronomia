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
		self.init(uncheckedJulianDayNumber: calendarDate.julianDayNumber, fractionFromNoon: calendarDate.dayFraction - 0.5)
	}
}

extension JulianDate {
	/// The Julian Date as a calendar date in the Julian-Gregorian calendar.
	///
	/// The Julian-Gregorian calendar is the conventional choice in astronomy.
	/// Use ``calendarDate(_:)`` for another calendar.
	///
	/// - Note: The calendar date is in this Julian Date's timescale.
	public var calendarDate: CalendarDate {
		calendarDate(.julianGregorian)
	}

	/// Returns the Julian Date as a calendar date in the specified calendar.
	/// - Note: The calendar date is in this Julian Date's timescale.
	public func calendarDate(_ calendar: CalendarIdentifier) -> CalendarDate {
		CalendarDate(calendarDay: CalendarDay(julianDayNumber: julianDayNumber, calendar), uncheckedDayFraction: fractionSinceMidnight)
	}
}
