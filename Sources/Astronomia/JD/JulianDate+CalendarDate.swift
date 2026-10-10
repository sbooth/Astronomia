//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Creates a Julian Date from a calendar date.
	///
	/// The conversion is exact for times of day from 06:00. Earlier times can round by up to
	/// 2^-55 days (about 2.4 ps).
	///
	/// - Note: The Julian Date is in the calendar date's timescale.
	/// - Parameter calendarDate: The calendar date to convert.
	public init(_ calendarDate: CalendarDate) {
		self.init(uncheckedJulianDayNumber: calendarDate.julianDayNumber, fractionFromNoon: calendarDate.dayFraction - 0.5)
	}
}

extension JulianDate {
	/// Creates a Julian Date from year, month, day, and day fraction values in the specified calendar.
	///
	/// - Note: The Julian Date is in the calendar date's timescale.
	public init(year: Int, month: Int, day: Int, dayFraction: Double = 0, _ calendar: CalendarIdentifier = .julianGregorian) throws(CalendarError) {
		try self.init(CalendarDate(year: year, month: month, day: day, dayFraction: dayFraction, calendar))
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
	///
	/// The time of day is exact from midnight to 06:00 and can otherwise round by up to
	/// 2^-54 days (about 4.8 ps). A time that would round up to the following midnight is
	/// clamped to the largest day fraction below 1, so the result is always on the same
	/// calendar day as this Julian Date.
	///
	/// - Note: The calendar date is in this Julian Date's timescale.
	/// - Parameter calendar: The calendar in which to express the date.
	/// - Returns: The calendar date and time of day of this Julian Date.
	public func calendarDate(_ calendar: CalendarIdentifier) -> CalendarDate {
		CalendarDate(calendarDay: CalendarDay(julianDayNumber: julianDayNumber, calendar), uncheckedDayFraction: fractionSinceMidnight)
	}
}
