//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation

/// The number of seconds between epoch J2000 and the reference epoch.
/// - note: The J2000 epoch is 11:58:55.816 UTC on 1 January 2000.
/// - note: The reference epoch is 00:00:00 UTC on 1 January 2001.
let timeIntervalBetweenJ2000AndReferenceDate: Double = 31_579_264.184

extension Date {
	/// Returns the number of seconds between `self` and the J2000 epoch.
	public var timeIntervalSinceJ2000: TimeInterval {
		timeIntervalSinceReferenceDate + timeIntervalBetweenJ2000AndReferenceDate
	}

	/// Creates a date value relative to the J2000 epoch.
	/// - parameter timeInterval: A number of seconds.
	public init(timeIntervalSinceJ2000 timeInterval: TimeInterval) {
		self.init(timeIntervalSinceReferenceDate: timeInterval - timeIntervalBetweenJ2000AndReferenceDate)
	}

	/// The epoch J2000, defined as 12:00:00 TT on 1 January 2000.
	///
	/// The following times are equivalent and correspond to the J2000 epoch:
	/// | Time Standard | Time | Date |
	/// | -- | --- | --- |
	/// | TT | 12:00:00 | 1 January 2000 |
	/// | UTC | 11:58:55.816 | 1 January 2000 |
	public static var j2000: Date {
		Date(timeIntervalSinceReferenceDate: -timeIntervalBetweenJ2000AndReferenceDate)
	}
}

/// The number of seconds in one day.
let secondsPerDay: Double = 60 * 60 * 24

extension Date {
	/// Returns the number of days between `self` and the J2000 epoch.
	public var daysSinceJ2000: Double {
		timeIntervalSinceJ2000 / secondsPerDay
	}

	/// Creates a date value relative to the J2000 epoch by a given number of days.
	/// - parameter days: A number of days.
	public init(daysSinceJ2000 days: Double) {
		self.init(timeIntervalSinceJ2000: days * secondsPerDay)
	}
}

/// The Julian date in UTC for epoch J2000.
let J2000JD_UTC: Double = 2451544.9992571296

extension Date {
	/// Returns the Julian date in UTC corresponding to `self`.
	public var julianDate: Double {
		daysSinceJ2000 + J2000JD_UTC
	}

	/// Creates a date value initialized to the specified Julian date in UTC.
	/// - parameter JD: A Julian date in UTC.
	public init(julianDate JD: Double) {
		self.init(daysSinceJ2000: JD - J2000JD_UTC)
	}
}

import CAstronomyEngine

/// The number of seconds between 11:58:55.816 UTC and 12:00:00 UTC on 1 January 2000.
///
/// Astronomy Engine defines the J2000 epoch as 12:00:00 UTC on 1 January 2000.
/// A more correct definition is either 11:58:55.816 UTC or 12:00:00 TT, a difference of 64.184 seconds.
let astronomyEngineJ2000Offset = 64.184

extension Date {
	/// Initializes `self` to the value of `time`.
	init(_ time: astro_time_t) {
		self.init(timeIntervalSinceJ2000: (time.ut * secondsPerDay) + astronomyEngineJ2000Offset)
	}

	/// Converts `self` to an `astro_time_t` instance.
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
