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
	/// JD of the `Date` reference epoch, 2001-01-01T00:00:00 UTC.
	static let referenceDate_JD: Double = 2_451_910.5

	/// The `Date` reference epoch, 2001-01-01T00:00:00 UTC, in canonical form.
	static let referenceDate = JulianDate(uncheckedDay: 2_451_911, fraction: -0.5)

	/// Creates a UTC-labelled Julian Date from a `Date`.
	///
	/// `Date` counts seconds since 2001-01-01T00:00:00 UTC as if every day had exactly
	/// 86,400 seconds, the same convention as POSIX time. The resulting Julian Date has
	/// the UTC calendar day and time of day of `date`, but its days are uniform: it is a UTC label
	/// on a timeline that has no leap seconds. It is not a TAI, TT, or UT1 Julian Date, and
	/// intervals between such dates are not elapsed SI seconds. An interval spanning a leap second
	/// is one second shorter than the time that elapsed.
	///
	/// UTC began in 1960 and has had integral leap seconds only since 1972. For earlier instants,
	/// `Date` simply extends its uniform count backward proleptically, so the "UTC" label has no
	/// standard meaning before 1960 and only an approximate one before 1972.
	///
	/// - Parameter date: The date to convert.
	/// - Precondition: The date's time interval is finite.
	public init(_ date: Date) {
		guard let jd = Self(validating: date) else {
			preconditionFailure("Date \(date.timeIntervalSinceReferenceDate) s from the reference date is not finite")
		}
		self = jd
	}

	/// Creates a UTC-labelled Julian Date from a `Date`, returning `nil` if the date's
	/// time interval is not finite.
	///
	/// The result labels instants with UTC calendar days of exactly 86,400 seconds, ignoring
	/// leap seconds. See ``init(_:)-(Date)`` for an explanation of a UTC-labelled Julian Date.
	///
	/// - Parameter date: The date to convert.
	public init?(validating date: Date) {
		// The reference epoch is a midnight, so moving to the noon-based form rounds
		// by at most 2^-54 days.
		guard let jd = Self.referenceDate.addingIfRepresentable(seconds: date.timeIntervalSinceReferenceDate) else {
			return nil
		}
		self = jd
	}

	/// The Julian Date as a `Date`, treating this Julian Date as UTC-labelled.
	///
	/// The conversion assumes days of exactly 86,400 seconds, ignoring leap seconds, so it is only
	/// meaningful if this Julian Date is a UTC label, for example one created from a `Date`.
	/// It is not a timescale conversion.
	///
	/// ### Precision
	///
	/// `Date` stores a single `Double` of seconds since 2001-01-01, giving about 0.1 µs resolution
	/// near the present and coarser resolution farther away. The conversion therefore rounds, and
	/// a round trip through `Date` may not produce an equal `JulianDate`. The reverse round trip,
	/// `Date` to `JulianDate` and back, is exact except within about two weeks of 2001-01-01, where
	/// `Date` is finer than this type's 2^-54-day resolution.
	///
	/// For Julian Dates beyond about ±5 × 10^300 years the time interval overflows and the
	/// resulting `Date` is infinitely distant.
	public var date: Date {
		// A half-integer, exact while its magnitude is below 2^52.
		let days = day - Self.referenceDate_JD
		// One rounding for the fraction (<= ~4 ps); the fused multiply-add adds only
		// the final rounding.
		let seconds = (fraction * Self.secondsPerDay).addingProduct(days, Self.secondsPerDay)
		return Date(timeIntervalSinceReferenceDate: seconds)
	}
}

#endif
