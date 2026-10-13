//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate.Interval {
	/// Returns the sum of this interval and another interval.
	///
	/// - Parameter other: The interval to add.
	/// - Returns: This interval plus `other`.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func adding(_ other: JulianDate.Interval) throws(JulianDateError) -> JulianDate.Interval {
		try JulianDate.Interval { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.add(other)
		}
	}

	/// Returns the difference of this interval and another interval.
	///
	/// - Parameter other: The interval to subtract.
	/// - Returns: This interval minus `other`.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func subtracting(_ other: JulianDate.Interval) throws(JulianDateError) -> JulianDate.Interval {
		try JulianDate.Interval { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.subtract(other)
		}
	}
}

extension JulianDate.Interval {
	/// Returns this interval advanced by a whole number of days.
	///
	/// - Parameter days: The signed number of days to add.
	/// - Returns: This interval plus `days`.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func adding(days: Int) throws(JulianDateError) -> JulianDate.Interval {
		let (n, overflow) = self.days.addingReportingOverflow(days)
		guard !overflow else { throw .dayCountNotRepresentable }
		return JulianDate.Interval(uncheckedDays: n, fractionalDay: fractionalDay)
	}

	/// Returns this interval advanced by a number of days.
	///
	/// Only the result has to be representable: `days` may itself exceed the range of `Int`
	/// if this interval offsets it.
	///
	/// - Parameter days: The signed number of days to add.
	/// - Returns: This interval plus `days`.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `days` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result cannot
	///     be represented as an `Int`.
	public func adding(days: Double) throws(JulianDateError) -> JulianDate.Interval {
		try JulianDate.Interval { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.add(days)
		}
	}

	/// Returns this interval advanced by a number of seconds.
	///
	/// Only the result has to be representable: the whole days in `seconds` may themselves
	/// exceed the range of `Int` if this interval offsets them.
	///
	/// - Important: Assumes 86,400 seconds per day.
	/// - Parameter seconds: The signed number of seconds to add.
	/// - Returns: This interval plus `seconds`.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `seconds` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result cannot
	///     be represented as an `Int`.
	public func adding(seconds: Double) throws(JulianDateError) -> JulianDate.Interval {
		try JulianDate.Interval { acc throws(DayAccumulator.Failure) in
			try acc.add(self)
			try acc.add(seconds: seconds)
		}
	}

	/// Returns the interval with its sign reversed.
	///
	/// - Returns: The negation of this interval.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func negated() throws(JulianDateError) -> JulianDate.Interval {
		if fractionalDay == -0.5 {
			// -(d - 0.5) = (1 - d) - 0.5, keeping the fraction in [-0.5, 0.5)
			let (n, overflow) = 1.subtractingReportingOverflow(days)
			guard !overflow else { throw .dayCountNotRepresentable }
			return JulianDate.Interval(uncheckedDays: n, fractionalDay: -0.5)
		}
		let (n, overflow) = 0.subtractingReportingOverflow(days)
		guard !overflow else { throw .dayCountNotRepresentable }
		return JulianDate.Interval(uncheckedDays: n, fractionalDay: fractionalDay == 0 ? 0 : -fractionalDay)
	}
}

extension JulianDate.Interval {
	/// Returns this interval multiplied by an integer.
	///
	/// The whole days of the product are exact, and its fractional day is rounded once.
	///
	/// - Parameter k: The multiplier.
	/// - Returns: This interval times `k`.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func multiplied(by k: Int) throws(JulianDateError) -> JulianDate.Interval {
		let k64 = Int64(k)
		let wholeDays = Int64(days).multipliedFullWidth(by: k64)
		let (kHigh, kLow) = k64.exactDoubleComponents
		return try JulianDate.Interval { acc throws(DayAccumulator.Failure) in
			try acc.add(WideInteger(high: wholeDays.high, low: wholeDays.low))
			try acc.add(product: fractionalDay, kHigh)
			try acc.add(product: fractionalDay, kLow)
		}
	}

	/// Returns this interval multiplied by a scalar.
	///
	/// The product is computed without intermediate rounding, and its fractional day is
	/// rounded once.
	///
	/// - Parameter s: The multiplier.
	/// - Returns: This interval times `s`.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `s` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result cannot
	///     be represented as an `Int`.
	public func multiplied(by s: Double) throws(JulianDateError) -> JulianDate.Interval {
		let (daysHigh, daysLow) = Int64(days).exactDoubleComponents
		return try JulianDate.Interval { acc throws(DayAccumulator.Failure) in
			try acc.add(product: daysHigh, s)
			try acc.add(product: daysLow, s)
			try acc.add(product: fractionalDay, s)
		}
	}
}

private extension Int64 {
	/// Two values, each exactly representable as a `Double`, that sum to this value.
	///
	/// The high part is a multiple of 2^32 with at most 32 significant bits, and the low part
	/// is in the right-open interval [0, 2^32).
	var exactDoubleComponents: (high: Double, low: Double) {
		(Double(self & ~0xFFFF_FFFF), Double(self & 0xFFFF_FFFF))
	}
}
