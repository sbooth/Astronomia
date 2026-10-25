//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A timescale whose days all last 86,400 of its own seconds.
///
/// In a uniform timescale the difference between two Julian Dates is the time elapsed between
/// them, measured in that timescale's seconds, so ``Instant`` supports arithmetic. TAI, TT,
/// TDB, TCG, TCB, and the GNSS times that differ from TAI by a fixed offset are uniform.
///
/// UTC and GLONASS are not: a day ending in a leap second lasts 86,401 or 86,399 seconds, so
/// the difference between two Julian Dates spanning it is off by a second. UT1 is not either:
/// its days follow Earth's rotation, so its seconds vary in length. To measure elapsed time
/// between instants in those timescales, convert them to TAI first, or in UTC use
/// ``Instant/elapsed(to:context:)``.
///
/// The seconds of different uniform timescales need not agree. A TCB second is shorter than a
/// TDB second by a factor of 1 - L_B, and TDB runs ahead of and behind TT by up to about
/// 1.7 ms over a year. An interval is therefore measured in the timescale of its instants.
public protocol UniformTimescale: Timescale {}

extension Instant where Scale: UniformTimescale {
	/// Returns the time elapsed from this instant to the specified instant.
	///
	/// The interval is positive if `other` is later than this instant.
	///
	/// - Parameter other: The end of the interval.
	/// - Returns: `other` minus this instant, in the days and seconds of `Scale`.
	/// - Throws: ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the interval
	///   cannot be represented as an `Int`.
	public func interval(to other: Instant) throws(DayIntervalError) -> DayInterval {
		try julianDate.interval(to: other.julianDate)
	}

	/// Returns the instant the specified interval after this one.
	///
	/// - Parameter interval: The interval to add, in the days and seconds of `Scale`.
	/// - Returns: This instant plus `interval`.
	/// - Throws: ``JulianDateError/julianDayNumberNotRepresentable`` if the resulting Julian day
	///   number cannot be represented as a ``JulianDayNumber``.
	public func adding(_ interval: DayInterval) throws(JulianDateError) -> Instant {
		Instant(try julianDate.adding(interval))
	}

	/// Returns the instant the specified interval before this one.
	///
	/// - Parameter interval: The interval to subtract, in the days and seconds of `Scale`.
	/// - Returns: This instant minus `interval`.
	/// - Throws: ``JulianDateError/julianDayNumberNotRepresentable`` if the resulting Julian day
	///   number cannot be represented as a ``JulianDayNumber``.
	public func subtracting(_ interval: DayInterval) throws(JulianDateError) -> Instant {
		Instant(try julianDate.subtracting(interval))
	}

	/// Returns the instant the specified number of seconds after this one.
	///
	/// - Parameter seconds: The signed number of seconds of `Scale` to add.
	/// - Returns: This instant advanced by `seconds`.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `seconds` is NaN or infinite.
	///   - ``JulianDateError/julianDayNumberNotRepresentable`` if the resulting Julian day
	///     number cannot be represented as a ``JulianDayNumber``.
	public func adding(seconds: Double) throws(JulianDateError) -> Instant {
		Instant(try julianDate.adding(seconds: seconds))
	}
}
