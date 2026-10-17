//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Coordinated Universal Time (UTC).
///
/// A UTC Julian Date is a quasi-JD whose fraction is the fraction of the UTC clock day elapsed,
/// whatever that day's length. On a day ending in a positive leap second the clock reads from
/// 0 to 86,401 s, so 23:59:60 is represented by fractions in [86,400/86,401, 1). This follows
/// the IAU SOFA convention and makes the conversion invertible.
///
/// - Important: On a day ending in a leap second, or a pre-1972 day ending in a fractional
///   step, a UTC fraction is not seconds / 86,400. Use
///   ``UTCDay/julianDate(secondsSinceMidnight:)`` to convert a clock reading.
///
/// - Note: UTC began on 1961-01-01, and conversions of earlier dates throw
///   ``TimescaleConversionError/unsupported``. For earlier times, use ``UT1``, whose ΔT
///   reaches back to antiquity. Historical times given as UT or GMT are UT1 to within the
///   precision of the records, but astronomical records before 1925 often count GMT from
///   noon, 12 hours behind the civil reckoning from midnight.
public enum UTC: Timescale {
	public static let abbreviation = "UTC"
	/// The built-in leap second table, assuming no further leap seconds past its horizon.
	public static let defaultContext = Context(leapSecondTable: .builtIn, extrapolationPolicy: .allow)

	public static func toTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		let day = try UTCDay(containing: julianDate, leapSecondTable: context.leapSecondTable)
		try day.offsetSource.check(context.extrapolationPolicy)
		let tai = try day.tai(fractionSinceMidnight: julianDate.fractionSinceMidnight)
		return try TAI.toTT(tai)
	}

	public static func fromTT(_ julianDate: JulianDate, context: Context) throws(TimescaleConversionError) -> JulianDate {
		let tai = try TAI.fromTT(julianDate)

		// TAI is ahead of UTC by less than a day, so the UTC day is either TAI's calendar day
		// or the day before
		var day = try UTCDay(julianDayNumber: tai.julianDayNumber, leapSecondTable: context.leapSecondTable)
		var startOfDay = try day.tai(fractionSinceMidnight: 0)
		if tai < startOfDay {
			let (previousJ, overflow) = day.julianDayNumber.subtractingReportingOverflow(1)
			guard !overflow else { throw .dateOutOfRange }
			day = try UTCDay(julianDayNumber: previousJ, leapSecondTable: context.leapSecondTable)
			startOfDay = try day.tai(fractionSinceMidnight: 0)
		}
		let endOfDay = try day.tai(fractionSinceMidnight: 1)

		try day.offsetSource.check(context.extrapolationPolicy)

		let elapsed: Double
		let dayLength: Double
		do throws(DayIntervalError) {
			elapsed = try startOfDay.interval(to: tai).inDays
			dayLength = try startOfDay.interval(to: endOfDay).inDays
		}
		catch { throw TimescaleConversionError(error) }

		// Rounding can push the quotient just outside [0, 1); keep it on this UTC day
		let fraction = min(max(elapsed / dayLength, 0), Double(1).nextDown)
		return JulianDate(uncheckedJulianDayNumber: day.julianDayNumber, fractionFromNoon: fraction - 0.5)
	}
}

extension UTC {
	/// Whether a conversion may use a UTC day past the leap-second table's horizon.
	public enum ExtrapolationPolicy: Hashable, Sendable {
		/// Throw ``TimescaleConversionError/leapSecondTableExpired`` for days past the horizon.
		case strict
		/// Assume no further leap seconds past the horizon.
		case allow
	}

	/// The leap seconds and extrapolation policy used by UTC conversions.
	public struct Context: Hashable, Sendable {
		/// The leap second table.
		public let leapSecondTable: LeapSecondTable
		/// Whether conversions may use days past the table's horizon.
		public let extrapolationPolicy: ExtrapolationPolicy

		/// Creates a UTC context.
		///
		/// - Parameters:
		///   - leapSecondTable: The leap second table.
		///   - extrapolationPolicy: Whether conversions may use days past the table's horizon.
		public init(leapSecondTable: LeapSecondTable, extrapolationPolicy: ExtrapolationPolicy = .allow) {
			self.leapSecondTable = leapSecondTable
			self.extrapolationPolicy = extrapolationPolicy
		}
	}
}

extension UTC {
	/// Returns TAI - UTC, in seconds, at the specified UTC.
	///
	/// From 1972, TAI - UTC is a whole number of seconds that changes at the UTC midnight after
	/// a leap second, so during 23:59:60 it still has the value from before the leap second.
	/// Before 1972 it drifts linearly through each day, and any step takes effect at the next
	/// midnight.
	///
	/// - Note: TAI - UTC is not the number of leap seconds. UTC began in 1972 already 10 s
	///   behind TAI, so TAI - UTC = 37 s after 27 leap seconds.
	/// - Parameters:
	///   - utc: A Julian Date in UTC.
	///   - context: The leap seconds and extrapolation policy.
	/// - Returns: TAI - UTC, in seconds.
	/// - Throws:
	///   - ``TimescaleConversionError/dateOutOfRange`` if the Julian day number is out of range.
	///   - ``TimescaleConversionError/unsupported`` if `utc` is before 1961, when UTC began.
	///     Use ``UT1`` for earlier times.
	///   - ``TimescaleConversionError/leapSecondTableExpired`` if `utc` is on or after the
	///     table's horizon and the policy is ``ExtrapolationPolicy/strict``.
	public static func taiMinusUTC(at utc: JulianDate, context: Context = defaultContext) throws(TimescaleConversionError) -> Double {
		let day = try UTCDay(containing: utc, leapSecondTable: context.leapSecondTable)
		try day.offsetSource.check(context.extrapolationPolicy)
		// The drift accumulates through the day; the step is excluded because it takes effect
		// at the next midnight.
		return day.offsetAtStart + utc.fractionSinceMidnight * (day.offsetChange - day.offsetStep)
	}
}

extension UTCDay.OffsetSource {
	/// Throws if `policy` does not allow this offset source.
	func check(_ policy: UTC.ExtrapolationPolicy) throws(TimescaleConversionError) {
		if policy == .strict && self == .extrapolation { throw .leapSecondTableExpired }
	}
}
