//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

#if canImport(FoundationEssentials) || canImport(Foundation)

#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

extension JulianDate {
	/// The `Date` reference epoch, 2001-01-01T00:00:00 UTC (JD 2451910.5).
	static let referenceDate = JulianDate(uncheckedJulianDayNumber: 2_451_911, fractionFromNoon: -0.5)

	/// Creates a Julian Date from a `Date`.
	///
	/// `Date` counts seconds since 2001-01-01T00:00:00 UTC as if every day had exactly
	/// 86,400 seconds, the same convention as POSIX time. The resulting Julian Date has the
	/// UTC calendar day and time of day of `date`, but its days are uniform: it is a UTC label
	/// on a timeline that has no leap seconds. It is not a TAI, TT, or UT1 Julian Date, and
	/// intervals between such dates are not elapsed SI seconds. An interval spanning a leap
	/// second is one second shorter than the time that elapsed.
	///
	/// UTC began in 1960 and has had integral leap seconds only since 1972. For earlier
	/// instants, `Date` simply extends its uniform count backward proleptically, so the "UTC"
	/// label has no standard meaning before 1960 and only an approximate one before 1972.
	///
	/// - Parameter date: The date to convert.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if the time interval of `date` is NaN or
	///     infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days between `date` and
	///     the reference date cannot be represented as an `Int`.
	///   - ``JulianDateError/julianDayNumberNotRepresentable`` if the resulting Julian day
	///     number cannot be represented as a ``JulianDayNumber``.
	public init(_ date: Date) throws(JulianDateError) {
		self = try Self.referenceDate.adding(seconds: date.timeIntervalSinceReferenceDate)
	}

	/// The Julian Date as a `Date`.
	///
	/// The conversion assumes days of exactly 86,400 seconds, ignoring leap seconds, so it is
	/// only meaningful if this Julian Date is a UTC label, for example one created from a
	/// `Date`.
	///
	/// `Date` cannot represent leap seconds. If this Julian Date is a UTC quasi-JD on a day
	/// ending in a leap second, the result can be off by up to one second.
	///
	/// - Note: The result is limited by the precision of the `Double` that `Date` stores,
	///   about 0.1 µs near the present.
	public var date: Date {
		let days = differenceAsDouble(julianDayNumber, Self.referenceDate.julianDayNumber) + 0.5
		let seconds = (fractionFromNoon * Self.secondsPerDay).addingProduct(days, Self.secondsPerDay)
		return Date(timeIntervalSinceReferenceDate: seconds)
	}
}

#endif
