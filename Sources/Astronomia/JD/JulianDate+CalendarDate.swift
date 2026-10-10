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
	/// Creates a Julian Date for the specified year, month, and day in the given calendar
	/// with the specified day fraction.
	///
	/// - Note: The Julian Date is in the calendar date's timescale.
	/// - Parameters:
	///   - year: The arithmetic year number. Year number 0 is 1 BCE.
	///   - month: The month number from 1 (January) to 12 (December).
	///   - day: The day number, starting at 1.
	///   - dayFraction: The fraction of the day elapsed since midnight.
	///   - calendar: The calendar the year, month, and day belong to.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the day fraction is not finite.
	///   - ``CalendarError/invalidDayFraction`` if the day fraction is outside
	///     the right-open interval [0, 1).
	///   - ``CalendarError/invalidDate`` if the year, month, and day do not form a valid
	///     date in the specified calendar.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the year, month, and day form
	///     a valid date, but its Julian day number cannot be represented as a
	///     ``JulianDayNumber``.
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
