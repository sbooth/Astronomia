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
public enum UTC: Timescale {
	public static let abbreviation = "UTC"
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
		catch { throw .dateOutOfRange }

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

	public struct Context: Hashable, Sendable {
		public let leapSecondTable: LeapSecondTable
		public let extrapolationPolicy: ExtrapolationPolicy

		public init(leapSecondTable: LeapSecondTable, extrapolationPolicy: ExtrapolationPolicy) {
			self.leapSecondTable = leapSecondTable
			self.extrapolationPolicy = extrapolationPolicy
		}
	}
}

extension UTCDay.OffsetSource {
	/// Throws if `policy` does not allow this offset source.
	func check(_ policy: UTC.ExtrapolationPolicy) throws(TimescaleConversionError) {
		if policy == .strict && self == .extrapolation { throw .leapSecondTableExpired }
	}
}
