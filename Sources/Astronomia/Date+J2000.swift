//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation

/// The number of seconds between epoch J2000 and the reference date.
/// - note: The J2000 epoch is 11:58:55.816 UTC on 1 January 2000.
/// - note: The reference date is 00:00:00 UTC on 1 January 2001.
private let timeIntervalBetweenJ2000AndReferenceDate: TimeInterval = 31_579_264.184

extension Date {
	/// The number of seconds between the date value and 11:58:55.816 UTC on 1 January 2000.
	///
	/// This ignores leap seconds; it is a UTC-based count, not elapsed TT.
	public var timeIntervalSinceJ2000: TimeInterval {
		timeIntervalSinceReferenceDate + timeIntervalBetweenJ2000AndReferenceDate
	}

	/// Creates a date value initialized relative to 11:58:55.816 UTC on 1 January 2000 by a given number of seconds.
	/// - parameter timeInterval: A number of seconds.
	public init(timeIntervalSinceJ2000 timeInterval: TimeInterval) {
		self.init(timeIntervalSinceReferenceDate: timeInterval - timeIntervalBetweenJ2000AndReferenceDate)
	}

	/// The epoch J2000, defined as 12:00:00 TT (11:58:55.816 UTC) on 1 January 2000.
	public static var j2000: Date {
		Date(timeIntervalSinceJ2000: 0)
	}
}

/// The number of seconds in one day.
private let secondsPerDay: TimeInterval = 60 * 60 * 24

extension Date {
	/// The number of days between the date value  and 11:58:55.816 UTC on 1 January 2000.
	/// - note: This ignores leap seconds; a day is assumed to contain 86,400 seconds.
	public var daysSinceJ2000: Double {
		timeIntervalSinceJ2000 / secondsPerDay
	}

	/// Creates a date value initialized relative to 11:58:55.816 UTC on 1 January 2000 by a given number of days.
	/// A day is assumed to contain 86,400 seconds.
	/// - parameter days: A number of days.
	public init(daysSinceJ2000 days: Double) {
		self.init(timeIntervalSinceJ2000: days * secondsPerDay)
	}
}

/// Julian date of the reference date, 00:00:00 UTC on 1 January 2001.
private let referenceDateJulianDate: Double = 2_451_910.5

extension Date {
	/// Returns the Julian date in UTC corresponding to the date value.
	public var julianDate: Double {
		timeIntervalSinceReferenceDate / secondsPerDay + referenceDateJulianDate
	}

	/// Creates a date value initialized to the specified Julian date in UTC.
	/// - parameter JD: A Julian date in UTC.
	public init(julianDate JD: Double) {
		self.init(timeIntervalSinceReferenceDate: (JD -  referenceDateJulianDate) * secondsPerDay)
	}
}

import CAstronomyEngine

/// The number of seconds between 11:58:55.816 UTC and 12:00:00 UTC on 1 January 2000.
///
/// Astronomy Engine defines the J2000 epoch as 12:00:00 UTC on 1 January 2000.
/// A more correct definition is either 11:58:55.816 UTC or 12:00:00 TT, a difference of 64.184 seconds.
private let astronomyEngineJ2000Offset = 64.184

extension Date {
	/// Creates a date value initialized to the value of `time`.
	init(_ time: astro_time_t) {
		self.init(timeIntervalSinceJ2000: (time.ut * secondsPerDay) + astronomyEngineJ2000Offset)
	}

	/// Converts the date value to an `astro_time_t` instance.
	func toAstroTime() -> astro_time_t {
		Astronomy_TimeFromDays((timeIntervalSinceJ2000 - astronomyEngineJ2000Offset) / secondsPerDay)
	}
}

extension astro_time_t {
	/// Converts `self` to a `Date` instance.
	func toDate() -> Date {
		Date(self)
	}
}
