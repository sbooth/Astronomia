//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Foundation

/// The number of seconds in one day.
let secondsPerDay: Double = 60 * 60 * 24
/// The Julian date in UTC corresponding to the Unix epoch.
/// - note: The Unix epoch is 00:00:00 UTC on 1 January 1970.
let unixEpoch_UTC = 2440587.5
/// The Julian date in UTC for epoch J2000.
/// - note: The J2000 epoch is 11:58:55.816 UTC on 1 January 2000.
let J2000_UTC = 2451544.9992571296
/// The Julian date in TT for epoch J2000.
/// - note: The J2000 epoch is 12:00:00 TT on 1 January 2000.
let J2000_TT = 2451545.0
/// The Julian date for the the change from Julian to Gregorian calendars (Papal Reformation).
/// - note: The changeover occurred on 15 October 1582.
/// - note: Julian Thursday, 4 October 1582 was followed by Gregorian Friday, 15 October.
/// - note: The actual adoption date of the Gregorian calendar varies by country.
let gregorianChangeover = 2299160.5
// 2299161.0 = 12:00:00
// 2299160.5 = 00:00:00

extension Date {
	/// Returns the Julian date in UTC corresponding to `self`.
	public var julianDate: Double {
		timeIntervalSince1970 / secondsPerDay + unixEpoch_UTC
	}

	/// Creates a date value initialized to the specified Julian date in UTC.
	public init(julianDate: Double) {
		self.init(timeIntervalSince1970: (julianDate - unixEpoch_UTC) * secondsPerDay)
	}

	/// Returns the number of days between `self` and the J2000 epoch.
	public var daysSinceJ2000: Double {
		julianDate - J2000_UTC
	}

	/// Creates a date value relative to the J2000 epoch by a given number of days.
	public init(daysSinceJ2000: Double) {
		self.init(julianDate: J2000_UTC + daysSinceJ2000)
	}

	/// The epoch J2000.
	///
	/// The J2000 epoch is defined as 12:00:00 TT on 1 January 2000.
	///
	/// The following times are equivalent and correpond to the J2000 epoch:
	/// | Time Standard | Time and Date | Julian Date |
	/// | -- | --- | --- |
	/// | TT | 12:00:00 on 1 January 2000 | 2451545.0 |
	/// | UTC | 11:58:55.816 on 1 January 2000 | 2451544.9992571296 |
	public static var j2000: Date {
		Date(julianDate: J2000_UTC)
	}

	/// True if the Julian date in UTC for `self` is at or after the Gregorian changeover.
	/// - note: The Gregorian changeover occurred on October 15, 1582 and corresponds to Julian date 2299160.5 in UTC
	public var atOrAfterGregorianChangeover: Bool {
		julianDate >= gregorianChangeover
	}
}

import CAstronomyEngine

/// The number of days between 11:58:55.816 UTC and 12:00:00 UTC.
///
/// Astronomy Engine defines the J2000 epoch as 12:00:00 UTC on 1 January 2000.
/// A more correct definition is either 11:58:55.816 UTC or 12:00:00 TT, a difference of 64.184 seconds.
let astronomyEngineJ2000Offset = 64.184 / secondsPerDay

extension Date {
	/// Initializes `self` to the value of `time`.
	init(_ time: astro_time_t) {
		// Adjust for the difference here although it won't make a practical difference
		self.init(daysSinceJ2000: time.ut + astronomyEngineJ2000Offset)
	}

	/// Converts `self` to an `astro_time_t` instance.
	func toAstroTime() -> astro_time_t {
		// Adjust for the difference here although it won't make a practical difference
		Astronomy_TimeFromDays(self.daysSinceJ2000 - astronomyEngineJ2000Offset)
	}
}

extension astro_time_t {
	/// Converts `self` to a `Date` instance.
	func toDate() -> Date {
		Date(self)
	}
}
