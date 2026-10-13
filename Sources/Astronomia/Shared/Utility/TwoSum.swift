//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The *2Sum* error-free transformation of a floating-point sum.
///
/// Returns `sum` and `error` such that `sum` is `a + b` rounded to the nearest `Double` and
/// the exact value of `a + b` is `sum + error`.
///
/// - Parameters:
///   - a: The first addend.
///   - b: The second addend.
/// - Returns: The rounded sum and its rounding error, or `nil` if `sum` is not finite
///   (either addend is NaN or infinite, or the sum overflows).
/// - SeeAlso: [2Sum](https://en.wikipedia.org/wiki/2Sum)
func twoSum(_ a: Double, _ b: Double) -> (sum: Double, error: Double)? {
	let s = a + b
	guard s.isFinite else { return nil }
	let bb = s - a
	let e = (a - (s - bb)) + (b - bb)
	return (s, e)
}

/// Returns `a + b` as an integer plus a remainder in the right-open interval [-0.5, 0.5),
/// or `nil` if the inputs are non-finite or the integer cannot be represented as an `Int`.
///
/// The integer is computed exactly and the remainder is correctly rounded: it is the exact
/// remainder of `a + b` rounded once. For example, `normalizedSum(0.3, 0.4)` is `(1, -0.3)`,
/// whereas `(0.3 + 0.4).nearestIntegerAndRemainder` gives a remainder of
/// -0.30000000000000004 because the sum is rounded before the carry is removed.
///
/// To subtract, pass the negated second operand, which is exact.
///
/// - Parameters:
///   - a: The first addend.
///   - b: The second addend.
/// - Returns: The integral part and remainder of `a + b`, or `nil` if either input is not finite or
///   the integral part cannot be represented as an `Int`.
func normalizedSum(_ a: Double, _ b: Double) -> (integral: Int, remainder: Double)? {
	guard a.isFinite, b.isFinite else { return nil }
	let aRounded = a.rounded()
	let bRounded = b.rounded()
	guard let intA = Int(exactly: aRounded),
		  let intB = Int(exactly: bRounded)
	else { return normalizedTwoSum(a, b) }
	guard let (carry, remainder) = normalizedResidueSum(a - aRounded, b - bRounded),
		  let sum = intA.adding(intB, plus: carry)
	else { return nil }
	return (sum, remainder)
}

/// ``normalizedSum(_:_:)`` for parts whose nearest integers are not both representable as
/// `Int`.
///
/// The parts are first combined with ``twoSum(_:_:)``, so this returns `nil` if `a + b`
/// overflows `Double` even when the integer would otherwise be representable.
///
/// - Returns: The integral part and remainder of `a + b`, or `nil` if `a + b` overflows or its
///   integral part cannot be represented as an `Int`.
private func normalizedTwoSum(_ a: Double, _ b: Double) -> (integral: Int, remainder: Double)? {
	guard let (sum, sumError) = twoSum(a, b) else { return nil }
	let roundedSum = sum.rounded()
	let roundedError = sumError.rounded()
	guard let (base, offset) = roundedSum.integralParts, let intError = Int(exactly: roundedError) else { return nil }
	guard let (carry, remainder) = normalizedResidueSum(sum - roundedSum, sumError - roundedError) else { return nil }
	let (correction, overflow) = intError.addingReportingOverflow(carry)
	guard !overflow, let whole = base.adding(offset, plus: correction) else { return nil }
	return (whole, remainder)
}

/// Returns the sum of two residues as a carry plus a correctly rounded remainder in the
/// right-open interval [-0.5, 0.5).
///
/// The residues are the exact differences between values and their nearest integers, so each
/// lies in [-0.5, 0.5]. Their sum is computed with ``twoSum(_:_:)`` and its rounding error is
/// added back only after the carry is removed. When the sum carries, the remainder is smaller
/// in magnitude than the sum and can hold bits the rounded sum could not, so it is rounded
/// only once.
///
/// - Parameters:
///   - x: The first residue.
///   - y: The second residue.
/// - Returns: The carry, which is -1, 0 or 1, and the remainder, or `nil` if either residue
///   is not finite.
private func normalizedResidueSum(_ x: Double, _ y: Double) -> (carry: Int, remainder: Double)? {
	guard let (sum, error) = twoSum(x, y),
		  let (n1, r1) = sum.nearestIntegerAndRemainder,
		  // `r1 + error` is the exact remainder. Rounding it can reach ±0.5 or just beyond,
		  // so it is normalized again.
		  let (n2, r2) = (r1 + error).nearestIntegerAndRemainder
	else { return nil }
	// |x + y| ≤ 1, so both carries are small and their sum cannot overflow
	return (n1 + n2, r2)
}
