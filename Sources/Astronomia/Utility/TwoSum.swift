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
/// The integer is computed exactly. The remainder is the sum of the parts' fractional
/// residues, so it may be rounded once.
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
	let residual = (a - aRounded) + (b - bRounded)
	guard let (nearest, remainder) = residual.nearestIntegerAndRemainder else { return nil }
	guard let sum = intA.adding(intB, plus: nearest) else { return nil }
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
	let residual = (sum - roundedSum) + (sumError - roundedError)
	guard let (nearest, remainder) = residual.nearestIntegerAndRemainder else { return nil }
	let (correction, overflow) = intError.addingReportingOverflow(nearest)
	guard !overflow, let whole = base.adding(offset, plus: correction) else { return nil }
	return (whole, remainder)
}
