//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// The *2Sum* error-free transformation of a floating-point sum.
///
/// Returns `sum` and `error` such that the exact value of `a + b` is represented
/// by `sum + error`, or `nil` if `sum` is not finite.
func twoSum(_ a: Double, _ b: Double) -> (sum: Double, error: Double)? {
	let s = a + b
	guard s.isFinite else { return nil }
	let bb = s - a
	let e = (a - (s - bb)) + (b - bb)
	return (s, e)
}

/// Returns `a + b` as an integer plus a remainder in the right-open interval [-0.5, 0.5),
/// or `nil` if the inputs are non-finite or the result cannot be represented.
func normalizedSum(_ a: Double, _ b: Double) -> (integral: Int, remainder: Double)? {
	guard a.isFinite, b.isFinite else {
		return nil
	}
	let aRounded = a.rounded()
	let bRounded = b.rounded()
	guard let intA = Int(exactly: aRounded),
		  let intB = Int(exactly: bRounded)
	else { return normalizedTwoPartSum(a, b) }
	let residual = (a - aRounded) + (b - bRounded)
	guard let (nearest, remainder) = residual.nearestIntegerAndRemainder else { return nil }
	guard let sum = intA.adding(intB, plus: nearest) else { return nil }
	return (sum, remainder)
}

/// ``normalizedSum(_:_:)`` for parts whose nearest integers are not both representable as `Int`.
private func normalizedTwoPartSum(_ a: Double, _ b: Double) -> (integral: Int, remainder: Double)? {
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
