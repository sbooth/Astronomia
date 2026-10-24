//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

internal import CAstronomiaPlatform

extension Instant where Scale == UTC {
	/// The current instant, from the system clock.
	///
	/// The system clock counts POSIX time, whose days all have 86,400 seconds, so a reading is
	/// split into its UTC day and the clock reading on that day, and the day's length from the
	/// built-in leap second table gives the fraction. On a day ending in a leap second the
	/// fraction is the reading / 86,401, as ``UTC`` requires.
	///
	/// POSIX time has no label for a leap second itself: during 23:59:60 most clocks repeat
	/// 23:59:59, and a clock synchronized to a smearing time server spreads the second over
	/// hours. The result can then be off by up to one second.
	///
	/// - Throws:
	///   - ``TimescaleConversionError/invalidTimeOfDay`` if the system clock could not be read.
	///   - ``TimescaleConversionError/unsupported`` if the clock reads before
	///     January 1, 1961, when UTC began.
	public static var now: Instant<UTC> {
		get throws(TimescaleConversionError) {
			var time = astronomia_unix_time()
			guard astronomia_unix_time_now(&time) else { throw .invalidTimeOfDay }
			return try Instant(unixSeconds: time.seconds, nanoseconds: time.nanoseconds)
		}
	}

	/// Creates an instant from a reading of POSIX time.
	///
	/// - Parameters:
	///   - unixSeconds: The whole seconds since 1970-01-01T00:00:00 UTC, as if every day had
	///     86,400 seconds, negative before it.
	///   - nanoseconds: The nanoseconds past `unixSeconds`, in the right-open interval
	///     [0, 1,000,000,000).
	///   - leapSecondTable: The leap second table that gives the lengths of UTC days.
	/// - Throws: ``TimescaleConversionError/unsupported`` if the reading is before
	///   January 1, 1961.
	init(unixSeconds: Int64, nanoseconds: Int32, leapSecondTable: LeapSecondTable = .builtIn) throws(TimescaleConversionError) {
		assert(nanoseconds >= 0 && nanoseconds < 1_000_000_000, "Nanoseconds must be in the right-open interval [0, 1,000,000,000)")
		// The day and the seconds since its midnight, rounding the day down before the epoch
		var (days, seconds) = unixSeconds.quotientAndRemainder(dividingBy: 86_400)
		if seconds < 0 {
			days -= 1
			seconds += 86_400
		}
		let day = try UTCDay(julianDayNumber: Self.unixEpochJulianDayNumber + JulianDayNumber(days), leapSecondTable: leapSecondTable)
		let secondsSinceMidnight = Double(seconds) + Double(nanoseconds) * 1e-9
		self.init(try day.julianDate(secondsSinceMidnight: secondsSinceMidnight))
	}

	/// The Julian day number of 1970-01-01, the day of the POSIX epoch.
	static var unixEpochJulianDayNumber: JulianDayNumber {
		2_440_588
	}
}
