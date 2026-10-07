//
// SPDX-FileCopyrightText: 2021 Stephen F. Booth <contact@sbooth.dev>
// SPDX-License-Identifier: MIT
//
// Part of https://github.com/sbooth/Astronomia
//

/// Knuth's *TwoSum* error-free transformation of a floating-point sum.
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

/// Returns `a + b` as an integer plus a fraction in the right-open interval [-0.5, 0.5),
/// or `nil` if a part is not finite, the integral part of either is not representable as an `Int`,
/// or the result is not representable.
func normalizedTwoSum(_ a: Double, _ b: Double) -> (whole: Int, fraction: Double)? {
#if true
	let wa = a.rounded()
	let wb = b.rounded()
//	guard let ia = Int(exactly: wa), let ib = Int(exactly: wb) else { return nil }
	guard let ia = Int(exactly: wa), let ib = Int(exactly: wb) else {
		guard let (s, e) = twoSum(a, b), e == 0, s != a else { return nil }
		return normalizedTwoSum(s, 0)
	}

	let g = (a - wa) + (b - wb)
	var v = g.rounded()
	var fraction = g - v
	if fraction == 0.5 {
		v += 1
		fraction = -0.5
	}

	let (low, lowOverflow) = ib.addingReportingOverflow(Int(v))
	guard !lowOverflow else { return nil }
	let (whole, overflow) = ia.addingReportingOverflow(low)
	guard !overflow else { return nil }

	return (whole, fraction + 0.0)
#else
	guard let (s, e) = twoSum(a, b) else { return nil }

	let ws = s.rounded()
	guard let wholeS = Int(exactly: ws) else { return nil }

	let we = e.rounded()
	guard let wholeE = Int(exactly: we) else { return nil }

	// Exact residual after removing the integral portions.
	let g = (s - ws) + (e - we)

	var v = g.rounded()
	var fraction = g - v
	// Canonical interval is [-0.5, 0.5).
	// Move +0.5 to the upper whole-number boundary.
	if fraction == 0.5 {
		v += 1
		fraction = -0.5
	}

	let (wholeWithError, overflowE) = wholeS.addingReportingOverflow(wholeE)
	guard !overflowE else { return nil }

	let (normalizedWhole, overflowV) = wholeWithError.addingReportingOverflow(Int(v))
	guard !overflowV else { return nil }

	return (normalizedWhole, fraction + 0.0)
#endif
}
