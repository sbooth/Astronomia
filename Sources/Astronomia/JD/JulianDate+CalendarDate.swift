//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Creates a Julian Date from a calendar date.
	///
	/// The day fraction is shifted from midnight to noon, which rounds by at most 2^-55 days. Julian day
	/// numbers beyond 2^53 in magnitude round to the nearest representable integer.
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
		guard var J = JulianDayNumber(exactly: day) else {
			throw .julianDayNumberOutOfRange
		}
		var dayFraction = fraction + 0.5 // Exact sum in [0, 1); rounds into [0, 1].
		if dayFraction == 1 {
			// Increment as an integer: above 2^53, day + 1 is not representable as a Double.
			let (nextDay, overflow) = J.addingReportingOverflow(1)
			guard !overflow else {
				throw .julianDayNumberOutOfRange
			}
			J = nextDay
			dayFraction = 0
		}
		return try CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar), dayFraction: dayFraction)
	}
}
