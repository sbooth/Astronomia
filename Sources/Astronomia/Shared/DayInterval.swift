//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// A signed number of days, possibly fractional, stored as a whole number of days plus a
/// fractional day in the right-open interval [-0.5, 0.5).
///
/// A day interval measures days, not elapsed time. In a uniform timescale such as TAI or
/// TT the two agree. In UTC, a day containing a leap second is 86,401 (or 86,399) seconds
/// long, so the seconds-based accessors, which assume 86,400 seconds per day, can differ
/// from elapsed time by up to one second per leap second crossed.
public struct DayInterval: Hashable, Sendable {
	/// The interval rounded to the nearest whole number of days, with halves rounded up.
	///
	/// This is not the truncated number of whole days: an interval of 0.75 days has
	/// ``days`` equal to 1 and ``fractionalDay`` equal to -0.25.
	public let days: Int
	/// The remainder of the interval after ``days``, in the right-open interval [-0.5, 0.5).
	public let fractionalDay: Double

	/// Creates a day interval from parts that are already canonical.
	///
	/// - Precondition: `fractionalDay` is finite and in the right-open interval [-0.5, 0.5).
	init(uncheckedDays days: Int, fractionalDay: Double) {
		assert(fractionalDay.isFinite, "Fractional day must be finite")
		assert(fractionalDay >= -0.5 && fractionalDay < 0.5, "Fractional day is outside the right-open interval [-0.5, 0.5)")
		self.days = days
		self.fractionalDay = fractionalDay
	}
}

extension DayInterval {
	/// An interval of zero days.
	public static let zero = DayInterval(uncheckedDays: 0, fractionalDay: 0)
}

extension DayInterval {
	/// Creates a day interval from the specified number of days and fractional day.
	///
	/// `fractionalDay` need not lie in the right-open interval [-0.5, 0.5); whole days are
	/// carried into ``days``.
	///
	/// - Parameters:
	///   - days: The signed number of whole days.
	///   - fractionalDay: The signed number of additional days.
	/// - Throws:
	///   - ``DayIntervalError/nonFiniteValue`` if `fractionalDay` is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the total number of whole days cannot be
	///     represented as an `Int`.
	public init(days: Int, fractionalDay: Double = 0) throws(DayIntervalError) {
		try self.init { acc throws(DayAccumulator.Failure) in
			try acc.add(days)
			try acc.add(fractionalDay)
		}
	}

	/// Creates an interval from a single number of days.
	///
	/// - Parameter days: The signed number of days.
	/// - Throws:
	///   - ``DayIntervalError/nonFiniteValue`` if `days` is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the whole days in `days` cannot be
	///     represented as an `Int`.
	public init(days: Double) throws(DayIntervalError) {
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
	///   - ``DayIntervalError/nonFiniteValue`` if `days1` or `days2` is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the whole days in `days1 + days2` cannot be
	///     represented as an `Int`.
	public init(days1: Double, days2: Double) throws(DayIntervalError) {
		try self.init { acc throws(DayAccumulator.Failure) in
			try acc.add(sum: days1, days2)
		}
	}

	/// Creates an interval from a single number of seconds.
	///
	/// - Important: Assumes 86,400 seconds per day.
	/// - Parameter seconds: The signed number of seconds.
	/// - Throws:
	///   - ``DayIntervalError/nonFiniteValue`` if `seconds` is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the whole days in `seconds` cannot be
	///     represented as an `Int`.
	public init(seconds: Double) throws(DayIntervalError) {
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
	///   - ``DayIntervalError/nonFiniteValue`` if `seconds1` or `seconds2` is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the whole days in `seconds1 + seconds2` cannot be
	///     represented as an `Int`.
	public init(seconds1: Double, seconds2: Double) throws(DayIntervalError) {
		try self.init { acc throws(DayAccumulator.Failure) in
			try acc.add(seconds: seconds1, seconds2)
		}
	}
}

extension DayInterval {
	/// Creates an interval from the exact sum of the terms that `body` adds to an empty
	/// accumulator, rounding the fractional day once at the end.
	///
	/// - Parameter body: A closure that adds terms to the accumulator.
	/// - Throws:
	///   - ``DayIntervalError/nonFiniteValue`` if a term is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the sum or an intermediate value is
	///     not representable.
	init(accumulating body: (inout DayAccumulator) throws(DayAccumulator.Failure) -> Void) throws(DayIntervalError) {
		let sum: (days: Int, fractionalDay: Double)
		do throws(DayAccumulator.Failure) {
			var acc = DayAccumulator()
			try body(&acc)
			sum = try acc.result()
		} catch {
			switch error {
			case .nonFiniteValue: throw .nonFiniteValue
			case .overflow: throw .dayCountNotRepresentable
			}
		}
		self.init(uncheckedDays: sum.days, fractionalDay: sum.fractionalDay)
	}
}

extension DayAccumulator {
	/// Adds an interval.
	///
	/// - Parameter interval: The interval to add.
	/// - Throws: ``Failure/overflow`` if the sum overflows 128 bits.
	mutating func add(_ interval: DayInterval) throws(Failure) {
		var result = self
		try result.add(interval.days)
		try result.add(interval.fractionalDay)
		self = result
	}

	/// Subtracts an interval.
	///
	/// - Parameter interval: The interval to subtract.
	/// - Throws: ``Failure/overflow`` if the sum overflows 128 bits.
	mutating func subtract(_ interval: DayInterval) throws(Failure) {
		var result = self
		try result.subtract(interval.days)
		try result.add(-interval.fractionalDay)
		self = result
	}
}

extension DayInterval {
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
		(fractionalDay * secondsPerDay).addingProduct(Double(days), secondsPerDay)
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
		let s = fractionalDay * secondsPerDay
		var w = s.rounded()
		var f = s - w
		if f == 0.5 {
			w += 1
			f = -0.5
		}

		let (daySeconds, productOverflow) = days.multipliedReportingOverflow(by: 86_400)
		if !productOverflow {
			// `w` is in [-43,200, 43,200]
			let (seconds, sumOverflow) = daySeconds.addingReportingOverflow(Int(w))
			if !sumOverflow {
				return (Double(seconds), f)
			}
		}
		return (w.addingProduct(Double(days), secondsPerDay), f)
	}
}

extension DayInterval: Comparable {
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

extension DayInterval: CustomStringConvertible {
	/// A textual representation of the interval, such as `1 - 0.25 days`.
	public var description: String {
		if fractionalDay == 0 {
			return "\(days) days"
		} else {
			return "\(days) \(fractionalDay < 0 ? "-" : "+") \(abs(fractionalDay)) days"
		}
	}
}

extension DayInterval: CustomDebugStringConvertible {
	/// A textual representation of the interval's stored parts, suitable for debugging.
	public var debugDescription: String {
		"DayInterval(days: \(days), fractionalDay: \(fractionalDay))"
	}
}

extension DayInterval: Codable {
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

		do throws(DayIntervalError) {
			self = try DayInterval(days: days, fractionalDay: fractionalDay)
		} catch .nonFiniteValue {
			throw DecodingError.dataCorruptedError(forKey: .fractionalDay, in: container, debugDescription: "Fractional day must be finite")
		} catch .dayCountNotRepresentable {
			throw DecodingError.dataCorruptedError(forKey: .days, in: container, debugDescription: "The interval's whole days are not representable")
		}
	}
}
