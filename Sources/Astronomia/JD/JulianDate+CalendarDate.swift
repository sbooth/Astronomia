//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// Returns `true` if the magnitude of the specified Julian day number is less than 2^51,
	/// matching the `|JD| < 2^51` limit of the canonical form.
	///
	/// The comparison is done in `Double` so it is correct for any width of `JulianDayNumber`:
	/// the conversion is exact below 2^53 and monotonic above it, so no value at or beyond
	/// 2^51 can round below the bound. On 32-bit targets this is always `true`.
	static func isRepresentable(julianDayNumber J: JulianDayNumber) -> Bool {
		Double(J).magnitude < 0x1p51
	}

	/// Creates a Julian Date from a calendar date.
	///
	/// The day with Julian day number `J` begins at midnight `J − 0.5`, so the conversion is exact:
	/// the calendar date's day fraction becomes this Julian Date's day fraction unchanged.
	///
	/// Neither type records a timescale; the Julian Date is in the calendar date's timescale.
	///
	/// - precondition: The magnitude of the calendar date's Julian day number is less than 2^51.
	public init(_ calendarDate: CalendarDate) {
		let J = calendarDate.calendarDay.julianDayNumber
		precondition(Self.isRepresentable(julianDayNumber: J), "Julian day number \(J) cannot be represented exactly")
		// Exact: |J| < 2^51, so both J and J - 0.5 are representable.
		self.init(midnight: Double(J) - 0.5, offset: calendarDate.dayFraction)
	}

	/// Creates a Julian Date from a calendar date, returning `nil` if the magnitude of its Julian day number is not less than 2^51.
	public init?(validatingCalendarDate calendarDate: CalendarDate) {
		guard Self.isRepresentable(julianDayNumber: calendarDate.julianDayNumber) else {
			return nil
		}
		self.init(calendarDate)
	}
}

extension JulianDate {
	/// The Julian Date as a calendar date in the Julian-Gregorian calendar.
	///
	/// The Julian-Gregorian calendar is the conventional choice in astronomy. Use ``calendarDate(_:)`` for another calendar.
	///
	/// Neither type records a timescale; the calendar date is in this Julian Date's timescale.
	///
	/// - throws: `CalendarDateError.julianDayNumberOutOfRange` if the Julian day number of the day containing this Julian Date cannot be represented as an `Int`.
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
	/// - throws: `CalendarDateError.julianDayNumberOutOfRange` if the Julian day number of the day containing this Julian Date cannot be represented as an `Int`.
	public func calendarDate(_ calendar: CalendarIdentifier) throws(CalendarDateError) -> CalendarDate {
		// Exact for |midnight| < 2^52, where midnight is a true half-integer.
		guard let J = JulianDayNumber(exactly: midnight + 0.5) else {
			throw .julianDayNumberOutOfRange
		}
		return try CalendarDate(calendarDay: CalendarDay(julianDayNumber: J, calendar), dayFraction: dayFraction)
	}
}
