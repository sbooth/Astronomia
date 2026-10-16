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
		let seconds = try secondsSinceMidnight(julianDate)
		// Before 1972 a day could end in a fractional step, so readings can pass 86,400 s by
		// less than a second; none reach 86,401 s.
		return TimeOfDay(uncheckedSecondsSinceMidnight: min(seconds, clockSeconds.nextDown))
	}

	/// Returns the UTC Julian Date for a clock reading on this UTC day.
	///
	/// - Parameter timeOfDay: The time of day on the UTC clock. 23:59:60 is valid only on a day
	///   ending in a positive leap second.
	/// - Returns: The UTC Julian Date.
	/// - Throws: ``TimescaleConversionError/invalidTimeOfDay`` if the reading does not occur on
	///   this UTC day.
	public func julianDate(_ timeOfDay: TimeOfDay) throws(TimescaleConversionError) -> JulianDate {
		try julianDate(secondsSinceMidnight: timeOfDay.secondsSinceMidnight)
	}
}
