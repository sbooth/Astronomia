//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Creates a Julian Date from a timescale-agnostic decimal year in the given calendar.
	///
	/// The fraction of the decimal year is the number of days elapsed since midnight on
	/// January 1 divided by the number of days in the year, so 1985.5 in the
	/// Julian-Gregorian calendar is 182.5 days after the start of 1985, which is noon on
	/// July 2, 1985.
	///
	/// This is equivalent to creating a ``CalendarDate`` with
	/// ``CalendarDate/init(decimalYear:calendar:)`` and passing it to ``init(_:)``. Errors are
	/// ``CalendarError`` values, not ``JulianDateError`` values, because they describe an
	/// invalid decimal year.
	///
	/// - Note: The Julian Date is in the timescale the decimal year was expressed in.
	/// - Note: The resolution of a decimal year depends on the year's magnitude.
	/// - Note: A decimal year is calendar-based, not an astronomical epoch. To create a
	///   Julian Date from a Julian or Besselian epoch, use ``init(julianEpoch:)`` or
	///   ``init(besselianEpoch:)``.
	/// - Parameters:
	///   - decimalYear: The decimal year. Year number 0 is 1 BCE.
	///   - calendar: The calendar the decimal year is expressed in.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if the decimal year is not finite.
	///   - ``CalendarError/invalidDecimalYear`` if the year cannot be represented as an `Int`.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the Julian day number for the
	///     day cannot be represented as a ``JulianDayNumber``.
	public init(decimalYear: Double, calendar: CalendarIdentifier = .julianGregorian) throws(CalendarError) {
		self.init(try CalendarDate(decimalYear: decimalYear, calendar: calendar))
	}
}

extension JulianDate {
	/// The Julian Date as a timescale-agnostic decimal year in the Julian-Gregorian calendar.
	///
	/// The Julian-Gregorian calendar is the conventional choice in astronomy.
	/// Use ``decimalYear(in:)`` for another calendar.
	///
	/// - Note: The decimal year is in this Julian Date's timescale.
	/// - Note: A decimal year is calendar-based, not an astronomical epoch. Use
	///   ``julianEpoch`` or ``besselianEpoch`` for those.
	public var decimalYear: Double {
		decimalYear(in: .julianGregorian)
	}

	/// Returns the Julian Date as a timescale-agnostic decimal year in the specified calendar.
	///
	/// The fraction of the decimal year is the number of days elapsed since midnight on
	/// January 1, including the fraction of the current day, divided by the number of days in
	/// the year. For example, noon on January 1, 1985 is 1985 + 0.5/365 ≈ 1985.0014.
	///
	/// The same instant can have slightly different decimal years in different calendars,
	/// because the calendars disagree on when the year begins and how long it is.
	///
	/// - Note: The decimal year is in this Julian Date's timescale.
	/// - Note: The resolution of a decimal year depends on the year's magnitude.
	/// - Note: A decimal year is calendar-based, not an astronomical epoch. Use
	///   ``julianEpoch`` or ``besselianEpoch`` for those.
	/// - Parameter calendar: The calendar in which to express the decimal year.
	/// - Returns: The decimal year of this Julian Date.
	public func decimalYear(in calendar: CalendarIdentifier) -> Double {
		calendarDate(in: calendar).decimalYear
	}
}
