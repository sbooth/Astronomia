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
		guard let f = normalizedSum(fractionalDay, other.fractionalDay),
			  let n = days.adding(other.days, plus: f.integral)
		else { throw .dayCountNotRepresentable }
		return JulianDate.Interval(uncheckedDays: n, fractionalDay: f.remainder)
	}

	/// Returns the difference of this interval and another interval.
	///
	/// - Parameter other: The interval to subtract.
	/// - Returns: This interval minus `other`.
	/// - Throws: ``JulianDateError/dayCountNotRepresentable`` if the whole days in the result
	///   cannot be represented as an `Int`.
	public func subtracting(_ other: JulianDate.Interval) throws(JulianDateError) -> JulianDate.Interval {
		guard let f = normalizedSum(fractionalDay, -other.fractionalDay),
			  let n = days.subtracting(other.days, plus: f.integral)
		else { throw .dayCountNotRepresentable }
		return JulianDate.Interval(uncheckedDays: n, fractionalDay: f.remainder)
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
		guard days.isFinite else { throw .nonFiniteValue }
		do throws(JulianDateError) {
			return try adding(JulianDate.Interval(days: days))
		} catch {
			// Either the whole days in `days` do not fit in an `Int` on their own, or the result
			// does not fit. `self + days / 2` lies between `self` and the result, so if the
			// result is representable then so is that midpoint and adding the half twice
			// succeeds. Otherwise one of the two additions throws.
			let half = try JulianDate.Interval(days: days / 2)
			return try adding(half).adding(half)
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
		guard seconds.isFinite else { throw .nonFiniteValue }
		do throws(JulianDateError) {
			return try adding(JulianDate.Interval(seconds: seconds))
		} catch {
			// Either the whole days in `seconds` do not fit in an `Int` on their own, or the
			// result does not fit. `self + seconds / 2` lies between `self` and the result, so
			// if the result is representable then so is that midpoint and adding the half twice
			// succeeds. Otherwise one of the two additions throws.
			let half = try JulianDate.Interval(seconds: seconds / 2)
			return try adding(half).adding(half)
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
