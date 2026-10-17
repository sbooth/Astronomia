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
	public func timeOfDay(_ julianDate: JulianDate) throws(TimescaleConversionError) -> TimeOfDay {
		// A leap second table steps by at most a second, and the steps before 1972 were less,
		// so a clock day is under 86,401 s. The product in secondsSinceMidnight can round up to
		// the end of the day.
		let seconds = try min(secondsSinceMidnight(julianDate), clockSeconds.nextDown)
		return TimeOfDay(uncheckedSecondsSinceMidnight: seconds)
	}

	/// Returns the UTC Julian Date for a clock reading on this UTC day.
	///
	/// - Parameter timeOfDay: The time of day on the UTC clock. 23:59:60 is valid only on a day
	///   ending in a positive leap second.
	/// - Returns: The UTC Julian Date.
	/// - Throws: ``TimescaleConversionError/invalidTimeOfDay`` if the reading does not occur on
	///   this UTC day.
	public func julianDate(_ timeOfDay: TimeOfDay) throws(TimescaleConversionError) -> JulianDate {
		// Check the reading against the end of the clock day before summing the components,
		// which can round a reading just before the end up to it. Both terms of the difference
		// are multiples of the spacing of doubles near 86,400 and below 2^17, so it is exact.
		let wholeSeconds = Double(timeOfDay.hour * 3_600 + timeOfDay.minute * 60)
		guard timeOfDay.second < clockSeconds - wholeSeconds else { throw .invalidTimeOfDay }
		return try julianDate(secondsSinceMidnight: min(wholeSeconds + timeOfDay.second, clockSeconds.nextDown))
	}
}
