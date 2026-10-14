//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension CalendarDate {
	/// Returns the interval from this calendar date to the specified calendar date.
	///
	/// The interval is positive if `other` is later than this calendar date.
	///
	/// - Note: Because `CalendarDate` stores a fraction since midnight, an interval between
	///   calendar dates converted from Julian Dates can differ from the Julian Date interval by
	///   up to one ulp.
	/// - Parameter other: The end of the interval.
	/// - Returns: `other` minus this calendar date.
	/// - Throws: ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the interval
	///   cannot be represented as an `Int`.
	public func interval(to other: CalendarDate) throws(DayIntervalError) -> DayInterval {
		try DayInterval { acc throws(DayAccumulator.Failure) in
			try acc.add(midnightBased: other)
			try acc.subtract(midnightBased: self)
		}
	}

	/// Returns the calendar date advanced by the specified interval, in the same calendar.
	///
	/// The time of day is computed from the exact sum and rounded once.
	///
	/// - Parameter interval: The interval to add.
	/// - Returns: This calendar date plus `interval`, in this calendar date's calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the resulting date's
	///   Julian day number cannot be represented as a ``JulianDayNumber``.
	public func adding(_ interval: DayInterval) throws(CalendarError) -> CalendarDate {
		try CalendarDate(calendar) { acc throws(DayAccumulator.Failure) in
			try acc.add(midnightBased: self)
			try acc.add(interval)
		}
	}

	/// Returns the calendar date moved back by the specified interval, in the same calendar.
	///
	/// - Parameter interval: The interval to subtract.
	/// - Returns: This calendar date minus `interval`, in this calendar date's calendar.
	/// - Throws: ``CalendarError/julianDayNumberNotRepresentable`` if the resulting date's
	///   Julian day number cannot be represented as a ``JulianDayNumber``.
	public func subtracting(_ interval: DayInterval) throws(CalendarError) -> CalendarDate {
		try CalendarDate(calendar) { acc throws(DayAccumulator.Failure) in
			try acc.add(midnightBased: self)
			try acc.subtract(interval)
		}
	}
}
