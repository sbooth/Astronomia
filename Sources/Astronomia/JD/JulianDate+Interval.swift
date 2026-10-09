//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate {
	/// A signed interval between two Julian Dates, stored as an integral number of days plus a
	/// fractional day.
	///
	/// An interval measures days and fractions of a day, not elapsed time. In a uniform timescale
	/// such as TAI or TT, the two are equivalent. For UTC quasi-JDs, converting intervals on or
	/// across leap-second days using 86,400 seconds per day can differ from elapsed time by up to
	/// one second per leap second.
	public struct Interval: Hashable, Sendable {
		/// The number of whole days.
		public let days: Int
		/// The fractional day, in the right-open interval [-0.5, 0.5).
		public let fractionalDay: Double

		/// Creates an interval from parts that are already canonical.
		init(uncheckedDays days: Int, fractionalDay: Double) {
			assert(fractionalDay.isFinite, "Fractional day must be finite")
			assert(fractionalDay >= -0.5 && fractionalDay < 0.5, "Fractional day is outside the right-open interval [-0.5, 0.5)")
			self.days = days
			self.fractionalDay = fractionalDay
		}
	}
}

extension JulianDate.Interval {
	/// Creates an interval from the specified number of days and fractional day.
	public init(days: Int, fractionalDay: Double = 0) throws(JulianDateError) {
		guard fractionalDay.isFinite else { throw .nonFiniteValue }
		guard let f = normalizedSum(fractionalDay, 0) else { throw .dayCountNotRepresentable }
		let (n, overflow) = days.addingReportingOverflow(f.integral)
		guard !overflow else { throw .dayCountNotRepresentable }
		self.init(uncheckedDays: n, fractionalDay: f.remainder)
	}

	/// Creates an interval from a single number of days.
	public init(days: Double) throws(JulianDateError) {
		try self.init(days1: days, days2: 0)
	}

	/// Creates an interval of `days1 + days2` days.
	///
	/// For full precision pass whole days in `days1` and the remainder in `days2`.
	public init(days1: Double, days2: Double) throws(JulianDateError) {
		guard days1.isFinite, days2.isFinite else { throw .nonFiniteValue }
		guard let sum = normalizedSum(days1, days2) else { throw .dayCountNotRepresentable }
		self.init(uncheckedDays: sum.integral, fractionalDay: sum.remainder)
	}

	/// Creates an interval from a single number of seconds.
	///
	/// - Important: Assumes 86,400 seconds per day.
	public init(seconds: Double) throws(JulianDateError) {
		try self.init(seconds1: seconds, seconds2: 0)
	}

	/// Creates an interval of `seconds1 + seconds2` seconds.
	///
	/// For full precision pass whole seconds in `seconds1` and the remainder in `seconds2`.
	///
	/// - Important: Assumes 86,400 seconds per day.
	public init(seconds1: Double, seconds2: Double) throws(JulianDateError) {
		guard seconds1.isFinite, seconds2.isFinite else { throw .nonFiniteValue }
		guard let (sum, sumError) = twoSum(seconds1, seconds2) else { throw .dayCountNotRepresentable }
		let extractedDays = (sum / JulianDate.secondsPerDay).rounded()
		let remainingSeconds = sum.addingProduct(-extractedDays, JulianDate.secondsPerDay) + sumError
		let additionalDays = (remainingSeconds / JulianDate.secondsPerDay).rounded()
		let secondsWithinDay = remainingSeconds.addingProduct(-additionalDays, JulianDate.secondsPerDay)
		guard let (carry, fraction) = normalizedSum(secondsWithinDay / JulianDate.secondsPerDay, 0),
			  let (baseDays, dayOffset) = extractedDays.integralParts,
			  let integerAdjustment = Int(exactly: additionalDays)
		else { throw .dayCountNotRepresentable }
		let (totalAdjustment, overflow) = integerAdjustment.addingReportingOverflow(carry)
		guard !overflow, let days = baseDays.adding(dayOffset, plus: totalAdjustment) else { throw .dayCountNotRepresentable }
		self.init(uncheckedDays: days, fractionalDay: fraction)
	}
}

extension JulianDate.Interval {
	/// The interval in days as a single value.
	///
	/// - Note: Loses precision for long intervals.
	public var inDays: Double {
		Double(days) + fractionalDay
	}

	/// The interval in seconds as a single value.
	///
	/// - Important: Assumes 86,400 seconds per day.
	/// - Note: Loses precision for long intervals.
	public var inSeconds: Double {
		(fractionalDay * JulianDate.secondsPerDay).addingProduct(Double(days), JulianDate.secondsPerDay)
	}

	/// The interval as an integral number of seconds and a fractional second in the right-open
	/// interval [-0.5, 0.5).
	///
	/// - Important: Assumes 86,400 seconds per day.
	public var wholeAndFractionalSeconds: (seconds: Double, fractionalSecond: Double) {
		let s = fractionalDay * JulianDate.secondsPerDay
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
		guard let f = normalizedSum(other.fractionFromNoon - fractionFromNoon, 0),
			  let days = other.julianDayNumber.subtracting(julianDayNumber, plus: f.integral)
		else { throw .dayCountNotRepresentable }
		return Interval(uncheckedDays: days, fractionalDay: f.remainder)
	}

	public func adding(_ interval: Interval) throws(JulianDateError) -> JulianDate {
		guard let f = normalizedSum(fractionFromNoon + interval.fractionalDay, 0),
			  let day = julianDayNumber.adding(interval.days, plus: f.integral)
		else { throw .julianDayNumberNotRepresentable }
		return JulianDate(uncheckedJulianDayNumber: day, fractionFromNoon: f.remainder)
	}

	public func subtracting(_ interval: Interval) throws(JulianDateError) -> JulianDate {
		guard let f = normalizedSum(fractionFromNoon - interval.fractionalDay, 0),
			  let day = julianDayNumber.subtracting(interval.days, plus: f.integral)
		else { throw .julianDayNumberNotRepresentable }
		return JulianDate(uncheckedJulianDayNumber: day, fractionFromNoon: f.remainder)
	}
}

extension JulianDate.Interval: Comparable {
	public static func < (lhs: Self, rhs: Self) -> Bool {
		(lhs.days, lhs.fractionalDay) < (rhs.days, rhs.fractionalDay)
	}
}

extension JulianDate.Interval: CustomStringConvertible {
	public var description: String {
		if fractionalDay == 0 {
			return "\(days) days"
		} else {
			return "\(days) \(fractionalDay < 0 ? "-" : "+") \(abs(fractionalDay)) days"
		}
	}
}

extension JulianDate.Interval: CustomDebugStringConvertible {
	public var debugDescription: String {
		"JulianDate.Interval(days: \(days), fractionalDay: \(fractionalDay))"
	}
}

extension JulianDate.Interval: Codable {
	private enum CodingKeys: String, CodingKey {
		case days, fractionalDay
	}

	/// Decodes and validates an interval between two Julian Dates.
	public init(from decoder: any Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let days = try container.decode(Int.self, forKey: .days)
		let fractionalDay = try container.decode(Double.self, forKey: .fractionalDay)

		do throws(JulianDateError) {
			self = try JulianDate.Interval(days: days, fractionalDay: fractionalDay)
		} catch .nonFiniteValue {
			throw DecodingError.dataCorruptedError(forKey: .fractionalDay, in: container, debugDescription: "Fractional day must be finite")
		} catch .dayCountNotRepresentable {
			throw DecodingError.dataCorruptedError(forKey: .days, in: container, debugDescription: "The interval's whole days are not representable")
		}
	}
}
