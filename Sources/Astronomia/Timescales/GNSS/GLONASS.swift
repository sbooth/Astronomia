//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// GLONASS Time.
///
/// GLONASS Time is UTC(SU) + 3 h, Moscow time. Unlike the other GNSS times it includes leap
/// seconds, so it converts by way of ``UTC`` and takes UTC's context.
///
/// A GLONASS day runs from 21:00 UTC on the previous UTC day, so a leap second at the end of
/// UTC day J - 1 falls at 02:59:60 on GLONASS day J. As with UTC, a GLONASS Julian Date is a
/// quasi-JD whose fraction is the fraction of the GLONASS clock day elapsed, so on such a day
/// the clock reads from 0 to 86,401 s and the fraction is not seconds / 86,400. Use
/// ``julianDate(julianDayNumber:secondsSinceMidnight:leapSecondTable:)`` to convert a clock
/// reading.
///
/// - Note: GLONASS began operation in 1982. For earlier dates the conversion applies UTC's
///   rules arithmetically; days before 1961-01-02 are unsupported.
public enum GLONASS: Timescale {
	public static let abbreviation = "GLONASST"
	public typealias Context = UTC.Context
	public static let defaultContext = UTC.defaultContext

	/// GLONASS - UTC, in seconds.
	public static let offsetFromUTC: Double = 10_800

	/// The UTC clock reading at the start of a GLONASS day, 21:00.
	static let utcSecondsAtStartOfDay: Double = secondsPerDay - offsetFromUTC

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		let J = julianDate.julianDayNumber
		let previous = try utcDay(before: J, leapSecondTable: context.leapSecondTable)
		let seconds = julianDate.fractionSinceMidnight * previous.clockSeconds
		let utc = try utcDate(julianDayNumber: J, secondsSinceMidnight: seconds, previous: previous, leapSecondTable: context.leapSecondTable)
		return try UTC.toTT(utc, context: context)
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		let utc = try UTC.fromTT(julianDate, context: context)
		let day = try UTCDay(julianDayNumber: utc.julianDayNumber, leapSecondTable: context.leapSecondTable)
		let utcSeconds = try day.secondsSinceMidnight(utc)

		let J: JulianDayNumber
		let seconds: Double
		let clockSeconds: Double
		if utcSeconds < utcSecondsAtStartOfDay {
			// Before 21:00 UTC: the same GLONASS day, after any step at the previous UTC midnight
			let previous = try utcDay(before: day.julianDayNumber, leapSecondTable: context.leapSecondTable)
			J = day.julianDayNumber
			seconds = utcSeconds + offsetFromUTC + previous.offsetStep
			clockSeconds = previous.clockSeconds
		} else {
			// From 21:00 UTC: the next GLONASS day, which contains this UTC day's step
			let (next, overflow) = day.julianDayNumber.addingReportingOverflow(1)
			guard !overflow else { throw .dateOutOfRange }
			J = next
			seconds = utcSeconds - utcSecondsAtStartOfDay
			clockSeconds = day.clockSeconds
		}

		// Rounding can push the quotient just outside [0, 1); keep it on this GLONASS day
		let fraction = min(max(seconds / clockSeconds, 0), Double(1).nextDown)
		return JulianDate(uncheckedJulianDayNumber: J, fractionFromNoon: fraction - 0.5)
	}
}

extension GLONASS {
	/// Returns the GLONASS Julian Date for a clock reading on a GLONASS day.
	///
	/// - Parameters:
	///   - J: The GLONASS day's Julian day number.
	///   - seconds: The clock reading as seconds since GLONASS midnight. On a day containing a
	///     leap second, 02:59:60.5 is 10,800.5 and later readings count elapsed seconds, so
	///     03:00:00 is 10,801.
	///   - leapSecondTable: The leap seconds.
	/// - Throws:
	///   - ``TimescaleConversionError/nonFiniteValue`` if `seconds` is NaN or infinite.
	///   - ``TimescaleConversionError/invalidTimeOfDay`` if the reading does not occur on the day.
	///   - ``TimescaleConversionError/unsupported`` if the day is before 1961-01-02.
	public static func julianDate(julianDayNumber J: JulianDayNumber, secondsSinceMidnight seconds: Double, leapSecondTable: LeapSecondTable = .builtIn) throws(TimescaleConversionError) -> JulianDate {
		guard seconds.isFinite else { throw .nonFiniteValue }
		let clockSeconds = try utcDay(before: J, leapSecondTable: leapSecondTable).clockSeconds
		guard seconds >= 0, seconds < clockSeconds else { throw .invalidTimeOfDay }
		let fraction = min(seconds / clockSeconds, Double(1).nextDown)
		return JulianDate(uncheckedJulianDayNumber: J, fractionFromNoon: fraction - 0.5)
	}

	/// Returns the clock reading, in seconds since GLONASS midnight, for a GLONASS Julian Date.
	///
	/// The inverse of ``julianDate(julianDayNumber:secondsSinceMidnight:leapSecondTable:)``.
	///
	/// - Throws: ``TimescaleConversionError/unsupported`` if the day is before 1961-01-02.
	public static func secondsSinceMidnight(_ julianDate: JulianDate, leapSecondTable: LeapSecondTable = .builtIn) throws(TimescaleConversionError) -> Double {
		let previous = try utcDay(before: julianDate.julianDayNumber, leapSecondTable: leapSecondTable)
		return julianDate.fractionSinceMidnight * previous.clockSeconds
	}
}

extension GLONASS {
	/// Returns the UTC day that ends at 03:00 on GLONASS day `J`.
	///
	/// Its step, if any, falls on GLONASS day `J`, so its clock seconds are also GLONASS day
	/// `J`'s.
	static func utcDay(before J: JulianDayNumber, leapSecondTable: LeapSecondTable) throws(TimescaleConversionError) -> UTCDay {
		let (previousJ, overflow) = J.subtractingReportingOverflow(1)
		guard !overflow else { throw .dateOutOfRange }
		return try UTCDay(julianDayNumber: previousJ, leapSecondTable: leapSecondTable)
	}

	/// Returns the UTC Julian Date for a clock reading on GLONASS day `J`.
	static func utcDate(julianDayNumber J: JulianDayNumber, secondsSinceMidnight seconds: Double, previous: UTCDay, leapSecondTable: LeapSecondTable) throws(TimescaleConversionError) -> JulianDate {
		if seconds < offsetFromUTC + previous.offsetStep {
			// Before 03:00, including any leap second: the previous UTC day from 21:00
			let utcSeconds = min(seconds + utcSecondsAtStartOfDay, previous.clockSeconds.nextDown)
			return try previous.julianDate(secondsSinceMidnight: utcSeconds)
		}
		let day = try UTCDay(julianDayNumber: J, leapSecondTable: leapSecondTable)
		let utcSeconds = max(seconds - offsetFromUTC - previous.offsetStep, 0)
		return try day.julianDate(secondsSinceMidnight: utcSeconds)
	}
}
