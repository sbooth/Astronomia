//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension DayInterval {
	/// Returns the sum of this day interval and another day interval.
	///
	/// - Parameter other: The day interval to add.
	/// - Returns: This day interval plus `other`.
	/// - Throws: ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func adding(_ other: DayInterval) throws(DayIntervalError) -> DayInterval {
		try DayInterval { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.add(other)
		}
	}

	/// Returns the difference between this day interval and another day interval.
	///
	/// - Parameter other: The day interval to subtract.
	/// - Returns: This day interval minus `other`.
	/// - Throws: ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func subtracting(_ other: DayInterval) throws(DayIntervalError) -> DayInterval {
		try DayInterval { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.subtract(other)
		}
	}
}

extension DayInterval {
	/// Returns this day interval advanced by a whole number of days.
	///
	/// - Parameter days: The signed number of days to add.
	/// - Returns: This day interval plus `days`.
	/// - Throws: ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func adding(days: Int) throws(DayIntervalError) -> DayInterval {
		let (n, overflow) = self.days.addingReportingOverflow(days)
		guard !overflow else { throw .dayCountNotRepresentable }
		return DayInterval(uncheckedDays: n, fractionalDay: fractionalDay)
	}

	/// Returns this day interval advanced by a number of days.
	///
	/// Only the result has to be representable: `days` may itself exceed the range of `Int`
	/// if this day interval offsets it.
	///
	/// - Parameter days: The signed number of days to add.
	/// - Returns: This day interval plus `days`.
	/// - Throws:
	///   - ``DayIntervalError/nonFiniteValue`` if `days` is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the result cannot be
	///     represented as an `Int`.
	public func adding(days: Double) throws(DayIntervalError) -> DayInterval {
		try DayInterval { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.add(days)
		}
	}

	/// Returns this day interval advanced by a number of seconds.
	///
	/// Only the result has to be representable: the whole days in `seconds` may themselves
	/// exceed the range of `Int` if this day interval offsets them.
	///
	/// - Important: Assumes 86,400 seconds per day.
	/// - Parameter seconds: The signed number of seconds to add.
	/// - Returns: This day interval plus `seconds`.
	/// - Throws:
	///   - ``DayIntervalError/nonFiniteValue`` if `seconds` is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the result cannot be
	///     represented as an `Int`.
	public func adding(seconds: Double) throws(DayIntervalError) -> DayInterval {
		try DayInterval { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.add(seconds: seconds)
		}
	}

	/// Returns the interval with its sign reversed.
	///
	/// - Returns: The negation of this day interval.
	/// - Throws: ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func negated() throws(DayIntervalError) -> DayInterval {
		if fractionalDay == -0.5 {
			// -(d - 0.5) = (1 - d) - 0.5, keeping the fraction in [-0.5, 0.5)
			let (n, overflow) = 1.subtractingReportingOverflow(days)
			guard !overflow else { throw .dayCountNotRepresentable }
			return DayInterval(uncheckedDays: n, fractionalDay: -0.5)
		}
		let (n, overflow) = 0.subtractingReportingOverflow(days)
		guard !overflow else { throw .dayCountNotRepresentable }
		return DayInterval(uncheckedDays: n, fractionalDay: fractionalDay == 0 ? 0 : -fractionalDay)
	}
}

extension DayInterval {
	/// Returns this day interval multiplied by an integer.
	///
	/// The whole days of the product are exact, and its fractional day is rounded once.
	///
	/// - Parameter k: The multiplier.
	/// - Returns: This day interval times `k`.
	/// - Throws: ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func multiplied(by k: Int) throws(DayIntervalError) -> DayInterval {
		switch k {
		case 1:  return self
		case 0:  return .zero
		case -1: return try negated()
		default: break
		}

		let k64 = Int64(k)
		let wholeDays = Int64(days).multipliedFullWidth(by: k64)
		let (kHigh, kLow) = k64.exactDoubleComponents
		return try DayInterval { acc throws(DayAccumulator.Failure) in
			try acc.add(WideInteger(high: wholeDays.high, low: wholeDays.low))
			try acc.add(product: fractionalDay, kHigh)
			try acc.add(product: fractionalDay, kLow)
		}
	}

	/// Returns this day interval multiplied by a scalar.
	///
	/// The product is computed without intermediate rounding, and its fractional day is
	/// rounded once.
	///
	/// - Parameter s: The multiplier.
	/// - Returns: This day interval times `s`.
	/// - Throws:
	///   - ``DayIntervalError/nonFiniteValue`` if `s` is NaN or infinite.
	///   - ``DayIntervalError/dayCountNotRepresentable`` if the whole days in the result cannot
	///     be represented as an `Int`.
	public func multiplied(by s: Double) throws(DayIntervalError) -> DayInterval {
		guard s.isFinite else { throw .nonFiniteValue }
		if s == 1 { return self }
		if s == 0 { return .zero }
		if s == -1 { return try negated() }
		let (daysHigh, daysLow) = Int64(days).exactDoubleComponents
		return try DayInterval { acc throws(DayAccumulator.Failure) in
			try acc.add(product: daysHigh, s)
			try acc.add(product: daysLow, s)
			try acc.add(product: fractionalDay, s)
		}
	}
}

private extension Int64 {
	/// Two values, each exactly representable as a `Double`, that sum to this value.
	///
	/// Both parts have the same sign as this value (or are zero), and neither exceeds it in
	/// magnitude, so scaling them cannot overflow unless scaling the value itself would.
	/// The high part is a multiple of 2^32 with at most 32 significant bits, and the low part
	/// is in the open interval (-2^32, 2^32).
	var exactDoubleComponents: (high: Double, low: Double) {
		let low = self % 0x1_0000_0000
		return (Double(self - low), Double(low))
	}
}
