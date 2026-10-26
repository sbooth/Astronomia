//
// SPDX-FileCopyrightText: 2026 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// An exact running sum of days.
///
/// Whole days are held exactly in a 128-bit integer, so intermediate sums may leave the range
/// of `Int` as long as the final result returns to it. The fractional day is held as an
/// unevaluated double-double `hi + lo` whose exact value lies in the right-open interval
/// [-0.5, 0.5). The result is faithfully rounded: its fraction is within 1 ulp of the exact sum.
///
/// Every `add` either succeeds or throws and leaves the accumulator unchanged.
struct DayAccumulator {
	/// The reason an accumulation failed.
	enum Failure: Error {
		/// An input was NaN or infinite.
		case nonFiniteValue
		/// The inputs were finite, but the sum or an intermediate value is not representable.
		case overflow
	}

	/// The whole days of the sum, held exactly.
	///
	/// May temporarily leave the range of `Int`; only ``result()`` requires it to fit.
	private var days: WideInteger
	/// The leading part of the fractional day.
	///
	/// Together with ``lo``, an unevaluated sum whose exact value lies in the right-open
	/// interval [-0.5, 0.5).
	private var hi: Double = 0
	/// The trailing part of the fractional day: the error of ``hi``, with
	/// `|lo| ≤ ulp(hi) / 2`.
	private var lo: Double = 0

	/// Creates an accumulator holding `days` whole days.
	///
	/// - Parameter days: The initial number of days.
	init(days: Int = 0) {
		self.days = WideInteger(days)
	}

	/// Adds `n` days.
	///
	/// - Parameter n: The signed number of days to add.
	/// - Throws: ``Failure/overflow`` if the whole days overflow 128 bits.
	mutating func add(_ n: Int) throws(Failure) {
		self = try adding(n)
	}

	/// Subtracts `n` days.
	///
	/// Unlike `add(-n)`, this does not overflow when `n` is `Int.min`.
	///
	/// - Parameter n: The signed number of days to subtract.
	/// - Throws: ``Failure/overflow`` if the whole days overflow 128 bits.
	mutating func subtract(_ n: Int) throws(Failure) {
		// The negation of any Int fits in 128 bits.
		self = try adding(WideInteger(n).negated()!)
	}

	/// Adds `n` days.
	///
	/// - Parameter n: The signed number of days to add.
	/// - Throws: ``Failure/overflow`` if the whole days overflow 128 bits.
	mutating func add(_ n: WideInteger) throws(Failure) {
		self = try adding(n)
	}

	/// Adds `x` days.
	///
	/// - Parameter x: The signed number of days to add.
	/// - Throws:
	///   - ``Failure/nonFiniteValue`` if `x` is NaN or infinite.
	///   - ``Failure/overflow`` if the sum overflows 128 bits.
	mutating func add(_ x: Double) throws(Failure) {
		self = try adding(x)
	}

	/// Adds `a + b` days.
	///
	/// The parts are combined exactly before their whole days are taken, so each part may
	/// exceed the 128-bit range on its own as long as their sum does not.
	///
	/// - Parameters:
	///   - a: The first part of the signed number of days to add.
	///   - b: The second part of the signed number of days to add.
	/// - Throws:
	///   - ``Failure/nonFiniteValue`` if `a` or `b` is NaN or infinite.
	///   - ``Failure/overflow`` if `a + b` overflows `Double` or the sum overflows 128 bits.
	mutating func add(sum a: Double, _ b: Double) throws(Failure) {
		self = try adding(sum: a, b)
	}

	/// Adds `a × b` days with no intermediate rounding.
	///
	/// - Parameters:
	///   - a: The first factor.
	///   - b: The second factor.
	/// - Throws:
	///   - ``Failure/nonFiniteValue`` if `a` or `b` is NaN or infinite.
	///   - ``Failure/overflow`` if the product overflows `Double` or the sum overflows
	///     128 bits.
	mutating func add(product a: Double, _ b: Double) throws(Failure) {
		self = try adding(product: a, b)
	}

	/// Adds `s` seconds, assuming 86,400 seconds per day.
	///
	/// - Parameter s: The signed number of seconds to add.
	/// - Throws:
	///   - ``Failure/nonFiniteValue`` if `s` is NaN or infinite.
	///   - ``Failure/overflow`` if the sum overflows 128 bits.
	mutating func add(seconds s: Double) throws(Failure) {
		self = try adding(seconds: s)
	}

	/// Adds `a + b` seconds, assuming 86,400 seconds per day.
	///
	/// The parts are combined exactly before their whole days are taken, so each part may
	/// exceed the 128-bit range on its own as long as their sum does not.
	///
	/// - Parameters:
	///   - a: The first part of the signed number of seconds to add.
	///   - b: The second part of the signed number of seconds to add.
	/// - Throws:
	///   - ``Failure/nonFiniteValue`` if `a` or `b` is NaN or infinite.
	///   - ``Failure/overflow`` if `a + b` overflows `Double` or the sum overflows 128 bits.
	mutating func add(seconds a: Double, _ b: Double) throws(Failure) {
		self = try adding(seconds: a, b)
	}

	/// The accumulated sum as whole days and a fraction in the right-open interval [-0.5, 0.5).
	///
	/// The fraction is never `-0.0`.
	///
	/// - Throws: ``Failure/overflow`` if the whole days cannot be represented as an `Int`.
	func result() throws(Failure) -> (days: Int, fractionalDay: Double) {
		var d = days
		var f = hi + lo
		// The exact total is in [-0.5, 0.5), and rounding is monotone, so `f` is at least -0.5.
		// It can reach 0.5 only when a total just below 0.5 rounds up; carry to stay canonical.
		if f == 0.5 {
			guard let carried = d.adding(1) else { throw .overflow }
			d = carried
			f = -0.5
		}
		assert(f >= -0.5 && f < 0.5, "Fraction must be in the right-open interval [-0.5, 0.5)")
		guard let wholeDays = d.intValue else { throw .overflow }
		return (wholeDays, f == 0 ? 0 : f)
	}

	/// The accumulated sum as whole days rounded down and a fraction since midnight
	/// in the right-open interval [0, 1).
	///
	/// A total just below a whole number of days whose fraction rounds up to 1 is returned as
	/// the next whole day with a fraction of 0. The fraction is never `-0.0`.
	///
	/// - Throws: ``Failure/overflow`` if the whole days cannot be represented as an `Int`.
	func flooredResult() throws(Failure) -> (days: Int, fractionSinceMidnight: Double) {
		// The fractional day hi + lo has the sign of hi, except that a zero hi can carry a
		// lo too small to affect it.
		guard hi < 0 || (hi == 0 && lo < 0) else {
			guard let wholeDays = days.intValue else { throw .overflow }
			let f = hi + lo
			return (wholeDays, f == 0 ? 0 : f)
		}
		// Borrow a day, so the fraction is 1 + hi + lo, in [0.5, 1). 1 + hi is computed
		// exactly as s + e and rounded once with lo.
		guard let (s, e) = twoSum(1, hi) else { throw .overflow }
		let f = s + (e + lo)
		if f == 1 {
			// The total is so close to the next midnight that it rounds to it.
			guard let wholeDays = days.intValue else { throw .overflow }
			return (wholeDays, 0)
		}
		guard let borrowed = days.adding(-1), let wholeDays = borrowed.intValue else { throw .overflow }
		return (wholeDays, f)
	}
}

// Each operation is computed on a copy and returned, so a throw can never leave the
// accumulator partially updated. The public mutating methods assign the result only on success.
extension DayAccumulator {
	private func adding(_ n: Int) throws(Failure) -> DayAccumulator {
		try adding(WideInteger(n))
	}

	private func adding(_ n: WideInteger) throws(Failure) -> DayAccumulator {
		guard let d = days.adding(n) else { throw .overflow }
		var result = self
		result.days = d
		return result
	}

	private func adding(_ x: Double) throws(Failure) -> DayAccumulator {
		guard x.isFinite else { throw .nonFiniteValue }
		let n = x.rounded(.toNearestOrEven)
		// Subtracting the nearest integer is always exact and leaves a value in [-0.5, 0.5].
		let r = x - n
		var result = self
		if n != 0 {
			// Fast path: whole days that fit in 64 bits, the common case, skip the general
			// 128-bit conversion.
			let whole: WideInteger
			if let w = Int64(exactly: n) {
				whole = WideInteger(w)
			} else {
				guard let w = WideInteger(exactly: n) else { throw .overflow }
				whole = w
			}
			guard let d = days.adding(whole) else { throw .overflow }
			result.days = d
		}
		// Fast path: an integral x leaves the fractional day unchanged.
		return r == 0 ? result : try result.addingFraction(r)
	}

	private func adding(sum a: Double, _ b: Double) throws(Failure) -> DayAccumulator {
		guard a.isFinite, b.isFinite else { throw .nonFiniteValue }
		// s + e is exactly a + b, and s is within half an ulp of it.
		guard let (s, e) = twoSum(a, b) else { throw .overflow }
		return try adding(s).adding(e)
	}

	private func adding(seconds a: Double, _ b: Double) throws(Failure) -> DayAccumulator {
		guard a.isFinite, b.isFinite else { throw .nonFiniteValue }
		guard let (s, e) = twoSum(a, b) else { throw .overflow }
		return try adding(seconds: s).adding(seconds: e)
	}

	private func adding(product a: Double, _ b: Double) throws(Failure) -> DayAccumulator {
		guard a.isFinite, b.isFinite else { throw .nonFiniteValue }
		let p = a * b
		guard p.isFinite else { throw .overflow }
		// The rounding error of the product, recovered exactly with a fused multiply-add.
		let e = (-p).addingProduct(a, b)
		return try adding(p).adding(e)
	}

	private func adding(seconds s: Double) throws(Failure) -> DayAccumulator {
		guard s.isFinite else { throw .nonFiniteValue }
		let n = (s / secondsPerDay).rounded(.toNearestOrEven)
		let r = s.addingProduct(-n, secondsPerDay)        // exact
		let q = r / secondsPerDay
		let residual = r.addingProduct(-q, secondsPerDay) // exact remainder of the division
		return try adding(n).adding(q).adding(residual / secondsPerDay)
	}

	/// Adds `x`, which must be finite and in the closed interval [-0.5, 0.5], to the fractional
	/// day.
	private func addingFraction(_ x: Double) throws(Failure) -> DayAccumulator {
		assert(x.isFinite && x >= -0.5 && x <= 0.5, "Fraction to add must be in the closed interval [-0.5, 0.5]")
		// All operands are bounded by 1, so these twoSum calls cannot fail.
		let v: Double
		let w: Double
		if lo == 0 {
			// Fast path: with no trailing part, one twoSum gives the exact, normalized sum.
			// This is the common case, since lo stays zero until a sum is inexact, and
			// matches what the full double-double addition below computes when lo is zero.
			guard let (s, e) = twoSum(hi, x) else { throw .overflow }
			(v, w) = (s, e)
		} else {
			// Double-double addition.
			guard let (s, e) = twoSum(hi, x),
				  let (t, f) = twoSum(lo, e),
				  let (u, g) = twoSum(s, t),
				  let (vv, ww) = twoSum(u, g + f)
			else { throw .overflow }
			(v, w) = (vv, ww)
		}

		var result = self
		result.hi = v
		result.lo = w

		// Normalize so that the exact total hi + lo lies in [-0.5, 0.5).
		// hi ∓ 1 is exact (Sterbenz); re-pairing with lo restores |lo| ≤ ulp(hi) / 2.
		if v > 0.5 || (v == 0.5 && w >= 0) {
			guard let d = days.adding(1), let (h, l) = twoSum(v - 1, w) else { throw .overflow }
			result.days = d
			result.hi = h
			result.lo = l
		} else if v < -0.5 || (v == -0.5 && w < 0) {
			guard let d = days.adding(-1), let (h, l) = twoSum(v + 1, w) else { throw .overflow }
			result.days = d
			result.hi = h
			result.lo = l
		}

		return result
	}
}
