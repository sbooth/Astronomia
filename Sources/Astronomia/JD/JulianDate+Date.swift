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
	/// - precondition: The date's time interval is finite.
	public init(_ date: Date) {
		let seconds = date.timeIntervalSinceReferenceDate
		precondition(seconds.isFinite, "timeIntervalSinceReferenceDate must be finite")
		let r = seconds.remainder(dividingBy: Self.secondsPerDay)
		let d = (seconds - r) / Self.secondsPerDay
		self.init(midnight: Self.referenceDate_JD + d, offset: r / Self.secondsPerDay)
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
		let wholeDays = midnight - Self.referenceDate_JD
		let seconds = wholeDays * Self.secondsPerDay + dayFraction * Self.secondsPerDay
		return Date(timeIntervalSinceReferenceDate: seconds)
	}
}

#endif
