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

	/// Creates a Julian Date from a `Date`, assuming 86,400 seconds per day.
	///
	/// `Date` ignores leap seconds, so the result is effectively a UTC-labelled Julian Date.
	/// To convert it to TT, add TT − UTC = ΔAT + 32.184 s.
	/// - precondition: The date's time interval is finite and the resulting date is within the supported range.
	public init(_ date: Date) {
		guard let jd = Self(validating: date) else {
			preconditionFailure("Date \(date.timeIntervalSinceReferenceDate) s from the reference date is not finite or is outside the supported range")
		}
		self = jd
	}

	/// Creates a Julian Date from a `Date`, assuming 86,400 seconds per day, returning `nil` if the date's time interval is not finite or the resulting date is outside the supported range.
	public init?(validating date: Date) {
		let seconds = date.timeIntervalSinceReferenceDate
		guard seconds.isFinite else {
			return nil
		}
		let (d, offset) = Self.split(seconds: seconds)
		// referenceDate_JD is the midnight beginning 2001-01-01, so its day number is referenceDate_JD + 0.5 (exact).
		// The offset lies in [-0.5, 0.5], within the [-1, 2) the checked initializer accepts.
		self.init(dayNumber: (Self.referenceDate_JD + 0.5) + d, offset: offset)
	}

	/// The Julian Date as a `Date`, assuming 86,400 seconds per day.
	///
	/// `Date` ignores leap seconds, so this Julian Date is treated as UTC-labelled.
	/// To convert a TT Julian Date, first subtract TT − UTC = ΔAT + 32.184 s.
	///
	/// `Date` stores a single `Double` of seconds since 2001-01-01, giving about 0.1 µs
	/// resolution near the present and coarser resolution farther away. The conversion
	/// therefore rounds, and a round trip through `Date` may not produce an equal `JulianDate`.
	public var date: Date {
		let days = midnight - Self.referenceDate_JD
		let seconds = (dayFraction * Self.secondsPerDay).addingProduct(days, Self.secondsPerDay)
		return Date(timeIntervalSinceReferenceDate: seconds)
	}
}

#endif
