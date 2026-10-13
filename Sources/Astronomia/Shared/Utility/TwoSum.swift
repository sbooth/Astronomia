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
