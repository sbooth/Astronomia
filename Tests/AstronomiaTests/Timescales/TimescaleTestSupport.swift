//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

import Testing
@testable import Astronomia

/// Tolerance, in seconds, for conversions using whole-second offsets.
///
/// Each step rounds the day fraction by at most about 2^-53 days, or 10 ps.
let timescaleTolerance = 1e-9

/// Tolerance, in seconds, for conversions using the pre-1972 drift formulas.
///
/// On a 1960s step day, mapping a stretched clock reading linearly onto the day's SI length
/// differs from IAU SOFA's `iauUtctai` by up to about 3 ns.
let driftTolerance = 1e-8

/// The UTC context that rejects days past the built-in table's horizon.
let rejectContext = UTC.Context(leapSecondTable: .builtIn, extrapolationPolicy: .reject)

/// Returns the Julian day number of a Gregorian calendar date.
///
/// This is the number of the Julian day whose noon falls on the date, so the date's midnight is
/// at fraction -0.5.
func civilDay(_ year: Int, _ month: Int, _ day: Int) throws -> JulianDayNumber {
	try GregorianCalendar.julianDayNumber(year: year, month: month, day: day)
}

/// Returns the Julian Date `seconds` after the midnight that starts `day`, assuming
/// 86,400-second days.
///
/// Use this for uniform timescales such as TAI, TT and GPS.
func uniformDate(_ day: JulianDayNumber, seconds: Double = 0) throws -> JulianDate {
	try JulianDate(julianDayNumber: day, fractionFromNoon: -0.5).adding(seconds: seconds)
}

/// Returns the UTC Julian Date for a clock reading on the UTC day `day`.
func utcDate(_ day: JulianDayNumber, seconds: Double = 0, table: LeapSecondTable = .builtIn) throws -> JulianDate {
	try UTCDay(julianDayNumber: day, leapSecondTable: table).julianDate(secondsSinceMidnight: seconds)
}

/// Returns the clock reading, in seconds since midnight, of a UTC Julian Date.
func clockReading(_ utc: JulianDate, table: LeapSecondTable = .builtIn) throws -> Double {
	try UTCDay(containing: utc, leapSecondTable: table).secondsSinceMidnight(at: utc)
}

/// Returns the signed number of seconds from `start` to `end`, assuming 86,400-second days.
func seconds(from start: JulianDate, to end: JulianDate) throws -> Double {
	try start.interval(to: end).inSeconds
}

/// Dates spread over several millennia and times of day.
let sampleDates: [JulianDate] = [
	.j2000,
	.mjd0,
	try! JulianDate(julianDayNumber: 2_461_328, fractionFromNoon: -0.123_456_789),
	try! JulianDate(julianDayNumber: 2_457_754, fractionFromNoon: 0.499_999_999),
	try! JulianDate(julianDayNumber: 1_721_424, fractionFromNoon: -0.5),
	try! JulianDate(julianDayNumber: 0, fractionFromNoon: 0.25),
	try! JulianDate(julianDayNumber: -1_000_000, fractionFromNoon: -0.499_9),
	try! JulianDate(julianDayNumber: 5_373_484, fractionFromNoon: 0.1),
]

/// Dates on which UTC is defined, including leap-second days and pre-1972 days.
let utcSampleDates: [JulianDate] = [
	try! JulianDate(julianDayNumber: 2_437_301, fractionFromNoon: 0.1), // 1961-01-01
	try! JulianDate(julianDayNumber: 2_438_927, fractionFromNoon: -0.3), // 1965-06-15
	try! JulianDate(julianDayNumber: 2_441_318, fractionFromNoon: 0), // 1972-01-01
	.j2000,
	try! JulianDate(julianDayNumber: 2_457_754, fractionFromNoon: 0.499_9), // 2016-12-31
	try! JulianDate(julianDayNumber: 2_461_328, fractionFromNoon: -0.123_456_789), // 2026-10-14
]

/// Checks that converting `date` from `A` to `B` and back returns `date`.
func expectRoundTrip<A: Timescale, B: Timescale>(
	_: A.Type,
	_: B.Type,
	date: JulianDate,
	sourceLocation: SourceLocation = #_sourceLocation
) throws {
	let there = try Instant<A>(date).converted(to: B.self)
	let back = try there.converted(to: A.self)
	#expect(
		back.julianDate.isApproximatelyEqual(to: date, toleranceSeconds: timescaleTolerance),
		"\(A.abbreviation) → \(B.abbreviation) → \(A.abbreviation): \(date) became \(back.julianDate)",
		sourceLocation: sourceLocation
	)
}
