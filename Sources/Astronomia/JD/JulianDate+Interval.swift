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
	/// An interval measures days and fractions of a day, not elapsed time. In a uniform
	/// timescale such as TAI or TT, the two are equivalent. For UTC quasi-JDs, converting
	/// intervals on or across leap-second days using 86,400 seconds per day can differ from
	/// elapsed time by up to one second per leap second.
	public struct Interval: Hashable, Sendable {
		/// The interval rounded to the nearest whole number of days.
		///
		/// This is not the truncated number of whole days: an interval of 0.75 days has
		/// ``days`` equal to 1 and ``fractionalDay`` equal to -0.25.
		public let days: Int
		/// The remainder of the interval after ``days``, in the right-open interval
		/// [-0.5, 0.5).
		public let fractionalDay: Double

		/// Creates an interval from parts that are already canonical.
		///
		/// - Precondition: `fractionalDay` is finite and in the right-open interval
		///   [-0.5, 0.5).
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
	///
	/// `fractionalDay` need not lie in the right-open interval [-0.5, 0.5); whole days are
	/// carried into ``days``.
	///
	/// - Parameters:
	///   - days: The signed number of whole days.
	///   - fractionalDay: The signed number of additional days.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `fractionalDay` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in `fractionalDay`,
	///     or the total number of whole days, cannot be represented as an `Int`.
	public init(days: Int, fractionalDay: Double = 0) throws(JulianDateError) {
		guard fractionalDay.isFinite else { throw .nonFiniteValue }
		guard let f = normalizedSum(fractionalDay, 0) else { throw .dayCountNotRepresentable }
		let (n, overflow) = days.addingReportingOverflow(f.integral)
		guard !overflow else { throw .dayCountNotRepresentable }
		self.init(uncheckedDays: n, fractionalDay: f.remainder)
	}

	/// Creates an interval from a single number of days.
	///
	/// - Parameter days: The signed number of days.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `days` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in `days` cannot be
	///     represented as an `Int`.
	public init(days: Double) throws(JulianDateError) {
		try self.init(days1: days, days2: 0)
	}

	/// Creates an interval of `days1 + days2` days.
	///
	/// For full precision pass whole days in `days1` and the remainder in `days2`.
	///
	/// - Parameters:
	///   - days1: The first part of the signed number of days.
	///   - days2: The second part of the signed number of days.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `days1` or `days2` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in `days1 + days2`
	///     cannot be represented as an `Int`.
	public init(days1: Double, days2: Double) throws(JulianDateError) {
		guard days1.isFinite, days2.isFinite else { throw .nonFiniteValue }
		guard let sum = normalizedSum(days1, days2) else { throw .dayCountNotRepresentable }
		self.init(uncheckedDays: sum.integral, fractionalDay: sum.remainder)
	}

	/// Creates an interval from a single number of seconds.
	///
	/// - Important: Assumes 86,400 seconds per day.
	/// - Parameter seconds: The signed number of seconds.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `seconds` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in `seconds` cannot
	///     be represented as an `Int`.
	public init(seconds: Double) throws(JulianDateError) {
		try self.init(seconds1: seconds, seconds2: 0)
	}

	/// Creates an interval of `seconds1 + seconds2` seconds.
	///
	/// For full precision pass whole seconds in `seconds1` and the remainder in `seconds2`.
	///
	/// - Important: Assumes 86,400 seconds per day.
	/// - Parameters:
	///   - seconds1: The first part of the signed number of seconds.
	///   - seconds2: The second part of the signed number of seconds.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `seconds1` or `seconds2` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if `seconds1 + seconds2` overflows or
	///     its whole days cannot be represented as an `Int`.
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
	/// `seconds` is the interval rounded to the nearest whole second. It is exact up to 2^53
	/// seconds in magnitude (about 285 million years) and is otherwise rounded to the nearest
	/// representable `Double`.
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
	/// Returns the interval from this Julian Date to the specified Julian Date.
	///
	/// The interval is positive if `other` is later than this Julian Date.
	///
	/// - Parameter other: The end of the interval.
	/// - Returns: `other` minus this Julian Date.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the interval
	///   cannot be represented as an `Int`.
	public func interval(to other: JulianDate) throws(JulianDateError) -> Interval {
		guard let f = normalizedSum(other.fractionFromNoon - fractionFromNoon, 0),
			  let days = other.julianDayNumber.subtracting(julianDayNumber, plus: f.integral)
		else { throw .dayCountNotRepresentable }
		return Interval(uncheckedDays: days, fractionalDay: f.remainder)
	}

	/// Returns the Julian Date advanced by the specified interval.
	///
	/// - Parameter interval: The interval to add.
	/// - Returns: This Julian Date plus `interval`.
	/// - Throws: ``JulianDateError/julianDayNumberNotRepresentable`` if the resulting Julian day
	///   number cannot be represented as a ``JulianDayNumber``.
	public func adding(_ interval: Interval) throws(JulianDateError) -> JulianDate {
		guard let f = normalizedSum(fractionFromNoon + interval.fractionalDay, 0),
			  let day = julianDayNumber.adding(interval.days, plus: f.integral)
		else { throw .julianDayNumberNotRepresentable }
		return JulianDate(uncheckedJulianDayNumber: day, fractionFromNoon: f.remainder)
	}

	/// Returns the Julian Date moved back by the specified interval.
	///
	/// - Parameter interval: The interval to subtract.
	/// - Returns: This Julian Date minus `interval`.
	/// - Throws: ``JulianDateError/julianDayNumberNotRepresentable`` if the resulting Julian day
	///   number cannot be represented as a ``JulianDayNumber``.
	public func subtracting(_ interval: Interval) throws(JulianDateError) -> JulianDate {
		guard let f = normalizedSum(fractionFromNoon - interval.fractionalDay, 0),
			  let day = julianDayNumber.subtracting(interval.days, plus: f.integral)
		else { throw .julianDayNumberNotRepresentable }
		return JulianDate(uncheckedJulianDayNumber: day, fractionFromNoon: f.remainder)
	}
}

extension JulianDate.Interval: Comparable {
	/// Returns `true` if the first interval is less than the second in signed numeric order.
	///
	/// Intervals are ordered as signed numbers of days, not by magnitude: an interval of
	/// -2 days is less than an interval of -1 day.
	///
	/// - Returns: `true` if `lhs` is numerically less than `rhs`; otherwise, `false`.
	public static func < (lhs: Self, rhs: Self) -> Bool {
		(lhs.days, lhs.fractionalDay) < (rhs.days, rhs.fractionalDay)
	}
}

extension JulianDate.Interval: CustomStringConvertible {
	/// A textual representation of the interval, such as `1 - 0.25 days`.
	public var description: String {
		if fractionalDay == 0 {
			return "\(days) days"
		} else {
			return "\(days) \(fractionalDay < 0 ? "-" : "+") \(abs(fractionalDay)) days"
		}
	}
}

extension JulianDate.Interval: CustomDebugStringConvertible {
	/// A textual representation of the interval's stored parts, suitable for debugging.
	public var debugDescription: String {
		"JulianDate.Interval(days: \(days), fractionalDay: \(fractionalDay))"
	}
}

extension JulianDate.Interval: Codable {
	private enum CodingKeys: String, CodingKey {
		case days, fractionalDay
	}

	/// Creates an interval by decoding and validating it from the specified decoder.
	///
	/// A decoded fractional day outside the right-open interval [-0.5, 0.5) is normalized as by
	/// ``init(days:fractionalDay:)``.
	///
	/// - Parameter decoder: The decoder to read data from.
	/// - Throws: `DecodingError.dataCorrupted` if the fractional day is not finite or the
	///   decoded values do not form a representable interval, or any error thrown by
	///   `decoder`.
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
