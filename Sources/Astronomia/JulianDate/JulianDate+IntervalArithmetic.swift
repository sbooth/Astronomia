//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

extension JulianDate.Interval {
	/// An interval of zero days.
	public static let zero = JulianDate.Interval(uncheckedDays: 0, fractionalDay: 0)

	/// Returns the sum of this interval and another interval.
	///
	/// - Parameter other: The interval to add.
	/// - Returns: This interval plus `other`.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func adding(_ other: JulianDate.Interval) throws(JulianDateError) -> JulianDate.Interval {
		// Both fractions are in [-0.5, 0.5), so the sum is in [-1, 1) and the carry is -1, 0 or 1
		guard let f = (fractionalDay + other.fractionalDay).nearestIntegerAndRemainder,
			  let n = days.adding(other.days, plus: f.nearest)
		else { throw .dayCountNotRepresentable }
		return Self(uncheckedDays: n, fractionalDay: f.remainder)
	}

	/// Returns the difference of this interval and another interval.
	///
	/// - Parameter other: The interval to subtract.
	/// - Returns: This interval minus `other`.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func subtracting(_ other: JulianDate.Interval) throws(JulianDateError) -> JulianDate.Interval {
		// The difference of the fractions is in (-1, 1) and the carry is -1, 0 or 1
		guard let f = (fractionalDay - other.fractionalDay).nearestIntegerAndRemainder,
			  let n = days.subtracting(other.days, plus: f.nearest)
		else { throw .dayCountNotRepresentable }
		return JulianDate.Interval(uncheckedDays: n, fractionalDay: f.remainder)
	}

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
	/// - Parameter days: The signed number of days to add.
	/// - Returns: This interval plus `days`.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `days` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in `days` or in the
	///     result cannot be represented as an `Int`.
	public func adding(days: Double) throws(JulianDateError) -> JulianDate.Interval {
		try adding(JulianDate.Interval(days: days))
	}

	/// Returns this interval advanced by a number of seconds.
	///
	/// - Important: Assumes 86,400 seconds per day.
	/// - Parameter seconds: The signed number of seconds to add.
	/// - Returns: This interval plus `seconds`.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `seconds` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in `seconds` or in the
	///     result cannot be represented as an `Int`.
	public func adding(seconds: Double) throws(JulianDateError) -> JulianDate.Interval {
		try adding(JulianDate.Interval(seconds: seconds))
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

	/// Returns this interval scaled by an integer factor.
	///
	/// - Parameter factor: The factor to multiply by.
	/// - Returns: This interval multiplied by `factor`.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func multiplied(by factor: Int) throws(JulianDateError) -> JulianDate.Interval {
		let (d, productOverflow) = days.multipliedReportingOverflow(by: factor)
		guard !productOverflow,
			  let f = (fractionalDay * Double(factor)).nearestIntegerAndRemainder
		else { throw .dayCountNotRepresentable }
		let (n, sumOverflow) = d.addingReportingOverflow(f.nearest)
		guard !sumOverflow else { throw .dayCountNotRepresentable }
		return JulianDate.Interval(uncheckedDays: n, fractionalDay: f.remainder)
	}

	/// Returns this interval scaled by a factor.
	///
	/// The product of the whole days and `factor` is computed with its rounding error
	/// retained, so precision is not lost to the size of ``days``.
	///
	/// - Parameter factor: The factor to multiply by.
	/// - Returns: This interval multiplied by `factor`.
	/// - Throws:
	///   - ``JulianDateError/nonFiniteValue`` if `factor` is NaN or infinite.
	///   - ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result cannot
	///     be represented as an `Int`.
	public func multiplied(by factor: Double) throws(JulianDateError) -> JulianDate.Interval {
		guard factor.isFinite else { throw .nonFiniteValue }
		let d = Double(days)
		let product = d * factor
		guard product.isFinite else { throw .dayCountNotRepresentable }
		// The exact rounding error of `d * factor`
		let productError = (-product).addingProduct(d, factor)
		return try JulianDate.Interval(days1: product, days2: productError.addingProduct(fractionalDay, factor))
	}

	/// Returns the ratio of this interval to another interval.
	///
	/// For example, an interval of 3 days divided by an interval of 1.5 days is 2.
	///
	/// - Parameter other: The divisor.
	/// - Returns: This interval divided by `other`, or NaN or infinity if `other` is zero.
	public func ratio(to other: JulianDate.Interval) -> Double {
		inDays / other.inDays
	}
}
