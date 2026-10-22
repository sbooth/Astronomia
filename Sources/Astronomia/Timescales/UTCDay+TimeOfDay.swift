//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension UTCDay {
	/// Returns the UTC clock reading for a UTC Julian Date on this UTC day.
	///
	/// On a day ending in a positive leap second, the reading during the leap second is
	/// 23:59:60 with a second in the right-open interval [60, 61).
	///
	/// - Parameter julianDate: A UTC Julian Date on this UTC day.
	/// - Returns: The time of day on the UTC clock.
	/// - Throws: ``TimescaleConversionError/dateOutOfRange`` if `julianDate` is not on this UTC
	///   day.
	public func timeOfDay(at julianDate: JulianDate) throws(TimescaleConversionError) -> TimeOfDay {
		// A leap second table steps by at most a second, and the steps before 1972 were less,
		// so a clock day is at most 86,401 s and its readings are under 86,401. The product in
		// secondsSinceMidnight can round up to the end of the day.
		let seconds = try min(secondsSinceMidnight(at: julianDate), clockSeconds.nextDown)
		return TimeOfDay(uncheckedSecondsSinceMidnight: seconds)
	}

	/// Returns the UTC Julian Date for a clock reading on this UTC day.
	///
	/// - Parameter timeOfDay: The time of day on the UTC clock. 23:59:60 is valid only on a day
	///   ending in a positive leap second.
	/// - Returns: The UTC Julian Date.
	/// - Throws: ``TimescaleConversionError/invalidTimeOfDay`` if the reading does not occur on
	///   this UTC day.
	public func julianDate(at timeOfDay: TimeOfDay) throws(TimescaleConversionError) -> JulianDate {
		// Check the second against the end of the clock day before summing the components,
		// which can round a reading just before the end up to it. The step is added to the
		// whole seconds left in the day rather than to 86,400, which would round away part of a
		// fractional step: 86,400 + 0.1 is 86,400.100000000006, and would admit 23:59:60.1.
		let wholeSeconds = Double(timeOfDay.hour * 3_600 + timeOfDay.minute * 60)
		guard timeOfDay.second < (secondsPerDay - wholeSeconds) + offsetStep else { throw .invalidTimeOfDay }
		return try julianDate(secondsSinceMidnight: min(wholeSeconds + timeOfDay.second, clockSeconds.nextDown))
	}
}
