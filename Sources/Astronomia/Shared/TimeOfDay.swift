//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A time of day as hours, minutes, and seconds since midnight.
///
/// The second is not rounded, so the components are always in range: 59.9999 s stays
/// 59.9999 s rather than becoming 60 s. Rounding for display, with its carry into the minute,
/// hour, and day, belongs to formatting.
public struct TimeOfDay: Hashable, Sendable {
	/// The hour, from 0 to 23.
	public let hour: Int
	/// The minute, from 0 to 59.
	public let minute: Int
	/// The second, in the right-open interval [0, 60), or [0, 61) at 23:59 during a leap
	/// second.
	public let second: Double

	/// Creates a time of day.
	///
	/// A second of negative zero is stored as positive zero.
	///
	/// - Parameters:
	///   - hour: The hour, from 0 to 23.
	///   - minute: The minute, from 0 to 59.
	///   - second: The second, in the right-open interval [0, 60), or [0, 61) at 23:59. A
	///     second of 60 or more is a leap second, which occurs only on a UTC day ending in one.
	/// - Throws:
	///   - ``TimeOfDayError/nonFiniteValue`` if `second` is NaN or infinite.
	///   - ``TimeOfDayError/invalid`` if a component is out of range, or the second is
	///     60 or more at a time other than 23:59.
	public init(hour: Int, minute: Int, second: Double = 0) throws(TimeOfDayError) {
		guard second.isFinite else { throw .nonFiniteValue }
		guard hour >= 0 && hour <= 23, minute >= 0 && minute <= 59, second >= 0 else {
			throw .invalid
		}
		// Only the last minute of a UTC day can hold a leap second.
		guard second < 60 || (hour == 23 && minute == 59 && second < 61) else {
			throw .invalid
		}
		self.hour = hour
		self.minute = minute
		self.second = second == 0 ? 0 : second
	}

	/// The time of day as seconds since midnight, h × 3600 + m × 60 + s.
	public var secondsSinceMidnight: Double {
		Double(hour * 3_600 + minute * 60) + second
	}
}

extension TimeOfDay {
	/// Creates a time of day from seconds since midnight.
	///
	/// The hour and minute stop at 23 and 59, so a reading of 86,400 s or more, during a leap
	/// second, has a second of 60 or more.
	///
	/// - Precondition: `seconds` is finite and in the right-open interval [0, 86,401) s.
	init(uncheckedSecondsSinceMidnight seconds: Double) {
		assert(seconds.isFinite && seconds >= 0 && seconds < 86_401, "Seconds since midnight must be in the right-open interval [0, 86,401)")
		let hour = min(Int(seconds / 3_600), 23)
		let minute = min(Int((seconds - Double(hour * 3_600)) / 60), 59)
		self.hour = hour
		self.minute = minute
		self.second = seconds - Double(hour * 3_600 + minute * 60)
	}
}
