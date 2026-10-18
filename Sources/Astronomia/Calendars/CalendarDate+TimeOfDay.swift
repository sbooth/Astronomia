//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension CalendarDate {
	/// Creates a calendar date for the specified calendar day and time of day.
	///
	/// The time of day is converted to a fraction since midnight of a day of 86,400 seconds.
	///
	/// - Parameters:
	///   - calendarDay: The calendar day.
	///   - timeOfDay: The time of day, with a second below 60.
	/// - Throws: ``CalendarError/invalidTimeOfDay`` if the second is 60 or more, which a day of
	///   86,400 seconds cannot have. Use ``UTCDay/julianDate(_:)`` for a leap second.
	public init(calendarDay: CalendarDay, timeOfDay: TimeOfDay) throws(CalendarError) {
		guard timeOfDay.second < 60 else { throw .invalidTimeOfDay }
		// The quotient can round up to 1 for a time just below midnight.
		let fraction = min(timeOfDay.secondsSinceMidnight / secondsPerDay, Double(1).nextDown)
		self.init(calendarDay: calendarDay, uncheckedFractionSinceMidnight: fraction)
	}

	/// Creates a calendar date for the specified year, month, day, and time of day in the
	/// given calendar.
	///
	/// - Parameters:
	///   - year: The arithmetic year number. Year number 0 is 1 BCE.
	///   - month: The month number from 1 (January) to 12 (December).
	///   - day: The day number, starting at 1.
	///   - hour: The hour, from 0 to 23.
	///   - minute: The minute, from 0 to 59.
	///   - second: The second, in the right-open interval [0, 60).
	///   - calendar: The calendar the year, month, and day belong to.
	/// - Throws:
	///   - ``CalendarError/nonFiniteValue`` if `second` is NaN or infinite.
	///   - ``CalendarError/invalidDate`` if the year, month, and day do not form a valid
	///     date in the specified calendar.
	///   - ``CalendarError/invalidTimeOfDay`` if the hour, minute, or second is out of range.
	///   - ``CalendarError/julianDayNumberNotRepresentable`` if the year, month, and day form
	///     a valid date, but its Julian day number cannot be represented as a
	///     ``JulianDayNumber``.
	public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Double = 0, _ calendar: CalendarIdentifier) throws(CalendarError) {
		let calendarDay = try CalendarDay(year: year, month: month, day: day, calendar)
		let timeOfDay: TimeOfDay
		do throws(TimeOfDayError) {
			timeOfDay = try TimeOfDay(hour: hour, minute: minute, second: second)
		}
		catch { throw CalendarError(error) }
		try self.init(calendarDay: calendarDay, timeOfDay: timeOfDay)
	}

	/// The time of day, for a day of 86,400 seconds.
	///
	/// - Important: On a UTC day ending in a leap second, the fraction since midnight is a
	///   fraction of 86,401 seconds, so this is off by up to a second and never reads 23:59:60.
	///   Use ``UTCDay/timeOfDay(_:)`` for UTC.
	public var timeOfDay: TimeOfDay {
		// The product can round up to a whole day for a fraction just below 1.
		TimeOfDay(uncheckedSecondsSinceMidnight: min(fractionSinceMidnight * secondsPerDay, secondsPerDay.nextDown))
	}

	/// The hour, from 0 to 23, for a day of 86,400 seconds.
	public var hour: Int {
		timeOfDay.hour
	}

	/// The minute, from 0 to 59, for a day of 86,400 seconds.
	public var minute: Int {
		timeOfDay.minute
	}

	/// The second, in the right-open interval [0, 60), for a day of 86,400 seconds.
	public var second: Double {
		timeOfDay.second
	}
}
