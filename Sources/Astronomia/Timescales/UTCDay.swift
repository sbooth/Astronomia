//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A UTC day, from one UTC midnight to the next.
///
/// TAI - UTC changes linearly over a UTC day: by the drift rate before 1972, and by a step
/// at the final midnight when there is a leap second. The day therefore lasts
/// 86,400 s + the change in TAI - UTC of TAI, and a fraction of the day maps linearly to TAI.
///
/// Before 1972 the UTC clock's seconds were stretched to absorb the drift, so a clock day
/// reads from 0 to 86,400 s plus any step, while its elapsed length also includes the drift.
/// ``clockSeconds`` and ``duration`` give these two quantities.
///
/// Two UTC days are equal when they have the same Julian day number and TAI - UTC. The same
/// day from leap second tables that differ about it, such as one with a leap second at its
/// end and one without, is not equal. Whether TAI - UTC comes from a bulletin or from
/// extrapolation (``offsetSource``) is not part of the comparison, so a table with a later
/// horizon but the same leap seconds gives equal days.
public struct UTCDay: Sendable {
	/// The source of a UTC day's TAI - UTC offset.
	public enum OffsetSource: Hashable, Sendable {
		/// A published IERS Bulletin C.
		case bulletin
		/// Extrapolation from the last table entry past the table's expiry, assuming no
		/// further leap seconds.
		case extrapolation
	}

	/// The day's Julian Day Number.
	public let julianDayNumber: JulianDayNumber
	/// The source of the day's TAI - UTC offset.
	public let offsetSource: OffsetSource

	/// TAI - UTC offset at the start of the day, in seconds.
	let offsetAtStart: Double
	/// The step in TAI - UTC offset at the end of the day, in seconds.
	/// - Note: This excludes drift.
	let offsetStep: Double
	/// The change in TAI - UTC offset from the start of the day to the end, in seconds.
	///
	/// - Note: This includes drift and any step at the end of the day.
	let offsetChange: Double

	/// Creates a UTC day with the specified Julian Day Number.
	///
	/// - Throws:
	///   - ``TimescaleConversionError/dateOutOfRange`` if the Julian day number is out of range.
	///   - ``TimescaleConversionError/unsupported`` if the day is before January 1, 1961.
	public init(julianDayNumber J: JulianDayNumber, leapSecondTable: LeapSecondTable = .builtIn) throws(TimescaleConversionError) {
		let (nextJ, overflow) = J.addingReportingOverflow(1)
		guard !overflow else { throw .dateOutOfRange }

		guard let start = leapSecondTable.taiMinusUTC(atStartOfUTCDay: J),
			  let startOfNext = leapSecondTable.taiMinusUTC(atStartOfUTCDay: nextJ)
		else { throw .unsupported }

		let offsetAtStart = start.seconds
		let offsetChange = startOfNext.seconds - offsetAtStart
		let offsetStep = ((offsetChange - start.rate) * 1e9).rounded() / 1e9

		julianDayNumber = J
		offsetSource = julianDayNumber < leapSecondTable.horizon ? .bulletin : .extrapolation
		self.offsetAtStart = offsetAtStart
		self.offsetStep = offsetStep
		self.offsetChange = offsetChange
	}
}

extension UTCDay {
	/// Creates a UTC day containing the specified UTC Julian Date.
	///
	/// - Throws: ``TimescaleConversionError/unsupported`` if the day is before January 1, 1961.
	public init(containing julianDate: JulianDate, leapSecondTable: LeapSecondTable = .builtIn) throws(TimescaleConversionError) {
		try self.init(julianDayNumber: julianDate.julianDayNumber, leapSecondTable: leapSecondTable)
	}
}

extension UTCDay {
	/// UTC midnight at the start of the day.
	public var start: JulianDate {
		JulianDate(uncheckedJulianDayNumber: julianDayNumber, fractionFromNoon: -0.5)
	}

	/// How long the UTC day lasts, in SI seconds.
	///
	/// 86,401 on a day ending in a positive leap second; before 1972, also includes the
	/// drift.
	/// - Note: Clock readings use ``clockSeconds`` instead.
	public var duration: Double {
		secondsPerDay + offsetChange
	}

	/// How many seconds the UTC clock counts over the UTC day.
	///
	/// Clock readings on this day are in `0..<clockSeconds`: 86,401 on a day ending in a
	/// positive leap second, 86,400 + the step on a pre-1972 step day, and 86,400 otherwise.
	/// - Note: Before 1972 clock seconds were not SI seconds, so this can differ from ``duration``.
	public var clockSeconds: Double {
		secondsPerDay + offsetStep
	}
}

extension UTCDay {
	/// Returns the UTC Julian Date for a clock reading on this UTC day.
	///
	/// - Parameter seconds: The clock reading as seconds since midnight,
	///   h * 3600 + m * 60 + s. On a day ending in a leap second, 23:59:60.5 is 86,400.5.
	/// - Throws:
	///   - ``TimescaleConversionError/nonFiniteValue`` if `seconds` is NaN or infinite.
	///   - ``TimescaleConversionError/invalidTimeOfDay`` if the reading does not occur on this
	///     UTC day.
	public func julianDate(secondsSinceMidnight seconds: Double) throws(TimescaleConversionError) -> JulianDate {
		guard seconds.isFinite else { throw .nonFiniteValue }
		let fraction = try fractionSinceMidnight(secondsSinceMidnight: seconds)
		return JulianDate(uncheckedJulianDayNumber: julianDayNumber, fractionFromNoon: fraction - 0.5)
	}

	/// Returns the clock reading, in seconds since midnight, for a UTC Julian Date on this UTC day.
	///
	/// The inverse of ``julianDate(secondsSinceMidnight:)``. On a day ending in a leap second,
	/// the result is in the right-open interval [86,400, 86,401) during 23:59:60.
	///
	/// - Throws: ``TimescaleConversionError/dateOutOfRange`` if `julianDate` is not on this UTC
	///   day.
	public func secondsSinceMidnight(at julianDate: JulianDate) throws(TimescaleConversionError) -> Double {
		guard julianDate.julianDayNumber == julianDayNumber else { throw .dateOutOfRange }
		return julianDate.fractionSinceMidnight * clockSeconds
	}
}

extension UTCDay {
	/// Returns the TAI Julian Date for a clock reading on this UTC day.
	///
	/// - Parameter seconds: The clock reading as seconds since midnight.
	/// - Throws: ``TimescaleConversionError/invalidTimeOfDay`` if the reading does not occur on
	///   this UTC day.
	public func taiJulianDate(secondsSinceMidnight seconds: Double) throws(TimescaleConversionError) -> JulianDate {
		guard seconds.isFinite else { throw .nonFiniteValue }
		let fraction = try fractionSinceMidnight(secondsSinceMidnight: seconds)
		return try tai(fractionSinceMidnight: fraction)
	}

	/// Returns the UTC fraction since midnight for a clock reading.
	/// - Throws: ``TimescaleConversionError/invalidTimeOfDay`` if the reading does not occur on
	///   this UTC day.
	func fractionSinceMidnight(secondsSinceMidnight seconds: Double) throws(TimescaleConversionError) -> Double {
		assert(seconds.isFinite, "Seconds since midnight must be finite")
		let clockSeconds = self.clockSeconds
		guard seconds >= 0, seconds < clockSeconds else { throw .invalidTimeOfDay }
		// The quotient can round up to 1 for readings just below `length`
		return min(seconds / clockSeconds, Double(1).nextDown)
	}

	/// Returns the TAI Julian Date for a fraction since midnight of this UTC day.
	///
	/// - Parameter fraction: The fraction of the day since UTC midnight, in the closed interval
	///   [0, 1].
	func tai(fractionSinceMidnight fraction: Double) throws(TimescaleConversionError) -> JulianDate {
		assert(fraction.isFinite, "Fraction since midnight must be finite")
		assert(fraction >= 0 && fraction <= 1, "Fraction since midnight is outside the closed interval [0, 1]")
		let correction = (offsetAtStart + fraction * offsetChange) / secondsPerDay
		do throws(JulianDateError) {
			return try start.adding(days1: fraction, days2: correction)
		}
		catch { throw TimescaleConversionError(error) }
	}
}

extension UTCDay: Hashable {
	/// Returns `true` if two UTC days have the same Julian day number and TAI - UTC, whatever
	/// the source of their offsets.
	public static func == (lhs: UTCDay, rhs: UTCDay) -> Bool {
		lhs.julianDayNumber == rhs.julianDayNumber
			&& lhs.offsetAtStart == rhs.offsetAtStart
			&& lhs.offsetStep == rhs.offsetStep
			&& lhs.offsetChange == rhs.offsetChange
	}

	public func hash(into hasher: inout Hasher) {
		hasher.combine(julianDayNumber)
		hasher.combine(offsetAtStart)
		hasher.combine(offsetStep)
		hasher.combine(offsetChange)
	}
}

extension UTCDay: CustomStringConvertible {
	/// A textual representation of the UTC day and TAI - UTC at its start, such as
	/// `2016-12-31 UTC, TAI - UTC = 36.0 s, leap second +1.0 s`.
	///
	/// A day before 1972 also shows the drift in TAI - UTC through the day, and a day past the
	/// leap second table's horizon is marked as extrapolated. Values are shown to the nearest
	/// nanosecond, as the step already is, so the rounding of the offset arithmetic is hidden.
	public var description: String {
		/// Returns `seconds` rounded to the nearest nanosecond.
		func toNanoseconds(_ seconds: Double) -> Double {
			(seconds * 1e9).rounded() / 1e9
		}

		// UTC began in 1961, so its days are always Gregorian.
		let date = CalendarDay(julianDayNumber: julianDayNumber, calendar: .gregorian)
		var parts = ["\(date.year)-\(date.month)-\(date.day) UTC", "TAI - UTC = \(toNanoseconds(offsetAtStart)) s"]
		let drift = toNanoseconds(offsetChange - offsetStep)
		if drift != 0 {
			parts.append("drift \(drift) s")
		}
		if offsetStep != 0 {
			let kind = offsetStep.magnitude == 1 ? "leap second" : "step"
			parts.append("\(kind) \(offsetStep > 0 ? "+" : "")\(offsetStep) s")
		}
		if offsetSource == .extrapolation {
			parts.append("extrapolated")
		}
		return parts.joined(separator: ", ")
	}
}
