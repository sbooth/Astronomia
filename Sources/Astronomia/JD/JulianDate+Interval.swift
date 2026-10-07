//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//


extension JulianDate {
	/// A signed interval between two Julian Dates, stored as an integral number of days plus a
	/// fraction of a day.
	public struct Interval: Sendable, Hashable {
		/// The number of whole days.
		public let days: Int
		/// The fraction of a day, in the right-open interval [-0.5, 0.5).
		public let fraction: Double

		/// Creates an interval from parts that are already canonical.
		init(uncheckedDays days: Int, fraction: Double) {
			assert(fraction >= -0.5 && fraction < 0.5, "Fraction must be in the right-open interval [-0.5, 0.5)")
			self.days = days
			self.fraction = fraction
		}
	}
}

extension JulianDate.Interval {
	/// Creates an interval from the specified number of days and fraction of a day.
	public init(days: Int, fraction: Double = 0) throws(JulianDateError) {
		guard fraction.isFinite else { throw .nonFiniteInput }
		guard let f = normalizedTwoSum(fraction, 0) else { throw .intervalOutOfRange }
		let (n, overflow) = days.addingReportingOverflow(f.whole)
		guard !overflow else { throw .intervalOutOfRange }
		self.init(uncheckedDays: n, fraction: f.fraction)
	}

	/// Creates an interval from a single number of days.
	public init(days: Double) throws(JulianDateError) {
		try self.init(days1: days, days2: 0)
	}

	/// Creates an interval of `days1 + days2` days.
	///
	/// - Note: For full precision pass whole days in `days1` and the remainder in `days2`.
	public init(days1: Double, days2: Double) throws(JulianDateError) {
		guard days1.isFinite, days2.isFinite else { throw .nonFiniteInput }
		guard let sum = normalizedTwoSum(days1, days2) else { throw .intervalOutOfRange }
		self.days = sum.whole
		self.fraction = sum.fraction
	}

	/// Creates an interval from a single number of seconds.
	public init(seconds: Double) throws(JulianDateError) {
		try self.init(seconds1: seconds, seconds2: 0)
	}

	/// Creates an interval of `seconds1 + seconds2` seconds.
	///
	/// - Note: For full precision pass whole seconds in `seconds1` and the remainder in `seconds2`.
	public init(seconds1: Double, seconds2: Double) throws(JulianDateError) {
		guard seconds1.isFinite, seconds2.isFinite else { throw .nonFiniteInput }
		guard let (s, e) = twoSum(seconds1, seconds2) else { throw .intervalOutOfRange }
		let d = (s / JulianDate.secondsPerDay + 0.5).rounded(.down)
		guard let days = Int(exactly: d) else {
			throw .intervalOutOfRange
		}
		try self.init(days: days, fraction: (s.addingProduct(-d, JulianDate.secondsPerDay) + e) / JulianDate.secondsPerDay)
	}
}

extension JulianDate.Interval {
	/// The interval in days as a single value.
	/// - Note: Loses precision for long intervals.
	public var inDays: Double {
		Double(days) + fraction
	}

	/// The interval in seconds as a single value, assuming 86,400 seconds per day.
	/// - Note: Loses precision for long intervals.
	public var inSeconds: Double {
		(fraction * JulianDate.secondsPerDay).addingProduct(Double(days), JulianDate.secondsPerDay)
	}

	/// The interval as an integral number of seconds and a fraction of a second in the right-open
	/// interval [-0.5, 0.5), assuming 86,400 seconds per day.
	public var wholeAndFractionalSeconds: (seconds: Double, fraction: Double) {
		let s = fraction * JulianDate.secondsPerDay
		var w = s.rounded()
		var f = s - w
		if f == 0.5 {
			w += 1
			f = -0.5
		}

		let (daySeconds, productOverflow) = days.multipliedReportingOverflow(by: 86_400)
		if !productOverflow {
			let (seconds, sumOverflow) = daySeconds.addingReportingOverflow(Int(w))
			if !sumOverflow {
				return (Double(seconds), f)
			}
		}
		return (w.addingProduct(Double(days), JulianDate.secondsPerDay), f)
	}
}

extension JulianDate {
	public func interval(to other: JulianDate) throws(JulianDateError) -> Interval {
		guard let f = normalizedTwoSum(other.fraction - fraction, 0),
			  let days = other.jdn.subtracting(jdn, plus: f.whole)
		else { throw .intervalOutOfRange }
		return Interval(uncheckedDays: days, fraction: f.fraction)
	}

	public func adding(_ interval: Interval) throws(JulianDateError) -> JulianDate {
		guard let f = normalizedTwoSum(fraction + interval.fraction, 0),
			  let day = jdn.adding(interval.days, plus: f.whole)
		else { throw .dateOutOfRange }
		return JulianDate(uncheckedJDN: day, fraction: f.fraction)
	}

	public func subtracting(_ interval: Interval) throws(JulianDateError) -> JulianDate {
		guard let f = normalizedTwoSum(fraction + interval.fraction, 0),
			  let day = jdn.subtracting(interval.days, plus: f.whole)
		else { throw .dateOutOfRange }
		return JulianDate(uncheckedJDN: day, fraction: f.fraction)
	}
}

extension JulianDate.Interval: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		(lhs.days, lhs.fraction) < (rhs.days, rhs.fraction)
	}
}

extension JulianDate.Interval: CustomStringConvertible {
	public var description: String {
		if fraction == 0 {
			return "\(days) days"
		} else {
			return "\(days) \(fraction < 0 ? "-" : "+") \(abs(fraction)) days"
		}
	}
}

extension JulianDate.Interval: CustomDebugStringConvertible {
	public var debugDescription: String {
		"JulianDate.Interval(days: \(days), fraction: \(fraction))"
	}
}
